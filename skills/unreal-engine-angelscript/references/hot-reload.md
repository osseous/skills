# Hot Reload

The AngelScript plugin watches the `Script/` directory and reloads on save. No C++ recompile, no editor restart.

## What triggers a reload

- Saving any `.as` file in a watched directory (`Script/` by default).
- New `.as` files added — picked up on next save in the directory.
- `.as` files renamed — old class definition unbound, new one loaded.

## What survives a reload

- **Existing instance references** — pointers in the world are reseated to the new class definition.
- **Instance state on UNCHANGED fields** — preserved across reload.
- **Instance state on RENAMED/REMOVED fields** — lost.
- **Default property values from `default` blocks** — re-applied to CDO; affects newly spawned instances. Existing instances keep their current values unless you re-init.
- **Tests (`Test_*`)** — re-run automatically after a successful reload. This is the canonical liveness signal.

## What does NOT survive

- **Integration tests (`IntegrationTest_*`)** — must be run explicitly (Session Frontend or `Automation RunTests`). Not auto-re-run.
- **Currently-firing latent actions / coroutines** — cancelled on reload.
- **Timer handles** — cleared.
- **Delegate bindings to methods that were removed** — silently dropped (event listeners on living instances need to re-bind in `BeginPlay`, but `BeginPlay` doesn't fire again on reload — caveat noted below).

## What does NOT auto-fire on reload

- `BeginPlay()` — does NOT re-fire. Existing instances are alive; they already played their `BeginPlay`.
- Constructors / `default` blocks — re-applied to CDO but not to instances.

This is a common source of confusion: you change `BeginPlay` to bind a new delegate, save, and observe nothing. The fix is one of:

1. Restart PIE (cold start re-runs `BeginPlay` on freshly spawned instances).
2. Add a `UFUNCTION(CallInEditor)` "ReInit" method, hot-reload, click it on the actor.
3. Test logic that depends on `BeginPlay` from a `Test_*` instead, which DOES re-run.

## Verifying the reload happened

Use the `read-ue-logs` skill:

```
powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogAngelscript -Tail 50
```

Look for:

- `Compilation successful` / `Reload complete` — green path.
- `error: ...` — compile error; the OLD definition stays loaded until the error is fixed.
- Nothing at all — the file wasn't picked up. Possible causes: wrong directory (not under `Script/`), syntax error preventing parse, or plugin not enabled. Add a `Print()` at module scope to confirm the file is being processed.

## Compile errors stop the world

A compile error in any `.as` file blocks the entire reload. Other files in the same project will keep their previously-loaded definitions but no new changes apply until the error is fixed. This is intentional — partial reloads would yield incoherent type systems.

## Adding a `Print()` to verify

The simplest verification pattern when adding a new feature:

```angelscript
class AMyFeature : AActor
{
    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Print("AMyFeature::BeginPlay running");
        // ...
    }
}
```

Run PIE, grep the log for the marker line. If it doesn't appear, the file didn't load or the actor didn't spawn — investigate before assuming the logic is broken.

## Common mistakes

- Editing a file outside `Script/` and expecting reload → not watched. Add the directory to the plugin's watch list, or move the file.
- Expecting `BeginPlay` to re-fire on hot reload → it doesn't on existing instances. Restart PIE or use a `CallInEditor` re-init.
- Saving a file with a compile error and assuming the OLD logic is gone → it isn't. The old definition is still live until the error is fixed.
- Renaming a class and finding that BP references to it break → BP-level references are by class name; renaming breaks them. Use `Find References` before renaming.
- Adding a new `UPROPERTY()` field and finding existing instances have a zero value → expected; the new field initializes from the default. Existing instances do not "re-default" their existing fields.
