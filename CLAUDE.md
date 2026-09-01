<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->
# breachsafe-golden-go — repository policy

The pinned Go CI/build toolchain image for BreachSAFE Go repositories. A build-plane
component, not an application runtime and not a place for product source. This file is
self-contained; [`AGENTS.md`](AGENTS.md) and [`docs/go-gates.md`](docs/go-gates.md) carry the
same gate list and the review sequence in more detail.

## Contents

1. [Instruction hierarchy](#1-instruction-hierarchy)
2. [What this repository is](#2-what-this-repository-is)
3. [Invariants](#3-invariants)
4. [Required checks and smoke](#4-required-checks-and-smoke)
5. [Change loop and PR discipline](#5-change-loop-and-pr-discipline)
6. [Shared skills](#6-shared-skills)
7. [Licensing](#7-licensing)

## 1. Instruction hierarchy

Read and apply these sources in order.

1. **`~/claude/CLAUDE.md`** — platform policy: licensing, the OpenSSL 3.5 LTS baseline, repo
   identity, the greenfield rule, the ten-step change loop. It auto-loads from any ancestor
   directory.
2. **This file** — rules for this repository. Where it refines the platform file, it does so
   here and names the reason.
3. **[`AGENTS.md`](AGENTS.md)** — the invariants, the required checks, and the smoke commands.
4. **[`docs/go-gates.md`](docs/go-gates.md)** and **[`docs/skills.md`](docs/skills.md)** — the
   full gate list, the review order, and the skills that apply.

## 2. What this repository is

The shared, pinned Go build and security-gate image consumed by BreachSAFE Go repositories as
a CI dependency. Two variants, both non-root, both version-asserted by `doctor.sh`.

| Target | For | `CGO_ENABLED` | OpenSSL |
|---|---|:--:|:--:|
| `lean` (default) | every pure-Go repository | `0` | **none** |
| `cgo` | `go test -race`, `breachsafe-pdf` rendering, anything linking C | `1` | present, patched |

`go test -race` requires cgo; the lean variant cannot run it. The lean image contains no
OpenSSL, NSS, or NSPR, verified in CI by a filesystem search that fails the build on any match.
The cgo image retains OpenSSL because git-over-HTTPS links `libcurl` → `libssl` and it cannot
be removed; it is patched with `apk upgrade` at build time and scanned by the release workflow.

Consumers pin this image and add their own minimal runtime base. Do not copy the `Dockerfile`
into a consumer repository.

## 3. Invariants

- Go baseline is pinned in `Dockerfile` (`FROM golang:` line and `GOTOOLCHAIN`); a refresh
  requires a reviewed version and digest change.
- **Base image is pinned by SHA-256 digest, never a floating tag.** Every tool version is an
  explicit `ARG`. Never install `latest` in the image or in workflows.
- Actions are pinned to commit SHAs; workflows use least-privilege permissions.
- The image runs as **UID/GID 65532** and must contain no credentials and no application
  source. Compilation happens only in builder stages; the doctor fails if Go module-cache
  content reaches a shipped variant.
- Product images stay responsible for their own minimal runtime base.
- PR/push workflows have concurrency cancellation; publish workflows must not cancel in-flight
  pushes.
- SBOM and provenance attestations are required for published images.
- The immutable recipe tag (`1.27.0-r6`) is publish-refused if it already exists; consumers
  pin the resulting OCI digest.
- Do not add Python, QuReddy, Prowler, ePack, or product-specific runtime dependencies here.

## 4. Required checks and smoke

Full gate list and the review sequence: [`docs/go-gates.md`](docs/go-gates.md). A gate is only
meaningful when its exit status fails the workflow on a real finding; do not hide findings with
blanket exclusions. Build both variants, run the doctor in each, then run the gate string
against the fixture.

```sh
docker build --pull=false --target lean -t breachsafe-golden-go:lean .
docker build --pull=false --target cgo -t breachsafe-golden-go:cgo .
docker run --rm breachsafe-golden-go:lean golden-go-doctor
docker run --rm breachsafe-golden-go:cgo golden-go-doctor
docker run --rm -v "$PWD/testdata/fixture:/workspace" breachsafe-golden-go:lean \
  -c 'test -z "$(goimports -l .)" && staticcheck ./... && gosec -exclude-generated ./... && govulncheck ./... && golangci-lint run --config /etc/golden-go/golangci.yml ./...'
```

`golden-go-doctor` (installed from `doctor.sh`) asserts the running image against every pinned
version and fails on any mismatch. The workflows are `.github/workflows/ci.yml` (gates against
`testdata/fixture`) and `.github/workflows/build-and-push.yml` (publish, Trivy HIGH/CRITICAL
scan of the exact image digests, SBOM and provenance). A green job that did not execute is not
a passing gate.

## 5. Change loop and PR discipline

Every change follows the platform ten-step loop in **`~/claude/CLAUDE.md` §1**. Report progress
as `N/10`; mark any skipped step `NOT RUN` with a reason.

1. Work in an isolated worktree off `origin/main`, not the local checkout.
2. Open or reference an issue, branch, then implement the smallest contract-preserving change.
3. Run the checks in section 4 and record real exit codes, not a claim.
4. Commit, push, open a focused PR with `main` as the base.
5. Merge only after the hosted CI and the image-identity checks pass. Never treat a green job
   that did not execute as a passing gate.

Completing the loop is the authorization to commit, push, and open the PR. Destructive git
operations (force-push to a shared ref, history rewrite, deleting a branch/tag/release) always
need an explicit in-conversation instruction.

## 6. Shared skills

The canonical skill library lives in `breachsafe-common`, which is **private**. This repository
is public, so it names skills and does not link to them; earlier pinned URLs returned HTTP 404
to anyone without access. Read skills from a local checkout, never copy them in. `.claude/` is
gitignored, so nothing from the private repo enters this public one. Setup and the drift check
are in [`docs/skills.md`](docs/skills.md).

| Skill | Use when |
|---|---|
| `breachsafe-go-engineering` | Go structure, APIs, tests, and conventions |
| `breachsafe-cicd-hygiene` | Workflow concurrency, duplicate CI, and false-green checks |
| `breachsafe-container-hygiene` | Dockerfile, image, and runtime hardening |
| `breachsafe-quality-review` | PR-diff hygiene and the anti-pattern catalog |
| `breachsafe-release` | Supply chain, provenance, signing, and Scorecard posture |
| `breachsafe-review-gate` | Pre-merge orchestration and combined verdict |

Add `breachsafe-test-harness` for visual, fuzz, and adversarial fixture work. Add crypto audit
or conformance skills only when the change actually handles cryptography or a normative
standard.

## 7. Licensing

**This repository is PolyForm-Noncommercial-1.0.0 throughout.** It is not an Apache carve-out.
Every new first-party file gets `SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0`, matching
the `LICENSE`, `REUSE.toml`, and every existing header. `reuse lint` must stay clean. Public
does not mean open source: this image is source-available for non-commercial use. Never relabel
upstream, vendored, or generated content; it keeps its original licence.
