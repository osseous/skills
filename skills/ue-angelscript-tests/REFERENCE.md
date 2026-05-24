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

Inherits the same assertions as `FUnitTest`, plus a latent-command queue and map binding.

**The test function body runs *before* the map is loaded and *before* the first frame.** It does not assert directly on world state — it only **enqueues latent commands** that the framework runs over subsequent frames. A returned function is "commands queued," not "test complete."

- **Map binding** — the test requires a `.umap` at `/Content/Testing/IntegrationTest_<Name>.umap` — the map name matches the **full function name**. Override with `FString IntegrationTest_<Name>_GetMapName()` returning a map path (e.g. a shared map). No map and no override = no discovery. An agent generally cannot author a `.umap`; leave a TODO for a human.
- **`T.AddLatentAutomationCommand(cmd)`** — queue a `ULatentAutomationCommand` to run across ticks. Commands run in FIFO order; each must finish before the next starts.
- **Actor lookup** — `GetActorByLabel(UClass Class, const FName& Label)` fetches an actor placed in the test map by its editor label.

### Writing a latent command (multi-frame)

A latent command is a `ULatentAutomationCommand` subclass overriding `Update()` (return `true` when done, `false` to be called again next frame) and optionally `Describe()`:

```angelscript
class UWaitForHealthZero : ULatentAutomationCommand
{
    APawn TargetPawn;

    UFUNCTION(BlueprintOverride)
    bool Update()
    {
        // Return false to keep ticking; true when the condition is met.
        return TargetPawn.Health <= 0;
    }

    UFUNCTION(BlueprintOverride)
    FString Describe() const
    {
        return "Waiting for pawn health to reach zero";
    }
}
```

The framework keeps calling `Update()` while it returns `false` (default ~5-second timeout, then the command fails). Carry the `FIntegrationTest&` and any actors into the command as member fields if it needs to assert.

**Built-in latent commands** (no need to re-author): `FWaitForMapToLoadCommand()`, `FEnsureWorldLoaded()`, `FExitGameCommand()`.

### `ComplexIntegrationTest_*`

Adds a companion function `<FullName>_GetTests()` returning a list of sub-test names; the framework runs the body once per entry and `T.GetParam()` returns the current one — one map hosting many parameterized cases.

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

## The wider UE test landscape (and where AngelScript stops)

AngelScript gives you `Test_*`, `IntegrationTest_*`, `ComplexIntegrationTest_*`, and the diagnostic-actor pattern. The rest of UE's testing surface is **C++- or cooked-build-only** — know it exists so you can recognise when a task is out of `.as` scope, but don't try to author it in script.

### C++ automation tests (not reachable from AngelScript)

```cpp
// Single test. Flags = exactly one context | exactly one filter.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FMyTest, "Game.MySystem.Thing",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)
bool FMyTest::RunTest(const FString& Parameters)
{
    TestEqual(TEXT("sum"), Add(2, 3), 5);   // TestTrue / TestFalse / TestEqual ...
    return true;
}

// Parameterized: GetTests() supplies rows; RunTest runs once per row.
IMPLEMENT_COMPLEX_AUTOMATION_TEST(FMyComplex, "Game.MySystem.Cases", Flags)
```

BDD spec style (also C++ only):

```cpp
BEGIN_DEFINE_SPEC(FMySpec, "Game.MySystem",
    EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)
END_DEFINE_SPEC(FMySpec)
void FMySpec::Define() {
    Describe("FireRound", [this]() {
        It("reduces ammo", [this]() { TestTrue(TEXT("..."), Gun.FireRound()); });
        LatentIt("after a tick", [this](const FDoneDelegate& Done) { /* async */ });
    });
}
```

### `EAutomationTestFlags` (C++ declarations only)

A test must combine **exactly one context** with **exactly one filter** — get the count wrong and the engine logs *"must specify exactly one filter"* and the test never runs.

| Context (pick 1, or `ApplicationContextMask` = all) | Filter (pick exactly 1) |
| --- | --- |
| `EditorContext` — runs in the editor | `SmokeFilter` — fast critical-path checks |
| `ClientContext` — game client | `EngineFilter` — engine-level |
| `ServerContext` — dedicated server | `ProductFilter` — game/product tests (most common) |
| `CommandletContext` — commandlet | `PerfFilter` / `StressFilter` / `NegativeFilter` |

AngelScript `Test_*`/`IntegrationTest_*` take **no flags** — the plugin assigns context/filter for you.

### C++ latent commands

Where AngelScript uses a `ULatentAutomationCommand` subclass + `T.AddLatentAutomationCommand`, C++ uses macros:

```cpp
DEFINE_LATENT_AUTOMATION_COMMAND_ONE_PARAMETER(FWaitUntilReady, AActor*, Actor);
bool FWaitUntilReady::Update() { return Actor && Actor->HasActorBegunPlay(); }

ADD_LATENT_AUTOMATION_COMMAND(FWaitUntilReady(MyActor));
ADD_LATENT_AUTOMATION_COMMAND(FWaitLatentCommand(1.0f));          // built-in: wait N seconds
ADD_LATENT_AUTOMATION_COMMAND(FFunctionLatentCommand([=]{ ...; return true; }));
```

### Functional tests (`AFunctionalTest`)

Actor-based, scripted scenarios placed in a map; authored in Blueprint or C++ (an AngelScript subclass of the `AFunctionalTest` `UCLASS` is possible but uncommon). For most in-world checks an `IntegrationTest_*` + a small test map is cheaper. Works in-editor and from the command line; not Gauntlet.

### Gauntlet (cooked/staged builds only)

A separate framework (C++ test controllers + a Python harness) that launches the **fully built/cooked game** on PC, console, or mobile. Use it for boot/smoke (`*TestController*BootTest`), performance measurement, and on-device coverage. It **cannot** run in the editor or through a headless test MCP server — it needs a staged build. Out of scope for `.as` regression work; reach for it only for packaged-build / platform behavior.
