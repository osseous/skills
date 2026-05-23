---
name: ue-angelscript-tests
description: Author Unreal Engine AngelScript tests using the Hazelight FUnitTest / FIntegrationTest framework. Use when adding regression coverage for `.as` gameplay code, scaffolding a new Test_* function, deciding between a unit test and an integration test (which requires a /Content/Testing/*.umap), or running a script test — through the mcp-unreal MCP server (preferred), the Session Frontend, or the `Automation RunTests` CLI. Tests are plain prefixed functions (no UCLASS, no macros) discovered automatically by the AngelScript plugin on hot reload.
---

# ue-angelscript-tests

## The three test kinds

Hazelight AngelScript tests are **plain functions discovered by name prefix** — no `UCLASS`, no `IMPLEMENT_*_AUTOMATION_TEST` macros, no manifest. The plugin scans on hot reload.

| Prefix                      | Parameter                | Map required                        | Discovery group                   |
| --------------------------- | ------------------------ | ----------------------------------- | --------------------------------- |
| `Test_*`                    | `FUnitTest& T`           | no                                  | `Angelscript.UnitTests.*`         |
| `IntegrationTest_*`         | `FIntegrationTest& T`    | yes — `/Content/Testing/<Name>.umap` | `Angelscript.IntegrationTests.*` |
| `ComplexIntegrationTest_*`  | `FIntegrationTest& T` + companion `_GetTests()` | yes | `Angelscript.IntegrationTests.*` |

**Default to `Test_*`** unless the behavior genuinely needs a live world. Integration tests require a hand-authored `.umap` in `/Content/Testing/` — most agents cannot create one and should not attempt it.

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

**Preferred — through MCP.** If the project exposes the [`mcp-unreal`](https://github.com/remiphilippe/mcp-unreal) MCP server (a Go server that drives headless `UnrealEditor-Cmd` plus the editor's Remote Control API and the MCPUnreal plugin), run tests through its tools — never by hand-typing a command line:

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
