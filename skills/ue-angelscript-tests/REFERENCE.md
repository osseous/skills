# REFERENCE — ue-angelscript-tests

Full API surface for Hazelight AngelScript script tests. Source of truth: https://angelscript.hazelight.se/scripting/script-tests/.

## Discovery rules

The AngelScript plugin scans `.as` files on hot reload and registers any top-level function whose name starts with one of:

| Prefix                     | Parameter type           | Category in Session Frontend       |
| -------------------------- | ------------------------ | ---------------------------------- |
| `Test_`                    | `FUnitTest& T`           | `Angelscript.UnitTests.<Name>`     |
| `IntegrationTest_`         | `FIntegrationTest& T`    | `Angelscript.IntegrationTests.<Name>` |
| `ComplexIntegrationTest_`  | `FIntegrationTest& T`    | `Angelscript.IntegrationTests.<Name>` |

Function names map directly to test names — `Test_FooBar` registers as `Angelscript.UnitTests.FooBar`.

Tests must be **free functions**, not class methods. They can live in any `.as` file the plugin loads. A common convention is to group them under `Script/Tests/`.

## `FUnitTest` assertions

| Call                                    | Passes when                       |
| --------------------------------------- | --------------------------------- |
| `T.AssertTrue(expr)`                    | `expr == true`                    |
| `T.AssertFalse(expr)`                   | `expr == false`                   |
| `T.AssertEquals(actual, expected)`      | `actual == expected`              |
| `T.AssertNotEquals(actual, expected)`   | `actual != expected`              |
| `T.AssertNull(obj)`                     | `obj == nullptr`                  |
| `T.AssertNotNull(obj)`                  | `obj != nullptr`                  |

**Failure semantics:** a failed assertion logs an error and counts the test as failed, but **does not abort the function** — subsequent assertions still run. To stop early on failure, write an explicit `return` after the assertion or guard with a normal `if`. This differs from many test frameworks; do not assume short-circuit behavior.

Each assertion accepts an optional trailing string message in most overloads — useful when an assertion is one of several similar checks. Confirm signatures in the Hazelight docs for your plugin version.

## `FIntegrationTest`

Inherits the same assertions as `FUnitTest`, plus:

- **`T.AddLatentAutomationCommand(callback)`** — queue a callback to run on a later tick. Use for multi-frame setups (spawn an actor → wait one tick → assert it's initialized).
- **Map binding** — the test requires a `.umap` at `/Content/Testing/<TestName>.umap` (matching the function's `<Name>` suffix). The framework loads it before invoking the test function. No map = no discovery.

`ComplexIntegrationTest_*` adds a companion function `<TestName>_GetTests()` that returns a list of sub-test names, enabling one map to host multiple parameterized tests.

## Running from CLI

```
UnrealEditor-Cmd.exe <Project>.uproject -ExecCmds="Automation RunTests <Filter>; Quit" <flags>
```

Useful flags:

| Flag                          | Purpose                                                                |
| ----------------------------- | ---------------------------------------------------------------------- |
| `-unattended`                 | Do not show dialogs; required for CI.                                  |
| `-nopause`                    | Do not pause on exit.                                                  |
| `-nullrhi`                    | Skip rendering — fast headless run, fine for unit tests.               |
| `-as-exit-on-error`           | AngelScript-plugin flag: exit non-zero if any script error occurs.    |
| `-ReportOutputPath=<dir>`     | Write JSON / HTML test reports for CI ingestion.                       |
| `-ReportExportPath=<dir>`     | Alternate (older) report path flag — check your engine version.        |

Filter examples:
- `Automation RunTests Angelscript` — every script test.
- `Automation RunTests Angelscript.UnitTests` — unit only.
- `Automation RunTests Angelscript.UnitTests.MovementPatternStepIsOrthogonal` — single test.

Combine multiple filters with `+`: `Automation RunTests Angelscript.UnitTests+OtherCategory`.

## Reading results

Pass/fail summary lines are emitted by `LogAutomationController`. Per-assertion failures come from the AngelScript plugin's categories (varies by plugin version — search broadly the first time). The [`read-ue-logs`](../read-ue-logs/) skill is the supported way to inspect output:

```
# Summary only
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogAutomationController -Tail 50

# Per-test detail
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Search "Angelscript|FUnitTest|IntegrationTest" -Tail 200
```

CI integrations should parse the JSON report from `-ReportOutputPath` rather than scraping log text.

## Authoring conventions

- **File location**: `Script/Tests/<Subject>_Test.as` keeps tests discoverable and grouped. The plugin doesn't require this — it's a convention worth adopting.
- **One concept per `Test_*`**: small, fast functions. Several focused tests beat one giant test with many `Assert*` calls — failure messages are clearer.
- **No `UCLASS` / `UFUNCTION` decorators** on test functions. They are not registered with UE's reflection system; the plugin discovers them by name.
- **No setup/teardown framework**: do per-test setup inline. If two tests share heavy setup, extract a helper function.
- **Determinism**: avoid time-of-day, random seeds, or world state in unit tests. If you need any of these, write an integration test.
