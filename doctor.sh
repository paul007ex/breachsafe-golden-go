#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Smoke-test the toolchain image. Run it as `golden-go-doctor`.
#
# The uid check is conditional on purpose. The image ships USER 65532 for defence in
# depth, but a GitHub Actions `container:` job MUST override it with `options: --user root`:
# the runner owns /__w and /__w/_temp as uid 1001, so a 65532 container cannot write the
# runner file commands and every step dies before any tool runs, with
#   Error: EACCES: permission denied, open '/__w/_temp/_runner_file_commands/save_state_...'
# Asserting uid==65532 unconditionally would make this doctor report a false failure in
# exactly the configuration consumers need (issue #9). So: default run must be 65532, an
# explicit root override is accepted and reported.
set -eu

uid="$(id -u)"
gid="$(id -g)"

if [ "$uid" = "0" ]; then
    echo "golden-go doctor: running as root (expected only under an explicit --user root override)"
else
    test "$uid" = 65532 || { echo "unexpected uid $uid (want 65532 or an explicit root override)" >&2; exit 1; }
    test "$gid" = 65532 || { echo "unexpected gid $gid (want 65532)" >&2; exit 1; }
fi

go version
govulncheck -version
staticcheck -version
gosec -version
osv-scanner --version
golangci-lint version

test -w /go/cache
test -w /workspace

# The published image must not carry a Go build cache. It is pure bloat and is
# unreadable by uid 65532 anyway, since HOME=/tmp and XDG_CACHE_HOME=/tmp/.cache.
# Regression guard for issue #6.
test ! -d /root/.cache/go-build || { echo "/root/.cache/go-build shipped in the image" >&2; exit 1; }

# git is required: diff-scoped gates shell out to it, and actions/checkout silently
# degrades to a REST tarball without it, leaving no .git for any diff-based gate.
command -v git >/dev/null || { echo "git missing" >&2; exit 1; }

echo "golden-go doctor: PASS"
