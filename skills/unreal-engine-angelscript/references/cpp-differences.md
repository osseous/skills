# AS vs C++ — Full Diff

Canonical source: `https://angelscript.hazelight.se/scripting/cpp-differences/`. This file is a navigable summary. WebFetch the canonical page for anything you can't find here.

## File layout

| C++ | AngelScript |
|---|---|
| `.h` / `.cpp` split | One `.as` file per logical unit |
| `#include "Other.h"` | Auto-resolution; no include or import keyword |
| `*.generated.h` last | No generated headers |
| `IMPLEMENT_MODULE(...)` | No module manifest; folder presence is enough |

## Class declarations

```cpp
// C++
UCLASS()
class MYMODULE_API AMyPawn : public APawn
{
    GENERATED_BODY()
public:
    AMyPawn();
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Mesh")
    UStaticMeshComponent* Mesh;
};
```

```angelscript
// AngelScript
class AMyPawn : APawn
{
    UPROPERTY()  // == EditAnywhere | BlueprintReadWrite by default
    UStaticMeshComponent Mesh;

    default Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);
    default bReplicates = true;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Print("AMyPawn::BeginPlay");
    }
}
```

Key shifts:

- No `MYMODULE_API` (no DLL boundary in AS).
- No `: public` — just `:` with the parent name.
- No `GENERATED_BODY()`.
- No constructor; `default` block replaces it for property defaults; `BeginPlay()` for runtime init.
- `UStaticMeshComponent` is a reference, not a pointer. No `*`.

## Primitive types

| AS | Meaning |
|---|---|
| `int`, `int32` | 32-bit signed |
| `int64` | 64-bit signed |
| `uint`, `uint32`, `uint64` | unsigned |
| `bool` | bool |
| `float` | **64-bit (double)** — trap |
| `float32` | 32-bit float (use explicitly when wrapping C++ that takes `float`) |
| `float64` | alias for `float` |
| `FString` | string |
| `FName` | name; use `n"..."` literal |
| `FText` | localized text |

**Always use `float32` when binding to C++ APIs that take `float`** — silent precision conversion otherwise.

## UPROPERTY specifier defaults

C++ defaults: nothing (you must opt in).
AS defaults: `EditAnywhere | BlueprintReadWrite | Category = <class name>`.

| You want… | AS specifier |
|---|---|
| Hidden in editor | `UPROPERTY(NotEditable)` |
| Hidden in BP | `UPROPERTY(NotBlueprintCallable)` |
| Editor-only (default object only) | `UPROPERTY(EditDefaultsOnly)` |
| Read-only in BP | `UPROPERTY(BlueprintReadOnly)` |
| Replicated with RepNotify | `UPROPERTY(Replicated, ReplicatedUsing = OnRep_Foo)` |
| Skip GC tracking | impossible — AS auto-tracks all UObject refs |

## UFUNCTION specifier defaults

C++ default: nothing.
AS default: `BlueprintCallable`.

| You want… | AS specifier |
|---|---|
| BP-implementable event | `UFUNCTION(BlueprintEvent)` — single flavor replaces both `BlueprintImplementableEvent` and `BlueprintNativeEvent`. Base must have a body (can be empty). |
| Override a C++ `BlueprintNativeEvent` / `BlueprintEvent` | `UFUNCTION(BlueprintOverride)` |
| Hidden from BP | `UFUNCTION(NotBlueprintCallable)` |
| Server RPC | `UFUNCTION(Server)` (reliable by default) |
| Client RPC | `UFUNCTION(Client)` |
| Multicast RPC | `UFUNCTION(NetMulticast)` |
| Unreliable RPC | add `Unreliable` |

## Variable declarations

```angelscript
// Locals
int Count = 0;
AActor MyActor = SomeRef;   // reference; no *
TArray<AActor> Actors;
```

No `auto` keyword; types are explicit. No `nullptr` — use `null`.

## Null checks

```angelscript
if (MyActor is null) { ... }
if (!IsValid(MyActor)) { ... }   // also handles pending-kill
if (MyActor !is null && MyActor.bHidden) { ... }
```

`is` / `!is` are AS-specific identity-comparison operators for reference types.

## Casts

```angelscript
ACharacter Char = Cast<ACharacter>(SomeActor);
if (Char != null) { ... }
```

Identical to C++ `Cast<T>` semantics. Returns null on failure.

## Containers

`TArray<T>`, `TMap<K,V>`, `TSet<T>` — same surface as C++. Range-for:

```angelscript
for (AActor A : Actors) { ... }
```

## Class hooks

| Hook | Equivalent C++ |
|---|---|
| `BeginPlay()` with `UFUNCTION(BlueprintOverride)` | `BeginPlay` |
| `Tick(float DeltaSeconds)` with `UFUNCTION(BlueprintOverride)` | `Tick` |
| `EndPlay(EEndPlayReason::Type Reason)` with `UFUNCTION(BlueprintOverride)` | `EndPlay` |
| `default ...` block in class body | constructor / `OnConstruction` for property defaults |

Any C++ `UFUNCTION(BlueprintNativeEvent)` or `BlueprintImplementableEvent` is overridable from AS via `UFUNCTION(BlueprintOverride)`.

## `default` keyword (load-bearing)

`default` runs at CDO time — setting up subobject properties and defaults that the C++ constructor would handle.

```angelscript
class AMyActor : AActor
{
    UPROPERTY() UStaticMeshComponent Mesh;
    UPROPERTY() float Speed;

    default Mesh.SetStaticMesh(Cast<UStaticMesh>(LoadObject(null, "/Game/Meshes/Cube.Cube")));
    default Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);
    default Speed = 600.0;
    default bReplicates = true;
}
```

Anything outside a `default` block runs per-instance (in `BeginPlay`, member functions, etc.).

## Common conversion mistakes (from C++ memory)

- Writing `class UFoo : public UActorComponent` → wrong; drop `public`.
- Writing `UProperty(EditAnywhere)` → wrong specifier capitalization (also: it's `UPROPERTY`).
- Writing `nullptr` → use `null`.
- Writing `->` → use `.`.
- Writing `Super::BeginPlay()` and expecting it to call C++ `BeginPlay` → it only reaches AS parents.
- Writing a manual `GetLifetimeReplicatedProps` → unsupported; the specifier alone handles it.
- Writing a `UInterface` → unsupported in AS.
- Forgetting `float32` when wrapping a C++ `float` parameter → silent precision loss.
- Using `n"MyName"` to build an FName at runtime from a variable → `n""` is a *literal* form, not a constructor. Use `FName(Var)` when the value isn't known at compile time.
