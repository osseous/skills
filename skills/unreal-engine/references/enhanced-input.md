# Enhanced Input

Enhanced Input replaced the legacy `UInputComponent::BindAction` system in UE 5.1 and is the default for new projects in UE 5.x. Lyra exclusively uses Enhanced Input.

Official: `https://dev.epicgames.com/documentation/en-us/unreal-engine/enhanced-input-in-unreal-engine`

## Core types

| Type | Role |
|---|---|
| `UInputAction` | Asset representing an abstract action ("Jump", "Move") with a `ValueType` (Bool / Axis1D / Axis2D / Axis3D) |
| `UInputMappingContext` | Asset binding keys to actions, plus modifiers/triggers |
| `UEnhancedInputComponent` | Replaces `UInputComponent`; lives on the pawn / player controller |
| `UEnhancedInputLocalPlayerSubsystem` | Per-local-player; manages which contexts are active |
| `FInputActionValue` | Value of an action at trigger time (struct holding Bool/Axis1D/Axis2D/Axis3D variant) |

## Required modules

```csharp
PublicDependencyModuleNames.Add("EnhancedInput");
```

Plus `"EnhancedInput"` plugin enabled in `*.uproject` (default-on in UE 5.1+).

## Minimal wiring (non-Lyra)

```cpp
void AMyCharacter::SetupPlayerInputComponent(UInputComponent* Input)
{
    Super::SetupPlayerInputComponent(Input);

    if (UEnhancedInputComponent* EIC = CastChecked<UEnhancedInputComponent>(Input))
    {
        EIC->BindAction(JumpAction, ETriggerEvent::Triggered, this, &AMyCharacter::HandleJump);
        EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AMyCharacter::HandleMove);
    }
}

void AMyCharacter::PossessedBy(AController* NewController)
{
    Super::PossessedBy(NewController);
    AddInputContext();
}

void AMyCharacter::AddInputContext()
{
    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        if (auto* Sub = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer()))
        {
            Sub->AddMappingContext(DefaultContext, /*Priority*/ 0);
        }
    }
}

void AMyCharacter::HandleMove(const FInputActionValue& Value)
{
    const FVector2D Axis = Value.Get<FVector2D>();
    AddMovementInput(GetActorForwardVector(), Axis.Y);
    AddMovementInput(GetActorRightVector(),   Axis.X);
}
```

## Trigger events

```
Started     — entering the active state (e.g. button pressed)
Triggered   — actively firing (every frame while held, for axes)
Ongoing     — held but still in a hold-time pre-fire window
Completed   — released
Canceled    — pre-fire window broken (e.g. tap cancelled by movement)
```

Bind to `Triggered` for movement; `Started` for one-shots like jump; `Completed` for release behavior.

## Modifiers and triggers (on the mapping context, per binding)

- **Modifiers** transform the raw input: `Negate`, `Swizzle Input Axis Values` (XYZ → ZYX etc.), `Dead Zone`, `Scale`.
- **Triggers** gate when the action fires: `Hold`, `Tap`, `Pulse`, `Chord`, `Combo`.

Both are configured on each binding entry in the `UInputMappingContext` asset, not on the action itself.

## Lyra-specific path

Lyra wires input via `ULyraHeroComponent` + `ULyraInputConfig` + `ULyraInputComponent`. The input config maps **gameplay tags** (not C++ function pointers) to actions, and the binding is generic:

```cpp
LyraInputComponent->BindAbilityActions(InputConfig, this, &ThisClass::Input_AbilityInputTagPressed, &ThisClass::Input_AbilityInputTagReleased);
```

Where the released/pressed handlers fan out via the ASC's `AbilityLocalInputPressed(InputID)` keyed by the gameplay tag. To add a new input in Lyra:

1. Add the action to `ULyraInputConfig` data asset.
2. Add the key mapping to a `UInputMappingContext`.
3. Tag the ability with the matching input tag.
4. Game Feature action `UGameFeatureAction_AddInputContextMapping` adds the context.

No C++ changes to the pawn.

## Common mistakes

- Calling `BindAction` on a non-Enhanced `UInputComponent` → silent no-op (or compile error if you skip `CastChecked`).
- Adding the mapping context before the local player exists → no-op. Wait for `PossessedBy` / `OnPossessed`.
- Forgetting to set `ValueType` on the `UInputAction` → values are always zero.
- Binding to `Triggered` for a tap-style action → fires every frame while held.
- Lyra: forgetting the gameplay tag on the ability → input dispatched but no ability claims it.
