# read-ue-logs

A small, agent-neutral [skill](https://skills.sh) for reading Unreal Engine log output from any UE project's `Saved/Logs/` directory.

UE log analysis is fundamentally tail + grep across a few on-disk files; this skill does exactly that with a single PowerShell script — no editor plugin, no HTTP listener, no long-running proxy process. Built for AI coding agents (Claude Code, Codex, Cursor, Windsurf, Gemini, etc.) that need a fast, dependency-free way to inspect what UE just printed.

## Install

Using the [skills.sh](https://skills.sh) installer:

```bash
npx skills add osseous/read-ue-logs
```

The installer drops the skill under `.claude/skills/read-ue-logs/` (for Claude Code) or `.agents/skills/read-ue-logs/` (for agent-neutral installs), depending on which agents it detects.

Alternative — clone directly into your project:

```bash
git clone https://github.com/osseous/read-ue-logs.git .claude/skills/read-ue-logs
```

## Why this exists

- **Works editor-open or closed.** UE writes the same files either way; no in-editor HTTP plugin is required.
- **Handles concurrent instances.** A single editor writes `<Project>.log`. A second editor PIE, a standalone client, or multi-client test sessions each write their own `<Project>_N.log`. This skill merges across all of them by timestamp and tags each line with its source.
- **Recency-aware by default.** Old `<Project>_2.log` files from a test run that already exited are excluded unless you ask for them, so default output reflects only what is happening *now*.
- **Project-agnostic.** Auto-detects the project from the nearest `*.uproject`, so it works in any UE project without configuration.
- **Agent-neutral.** Follows the [skills.sh](https://skills.sh) layout. Any compliant agent can discover and invoke it.

## Quickstart

Run from your UE project root (the script auto-locates the project root from its own location, so cwd actually doesn't matter):

```powershell
# Last 50 log lines from currently-active sessions
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1

# Last 100 errors
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Verbosity Error -Tail 100

# Blueprint output only
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogBlueprint

# Anything mentioning "MyActor"
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Search "MyActor"

# Full help
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Help
```

On a machine with PowerShell 7+ installed you may substitute `pwsh -File ...` for `powershell -File ...`; the script is compatible with both editions.

## Full flag reference

| Flag | Default | Meaning |
|------|---------|---------|
| `-Tail <int>` | `50` | Print last N matching lines after all filtering. |
| `-Category <string>` | (none) | Case-insensitive substring match on log category. E.g. `LogTemp`, `LogBlueprint`, `LogRenderer`. |
| `-Verbosity <string>` | (none) | Exact match. One of `Error`, `Warning`, `Display`, `Verbose`, `VeryVerbose`. |
| `-Search <regex>` | (none) | .NET regex matched against the message body. |
| `-LogFile <path>` | auto | Bypass auto-discovery and read this one file. Pass `all` to scan all `<Project>*.log` files including rotated backups. |
| `-RecentMinutes <int>` | `10` | Auto-discovery window — only include log files modified within this many minutes. If nothing matches, falls back to the single most-recent log. |
| `-Source <name>` | (none) | When the merged stream contains entries from multiple files, restrict to one (e.g. `<Project>_2`). |
| `-ProjectName <name>` | auto | Override the auto-detected project name. Default: basename of the nearest `*.uproject`. |
| `-Format <text\|json>` | `text` | `text` prints raw log lines (with a `[source]` prefix when more than one file is in the merge); `json` prints one object per line for programmatic consumption. |
| `-Help` | | Print built-in usage and exit. |

## The multi-log-file model

UE writes a separate log file for each running instance of the project:

| File | Source |
|------|--------|
| `<Project>.log` | The first editor or game process |
| `<Project>_2.log`, `<Project>_3.log`, … | Additional concurrent processes (second editor, standalone client, headless server, etc.) |
| `<Project>-backup-<timestamp>.log` | Previous-session logs rotated out when the editor restarted |

By default this skill includes only the first two categories and only those touched within the recency window (default 10 minutes). That matches the intuition of "show me what's happening *now*."

To inspect a prior session, either:
- Restore it with `-RecentMinutes 99999` (still skips rotated backups), or
- Use `-LogFile all` (includes rotated backups), or
- Pass an explicit `-LogFile Saved/Logs/<Project>-backup-<timestamp>.log`.

## Output format

### Text (default)

When one file is merged, lines are printed verbatim. When two or more files are merged, each line is prefixed with `[<source>]`:

```
[MyProject]   [2026.05.23-01.49.53:512][918]LogD3D12RHI: ~FD3D12DynamicRHI
[MyProject_2] [2026.05.23-01.49.55:425][761]LogTemp: Hello from second client
```

### JSON (`-Format json`)

One object per line, NDJSON-style. Fields: `source`, `line`, `timestamp`, `thread`, `category`, `verbosity`, `message`. Lines UE emits that don't follow the standard `[ts][thread]Category: ...` prefix (footers, stack-trace continuations) appear with empty category/verbosity and the full original line as `message`, so nothing is dropped.

## Project detection

The script walks up from its own location looking for the first `*.uproject` file. The project root is that directory; the project name is the basename of the `.uproject`. UE names its log files after that basename, so the script can build the active-log regex (`^<Project>(_\d+)?\.log$`) and the all-log glob (`<Project>*.log`) automatically.

If you have an unusual setup — a renamed log directory, multiple `*.uproject` files in nested directories, or you simply want to point the script at a different project name — pass `-ProjectName <name>` to override auto-detection.

## Notes

- Exit codes: `0` on success even with zero matches; `1` only if the `Saved/Logs` directory is missing or the script itself errors. This means it's safe to chain with `&&` / `; if ($?) { ... }`.
- The script never modifies log files; it only reads them.
- If Epic adds a new verbosity level in a future UE release, edit the `-Verbosity` validation set inside `scripts/read-logs.ps1` (one regex group plus one help-text line).

## Requirements

- Windows + Windows PowerShell 5.1 or PowerShell 7+ (both editions are supported)
- A UE project with a `*.uproject` file at its root and a `Saved/Logs/` directory created by at least one editor session

## License

[MIT](../../LICENSE) © 2026 Maxim Kostin (inherited from the repo root)
