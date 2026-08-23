#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
set -eu
test "$(id -u)" = 65532
test "$(id -g)" = 65532
go version
govulncheck -version
staticcheck -version
gosec -version
osv-scanner --version
golangci-lint version
test -w /go/cache
test -w /workspace
echo 'golden-go doctor: PASS'
