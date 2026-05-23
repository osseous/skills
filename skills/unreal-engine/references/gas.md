# Gameplay Ability System (GAS)

GAS is opt-in via the `GameplayAbilities` plugin. It has its own learning curve and project-wide architecture decisions that are hard to change later. **Before adding anything, find out what the project already does** — ASC placement, attribute set layout, tag taxonomy, gameplay cue routing.

Official: `https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-ability-system-for-unreal-engine`

## Required modules

```csharp
PublicDependencyModuleNames.AddRange(new[] {
    "GameplayAbilities", "GameplayTags", "GameplayTasks",
});
```

Plus enable the plugin in `*.uproject`:

```json
{ "Name": "GameplayAbilities", "Enabled": true }
```

## Core types (grep for these first)

| Type | Role |
|---|---|
| `UAbilitySystemComponent` (ASC) | Per-actor controller; lives on `APawn`, `APlayerState`, or a dedicated actor |
| `UAttributeSet` | Holds replicated `FGameplayAttributeData` fields |
| `UGameplayAbility` | Activatable behavior (jump, fire, ability) |
| `UGameplayEffect` | Modifies attributes / applies tags (buffs, debuffs, costs, cooldowns) |
| `FGameplayTag` | Hierarchical tag (`Ability.Movement.Sprint`) |
| `FGameplayCue` | Cosmetic effect tied to a tag (sound, VFX, camera shake) |

## ASC placement decision

Two patterns; pick the same one the project already uses:

1. **ASC on Pawn** — simpler, ASC dies with the pawn. Good for AI and short-lived characters.
2. **ASC on PlayerState** — survives respawn (because PlayerState is per-player, not per-pawn). Standard for player characters in Lyra and most production games.

Lyra puts the ASC on PlayerState (`ULyraAbilitySystemComponent`). If you're in a Lyra project, match that.

`IAbilitySystemInterface::GetAbilitySystemComponent()` must be implemented on whatever actor owns the ASC so other systems can find it.

## Attributes — boilerplate

```cpp
// MyAttributeSet.h
UCLASS()
class UMyAttributeSet : public UAttributeSet
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Health)
    FGameplayAttributeData Health;
    ATTRIBUTE_ACCESSORS(UMyAttributeSet, Health);   // generates getter/setter/initter

    UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxHealth)
    FGameplayAttributeData MaxHealth;
    ATTRIBUTE_ACCESSORS(UMyAttributeSet, MaxHealth);

    UFUNCTION()
    void OnRep_Health(const FGameplayAttributeData& Old)    { GAMEPLAYATTRIBUTE_REPNOTIFY(UMyAttributeSet, Health, Old); }
    UFUNCTION()
    void OnRep_MaxHealth(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UMyAttributeSet, MaxHealth, Old); }

    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& Out) const override;
    virtual void PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue) override;
    virtual void PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data) override;
};
```

`ATTRIBUTE_ACCESSORS` and `GAMEPLAYATTRIBUTE_REPNOTIFY` are macros from `AttributeSet.h` — grep for them in the engine for the exact expansion.

## Initialization order

1. ASC is created (in `AMyPlayerState::AMyPlayerState` or `APawn::PostInitializeComponents`).
2. `AttributeSet` is created and added to ASC via `ASC->GetAttributeSubobject(UMyAttributeSet::StaticClass())` (created automatically on first reference if added via `Add Attribute Set` in component setup).
3. Owner/Avatar set: `ASC->InitAbilityActorInfo(OwnerActor, AvatarActor)` — call this in `OnPossess` (server) AND `OnRep_PlayerState` (client). **Both, or client side breaks.**
4. Default abilities granted via `ASC->GiveAbility(FGameplayAbilitySpec(...))`.
5. Startup effects applied via `ASC->ApplyGameplayEffectToSelf(...)`.

## Replication modes

Set per-ASC at construction:

```cpp
ASC->SetReplicationMode(EGameplayEffectReplicationMode::Mixed);
```

| Mode | Use case |
|---|---|
| `Full` | Single-player; all effects replicate to all clients |
| `Mixed` | Multiplayer player-owned ASC; effects to owner only, GameplayCues to all |
| `Minimal` | AI / NPC ASC; minimal traffic |

Lyra and most multiplayer projects use `Mixed` for players, `Minimal` for AI.

## Gameplay tags

Defined in `Config/DefaultGameplayTags.ini` or via a `UDataTable`. Reference via `FGameplayTag::RequestGameplayTag(FName("Ability.Movement.Sprint"))` — but prefer the macro:

```cpp
UE_DEFINE_GAMEPLAY_TAG_STATIC(TAG_Ability_Movement_Sprint, "Ability.Movement.Sprint");
// usage: TAG_Ability_Movement_Sprint
```

This validates at startup that the tag exists; mistypes fail loudly instead of silently no-oping.

## Common mistakes

- Forgetting `InitAbilityActorInfo` on the client → abilities don't activate locally.
- Putting the ASC on the Pawn when the project uses PlayerState (or vice versa) → ability state lost on respawn / inconsistent ownership.
- Calling `ApplyGameplayEffectToTarget` from client without authority → no-op.
- Using a raw `FName` for a tag instead of `RequestGameplayTag` → no validation, typos pass silently.
- Modifying an attribute by hand (`SetHealth(...)`) outside a GameplayEffect → bypasses replication, mods, and listeners. Always go through an effect.
