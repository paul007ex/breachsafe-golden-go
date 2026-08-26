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

## Ten-step loop (BreachSAFE development contract)

Every non-trivial change runs these; a skipped step is reported as `NOT RUN` with a reason.
A green command that did not execute the required scope is not evidence.

1. **Inventory** — read this file, `CLAUDE.md`, the issue, the tree, and the applicable skills.
2. **Steelman** — state the strongest case and the smallest defensible change.
3. **Isolated reproduction** — reproduce in a fresh temp workstream before touching the checkout.
4. **Pressure test** — alternatives, malformed input, both CPU arches, failure paths, regressions.
5. **Surgical implementation** — the smallest contract-preserving change.
6. **Regression test** — a check that fails before the fix (e.g. the image runs on both arches).
7. **Quality gates** — build, `go vet`/`gofmt`, tests + race, govulncheck/staticcheck/gosec/osv-scanner, actionlint, with real exit codes.
8. **Architecture/anti-pattern review** — ownership, pins, duplication, size, logging, extensibility.
9. **Issue/Git workflow** — evidence, commit, push, PR/merge under the repo's authorization rules.
10. **Release verification** — independently validate the published image, signatures/provenance, and a real `docker run` smoke on **every** published architecture.

## Required checks

The complete gate list and review sequence are in [`docs/go-gates.md`](docs/go-gates.md).

```sh
docker build --pull=false -t breachsafe-golden-go:dev .
docker run --rm breachsafe-golden-go:dev -c 'go version && govulncheck -version && staticcheck -version && gosec -version && osv-scanner --version'
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
