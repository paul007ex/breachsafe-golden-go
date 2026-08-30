# syntax=docker/dockerfile:1
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# recipe-revision: r3
# Two variants:
#   --target lean (default)  zero OpenSSL, zero NSS, no C compiler, no package manager.
#                            govulncheck + golangci-lint only (golangci-lint bundles
#                            gosec, staticcheck, errcheck, revive, gocritic, unused).
#   --target cgo             adds gcc/musl-dev for `go test -race`, plus git and the
#                            full gate set. Retains OpenSSL, because git-over-HTTPS links
#                            libcurl -> libssl and cannot be removed.
#
# Deliberately absent from both variants: poppler-utils. It is one consumer's dependency
# (breachsafe-pdf), and it drags Mozilla NSS and NSPR, a second complete TLS stack, into
# every BQP Go build. That consumer builds its own image FROM this one.
#
# `go test -race` REQUIRES cgo. The lean variant cannot run it; docs/go-gates.md says so.

FROM golang:1.27.0-alpine AS builder
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ARG STATICCHECK_VERSION=2025.1.1
ARG GOSEC_VERSION=v2.22.11
ENV GOBIN=/out
RUN apk add --no-cache git \
 && go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION} \
 && go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION} \
 && go install honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION} \
 && go install github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION}

FROM golang:1.27.0-alpine AS lean
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ENV EXPECT_GO_VERSION=go1.27.0 \
    EXPECT_GOVULNCHECK=${GOVULNCHECK_VERSION} \
    EXPECT_GOLANGCI_LINT=${GOLANGCI_LINT_VERSION}
ENV GOFLAGS=-mod=readonly GOTOOLCHAIN=go1.27.0 CGO_ENABLED=0 \
    GOBIN=/usr/local/bin PATH=/usr/local/go/bin:/usr/local/bin:$PATH \
    GOCACHE=/go/cache GOPATH=/go/pkg HOME=/tmp XDG_CACHE_HOME=/tmp/.cache \
    GOLDEN_GO_VARIANT=lean \
    GOLDEN_GO_REVISION=r2
COPY --from=builder /out/govulncheck /out/golangci-lint /usr/local/bin/
# Take security patches, keep only bash/jq/make, then remove the package manager
# and every OpenSSL consumer. Verified: go, bash, jq, make link none of it.
RUN apk upgrade --no-cache \
 && apk add --no-cache bash ca-certificates-bundle jq make \
 && addgroup -S -g 65532 breachsafe \
 && adduser -S -D -H -u 65532 -G breachsafe breachsafe \
 && mkdir -p /workspace /go/cache /go/pkg && chown -R 65532:65532 /workspace /go/cache /go/pkg \
 && rm -rf /usr/local/go/pkg/*/cmd /usr/local/go/test /usr/local/go/api \
 && apk del --no-scripts apk-tools \
 && rm -f /usr/bin/ssl_client /sbin/apk /usr/lib/libcrypto.so.3 /usr/lib/libssl.so.3 \
 && rm -rf /var/cache/apk /lib/apk /etc/apk
COPY --chmod=0755 doctor.sh /usr/local/bin/golden-go-doctor
WORKDIR /workspace
USER 65532:65532
ENTRYPOINT ["/bin/bash"]

# ---------- cgo: race detector and anything linking C ----------
# Keeps apk, git, and OpenSSL because git-over-HTTPS requires them. OpenSSL is
# patched via `apk upgrade` and scanned by the release workflow rather than removed.
FROM golang:1.27.0-alpine AS cgo
ARG OSV_SCANNER_VERSION=v2.4.0
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ARG STATICCHECK_VERSION=2025.1.1
ARG GOSEC_VERSION=v2.22.11
ENV EXPECT_GO_VERSION=go1.27.0 \
    EXPECT_GOVULNCHECK=${GOVULNCHECK_VERSION} \
    EXPECT_GOLANGCI_LINT=${GOLANGCI_LINT_VERSION}
ENV EXPECT_OSV_SCANNER=${OSV_SCANNER_VERSION} \
    EXPECT_STATICCHECK=${STATICCHECK_VERSION} \
    EXPECT_GOSEC=${GOSEC_VERSION}
ENV GOFLAGS=-mod=readonly GOTOOLCHAIN=go1.27.0 CGO_ENABLED=1 \
    GOBIN=/usr/local/bin PATH=/usr/local/go/bin:/usr/local/bin:$PATH \
    GOCACHE=/go/cache GOPATH=/go/pkg HOME=/tmp XDG_CACHE_HOME=/tmp/.cache \
    GOLDEN_GO_VARIANT=cgo \
    GOLDEN_GO_REVISION=r2
COPY --from=builder /out/govulncheck /out/golangci-lint /out/staticcheck /out/gosec /usr/local/bin/
RUN apk upgrade --no-cache \
 && apk add --no-cache bash ca-certificates git gcc musl-dev make jq \
 && go install github.com/google/osv-scanner/v2/cmd/osv-scanner@${OSV_SCANNER_VERSION} \
 && addgroup -S -g 65532 breachsafe \
 && adduser -S -D -H -u 65532 -G breachsafe breachsafe \
 && mkdir -p /workspace /go/cache /go/pkg && chown -R 65532:65532 /workspace /go/cache /go/pkg
COPY --chmod=0755 doctor.sh /usr/local/bin/golden-go-doctor
WORKDIR /workspace
USER 65532:65532
ENTRYPOINT ["/bin/bash"]
