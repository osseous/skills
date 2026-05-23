# Lyra Framework

Lyra is Epic's sample game framework. It is not a small thing to "add a feature to" — it composes Modular Gameplay Actors, Game Features, Ability Sets, Common UI, and a deeply opinionated init pipeline. Most "just add a component" fixes don't work because Lyra wires components via Experiences.

Official: `https://dev.epicgames.com/documentation/en-us/unreal-engine/lyra-sample-game-in-unreal-engine`

## Boot order (load-bearing)

1. `ULyraGameInstance` starts.
2. The current `ULyraExperienceDefinition` asset is resolved (from URL options, command line, or the world settings).
3. Required Game Feature plugins activate (`UGameFeatureAction_AddComponents`, `UGameFeatureAction_AddInputContextMapping`, etc.).
4. `ULyraExperienceManagerComponent::OnExperienceLoaded` fires.
5. Pawns spawn / possess; ability sets grant; input contexts add.

**Never bypass this** by spawning pawns directly or adding components in `BeginPlay`. The `OnExperienceLoaded` delegate is the canonical "I can touch the world now" signal.

## Core types

| Type | Role |
|---|---|
| `ULyraExperienceDefinition` | The "game mode" asset — declares plugins, default pawn, abilities, input |
| `ULyraExperienceManagerComponent` | Per-world; tracks loading state |
| `ULyraPawnData` | Pawn class + ability sets + input config |
| `ULyraAbilitySet` | Bundle of abilities + effects + attribute sets to grant |
| `ULyraInputConfig` | Maps gameplay tags to input actions |
| `ULyraAbilitySystemComponent` | ASC; lives on PlayerState |
| `ULyraGameplayAbility` / `ULyraGameplayEffect` | Project-specific bases |
| `UGameFeatureAction_*` | Plugin-activation actions (add components, add input, register types) |

## How to add a new gameplay feature in Lyra

1. **Decide where the feature lives** — in the main game module, or in a Game Feature plugin? Plugins are isolated and can be toggled per-experience.
2. **Author the feature** — UCLASS subclasses of `ULyraGameplayAbility`, etc.
3. **Wire it via data** — add to a `ULyraAbilitySet`, reference the set from `ULyraPawnData`, reference the pawn data from the experience.
4. **Test by selecting the experience** in PIE or via URL: `?Experience=ExperienceName`.

No code change to the pawn class is required for most features — that's the point of the framework.

## Game Features plugin

A Game Feature is a `*.uplugin` with `"GameFeaturePlugin"` capabilities and a `UGameFeatureData` asset under `Content/`. The asset lists `Actions` (e.g. `UGameFeatureAction_AddComponents` to inject a component into all matching actors).

To enable: `UGameFeaturesSubsystem::Get().LoadAndActivateGameFeaturePlugin(URL, ...)`. The experience system does this for you via `GameFeaturesToEnable` on the experience.

## Modular Gameplay Actors

`AModularPawn`, `AModularCharacter`, `AModularPlayerController`, etc. — these dispatch component lifecycle events (`InitGame`, `PreInitializeComponents`, `EndPlay`) to attached components via the `IGameFrameworkComponentManager`. Components register with `UGameFrameworkComponentManager::AddGameFrameworkComponentReceiver` and then can be added to any matching actor at runtime by a Game Feature action.

Do not inherit from `APawn` / `ACharacter` directly in a Lyra project — use the modular variants.

## Common Lyra gotchas

- **`InitAbilityActorInfo` is called by `ULyraHeroComponent`**, not by your pawn. If you replace the hero component, you must replicate that call.
- **Pawn data not set** → no ability set granted → abilities don't activate. Check `ULyraPawnExtensionComponent::SetPawnData` was called.
- **Game Feature plugin loaded but components missing** → the `UGameFeatureAction_AddComponents` `TargetActor` filter does not match your actor's class. Inspect the action in the editor.
- **Input not working** → input context not added. Game Feature must have `UGameFeatureAction_AddInputContextMapping` for the relevant context.
- **Experience not loading** → `Config/DefaultEngine.ini` `[/Script/EngineSettings.GameMapsSettings]` `GlobalDefaultGameMode` is bypassed by Lyra's URL-driven mode selection. Set the experience via URL or `LyraWorldSettings`.

## Replication in Lyra

Lyra uses a command-based replication pattern for board/inventory-style state (FFastArraySerializer with append-only command lists). If your feature needs to replicate complex state, **look at how nearby Lyra systems do it** — `ULyraInventoryManagerComponent` is a canonical reference for FFastArray-with-fragments style.

## Where to grep

| You want to learn how Lyra… | Grep for / open |
|---|---|
| Initializes a pawn | `LyraHeroComponent.cpp`, `LyraPawnExtensionComponent.cpp` |
| Grants abilities | `LyraAbilitySet.cpp`, `ULyraAbilitySystemComponent::SetAbilityActorInfo` |
| Wires input | `LyraHeroComponent::InitializePlayerInput`, `LyraInputComponent` |
| Loads experiences | `LyraExperienceManagerComponent::OnRep_CurrentExperience`, `OnExperienceLoaded` |
| Spawns players | `LyraGameMode::SpawnPlayerPawn` |
| Replicates inventory | `LyraInventoryManagerComponent`, `FLyraInventoryList` |
