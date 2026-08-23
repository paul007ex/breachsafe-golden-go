<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

# BreachSAFE Go toolchain

`breachsafe-container-go` is the shared, pinned CI/build image for BreachSAFE Go repositories.
It is intentionally a **toolchain image**, not an application runtime image.

Included gates and tools:

- Go 1.26.6
- `go fmt`, `go vet`, tests, race tests, and module verification from the Go distribution
- `govulncheck` v1.7.0
- Staticcheck 2025.1.1
- gosec v2.22.11
- OSV-Scanner v2.4.0
- Git, Bash, jq, Make, CA certificates

The image runs as UID/GID 65532 and has no application source or credentials. Product images
should use their own minimal runtime base (for example, the `scratch` image used by
`breachsafe-pdf`).

## Local use

```sh
docker build --pull=false -t breachsafe-go-toolchain:dev .
docker run --rm -v "$PWD:/workspace" breachsafe-go-toolchain:dev \
  -c 'go fmt ./... && go vet ./... && go test ./... && go mod verify && govulncheck ./...'
```

The base image and every tool version are explicit inputs. Refreshes must update the Dockerfile,
run the full toolchain validation, scan the image, and publish a new immutable tag.
