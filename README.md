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
| `govulncheck` | v1.7.0 | v1.7.0 |
| `golangci-lint` | v2.13.2 | v2.13.2 |
| `osv-scanner` | absent | v2.4.0 |
| apk packages | `bash`, `ca-certificates-bundle`, `jq`, `make` | the above plus `git`, `gcc`, `musl-dev`, `ca-certificates` |
| package manager | **removed** | present |
| C compiler | **absent** | `gcc`, `musl-dev` |

`golangci-lint` bundles `gosec`, `staticcheck`, `errcheck`, `revive`, `gocritic`, `ineffassign`,
and `unused`. Standalone `gosec` and `staticcheck` binaries are therefore not installed; enable
them as linters instead.

Both images run as UID/GID 65532 and contain no application source or credentials. Product
images should use their own minimal runtime base.

## 3. Tags

Derived from the `FROM golang:` line, so a tag can never disagree with the image contents.

| Tag | Mutability | Use it when |
|---|---|---|
| `1.27.0` | **immutable**, the workflow refuses to overwrite | reproducible builds, release provenance, lockfiles |
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
  -c 'gofmt -l . && go vet ./... && go test ./... && go mod verify && govulncheck ./... && golangci-lint run ./...'

# -race needs the cgo variant
docker build --target cgo -t breachsafe-go-toolchain:cgo .
docker run --rm -v "$PWD:/workspace" breachsafe-go-toolchain:cgo -c 'go test -race ./...'
```

## 6. Refresh procedure

The base image digest and every tool version are explicit build inputs, and `doctor.sh`
asserts the running image against them. A refresh must:

1. update the `FROM` digest and any tool `ARG`;
2. run `golden-go-doctor` in both variants, which fails on any version mismatch;
3. run the gates in `.github/workflows/ci.yml` against `testdata/fixture`;
4. publish, which fails closed if the immutable patch tag already exists and verifies the
   provenance attestation.

The published image is **not** vulnerability-scanned in CI today. `govulncheck` covers the Go
module graph, and nothing covers the OS package layer. The lean variant carries no OpenSSL and
about ten packages, so that surface is small; it is not zero. Tracked as an open gap.

Steps 2 through 4 are enforced by CI, not by convention.
