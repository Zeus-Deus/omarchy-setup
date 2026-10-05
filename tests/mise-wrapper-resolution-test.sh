#!/usr/bin/env bash
set -euo pipefail
readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Each Python test supplies its own temporary HOME and all XDG paths.
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s "$repo_dir/tests" -p 'test_mise_wrapper_*.py' -v
