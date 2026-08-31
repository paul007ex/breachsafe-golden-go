<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

# BreachSAFE Go toolchain

Shared, pinned CI and build image for BreachSAFE Go repositories. A toolchain image, not an
application runtime.

## Contents

1. [Variants](#1-variants)
2. [What is in each image](#2-what-is-in-each-image)
3. [Tags](#3-tags)
4. [Cryptographic posture](#4-cryptographic-posture)
5. [Local use](#5-local-use)
6. [Refresh procedure](#6-refresh-procedure)

## 1. Variants

| Target | For | `CGO_ENABLED` | OpenSSL |
|---|---|:--:|:--:|
| `lean` (default) | every pure-Go repository | `0` | **none** |
| `cgo` | `go test -race`, `breachsafe-pdf` rendering, anything linking C | `1` | present, patched |

`go test -race` **requires cgo**. The lean variant cannot run it. That gate lives in the cgo
variant, and `docs/go-gates.md` records which gates need which image.

## 2. What is in each image

Every installed package, not a summary.

| | lean | cgo |
|---|---|---|
| Go | 1.27.0, `GOTOOLCHAIN` pinned | same |
| `govulncheck` | v1.7.0 + fixed `x/mod` v0.40.0 | same |
| `golangci-lint` | v2.13.2 | v2.13.2 |
| apk packages | `bash`, `ca-certificates-bundle`, `jq`, `make` | the above plus `git`, `gcc`, `musl-dev`, `ca-certificates` |
| package manager | **removed** | present |
| C compiler | **absent** | `gcc`, `musl-dev` |

`golangci-lint` v2.13.2 bundles Go-1.27-capable Staticcheck 2026.2.1, gosec v2.28.0,
`errcheck`, `revive`, `gocritic`, `ineffassign`, and `unused`. Both variants carry the common
policy at `/etc/golden-go/golangci.yml`; consumers select it explicitly with `--config`.
Standalone `gosec` and `staticcheck` are intentionally absent: duplicate analyzers add binary
and dependency surface while producing version-dependent results.

OSV-Scanner is also intentionally external. Its multi-ecosystem Scalibr pipeline pulls container,
filesystem, package-manager, database, and archive parsers that do not belong in a Go-only
toolchain. Go consumers use `govulncheck`; image consumers run pinned image scanners separately.

The official govulncheck v1.7.0 module currently resolves `golang.org/x/mod` v0.39.0, which image
scanners flag for CVE-2026-56864 and CVE-2026-56865. Its own binary-mode analysis shows neither
vulnerable symbol is reachable, but this image does not suppress the findings: the builder uses
the exact v1.7.0 source with only `x/mod` raised to fixed v0.40.0. Remove that explicit override
when an official govulncheck release includes the fix.

Both images run as UID/GID 65532 and contain no application source or credentials. Product
images should use their own minimal runtime base. Compilation happens only in builder stages;
Doctor fails if any Go module-cache content reaches a shipped variant.

## 3. Tags

Derived from the `FROM golang:` line, so a tag can never disagree with the image contents.

| Tag | Mutability | Use it when |
|---|---|---|
| `1.27.0-r5` | **immutable**, the workflow refuses to overwrite | reproducible builds, release provenance, lockfiles |
| `1.27.0` | moves on each recipe revision | ordinary consumers pinned to a Go patch |
| `1.27` | moves on each patch | ordinary consumers |
| `latest` | moves | interactive use only |

The publish workflow records the image digest in the job summary and as an artifact. Pin the
digest when a tag is not strong enough.

## 4. Cryptographic posture

**The lean image contains no OpenSSL, no NSS, and no NSPR.** Verified in CI by a filesystem
search that fails the build on any match. Go's cryptography is pure Go and links none of it.

The cgo image **does** contain OpenSSL, and it cannot be removed: `git` over HTTPS links
`libcurl`, which links `libssl`. It is patched with `apk upgrade` at build time and scanned by
the release workflow. Only four things ever linked it: `apk`, `ssl_client`, `git-remote-https`,
and `libcurl`. `go`, `bash`, `git` itself, `jq`, and `make` link none of it.

`lib/fips140/` is preserved in both images, so `GOFIPS140=v1.0.0` builds against the
FIPS 140-3 validated Go Cryptographic Module, CMVP certificate #5247. CI proves the resulting
binary records `GOFIPS140` in `go version -m`.

Caveat worth knowing before you rely on it: `crypto/mldsa` is **not** in module v1.0.0. Code
that calls it compiles under `GOFIPS140=v1.0.0` and then panics at run time with
`mldsa: methods are unreachable in FIPS 140-3 Go Cryptographic Module v1.0.0`. Module v1.26.0,
which contains ML-DSA, is on the CMVP Modules In Process list.

## 5. Local use

```sh
docker build --target lean -t breachsafe-go-toolchain:dev .
docker run --rm breachsafe-go-toolchain:dev golden-go-doctor

docker run --rm -v "$PWD:/workspace" breachsafe-go-toolchain:dev \
  -c 'gofmt -l . && go vet ./... && go test ./... && go mod verify && govulncheck ./... && golangci-lint run --config /etc/golden-go/golangci.yml ./...'

# -race needs the cgo variant
docker build --target cgo -t breachsafe-go-toolchain:cgo .
docker run --rm -v "$PWD:/workspace" breachsafe-go-toolchain:cgo -c 'go test -race ./...'
```

## 6. Refresh procedure

The multi-architecture base image digest and every tool version are explicit build inputs, and `doctor.sh`
asserts the running image against them. A refresh must:

1. update the `FROM` digest and any tool `ARG`;
2. run `golden-go-doctor` in both variants, which fails on any version mismatch;
3. run the gates in `.github/workflows/ci.yml` against `testdata/fixture`;
4. publish, which fails closed if the immutable recipe tag already exists and verifies the
   provenance attestation.

Alpine package revisions intentionally follow the current security patch stream for the pinned
`v3.24` release during that one publish build. Rebuilding the recipe later is not the release
contract; the published OCI digest, SBOM, and provenance are. Consumers pin that digest.

The publish workflow scans the exact lean and cgo image digests with a commit-pinned Trivy
action and fails on every HIGH or CRITICAL finding. The scanner stays outside the image so its
multi-ecosystem dependency graph is not inherited by every Go build. `govulncheck` remains the
source-aware vulnerability gate for each consumer's own Go module.

Steps 2 through 4 are enforced by CI, not by convention.
