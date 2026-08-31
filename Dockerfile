# syntax=docker/dockerfile:1
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# recipe-revision: r6
# Two variants:
#   --target lean (default)  zero OpenSSL, zero NSS, no C compiler, no package manager.
#                            Carries the five independently invocable Go gates:
#                            goimports, staticcheck, gosec, govulncheck, golangci-lint.
#   --target cgo             adds gcc/musl-dev for `go test -race`, plus git. Retains
#                            OpenSSL, because git-over-HTTPS links
#                            libcurl -> libssl and cannot be removed.
#
# Deliberately absent from both variants: poppler-utils. It is one consumer's dependency
# (breachsafe-pdf), and it drags Mozilla NSS and NSPR, a second complete TLS stack, into
# every BQP Go build. That consumer builds its own image FROM this one.
#
# `go test -race` REQUIRES cgo. The lean variant cannot run it; docs/go-gates.md says so.

FROM golang:1.27.0-alpine3.24@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS builder
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ARG GOIMPORTS_VERSION=v0.49.0
ARG STATICCHECK_VERSION=v0.8.1
ARG GOSEC_VERSION=v2.29.0
ARG GOVULNCHECK_X_MOD_VERSION=v0.40.0
ENV GOBIN=/out
WORKDIR /build/govulncheck
# Alpine stable repositories intentionally supply current v3.24 security revisions. The
# published recipe tag and OCI digest freeze the resulting artifact after this one build.
# hadolint ignore=DL3018
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/root/.cache/go-build,sharing=locked \
    apk add --no-cache git \
 && go mod init golden-go-govulncheck-build \
 && go get golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION} \
 && go get golang.org/x/tools/cmd/goimports@${GOIMPORTS_VERSION} \
 && go get honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION} \
 && go get golang.org/x/mod@${GOVULNCHECK_X_MOD_VERSION} \
 && go build -trimpath -ldflags='-s -w' -o /out/govulncheck golang.org/x/vuln/cmd/govulncheck \
 && go build -trimpath -ldflags='-s -w' -o /out/goimports golang.org/x/tools/cmd/goimports \
 && go build -trimpath -ldflags='-s -w' -o /out/staticcheck honnef.co/go/tools/cmd/staticcheck \
 && go install -trimpath -ldflags='-s -w' github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION} \
 && go install -trimpath -ldflags='-s -w' github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION}

FROM golang:1.27.0-alpine3.24@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS lean
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ARG GOIMPORTS_VERSION=v0.49.0
ARG STATICCHECK_VERSION=v0.8.1
ARG GOSEC_VERSION=v2.29.0
ENV EXPECT_GO_VERSION=go1.27.0 \
    EXPECT_GOVULNCHECK=${GOVULNCHECK_VERSION} \
    EXPECT_GOLANGCI_LINT=${GOLANGCI_LINT_VERSION} \
    EXPECT_GOIMPORTS=${GOIMPORTS_VERSION} \
    EXPECT_STATICCHECK=${STATICCHECK_VERSION} \
    EXPECT_GOSEC=${GOSEC_VERSION}
ENV GOFLAGS=-mod=readonly GOTOOLCHAIN=go1.27.0 CGO_ENABLED=0 \
    GOBIN=/usr/local/bin PATH=/usr/local/go/bin:/usr/local/bin:$PATH \
    GOCACHE=/go/cache GOPATH=/go/pkg HOME=/tmp XDG_CACHE_HOME=/tmp/.cache \
    GOLDEN_GO_VARIANT=lean \
    GOLDEN_GO_REVISION=r6
COPY --from=builder /out/govulncheck /out/golangci-lint /out/goimports /out/staticcheck /out/gosec /usr/local/bin/
# Take security patches, keep only bash/jq/make, then remove the package manager
# and every OpenSSL consumer. Verified: go, bash, jq, make link none of it.
# hadolint ignore=DL3018
RUN apk upgrade --no-cache \
 && apk add --no-cache bash ca-certificates-bundle jq make \
 && addgroup -S -g 65532 breachsafe \
 && adduser -S -D -H -u 65532 -G breachsafe breachsafe \
 && mkdir -p /workspace /go/cache /go/pkg /etc/golden-go \
 && chmod 0755 /etc/golden-go \
 && chown -R 65532:65532 /workspace /go/cache /go/pkg \
 && rm -rf /usr/local/go/pkg/*/cmd /usr/local/go/test /usr/local/go/api \
 && apk del --no-scripts apk-tools \
 && rm -f /usr/bin/ssl_client /sbin/apk /usr/lib/libcrypto.so.3 /usr/lib/libssl.so.3 \
 && rm -rf /var/cache/apk /lib/apk /etc/apk
COPY --chmod=0444 .golangci.yml /etc/golden-go/golangci.yml
COPY --chmod=0755 doctor.sh /usr/local/bin/golden-go-doctor
WORKDIR /workspace
USER 65532:65532
ENTRYPOINT ["/bin/bash"]

LABEL org.opencontainers.image.title="BreachSAFE Golden Go" \
      org.opencontainers.image.description="Pinned non-root Go build and security-gate toolchain" \
      org.opencontainers.image.source="https://github.com/paul007ex/breachsafe-golden-go" \
      org.opencontainers.image.licenses="PolyForm-Noncommercial-1.0.0"

# ---------- cgo: race detector and anything linking C ----------
# Keeps apk, git, and OpenSSL because git-over-HTTPS requires them. OpenSSL is
# patched via `apk upgrade` and scanned by the release workflow rather than removed.
FROM golang:1.27.0-alpine3.24@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS cgo
ARG GOVULNCHECK_VERSION=v1.7.0
ARG GOLANGCI_LINT_VERSION=v2.13.2
ARG GOIMPORTS_VERSION=v0.49.0
ARG STATICCHECK_VERSION=v0.8.1
ARG GOSEC_VERSION=v2.29.0
ENV EXPECT_GO_VERSION=go1.27.0 \
    EXPECT_GOVULNCHECK=${GOVULNCHECK_VERSION} \
    EXPECT_GOLANGCI_LINT=${GOLANGCI_LINT_VERSION} \
    EXPECT_GOIMPORTS=${GOIMPORTS_VERSION} \
    EXPECT_STATICCHECK=${STATICCHECK_VERSION} \
    EXPECT_GOSEC=${GOSEC_VERSION}
ENV GOFLAGS=-mod=readonly GOTOOLCHAIN=go1.27.0 CGO_ENABLED=1 \
    GOBIN=/usr/local/bin PATH=/usr/local/go/bin:/usr/local/bin:$PATH \
    GOCACHE=/go/cache GOPATH=/go/pkg HOME=/tmp XDG_CACHE_HOME=/tmp/.cache \
    GOLDEN_GO_VARIANT=cgo \
    GOLDEN_GO_REVISION=r6
COPY --from=builder /out/govulncheck /out/golangci-lint /out/goimports /out/staticcheck /out/gosec /usr/local/bin/
# As above, the build consumes the current v3.24 security patch stream once; consumers pin
# the resulting immutable image digest rather than rebuilding the recipe for releases.
# hadolint ignore=DL3018
RUN apk upgrade --no-cache \
 && apk add --no-cache bash ca-certificates git gcc musl-dev make jq \
 && addgroup -S -g 65532 breachsafe \
 && adduser -S -D -H -u 65532 -G breachsafe breachsafe \
 && mkdir -p /workspace /go/cache /go/pkg /etc/golden-go \
 && chmod 0755 /etc/golden-go \
 && chown -R 65532:65532 /workspace /go/cache /go/pkg
COPY --chmod=0444 .golangci.yml /etc/golden-go/golangci.yml
COPY --chmod=0755 doctor.sh /usr/local/bin/golden-go-doctor
WORKDIR /workspace
USER 65532:65532
ENTRYPOINT ["/bin/bash"]

LABEL org.opencontainers.image.title="BreachSAFE Golden Go" \
      org.opencontainers.image.description="Pinned non-root Go build and security-gate toolchain" \
      org.opencontainers.image.source="https://github.com/paul007ex/breachsafe-golden-go" \
      org.opencontainers.image.licenses="PolyForm-Noncommercial-1.0.0"
