#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run each of the 10 existing binaries 10 times. Reusing an executable does not
# require rebuilding or creating numbered copies of it.
export COPIES_PER_APP=10
export REUSE_APP_BINARIES=1
export SUMMARY_ONLY=1

exec "$ROOT/run-all.sh"
