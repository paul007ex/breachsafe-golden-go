#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Conformance check, not a liveness check. Every assertion compares the running
# image against a value the build recorded, so drift between the Dockerfile and
# the published image is detected here rather than by a consumer.
#
# Usage:
#   golden-go-doctor              run every check, exit non-zero on any failure
#   golden-go-doctor --version    report image identity and exit
#   golden-go-doctor --json       report image identity as JSON and exit
#   golden-go-doctor --help       this text

DOCTOR_VERSION=1.1.0

usage() {
  sed -n '/^# Usage:/,/^#   golden-go-doctor --help/p' "$0" | sed 's/^# \{0,1\}//'
}

identity() {
  echo "golden-go-doctor ${DOCTOR_VERSION}"
  echo "  variant         ${GOLDEN_GO_VARIANT:-unknown}"
  echo "  recipe revision ${GOLDEN_GO_REVISION:-unknown}"
  echo "  go              $(go version 2>/dev/null | awk '{print $3}')"
  echo "  govulncheck     $(govulncheck -version 2>/dev/null | sed -n 's/^Scanner: govulncheck@//p')"
  echo "  golangci-lint   v$(golangci-lint version 2>/dev/null | sed -n 's/.*has version \([0-9.]*\) .*/\1/p')"
  echo "  cgo             CGO_ENABLED=$(go env CGO_ENABLED 2>/dev/null)"
  echo "  openssl         $(find / -name 'libcrypto.so.*' -o -name 'libssl.so.*' 2>/dev/null | wc -l | tr -d ' ') shared object(s)"
  echo "  fips module     $(find /usr/local/go/lib/fips140 -type f -name '*.zip' 2>/dev/null | wc -l | tr -d ' ') snapshot(s)"
}

identity_json() {
  printf '{"doctor":"%s","variant":"%s","revision":"%s","go":"%s","govulncheck":"%s","golangci_lint":"v%s","cgo_enabled":"%s","libcrypto_files":%s,"fips_snapshots":%s}\n' \
    "${DOCTOR_VERSION}" "${GOLDEN_GO_VARIANT:-unknown}" "${GOLDEN_GO_REVISION:-unknown}" \
    "$(go version 2>/dev/null | awk '{print $3}')" \
    "$(govulncheck -version 2>/dev/null | sed -n 's/^Scanner: govulncheck@//p')" \
    "$(golangci-lint version 2>/dev/null | sed -n 's/.*has version \([0-9.]*\) .*/\1/p')" \
    "$(go env CGO_ENABLED 2>/dev/null)" \
    "$(find / -name 'libcrypto.so.*' 2>/dev/null | wc -l | tr -d ' ')" \
    "$(find /usr/local/go/lib/fips140 -type f -name '*.zip' 2>/dev/null | wc -l | tr -d ' ')"
}

case "${1:-}" in
  --version|-V) identity; exit 0 ;;
  --json)       identity_json; exit 0 ;;
  --help|-h)    usage; exit 0 ;;
  "")           ;;
  *)            echo "golden-go-doctor: unknown option '$1'" >&2; usage >&2; exit 2 ;;
esac

set -u
set +e   # collect every failure rather than stopping at the first

fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
check(){ # description, expected, actual
  if [ "$2" = "$3" ]; then ok "$1 = $3"; else bad "$1: expected '$2', got '$3'"; fi
}

echo "golden-go doctor: ${GOLDEN_GO_VARIANT:-unknown} variant"
echo
echo "identity"
check "uid" 65532 "$(id -u)"
check "gid" 65532 "$(id -g)"

echo
echo "toolchain matches build inputs"
check "go version"    "${EXPECT_GO_VERSION:-UNSET}" "$(go version | awk '{print $3}')"
check "GOTOOLCHAIN"   "${EXPECT_GO_VERSION:-UNSET}" "${GOTOOLCHAIN:-UNSET}"
check "govulncheck"   "${EXPECT_GOVULNCHECK:-UNSET}"    "$(govulncheck -version 2>/dev/null | sed -n 's/^Scanner: govulncheck@//p')"
check "golangci-lint" "${EXPECT_GOLANGCI_LINT:-UNSET}" "v$(golangci-lint version 2>/dev/null | sed -n 's/.*has version \([0-9.]*\) .*/\1/p')"
for duplicate in gosec osv-scanner staticcheck; do
  if command -v "$duplicate" >/dev/null 2>&1; then bad "duplicate analyzer present: $duplicate"; else ok "no standalone $duplicate"; fi
done
if [ ! -r /etc/golden-go/golangci.yml ]; then
  bad "shared golangci policy missing"
elif golangci-lint linters --config /etc/golden-go/golangci.yml 2>/dev/null | grep -q '^gosec:' \
  && golangci-lint linters --config /etc/golden-go/golangci.yml 2>/dev/null | grep -q '^staticcheck:'; then
  ok "shared golangci policy enables gosec and staticcheck"
else
  bad "shared golangci policy does not enable gosec and staticcheck"
fi

echo
echo "cgo posture"
case "${GOLDEN_GO_VARIANT:-}" in
  lean) check "CGO_ENABLED" 0 "$(go env CGO_ENABLED)"
        if command -v gcc >/dev/null 2>&1; then bad "gcc present in lean variant"; else ok "no C compiler"; fi ;;
  cgo)  check "CGO_ENABLED" 1 "$(go env CGO_ENABLED)"
        if command -v gcc >/dev/null 2>&1; then ok "gcc present for -race"; else bad "gcc missing in cgo variant"; fi ;;
  *)    bad "GOLDEN_GO_VARIANT unset" ;;
esac

echo
echo "transitive crypto inventory (reported, not asserted: libapk requires libcrypto)"
apk list --installed 2>/dev/null | grep -iE '^(libcrypto3|libssl3|nss|nspr)-' | sed 's/^/  /' || echo "  none"
for p in nss nspr; do
  if apk list --installed 2>/dev/null | grep -q "^$p-"; then bad "$p present (unused TLS stack)"; else ok "no $p"; fi
done

echo
echo "workspace"
if [ -w /go/cache ]; then ok "/go/cache writable"; else bad "/go/cache not writable"; fi
if [ -w /workspace ]; then ok "/workspace writable"; else bad "/workspace not writable"; fi
module_cache_entries="$(find /go/pkg/mod -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
check "shipped module-cache entries" 0 "$module_cache_entries"

echo
echo "the toolchain actually builds and runs post-quantum Go"
d=$(mktemp -d)
cat > "$d/go.mod" <<'GOMOD'
module doctor
go 1.27
GOMOD
cat > "$d/main.go" <<'GOSRC'
package main

import (
	"crypto/hpke"
	"crypto/mldsa"
	"fmt"
)

func main() {
	kem, err := hpke.NewKEM(0x0042) // ML-KEM-1024
	if err != nil { panic(err) }
	k, err := kem.GenerateKey()
	if err != nil { panic(err) }
	ct, err := hpke.Seal(k.PublicKey(), hpke.HKDFSHA384(), hpke.AES256GCM(), []byte("doctor"), []byte("ok"))
	if err != nil { panic(err) }
	pt, err := hpke.Open(k, hpke.HKDFSHA384(), hpke.AES256GCM(), []byte("doctor"), ct)
	if err != nil { panic(err) }
	sk, err := mldsa.GenerateKey(mldsa.MLDSA87())
	if err != nil { panic(err) }
	sig, err := sk.Sign(nil, []byte("doctor"), nil)
	if err != nil { panic(err) }
	if err := mldsa.Verify(sk.PublicKey(), []byte("doctor"), sig, nil); err != nil { panic(err) }
	fmt.Printf("hpke=%s mldsa87_sig=%d\n", pt, len(sig))
}
GOSRC
if out=$(cd "$d" && go run . 2>&1); then ok "ML-KEM-1024 + HKDF-SHA384 + AES-256-GCM + ML-DSA-87: $out"; else bad "PQC build/run failed: $out"; fi
rm -rf "$d"

echo
if [ "$fail" -eq 0 ]; then echo 'golden-go doctor: PASS'; else echo 'golden-go doctor: FAIL'; exit 1; fi
