# syntax=docker/dockerfile:1
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

# Pinned digest: update only through a reviewed toolchain refresh.
FROM golang:1.26.6-alpine@sha256:3889b425f035be855a72fb4755265311293b6d414521f0a519d819df32222d83

ARG GOVULNCHECK_VERSION=v1.7.0
ARG STATICCHECK_VERSION=2025.1.1
ARG GOSEC_VERSION=v2.22.11
ARG OSV_SCANNER_VERSION=v2.4.0

ENV CGO_ENABLED=0 \
    GOFLAGS=-mod=readonly \
    GOTOOLCHAIN=go1.26.6 \
    GOBIN=/usr/local/bin \
    PATH=/usr/local/go/bin:/usr/local/bin:$PATH

RUN apk add --no-cache \
      bash \
      ca-certificates \
      git \
      jq \
      make \
      tar \
      wget \
    && update-ca-certificates \
    && go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION} \
    && go install honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION} \
    && go install github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION} \
    && go install github.com/google/osv-scanner/v2/cmd/osv-scanner@${OSV_SCANNER_VERSION} \
    && addgroup -S -g 65532 breachsafe \
    && adduser -S -D -H -u 65532 -G breachsafe breachsafe \
    && mkdir -p /workspace /go/cache /go/pkg \
    && chown -R 65532:65532 /workspace /go/cache /go/pkg

ENV GOCACHE=/go/cache \
    GOPATH=/go/pkg

WORKDIR /workspace
USER 65532:65532

LABEL org.opencontainers.image.title="BreachSAFE Go toolchain" \
      org.opencontainers.image.description="Pinned Go build, test, and security-gate environment" \
      org.opencontainers.image.licenses="PolyForm-Noncommercial-1.0.0"

ENTRYPOINT ["/bin/bash"]
