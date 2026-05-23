#!/usr/bin/env bash
# Symlink every skill in this repo into ~/.claude/skills/<skill-name>.
# Idempotent — re-running replaces existing links without error.
#
# Override the install target by setting CLAUDE_SKILLS_DIR before running.
#
# Windows note: symlink creation requires either Administrator rights or
# Developer Mode enabled (Settings > Privacy & security > For developers).
# Without it, this script will fall back to a directory copy.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$CLAUDE_SKILLS_DIR"

abs_path() {
    # Portable absolute-path resolution (no GNU realpath dependency).
    ( cd "$1" && pwd )
}

linked=0
while IFS= read -r skill_md; do
    skill_dir="$(dirname "$skill_md")"
    skill_name="$(basename "$skill_dir")"
    target="$(abs_path "$skill_dir")"
    link="$CLAUDE_SKILLS_DIR/$skill_name"

    if ln -sfn "$target" "$link" 2>/dev/null; then
        echo "linked  $link -> $target"
    else
        # Symlink failed (likely Windows without privs) — fall back to copy.
        rm -rf "$link"
        cp -R "$target" "$link"
        echo "copied  $link  (symlink unavailable)"
    fi
    linked=$((linked + 1))
done < <(find skills -name SKILL.md | sort)

echo ""
echo "Installed $linked skill(s) into $CLAUDE_SKILLS_DIR"
