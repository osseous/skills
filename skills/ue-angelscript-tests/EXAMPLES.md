# EXAMPLES — ue-angelscript-tests

Three patterns: unit test, integration test (outline), diagnostic actor (counter-example). Subject code is illustrative — substitute your own helpers and types.

---

## 1. Unit test — `Test_*`

File: `Script/Tests/MathUtils_Test.as`

```angelscript
// Pure-function tests for math helpers.
// Discovered as Angelscript.UnitTests.<FunctionName>.

void Test_ManhattanDistanceOnAxis(FUnitTest& T)
{
    FIntPoint From(0, 0);
    FIntPoint To(0, 3);

    int Distance = Math::Abs(To.X - From.X) + Math::Abs(To.Y - From.Y);

    T.AssertEquals(Distance, 3);
}

void Test_ManhattanDistanceOnDiagonal(FUnitTest& T)
{
    FIntPoint From(0, 0);
    FIntPoint To(2, 2);

    int Distance = Math::Abs(To.X - From.X) + Math::Abs(To.Y - From.Y);

    T.AssertEquals(Distance, 4);
}

void Test_PointEqualityIsValueBased(FUnitTest& T)
{
    T.AssertTrue(FIntPoint(1, 2) == FIntPoint(1, 2));
    T.AssertFalse(FIntPoint(1, 2) == FIntPoint(2, 1));
}
```

**Why this works as a unit test:** no world, no actors, no replication — pure value-in / value-out. Hot-reload friendly, runs in milliseconds, fine under `-nullrhi`.

**Run it:**

```
UnrealEditor-Cmd.exe <YourProject>.uproject -ExecCmds="Automation RunTests Angelscript.UnitTests.ManhattanDistanceOnAxis; Quit" -unattended -nopause -nullrhi
```

Verify with `read-ue-logs`:

```
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogAutomationController -Tail 30
```

---

## 2. Integration test — `IntegrationTest_*` (outline)

File: `Script/Tests/ActorSpawn_Test.as`
**Companion map required:** `/Content/Testing/IntegrationTest_ActorSpawnsAndTicks.umap` — the map name matches the **full function name** (hand-authored; an agent cannot create this — leave a TODO for a human). Override the default with `FString IntegrationTest_ActorSpawnsAndTicks_GetMapName()` to point at a shared map.

The test **body runs before the map loads and before frame 1** — it only enqueues latent commands. Multi-frame waits/asserts go in a `ULatentAutomationCommand` subclass (`Update()` returns `true` when done), *not* in a lambda — AngelScript has no `FFunctionLatentCommand` lambda form.

```angelscript
// Discovered as Angelscript.IntegrationTests.ActorSpawnsAndTicks.
// Requires /Content/Testing/IntegrationTest_ActorSpawnsAndTicks.umap.

// A latent command: ticked every frame until Update() returns true.
class UAssertActorBegunPlay : ULatentAutomationCommand
{
    FIntegrationTest Test;
    AActor Actor;

    UFUNCTION(BlueprintOverride)
    bool Update()
    {
        if (!Actor.HasActorBegunPlay())
            return false;   // not ready yet — tick again next frame

        Test.AssertTrue(Actor.HasActorBegunPlay());
        Test.AssertEquals(Actor.GetActorLocation().Z, 100.0);
        return true;        // command complete
    }

    UFUNCTION(BlueprintOverride)
    FString Describe() const { return "Assert spawned actor has begun play"; }
}

void IntegrationTest_ActorSpawnsAndTicks(FIntegrationTest& T)
{
    AActor SpawnedActor = SpawnActor(AActor::StaticClass(), FVector(0, 0, 100));
    T.AssertNotNull(SpawnedActor);

    UAssertActorBegunPlay Cmd = UAssertActorBegunPlay();
    Cmd.Test = T;
    Cmd.Actor = SpawnedActor;
    T.AddLatentAutomationCommand(Cmd);
}
```

**Why this is an integration test:** needs a live world to spawn an actor; needs a tick boundary to observe `BeginPlay`. A unit test cannot reach either.

**When to choose it over a diagnostic actor:** when the assertion is *programmatic* (exact value, tag presence, count) and the failure mode is deterministic. If the answer is "looks roughly right to a human eye," use a diagnostic actor instead.

---

## 3. Diagnostic actor — counter-example, NOT a `Test_*`

For systems too heavy to set up under the automation lifecycle — multi-component state that only makes sense once a full play session is initialised — drop a diagnostic actor in a test level instead of trying to force-fit a `Test_*`.

```angelscript
// Script/Diagnostics/MyFeatureDiagnostic.as
class AMyFeatureDiagnostic : AActor
{
    UPROPERTY(Category = "Diagnostics")
    bool bAutoRunOnBeginPlay = false;

    int Passed = 0;
    int Failed = 0;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        if (bAutoRunOnBeginPlay) RunDiagnostics();
    }

    UFUNCTION(BlueprintCallable, Category = "Diagnostics")
    void RunDiagnostics()
    {
        Passed = 0; Failed = 0;
        Print("[FEATURE] === Starting Diagnostics ===", Duration = 15.0f);

        UMyFeatureComponent Feature = GetMyFeatureComponent();
        if (Feature == nullptr)
        {
            Print("[FEATURE FAIL] component not found", Duration = 15.0f);
            Failed++;
            return;
        }

        // ... walk live component state, Print PASS / FAIL / SKIP per check ...

        Print(f"[FEATURE] {Passed} passed, {Failed} failed", Duration = 15.0f);
    }
}
```

**Why it's NOT a `Test_*`:**

- It needs the **full game running** (game mode loaded, dependent subsystems initialised, levels streamed) — none of which `FUnitTest` or `FIntegrationTest` will set up. The automation lifecycle is too short for that kind of warm-up.
- The failure mode is **diagnostic**, not regression: "is this behaving as expected *right now* during this manual repro," not "did this regress against a baseline."
- Output goes to **screen + log** because the developer is watching the game, not reading a JSON report.

**Invocation:** drop the actor into a test level, then either let `bAutoRunOnBeginPlay` fire it on level load, call `RunDiagnostics()` from a Blueprint, or wrap it in a console command.

**When to write one instead of a real test:** the system spans many components, requires human visual verification, or its state is only meaningful inside a specific gameplay flow that you cannot reproduce in isolation. Keep these rare — every rule that *can* be expressed as a `Test_*` should be.
