---
name: ue-angelscript-tests
description: Author Unreal Engine AngelScript tests using the Hazelight FUnitTest / FIntegrationTest framework. Use when adding regression coverage for `.as` gameplay code, scaffolding a new Test_* function, deciding between a unit test and an integration test (which requires a /Content/Testing/*.umap) — or deciding whether a test even belongs in AngelScript at all vs C++ automation tests / specs / functional tests / Gauntlet (cooked builds), and what EAutomationTestFlags or latent (multi-frame) commands a case needs. Also covers running a script test through an MCP test server (preferred), the Session Frontend, or the `Automation RunTests` CLI. Tests are plain prefixed functions (no UCLASS, no macros) discovered automatically by the AngelScript plugin on hot reload.
---

# ue-angelscript-tests

## The three test kinds

Hazelight AngelScript tests are **plain functions discovered by name prefix** — no `UCLASS`, no `IMPLEMENT_*_AUTOMATION_TEST` macros, no manifest. The plugin scans on hot reload.

| Prefix                      | Parameter                | Map required                        | Discovery group                   |
| --------------------------- | ------------------------ | ----------------------------------- | --------------------------------- |
| `Test_*`                    | `FUnitTest& T`           | no                                  | `Angelscript.UnitTests.*`         |
| `IntegrationTest_*`         | `FIntegrationTest& T`    | yes — `/Content/Testing/IntegrationTest_<Name>.umap` | `Angelscript.IntegrationTests.*` |
| `ComplexIntegrationTest_*`  | `FIntegrationTest& T` + companion `_GetTests()` | yes | `Angelscript.IntegrationTests.*` |

**Default to `Test_*`** unless the behavior genuinely needs a live world. Integration tests require a hand-authored `.umap` whose name **matches the full function name** (`IntegrationTest_Foo` → `/Content/Testing/IntegrationTest_Foo.umap`), or an override `FString IntegrationTest_Foo_GetMapName()` returning a map path — most agents cannot create a map and should not attempt it.

## Capability boundaries — what AngelScript can and cannot test

AngelScript reaches **only** the four AngelScript rows below. The rest are C++- or cooked-build-only; don't try to author them in `.as`.

| Mechanism | Language | World/map | Build | Reach from AngelScript |
| --- | --- | --- | --- | --- |
| `Test_*` (`FUnitTest`) | AngelScript | none | editor `-nullrhi` | ✅ default |
| `IntegrationTest_*` (`FIntegrationTest`) | AngelScript | yes | editor (often GPU) | ✅ when a world is required |
| `ComplexIntegrationTest_*` + `_GetTests()` | AngelScript | yes | editor | ✅ parameterized over one map |
| Diagnostic actor (`RunDiagnostics()`) | AngelScript | full PIE | editor | ✅ manual / human-verified |
| `IMPLEMENT_SIMPLE_/COMPLEX_AUTOMATION_TEST` | **C++ only** | optional | editor | ❌ |
| Automation Spec — `BEGIN_DEFINE_SPEC`/`Describe`/`It` | **C++ only** | optional | editor | ❌ |
| `AFunctionalTest` actor in a map | BP / C++ (AS can subclass) | yes | editor | ⚠️ possible but `IntegrationTest_*` is cheaper |
| **Gauntlet** (controller + Python) | C++ + Python | full game | **cooked/staged ONLY** | ❌ not in-editor, not via the test MCP |

- **C++-only macros do not exist in `.as`**: `IMPLEMENT_*_AUTOMATION_TEST`, `BEGIN_DEFINE_SPEC`, `DEFINE_LATENT_AUTOMATION_COMMAND_*`. If the code under test is pure C++ with no AngelScript binding, write a C++ automation test — outside this skill's scope.
- **`EAutomationTestFlags` is a C++ concern only.** A C++ test must OR exactly one context (`EditorContext`/`ClientContext`/`ServerContext`/`CommandletContext`, or `ApplicationContextMask`) with exactly one filter (`Smoke`/`Engine`/`Product`/`Perf`/`Stress`/`Negative`Filter); wrong count → "must specify exactly one filter" and the test silently won't run. AngelScript test functions take **no flags** — the plugin assigns them.
- **Gauntlet needs a cooked/staged build** and runs the full game on PC/console/device; it cannot run in-editor or through a headless test MCP. Use it for boot/smoke, perf, and platform coverage, not for logic regressions.
- **Hot-reload edge:** new `Test_*` functions appear on AngelScript hot reload; new **C++** tests need an **editor restart** ("Refresh Tests" won't find them).

## Quick start (unit test)

Drop a file in any `.as` source folder — a common convention is `Script/Tests/<Subject>_Test.as`:

```angelscript
// Script/Tests/MathUtils_Test.as
void Test_AddReturnsSum(FUnitTest& T)
{
    int Result = AddTwoInts(2, 3);
    T.AssertEquals(Result, 5);
}
```

Save the file → the AngelScript plugin hot-reloads → the test appears in `Angelscript.UnitTests.AddReturnsSum`. No recompile.

## Running tests

**Preferred — through MCP.** If the project exposes a test MCP server — [`osseous/ue-headless-mcp`](https://github.com/osseous/ue-headless-mcp) (focused: just `status` + the four below; detects completion from run-log markers and force-kills the editor so a run never hangs) or the broader [`remiphilippe/mcp-unreal`](https://github.com/remiphilippe/mcp-unreal) — run tests through its tools, never by hand-typing a command line:

| Tool | Use |
| --- | --- |
| `list_tests` | confirm your test registered (catches a missed hot reload) |
| `run_tests` | headless run (`-nullrhi`); the default for `Test_*` unit tests |
| `run_visual_tests` | GPU run; use when a test needs the RHI, a render target, or PIE |
| `get_test_log` | read pass/fail and assertion detail (first read — see Verifying results) |

Filter to a group or a single test by name, e.g. `Angelscript.UnitTests` or `Angelscript.UnitTests.AddReturnsSum`. Some projects' conventions (see their `CLAUDE.md`) make this MCP path **mandatory** and forbid the hand-typed CLI.

**Editor (interactive):** `Window > Test Automation`, expand `Angelscript.UnitTests` (or `.IntegrationTests`), select your test, click `Start Tests`.

**CLI (fallback when no MCP server is wired up):** from the project root,

```
UnrealEditor-Cmd.exe <YourProject>.uproject -ExecCmds="Automation RunTests Angelscript.UnitTests; Quit" -unattended -nopause
```

Filter to a single test by name: `Automation RunTests Angelscript.UnitTests.AddReturnsSum`.

## Verifying results

After a run, confirm pass/fail and see assertion details. If you ran via MCP, **`get_test_log` is the first read**. For deep forensics — merging the editor and standalone-client logs of a multi-instance run, or grepping across categories — use the sibling skill [`read-ue-logs`](../read-ue-logs/) (loaded as `read-ue-logs` once linked); do not invent another log reader.

```
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogAutomationController -Tail 100
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Search "Angelscript|FUnitTest" -Tail 100
```

Pass/fail lines come from `LogAutomationController`; per-assertion detail comes from the AngelScript plugin's own categories.

## When NOT to write a `Test_*`

- **Needs a live world, placed actors, or multi-frame timing →** write an `IntegrationTest_*` instead, using `T.AddLatentAutomationCommand(...)` for frame-by-frame logic. Requires a co-authored `.umap` in `/Content/Testing/`.
- **Spans many components and needs human visual verification →** prefer a diagnostic-actor pattern in the level, not the automation framework. The pattern: an `AActor` subclass with a `BlueprintCallable` `RunDiagnostics()` `UFUNCTION` that walks live component state and prints PASS/FAIL/SKIP to the screen and log. Optionally back it with a console command. Not discovered by `Automation RunTests`; invoked manually during a play session.
- **Pure C++ code with no AngelScript wrapper →** use UE's C++ `IMPLEMENT_SIMPLE_AUTOMATION_TEST` macro instead. This skill does not cover that path.

The hierarchy: `Test_*` first, `IntegrationTest_*` if a world is required, diagnostic-actor only if neither fits.

## Further reading

- [`REFERENCE.md`](REFERENCE.md) — full `FUnitTest` / `FIntegrationTest` assertion API, latent-command surface, CLI flag reference, failure semantics.
- [`EXAMPLES.md`](EXAMPLES.md) — full file examples of each test kind, copy-pasteable.
- Hazelight docs: https://angelscript.hazelight.se/scripting/script-tests/
- Epic Automation Test Framework: https://dev.epicgames.com/documentation/en-us/unreal-engine/automation-test-framework-in-unreal-engine
- Complex / latent functional tests (C++): https://unreal-garden.com/tutorials/complex-functional-tests/
- Unit & integration testing overview (specs, flags, cooked vs editor): https://community.gamedev.tv/t/unit-and-integration-testing-in-unreal-engine/184388
