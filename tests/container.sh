#!/usr/bin/env bash

set -euo pipefail

readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

docker run --rm --pull=missing \
  --volume "$repo_dir:/repo:ro" \
  alpine:3.22 \
  sh -lc 'apk add --no-cache bash coreutils jq lua5.4 >/dev/null && bash /repo/tests/install-smoke.sh'
