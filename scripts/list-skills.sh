#!/usr/bin/env bash
# List every SKILL.md path under skills/, sorted.
# A skill = any directory under skills/ containing a SKILL.md file.

set -euo pipefail

cd "$(dirname "$0")/.."
find skills -name SKILL.md | sort
