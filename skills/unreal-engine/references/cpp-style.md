# UE C++ Code Style

Project-specific style usually overrides this — check `.clang-format` and any nearby files first. The rules below are the **engine-wide invariants** that hold across UE 5.x projects.

## Type prefixes (load-bearing — UHT enforces them)

| Prefix | Meaning |
|---|---|
| `U` | `UObject` subclass: `UActorComponent`, `UMyComponent` |
| `A` | `AActor` subclass: `APawn`, `AMyCharacter` |
| `F` | Plain struct / non-UObject value type: `FVector`, `FMyData` |
| `E` | Enum: `EMovementMode`, `EMyState` |
| `I` | UInterface implementation: `IMyInterface` (paired with `UMyInterface : public UInterface`) |
| `T` | Template: `TArray`, `TSubclassOf` |
| `S` | Slate widget: `SButton`, `SMyWidget` |
| `b` | Boolean variable: `bIsActive`, `bReplicates` |

UHT will fail compilation if a `UCLASS` doesn't start with `U` or `A`. A `USTRUCT` must start with `F`.

## The five canonical declarations

```cpp
// .h
UCLASS()
class MYMODULE_API UMyComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MyCategory")
    TObjectPtr<USomeAsset> SomeAsset;

    UFUNCTION(BlueprintCallable, Category = "MyCategory")
    void DoTheThing();
};

USTRUCT(BlueprintType)
struct FMyData
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere)
    int32 Count = 0;
};

UENUM(BlueprintType)
enum class EMyState : uint8
{
    Idle    UMETA(DisplayName = "Idle"),
    Active  UMETA(DisplayName = "Active"),
};

UINTERFACE(MinimalAPI, Blueprintable)
class UMyInterface : public UInterface { GENERATED_BODY() };
class IMyInterface
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintNativeEvent)
    void OnPing();
};

DECLARE_LOG_CATEGORY_EXTERN(LogMyModule, Log, All);  // header
DEFINE_LOG_CATEGORY(LogMyModule);                    // exactly one cpp
```

## UPROPERTY specifiers — quick reference

Always verify against the canonical list: `https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-uproperty-specifiers`. The high-traffic ones:

| Specifier | Effect |
|---|---|
| `EditAnywhere` | Editable in archetype + per-instance |
| `EditDefaultsOnly` | Editable in archetype/blueprint defaults only |
| `EditInstanceOnly` | Editable on placed instances only |
| `VisibleAnywhere` / `VisibleDefaultsOnly` / `VisibleInstanceOnly` | Read-only counterparts |
| `BlueprintReadWrite` | Get + Set in BP |
| `BlueprintReadOnly` | Get only in BP |
| `Category = "X"` | Required if any Blueprint or editor flag is set |
| `Replicated` | Replicated; pair with `DOREPLIFETIME` in `GetLifetimeReplicatedProps` |
| `ReplicatedUsing = OnRep_X` | Replicated with RepNotify; `OnRep_X` must be a UFUNCTION |
| `Transient` | Skipped during save/load |
| `SaveGame` | Included only in `SaveGame` archives |
| `AdvancedDisplay` | Hidden behind the "advanced" expander in details |
| `meta = (...)` | Editor-only hints: `ClampMin`, `EditCondition`, `AllowPrivateAccess`, `DisplayName`, `ToolTip` |

## UFUNCTION specifiers — quick reference

| Specifier | Effect |
|---|---|
| `BlueprintCallable` | Callable from BP |
| `BlueprintPure` | Callable, no exec pins (treat as getter) |
| `BlueprintImplementableEvent` | No C++ body; implemented in BP. Cannot be called from BP child of same class. |
| `BlueprintNativeEvent` | C++ default in `Foo_Implementation`; BP can override |
| `BlueprintCosmetic` | Server-side compile error if called on dedicated server |
| `Server` / `Client` / `NetMulticast` | RPC direction. **Default is unreliable** — add `Reliable` if needed. |
| `WithValidation` | Required on `Server` RPCs; you must implement `Foo_Validate` |
| `Exec` | Console-callable via `Exec` |
| `CallInEditor` | Adds a button in Details when on a UCLASS without `BlueprintType` |
| `meta = (WorldContext = "X", BlueprintInternalUseOnly = "true", AutoCreateRefTerm = "Foo,Bar")` | Common meta hints |

**For `BlueprintNativeEvent`, the C++ implementation goes in `Foo_Implementation`, not `Foo`.** The UHT generates a thunk named `Foo` that dispatches.

## UCLASS specifiers — quick reference

| Specifier | Effect |
|---|---|
| `Blueprintable` | Can be subclassed in BP |
| `BlueprintType` | Can be used as a variable type in BP |
| `Abstract` | Cannot be instantiated directly |
| `NotBlueprintable` | Cannot be subclassed in BP (explicit negation) |
| `Within = USomething` | Must live inside the given outer |
| `Config = Game` | Properties marked `Config` save to `Game.ini` |
| `DefaultToInstanced, EditInlineNew` | For composable subobjects (e.g. components, behavior trees) |
| `meta = (DisplayName, ShortToolTip, ScriptName)` | Editor labels |

## Forward declaration

Forward-declare in headers whenever possible — full `#include` only in the `.cpp`. This keeps compile times sane.

```cpp
// .h
class UStaticMeshComponent;

// .cpp
#include "Components/StaticMeshComponent.h"
```

## Naming

- Method names: `PascalCase`, verb-first (`SpawnPickup`, not `pickupSpawn`).
- Boolean variables and methods: `b` prefix on the var (`bIsActive`), `Is`/`Has`/`Should` prefix on the method (`IsActive()`).
- Local variables and parameters: `PascalCase` too (UE convention — no `lowerCamel` here).
- One UCLASS per `.h`/`.cpp` pair when reasonable. Multiple small USTRUCTs per file is fine.

## Common mistakes

- Forgetting `Category` on a `UPROPERTY` with any BP/editor flag → UHT error.
- Calling a `BlueprintNativeEvent` directly instead of via the thunk → ambiguous when BP overrides.
- Using `BlueprintImplementableEvent` and then trying to provide a default in C++ → silently ignored.
- Putting `*.generated.h` anywhere other than last in the include list → UHT error.
- Declaring a UINTERFACE without the paired `IFoo` abstract class → compile errors.
- Returning `TSharedPtr<T>` from a `UFUNCTION` → unsupported, BP reflection cannot marshal Slate types.
