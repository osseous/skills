---
name: unreal-engine-angelscript
description: Author Hazelight AngelScript (.as) gameplay code for Unreal Engine 5.x projects using the Hazelight UnrealEngine-Angelscript fork. AngelScript looks like UE C++ but differs in load-bearing ways — no `#include`, no `GENERATED_BODY`, `default` keyword for sub-object config, `float` is 64-bit, RPCs are reliable by default, no `GetLifetimeReplicatedProps`, no `UInterface` support. This skill mandates consulting `angelscript.hazelight.se` and grepping the project `Script/` directory before claiming any binding exists. Use when adding/editing any `.as` file, subclassing a C++ UCLASS in script, wiring replication, writing tests (`Test_*` / `IntegrationTest_*`), or migrating logic from C++ to AngelScript.
---

# unreal-engine-angelscript

You are working in a Hazelight AngelScript project layered on Unreal Engine 5.x. AngelScript is a separate language from UE C++ — and the surface that looks the most familiar is exactly where the LLM-failure traps are.

If the project does NOT have `Script/*.as` files or the `UnrealEngine-Angelscript` plugin, use the sibling **`unreal-engine`** skill instead.

For the C++ side of the project (modules, Build.cs, replication framework), defer to **`unreal-engine`** — this skill covers only the AngelScript layer.

## The rule that overrides everything

> **AngelScript symbols, types, and bindings are not the same set as UE C++. Before claiming any AS API exists, you MUST verify by either (1) grepping the project `Script/` tree, or (2) WebFetching `https://angelscript.hazelight.se/api`, or (3) reading the C++ source the binding wraps. If three sources can't confirm it, say "I cannot verify this" rather than invent it.**

The Hazelight docs site (`angelscript.hazelight.se`) is the single source of truth for the language and its UE bindings. Treat it the way the C++ skill treats `dev.epicgames.com`.

## The 8 traps (memorize these)

These are the AS-vs-C++ differences that catch out every LLM that writes UE C++ from memory and forgets to switch languages:

1. **No `#include`, no headers.** Types resolve automatically across the project. No `import` keyword for engine types either. One `.as` file == one logical unit.
2. **No `GENERATED_BODY()`, no macros.** `UCLASS()`, `USTRUCT()`, `UPROPERTY()`, `UFUNCTION()` are first-class language attributes, not preprocessor macros. There is no `.h/.cpp` split.
3. **`default` keyword replaces C++ constructors** for setting subobject/property defaults:
   ```angelscript
   class AMyPawn : APawn
   {
       UPROPERTY() UStaticMeshComponent Mesh;
       default Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);
       default bReplicates = true;
   }
   ```
   `BeginPlay()` is the only constructor-equivalent runtime hook.
4. **`float` is 64-bit (double).** Use `float32` for explicit 32-bit. Catches LLMs that assume C++ `float` semantics.
5. **`UPROPERTY()` defaults to `EditAnywhere | BlueprintReadWrite`** (the opposite of C++). `UFUNCTION()` defaults to `BlueprintCallable`. Opt out with `NotEditable` / `NotBlueprintCallable`.
6. **RPCs are reliable by default** (opposite of C++). `UFUNCTION(Server)` is reliable; add `Unreliable` to opt out. `WithValidation` is implicit on `Server` RPCs.
7. **No `GetLifetimeReplicatedProps` to write.** `UPROPERTY(Replicated, ReplicationCondition = OwnerOnly, ReplicatedUsing = OnRep_X)` — the specifier alone is sufficient. The plugin generates the registration.
8. **No `UInterface`/`IInterface` support.** This is a documented engine limitation. If C++ exposes a `UInterface`, you cannot implement or query it from AngelScript. Use composition or a `UFUNCTION(BlueprintEvent)` instead.

Plus two more high-value rules:

9. **`Super::Foo()` reaches only AngelScript parents.** When you `UFUNCTION(BlueprintOverride)` a C++ `BlueprintNativeEvent`, `Super::Foo()` does NOT call the C++ implementation — only AS parents in the chain. Re-route via a separate call if you need the C++ behavior.
10. **No `->`, no pointer types.** All `UObject` variables are auto-references; use `.` always. No `nullptr` either — use plain `null`. Validity check is `IsValid(Obj)` or `Obj is null`.

## Step 1 — Discover the project

Same as the C++ skill but additionally:

- Confirm the AngelScript plugin is installed: look for `Plugins/Angelscript/` or `Plugins/UnrealEngine-Angelscript/`, and the plugin name in the `*.uproject` Plugins list.
- Locate the AS root: usually `Script/` at the project root. Note any subfolder conventions (`Script/Board/`, `Script/Tests/`, etc.).
- Read the AS startup log: run the project once and grep `LogAngelscript` via the `read-ue-logs` skill to confirm the plugin is loading scripts. A silent plugin == every `Test_*` you write goes undiscovered.

Use `scripts/detect-angelscript.ps1` (sibling) to automate this.

## Step 2 — Verify any binding before using it

For any UE type, function, or specifier you're about to write in AS:

1. **Grep the project `Script/`** for the symbol — if a teammate already uses it, the binding works.
2. **Grep the project C++ `Source/`** for the underlying type. Bindings are reflection-driven: if BP can see it, AS can. So a `UFUNCTION(BlueprintCallable)` in C++ becomes an AS-callable member. A `UPROPERTY(BlueprintReadWrite)` becomes an AS property. **A C++ member with `meta = (NotInAngelscript)` or `NoAutoAngelscriptBind` is hidden** — check for those.
3. **WebFetch the Hazelight docs**:
   - `https://angelscript.hazelight.se/api` — the canonical AS API browser
   - `https://angelscript.hazelight.se/scripting/cpp-differences/` — language differences
   - `https://angelscript.hazelight.se/scripting/networking-features/` — replication & RPCs
   - `https://angelscript.hazelight.se/scripting/functions-and-events/` — `UFUNCTION` variants
   - `https://angelscript.hazelight.se/scripting/delegates/` — delegate/event binding
   - `https://angelscript.hazelight.se/scripting/mixin-methods/` — mixin functions
   - `https://angelscript.hazelight.se/scripting/script-tests/` — test framework
4. **If still unsure**: ask the user, or check the Hazelight engine fork at `https://github.com/Hazelight/UnrealEngine-Angelscript`.

## Step 3 — Code-style guardrails

Full details in the references; quick rules below.

- **Class declarations.** `class AMyPawn : APawn { ... }`. Always use the `U`/`A`/`F` prefix as in C++ — the binding generator enforces it.
- **`UPROPERTY` defaults.** Most code should write bare `UPROPERTY()`. Opt out of editor visibility with `NotEditable`; opt out of BP visibility with `NotBlueprintCallable`. See [references/cpp-differences.md](references/cpp-differences.md).
- **FName literals: `n"MyName"`.** Mandatory for any name-bound API (delegates, find-component-by-name, etc.). `FName("MyName")` works but allocates each call; the `n"..."` form interns at compile time.
- **f-strings: `f"Hello {Name} at {Loc.Z :.3}"`.** Python-style with format specifiers. Prefer over `FString::Printf`.
- **Mixins** for extension methods on existing types:
   ```angelscript
   mixin void Teleport(AActor Self, FVector Loc)
   {
       Self.ActorLocation = Loc;
   }
   // call site: MyActor.Teleport(SomeLoc);
   ```
   First parameter is the implicit `this`. Mixins are the AS-idiomatic alternative to subclassing for shared behavior.
- **Property accessors transparent.** Any C++ `GetX()`/`SetX()` is auto-exposed as a bare property. `Actor.ActorLocation` and `Actor.GetActorLocation()` are interchangeable. Prefer the property form.
- **`Cast<T>(Obj)` works identically** to C++. Returns null on failure.
- **Events vs delegates.** `event void FFoo(...)` is multicast (`AddUFunction`/`Broadcast`). `delegate void FFoo(...)` is single-bind (`BindUFunction`/`ExecuteIfBound`). Bound targets MUST be `UFUNCTION()`. See [references/delegates-and-events.md](references/delegates-and-events.md).
- **Gameplay tags.** Use the `GameplayTag` literal syntax: `FGameplayTag MyTag = GameplayTag(n"Board.Object.Pawn");`. See [references/gameplay-tags.md](references/gameplay-tags.md).
- **Editor-only.** Wrap with `if (Editor)` blocks or use `class UMyTool : UEditorBlueprintFunctionLibrary` (UE5.x editor scripting). See [references/editor-only.md](references/editor-only.md).

## Step 4 — Hot reload + verification

The AngelScript plugin watches the `Script/` directory. Saving a `.as` file with the editor open triggers a reload — no recompile, no editor restart.

- **What survives hot reload**: existing instance references (re-bound to the new class definition).
- **What changes on hot reload**: CDO + default property values; existing instance state is re-initialized only if the layout changed.
- **What does NOT auto-rerun**: Integration tests. Only unit tests (`Test_*`) re-run automatically.
- **Verification**: after every save, watch the log. Use the `read-ue-logs` skill:
  ```
  powershell -NoProfile -File .claude/skills/read-ue-logs/scripts/read-logs.ps1 -Category LogAngelscript -Tail 50
  ```
  Look for `Compilation successful` / `Reload complete`. Compile errors are loud — but a silently-skipped file (e.g. because the parent class was renamed) won't print errors, just won't reload. Verify by setting a `Print()` in `BeginPlay` and checking the log on the next PIE start.

## Step 5 — Test-first

For test authoring, defer to the sibling **`ue-angelscript-tests`** skill — it covers the three test kinds, the test framework asserts, and the run loop. Brief:

- Default to `Test_*` (unit tests; no world required; re-run on hot reload).
- Use `IntegrationTest_*` only when you genuinely need a live world; requires a `/Content/Testing/<Name>.umap`.
- The skill workflow is: write the test → save → confirm it appears in the log under `Angelscript.UnitTests.*` → make it fail → make it pass → read the log to confirm green. **Do not declare green based on compile success alone.**

## Reference docs (read on demand)

| File | When to open |
|---|---|
| [references/cpp-differences.md](references/cpp-differences.md) | Always read once per session. Full AS-vs-C++ diff with examples. |
| [references/replication.md](references/replication.md) | Any `Replicated` / RPC work. |
| [references/delegates-and-events.md](references/delegates-and-events.md) | Binding / broadcasting / `BindUFunction`. |
| [references/mixins.md](references/mixins.md) | Extension methods, mixin libraries from C++. |
| [references/literals-and-formatting.md](references/literals-and-formatting.md) | `n""`, `f""`, format specifiers, FString idioms. |
| [references/gameplay-tags.md](references/gameplay-tags.md) | `GameplayTag(n"...")` literal, container ops. |
| [references/editor-only.md](references/editor-only.md) | Editor-only code, asset registry, BlueprintFunctionLibrary. |
| [references/interop-with-cpp.md](references/interop-with-cpp.md) | Exposing C++ to AS, subclassing C++ from AS, `BlueprintOverride`. |
| [references/hot-reload.md](references/hot-reload.md) | What survives, what doesn't, how to verify. |
| [references/footguns.md](references/footguns.md) | Documented limitations: no UInterface, no Super-to-C++, etc. |
| [references/api-search-protocol.md](references/api-search-protocol.md) | Full search-before-claim protocol with URL patterns. |

## Helper scripts

- `scripts/detect-angelscript.ps1` — verifies the AngelScript plugin is enabled, locates `Script/`, counts `.as` files, prints discovered top-level types.
- `scripts/grep-binding.ps1 <Symbol>` — searches `Script/` AND `Source/` for an AngelScript symbol or its underlying C++ binding.
- `scripts/open-as-docs.ps1 <topic>` — prints canonical `angelscript.hazelight.se` URLs for a topic.

## Reference projects to grep

When the project's own code doesn't cover a pattern, these are public reference repos:

- **Engine fork** (plugin source, binding generator): `https://github.com/Hazelight/UnrealEngine-Angelscript`
- **Docs source** (Markdown for grepping): `https://github.com/Hazelight/Docs-UnrealEngine-Angelscript`
- **VS Code extension** (LSP, language semantics): `https://github.com/Hazelight/vscode-unreal-angelscript`
- **EmmsUI** (real-world AS plugin, immediate-mode UMG): `https://github.com/Hazelight/EmmsUI`
- The Hazelight Discord (under-documented behavior): `https://discord.gg/39wmC2e`

## Never do

- Never write a `#include` in `.as`. There are no includes.
- Never write `GENERATED_BODY()` in `.as`. There are no macros.
- Never use `->` in `.as`. Use `.` always.
- Never assume `Super::Foo()` reaches a C++ parent. It only reaches AS parents.
- Never use `UInterface` from AS — unsupported. Use composition or `UFUNCTION(BlueprintEvent)`.
- Never write `GetLifetimeReplicatedProps`. The `Replicated` specifier handles it.
- Never assume `Test_*` automatically re-runs after engine restart — only after hot reload. Use `Automation RunTests` after a cold start.
- Never use a binary plugin alongside the Hazelight fork — fork is incompatible with prebuilt binary plugins; all plugins must be source-built.
- Never declare a feature done without `Print()`-ing in `BeginPlay`, running a `Test_*`, and reading the log output yourself.
