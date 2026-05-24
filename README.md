# skills

A monorepo of agent skills for Unreal Engine + AngelScript workflows, following the [skills.sh](https://skills.sh) convention.

A **skill** is any directory under [`skills/`](skills/) containing a `SKILL.md` file. The directory name is the skill identifier (kebab-case). Skills are agent-neutral — anything that speaks the skills.sh layout (Claude Code, Codex, Cursor, etc.) can install and invoke them.

## Skills in this repo

| Skill | Purpose |
|---|---|
| [`unreal-engine`](skills/unreal-engine/) | Author UE 5.x C++/Blueprint code without hallucinating API surface. Discovery + grep + WebFetch protocol before writing any signature. Covers pointers/GC, IWYU, Build.cs, replication, GAS, Lyra, Enhanced Input, UMG, animation. |
| [`unreal-engine-angelscript`](skills/unreal-engine-angelscript/) | Author Hazelight AngelScript (`.as`) gameplay code on UE 5.x. Front-loads the 10 AS-vs-C++ traps (no `#include`, no `GENERATED_BODY`, `default` keyword, RPCs reliable by default, no `UInterface`, etc.) and enforces verify-before-claim against `angelscript.hazelight.se/api`. |
| [`read-ue-logs`](skills/read-ue-logs/) | Read and filter Unreal Engine log output from disk. Auto-detects the project, merges concurrent log files, default-windows to recent sessions. The deep reader behind a test MCP server's `get_test_log`. |
| [`ue-angelscript-tests`](skills/ue-angelscript-tests/) | Author Hazelight AngelScript tests (`Test_*` / `IntegrationTest_*`) for UE. Covers the test kinds, the wider C++/Gauntlet/cooked-build boundary, **running them through a test MCP server** (`list_tests` / `run_tests` / `run_visual_tests` / `get_test_log`), and how to verify results. |

**Per-project pick:** on any UE 5.x project, install **one** of `unreal-engine` or `unreal-engine-angelscript` (depending on whether the project uses the Hazelight fork). Pair with `read-ue-logs` always, and with `ue-angelscript-tests` if you're in an AngelScript project.

## Companion: a test MCP server

The two testing skills above are designed to pair with an MCP server that runs the headless test loop for the agent, so it never hand-types `UnrealEditor-Cmd … Automation RunTests`. Two options:

### Preferred: [`osseous/ue-headless-mcp`](https://github.com/osseous/ue-headless-mcp)

Our own focused Go server, scoped to the headless test loop. It exposes exactly **five** tools — `status`, `list_tests`, `run_tests` (headless `-nullrhi`), `run_visual_tests` (GPU), `get_test_log` — and nothing else. Install with `go install github.com/osseous/ue-headless-mcp/cmd/ue-headless-mcp@latest` and register it in `.mcp.json` (env: `UE_EDITOR_PATH`, `MCP_UNREAL_PROJECT`, optional `UEHM_TIMEOUT_MS`).

It exists because the editor process never reliably exits on Windows: it detects completion from the run log (the `**** TEST COMPLETE. EXIT CODE: N ****` marker, the AngelScript `Hot reload failed due to script compile errors` marker, and the optional `-ReportExportPath` `index.json`), sends child output to the null device to avoid inherited-pipe deadlock, and force-kills the whole process tree via a Windows Job Object the instant results exist. A clean run returns in ~20–45s; a **compile error returns in ~20s with the extracted AngelScript errors** instead of hanging. Each run writes a dedicated `Saved/Logs/McpTest_*.log` that `read-ue-logs` / `get_test_log` can read.

It does **not** build, cook, or drive the live editor (`call_function`, `spawn_actor`, `pie_control`, `capture_viewport`, console commands). Build C++ via UBT (`Build.bat`) directly; add the server below side-by-side if you need live editor control.

### Fuller (but hang-prone): [`remiphilippe/mcp-unreal`](https://github.com/remiphilippe/mcp-unreal)

A broader Go server that also exposes `build_project` / `cook_project` and live editor control via the Remote Control API (`:30010`) and the MCPUnreal editor plugin (`:8090`). It tied "done" to the editor process exiting and never force-killed the Windows process tree, so a run whose tests finished in seconds blocked until the client timeout — which is why `ue-headless-mcp` replaced it for the test loop. Re-add it side-by-side only when you genuinely need its live-editor / build / cook tools.

| Skill | Pairs with the test MCP server |
| --- | --- |
| `ue-angelscript-tests` | discover + run + read AngelScript tests via `list_tests`/`run_tests`/`run_visual_tests`/`get_test_log` |
| `read-ue-logs` | the deep, multi-instance log reader for anything `get_test_log` doesn't surface |

The skills still work without any MCP server — they fall back to the Session Frontend / `Automation RunTests` CLI — but a project that mandates the MCP path (in its `CLAUDE.md`) should keep all test execution on the server.

## Install

### One skill via skills.sh

```bash
npx skills add osseous/skills/<skill-name>
```

The installer drops the skill at `.claude/skills/<skill-name>/` (for Claude Code) or `.agents/skills/<skill-name>/` (agent-neutral).

### All skills, locally

Clone the repo and symlink everything into `~/.claude/skills/`:

```bash
git clone https://github.com/osseous/skills.git
cd skills
bash scripts/link-skills.sh
```

Override the install destination with `CLAUDE_SKILLS_DIR`:

```bash
CLAUDE_SKILLS_DIR=/path/to/agent/skills bash scripts/link-skills.sh
```

On Windows, symlink creation requires Administrator rights or Developer Mode (Settings > Privacy & security > For developers). Without it the script falls back to a directory copy.

## Layout

```
skills/                          # this repo
├── LICENSE                      # MIT, applies to every skill
├── README.md                    # this file
├── scripts/
│   ├── list-skills.sh           # prints every skills/**/SKILL.md path
│   └── link-skills.sh           # symlinks each skill into ~/.claude/skills/
└── skills/                      # all skills live here
    ├── unreal-engine/
    │   ├── SKILL.md             # frontmatter + agent entry point
    │   ├── README.md            # human-facing docs
    │   ├── references/          # spillover: cpp-style, replication, gas, lyra, ...
    │   └── scripts/             # detect-engine.ps1, find-uclass.ps1, open-epic-docs.ps1
    ├── unreal-engine-angelscript/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/          # cpp-differences, replication, mixins, footguns, ...
    │   └── scripts/             # detect-angelscript.ps1, grep-binding.ps1, open-as-docs.ps1
    ├── read-ue-logs/
    │   ├── SKILL.md
    │   ├── README.md
    │   └── scripts/             # read-logs.ps1
    └── ue-angelscript-tests/
        ├── SKILL.md
        ├── REFERENCE.md         # full API surface
        └── EXAMPLES.md          # copy-pasteable test scaffolds
```

## Adding a new skill

1. Create `skills/<your-skill-name>/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: your-skill-name
   description: <capability>. Use when <specific trigger contexts>.
   ---
   ```
2. Keep `SKILL.md` short (target < 100 lines). Spill detail into sibling `REFERENCE.md` / `EXAMPLES.md`.
3. Put deterministic helpers (scripts, templates) in `<your-skill-name>/scripts/`.
4. Run `bash scripts/list-skills.sh` to confirm the new skill is discovered.
5. Run `bash scripts/link-skills.sh` to install it locally for testing.

The `description` field is the agent's only routing signal — lead with the capability, then include explicit "Use when…" triggers so agents pick the right skill for the right task.

## License

[MIT](LICENSE) © 2026 Maxim Kostin
