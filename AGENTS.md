<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

# BreachSAFE Golden Go instructions

This repository owns the pinned Go CI/build toolchain image used by BreachSAFE Go repositories.
It is a build-plane component, not an application runtime and not a place for product source.

## Invariants

- Go baseline is pinned in `Dockerfile`; refreshes require a reviewed version and digest change.
- Every tool version is explicit. Never install `latest` in the image or workflows.
- The image runs as UID/GID 65532 and must not contain credentials or application source.
- Product images remain responsible for their own minimal runtime base.
- Actions are pinned to commit SHAs and workflows use least-privilege permissions.
- PR/push workflows have concurrency cancellation; publish workflows must not cancel in-flight pushes.
- SBOM and provenance attestations are required for published images.
- Do not add Python, QuReddy, Prowler, ePack, or product-specific runtime dependencies here.

## Required checks

The complete gate list and review sequence are in [`docs/go-gates.md`](docs/go-gates.md).

```sh
docker build --pull=false --target lean -t breachsafe-golden-go:lean .
docker build --pull=false --target cgo -t breachsafe-golden-go:cgo .
docker run --rm breachsafe-golden-go:lean golden-go-doctor
docker run --rm breachsafe-golden-go:cgo golden-go-doctor
docker run --rm -v "$PWD/testdata/fixture:/workspace" breachsafe-golden-go:lean \
  -c 'test -z "$(goimports -l .)" && staticcheck ./... && gosec -exclude-generated ./... && govulncheck ./... && golangci-lint run --config /etc/golden-go/golangci.yml ./...'
```

For consumer repositories, the image is a CI dependency; do not copy its Dockerfile into them.

## Shared skills

The canonical, current skills live in [`breachsafe-common`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills).
Use those files by reference; do not vendor copies into this repository. The most relevant skills
are:

- [`breachsafe-go-engineering`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills/breachsafe-go-engineering)
- [`breachsafe-cicd-hygiene`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills/breachsafe-cicd-hygiene)
- [`breachsafe-release`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills/breachsafe-release)
- [`breachsafe-quality-review`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills/breachsafe-quality-review)
- [`breachsafe-container-hygiene`](https://github.com/paul007ex/breachsafe-common/tree/main/skills/skills/breachsafe-container-hygiene)

Repository-specific workflow policy remains in `.github/workflows/`; shared skills provide review
guidance, not an excuse to skip executable gates.
