---
name: unreal-engine
description: Author and modify Unreal Engine C++/Blueprint code for UE 5.x projects without hallucinating API surface. Mandates a discovery-then-search workflow — parse the *.uproject and *.Build.cs, grep both project Source/ and engine headers, and WebFetch dev.epicgames.com before stating any signature. Use when adding a UCLASS/USTRUCT/UFUNCTION, wiring replication, modifying a Build.cs, touching GAS/Lyra/Enhanced Input/UMG/Slate/AnimInstance, or any task that requires knowing a UE type's real signature in the version this project targets.
---

# unreal-engine

You are working on an Unreal Engine project. Your prior knowledge of UE is stale — UE renames symbols across minor versions and many specifiers have been deprecated. **Verify every API surface before you write it.** This skill exists to keep you from hallucinating signatures.

If the project uses Hazelight AngelScript (look for `Script/*.as` files and a `UnrealEngine-Angelscript` plugin), prefer the sibling **`unreal-engine-angelscript`** skill — AngelScript syntax differs from C++ in load-bearing ways (no macros, no `#include`, `default` keyword, RPCs reliable by default, etc.).

## The rule that overrides everything

> **If you cannot find the symbol via Grep or via WebFetch of `dev.epicgames.com/documentation`, you do not know it exists. Say "I need to verify" instead of guessing.**

LLMs hallucinate UE API names constantly — `UGameplayStatics::SpawnActorFromClass` is real, `UGameplayStatics::SpawnActorAtLocation` is not. Always verify before writing.

## Step 1 — Discover the project (do this first, every session)

Before claiming any architecture decision, run the discovery protocol in [references/discovery-protocol.md](references/discovery-protocol.md). Minimum checks:

1. **Engine version** — parse `*.uproject` → `EngineAssociation`. Resolve to a concrete `5.x` number. UE 5.3+ requires `TObjectPtr<>` for UPROPERTY object refs (raw `UObject*` crashes under incremental GC). UE 5.5 changes Enhanced Input touch-point bindings. UE 5.7 ships Nanite skeletal mesh + new PCG runtime.
2. **Module layout** — list `Source/*/*.Build.cs`. Note `PublicDependencyModuleNames` and `PrivateDependencyModuleNames`. If you add an API you must add the module to one of those lists, or the link will fail.
3. **Frameworks in use** — is this Lyra? Modular Gameplay? Game Features plugin? GAS? Enhanced Input? Common UI? Each has its own conventions that override generic UE patterns.
4. **Source-control model** — `.git`? `.p4config`? Some projects (Perforce-backed) do not have git history; do not assume `git log`.

Use `scripts/detect-engine.ps1` to automate the first two.

## Step 2 — Search before you claim

| You want to… | Do this first |
|---|---|
| Use a UE type (e.g. `FActorSpawnParameters`) | Grep the project `Source/` AND the engine headers (`Engine/Source/Runtime/**/*.h`). If absent in both, it does not exist in this version. |
| Use a UPROPERTY/UFUNCTION specifier | WebFetch `https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-uproperty-specifiers` (or the matching `ufunction-specifiers` page). Do not invent specifiers — UE will silently ignore unknown ones. |
| Override a virtual (e.g. `BeginPlay`, `Tick`, `EndPlay`, `PostInitializeComponents`) | Grep the parent class for the exact signature including `override` qualifier. UE 5.x added new lifecycle hooks; older patterns leak. |
| Touch replication | Read [references/replication.md](references/replication.md). `DOREPLIFETIME` lives in `Net/UnrealNetwork.h` — include it or you get a cryptic linker error. |
| Add a GAS attribute | Read [references/gas.md](references/gas.md). ASC placement (PlayerState vs Pawn) is a project-wide decision; check what the project already does before making the call. |
| Use a Lyra system (Experiences, GameFeatures, AbilitySets) | Read [references/lyra.md](references/lyra.md). Lyra has its own modular boot order; do not bypass it. |

## Step 3 — Code-style guardrails

These are the failure modes that the older "always do X" cheatsheets get wrong. Full details in the references; quick rules below.

- **Pointers**: `TObjectPtr<UFoo>` for any UPROPERTY object reference in UE 5.3+. Raw `UObject*` UPROPERTYs are GC-unsafe under incremental GC and crash in cooked. `TWeakObjectPtr` for non-owning refs that may outlive their target. `TSoftObjectPtr` / `TSoftClassPtr` for asset references you do not want to force-load. See [references/pointers-and-gc.md](references/pointers-and-gc.md).
- **Includes**: IWYU is the law in UE 5.x. Each header must include exactly what it uses. Do not include `Engine.h` or `EngineMinimal.h`. `*.generated.h` is always the last include in a `UCLASS`/`USTRUCT` header. See [references/iwyu-and-includes.md](references/iwyu-and-includes.md).
- **Macros**: `GENERATED_BODY()` only (not `GENERATED_USTRUCT_BODY()` — that's UE4). Every `UCLASS`, `USTRUCT`, `UINTERFACE`, `UENUM` needs the matching `U`/`A`/`F`/`E` prefix on the C++ type name.
- **Build.cs**: If you add a public include from another module, list that module in `PublicDependencyModuleNames`. Private includes go in `PrivateDependencyModuleNames`. See [references/build-cs.md](references/build-cs.md).
- **Logging**: define a project-specific log category (`DECLARE_LOG_CATEGORY_EXTERN` in a header, `DEFINE_LOG_CATEGORY` in a `.cpp`). Never use `LogTemp` in shipping code — it is a flag for unfinished work.
- **Threading**: anything touching `UWorld`, `AActor`, `UObject` must run on the game thread. Use `AsyncTask(ENamedThreads::GameThread, ...)` to hop back.

## Step 4 — Verify by running the editor / tests

Compilation is necessary, not sufficient. After a change:

1. Run the project's tests (`Window > Test Automation` in editor, or `UnrealEditor-Cmd.exe <Proj>.uproject -ExecCmds="Automation RunTests <Filter>; Quit" -unattended -nopause`).
2. Read the log via the `read-ue-logs` skill — surface any `LogScript`, `Warning`, `Error` lines from the run.
3. If the change touches gameplay, launch PIE and exercise the path. UI/visual changes require a screenshot or human verification — type-checks do not catch dead pixels.

Do not declare a change green based on "the build succeeded".

## Reference docs (read on demand)

| File | When to open |
|---|---|
| [references/discovery-protocol.md](references/discovery-protocol.md) | Start of every session that will touch UE code. |
| [references/cpp-style.md](references/cpp-style.md) | Authoring a new `UCLASS`/`USTRUCT`/`UFUNCTION` — specifier tables with official-doc links. |
| [references/pointers-and-gc.md](references/pointers-and-gc.md) | Anywhere you write a `UPROPERTY` holding an object reference. |
| [references/iwyu-and-includes.md](references/iwyu-and-includes.md) | Authoring/editing any `.h` or `.cpp`. |
| [references/build-cs.md](references/build-cs.md) | Adding a module dependency or creating a new module. |
| [references/replication.md](references/replication.md) | Anything multiplayer-sensitive — RepNotify, RPC, FastArray, conditional replication. |
| [references/gas.md](references/gas.md) | Touching the Gameplay Ability System or attributes. |
| [references/lyra.md](references/lyra.md) | Touching Lyra Experiences, GameFeatures, AbilitySets, ModularGameplay. |
| [references/enhanced-input.md](references/enhanced-input.md) | Wiring input actions / contexts. |
| [references/umg-slate.md](references/umg-slate.md) | UMG widgets, Common UI, MVVM, Slate. |
| [references/animation.md](references/animation.md) | AnimInstance, ABP, Motion Matching, Control Rig. |
| [references/api-search-protocol.md](references/api-search-protocol.md) | The full search-before-claim protocol with WebFetch URL patterns. |

## Helper scripts

- `scripts/detect-engine.ps1` — parses `*.uproject` and prints engine version + module list. Run at session start.
- `scripts/find-uclass.ps1 <Name>` — greps the project + engine source for a UCLASS/USTRUCT/UFUNCTION. Use before claiming a type exists.
- `scripts/open-epic-docs.ps1 <symbol>` — prints the canonical `dev.epicgames.com/documentation` URL for a symbol. Feed the URL to WebFetch.

## Never do

- Never edit engine source. This project uses a binary engine — engine modifications will not propagate to teammates and will be wiped by the launcher.
- Never use `UInterface` patterns blindly — they have version-specific quirks; read [references/cpp-style.md](references/cpp-style.md).
- Never claim a Blueprint node name from memory. Either grep the codebase for the underlying `UFUNCTION` or open the Blueprint in-editor.
- Never call `GENERATED_USTRUCT_BODY()` or `GENERATED_UCLASS_BODY()` — those are UE4. UE 5.x is `GENERATED_BODY()` only.
- Never hold a raw `AActor*`/`UObject*` across frames without a `TWeakObjectPtr` — incremental GC will collect it.
- Never declare a feature done without running tests AND reading the log output.
