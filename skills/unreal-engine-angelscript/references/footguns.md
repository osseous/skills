# Documented Footguns

Sourced from `https://angelscript.hazelight.se/project/development-status/` and aggregated from community Discord experience. **Read this once at session start.**

## Unsupported

| Feature | Status | Workaround |
|---|---|---|
| `UInterface` / `IInterface` | Not supported in AS at all. Cannot implement or query from script. | Use composition, or expose the API as a `UFUNCTION(BlueprintEvent)` on a common base class. |
| `Super::Foo()` reaching a C++ parent | Only AS parents are reachable. | Expose the C++ parent behavior as a separate `BlueprintCallable` UFUNCTION the AS subclass can call explicitly. |
| Non-dynamic delegates | Not bindable from AS. | Wrap in C++ that re-broadcasts via a dynamic delegate. |
| `FFastArraySerializer` custom net delta | Cannot declare custom delta serializers in AS. | Declare the FastArray type in C++; emit/consume entries from AS via wrapped UFUNCTIONs. |
| Editor binary plugins alongside the fork | Hazelight fork is **not** binary-plugin compatible. | All plugins must be source-built against the fork. |
| Templates with non-trivial parameters | E.g. `TUniquePtr<T>`, custom traits. | Use the standard container types (`TArray`, `TMap`, `TSet`). |
| Cross-boundary deprecation warnings | C++ renames don't warn in AS. | Always grep `Script/` when renaming a C++ binding. |

## Silent failures (no error, wrong behavior)

- **Delegate bound to a non-`UFUNCTION` method** → silent no-op. Method is invisible to reflection.
- **`Replicated` specifier without `default bReplicates = true`** → property never replicates; no error.
- **Hot reload skipped a file** → no compile error if the file simply didn't get re-parsed (rare but happens). Verify with a `Print()` marker.
- **C++ binding hidden by `meta = (NotInAngelscript)`** → call site fails to resolve, sometimes with a confusing error pointing at the line *after* the actual issue.
- **`n"Foo"` typo in delegate bind** → name is just an invalid FName; bind silently does nothing.
- **`GameplayTag(n"Foo.Bar")` for an unregistered tag** → invalid tag returned; subsequent `HasTag` checks return false silently. Register all tags up front.
- **AS subclass of C++ that uses `BlueprintImplementableEvent`** → if you write the override body as `UFUNCTION(BlueprintCallable)` instead of `UFUNCTION(BlueprintOverride)`, it does not override. Just becomes a new method.
- **RPC called on the wrong machine** → no error; just doesn't run remotely. Always check `HasAuthority()` / `GetLocalRole()` in handlers.

## Performance gotchas

- **`Print(f"...")` in tight loops** — formatted string + log allocation per call. Strip from shipping or gate with `if (Editor)`.
- **`FName(SomeString)` in a hot path** — allocates per call. Use `n""` literals or cache once.
- **Tick on AS class** — AS Tick has overhead beyond C++ Tick (cross-boundary call). Prefer event-driven where possible; use a UE timer (`SetTimer`) for periodic work.
- **Heavy work in a UI Tick** — same as C++; avoid.

## Project hygiene gotchas

- **`.as` file outside watched directory** — silently not loaded. The default watch is `Script/`; check the plugin config for additions.
- **Renaming an AS class** — BP references break (BP refers to classes by name). Search and fix or alias before renaming.
- **Multiple AS classes with the same name in different folders** — the loader picks one; the other is shadowed. Use unique class names project-wide.
- **`default` block referencing a runtime-only value** — fails to evaluate at CDO time. Defaults must be compile-time constants or static-callable expressions.

## When in doubt, log it

If behavior is wrong and you can't tell why, add `Print()` markers:

```angelscript
Print(f"reached point A, value = {Value}");
```

Save, repro, read the log via the `read-ue-logs` skill. Five `Print` lines beat ten minutes of "should this work?" reasoning.
