---
name: read-ue-logs
description: Read and filter Unreal Engine log output from disk for any UE project. Auto-detects the project from the nearest *.uproject, merges entries across all concurrently-active log files (editor session, standalone clients), and surfaces only recently-active sessions by default. Use when diagnosing a silent failure after a repro, checking startup warnings, inspecting what UE printed for a recent gameplay action, or analyzing multi-client test runs.
---

# read-ue-logs

## Quick start

From the project root, run:

```
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Tail 50
```

By default this scans `Saved/Logs/<Project>.log` plus any `Saved/Logs/<Project>_N.log` modified in the last 10 minutes, merges them by timestamp, and prints the last 50 lines. The script auto-locates the project root and project name from the nearest `*.uproject`, so the working directory does not need to be the repo root. Use `pwsh -File ...` instead of `powershell -File ...` if PowerShell 7+ is installed (both editions are supported).

## Workflows

### Diagnose a failure after a repro

```
# Recent errors only
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Verbosity Error -Tail 100

# Blueprint-specific output
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogBlueprint -Tail 100

# Hunt for a specific keyword (regex)
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Search "MyActor|Spawn"
```

### Analyze a multi-client test run

When multiple instances run (editor + standalone clients), UE writes `<Project>.log`, `<Project>_2.log`, `<Project>_3.log` etc. Default behavior merges all of them and prefixes each line with `[<source>]`.

```
# All clients, last 10 min, merged and prefixed
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Tail 200

# Isolate one client (substitute your actual project name)
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Source MyProject_2
```

### Programmatic consumption

```
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Format json -Tail 50
```

Each line is one JSON object: `{source, line, timestamp, thread, category, verbosity, message}`.

## Advanced features

- `-RecentMinutes <N>` — change the auto-discovery window (default 10). Pass a large value to merge older sessions; if nothing matches the window, the script falls back to the single most-recent log so it never returns empty.
- `-LogFile <path>` — point at one specific log file, bypassing auto-discovery. Pass `-LogFile all` to include rotated `<Project>-backup-*.log` files too.
- `-ProjectName <name>` — override the auto-detected project name for unusual setups (renamed logs, multi-uproject monorepos).
- Exit codes: `0` on success (even with zero matches), `1` only on a missing log directory or script error.
- The editor does not need to be running — the script reads files on disk.

See [README.md](README.md) for the full flag reference, the multi-file model, and notes on extending the parser.
