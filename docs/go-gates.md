<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

# Go quality gates

Run these gates in a repository using the golden image. A gate is only meaningful when its exit
status fails the workflow on a real finding.

```sh
gofmt -l .                         # must print nothing
goimports -l .                     # import order/grouping; must print nothing
go vet ./...                       # correctness checks
go test ./...                      # unit/integration tests
go test -race ./...                # data-race checks; CGO must be available
go mod verify                      # module archive verification
staticcheck ./...                  # standalone current static analysis
gosec -exclude-generated ./...     # standalone current security analysis
golangci-lint run --config /etc/golden-go/golangci.yml ./...
                                    # shared policy: broad correctness/security linters
govulncheck ./...                  # reachable Go vulnerability analysis
```

For product repositories, add:

```text
CodeQL (Go, security-extended)
golden PDF/render regression tests where output is visual
fuzz/property tests for parsers and bounded input
Docker build and non-root smoke test
Trivy HIGH/CRITICAL image gate (external pinned tool; not embedded here)
SBOM and provenance attestations
keyless image signing and verification
```

Do not hide findings with blanket exclusions. Repository-specific exceptions need narrow scope,
written rationale, an owner, and an expiry.

## Review sequence

Use the shared skills in this order:

1. `breachsafe-go-engineering`
2. `breachsafe-quality-review`
3. `breachsafe-cicd-hygiene`
4. `breachsafe-container-hygiene`
5. `breachsafe-release`
6. `breachsafe-review-gate`

Add `breachsafe-test-harness` for visual, fuzz, and adversarial fixture work. Add crypto audit or
conformance skills only when the change actually handles cryptography or a normative standard.
