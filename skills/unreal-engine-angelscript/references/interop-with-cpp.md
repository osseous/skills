# C++ / AngelScript Interop

Canonical: `https://angelscript.hazelight.se/cpp-bindings/automatic-bindings/`

The Hazelight plugin auto-generates AS bindings from UE reflection. The rule: **if Blueprint can see it, AngelScript can see it.**

## What gets bound

| C++ side | AS visibility |
|---|---|
| `UCLASS()` (any) | Type is visible as a parent class candidate |
| `UCLASS(BlueprintType)` | Usable as a property type, parameter type |
| `UPROPERTY(BlueprintReadWrite)` | Property; gettable + settable from AS |
| `UPROPERTY(BlueprintReadOnly)` | Property; gettable only |
| `UPROPERTY(EditAnywhere)` | Visible in default block / inspector |
| `UFUNCTION(BlueprintCallable)` | Callable method |
| `UFUNCTION(BlueprintPure)` | Callable method, treated as getter |
| `UFUNCTION(BlueprintImplementableEvent)` | Overridable via `UFUNCTION(BlueprintEvent)` in AS subclass |
| `UFUNCTION(BlueprintNativeEvent)` | Overridable via `UFUNCTION(BlueprintOverride)` in AS subclass |
| `USTRUCT(BlueprintType)` | Visible as struct type |
| `UENUM(BlueprintType)` | Visible as enum type |
| Static `UFUNCTION` | Becomes a namespaced global function |
| `UFUNCTION(BlueprintAssignable)` event | Bindable via `AddUFunction` |

## What's NOT bound

- C++ types/members **without** UE reflection (no UCLASS/UPROPERTY/UFUNCTION).
- Members marked `meta = (NotInAngelscript)` or `meta = (NoAutoAngelscriptBind)` — explicit opt-out.
- `UInterface` / `IInterface` — full category is unsupported in AS.
- Non-dynamic delegates (`DECLARE_DELEGATE`, `DECLARE_DELEGATE_RetVal`, etc.). Only dynamic multicast delegates (`DECLARE_DYNAMIC_MULTICAST_DELEGATE_*`) cross the boundary.
- Templates with non-trivial template parameters (most `TArray<T>` / `TMap<K,V>` instantiations DO work; `TSubclassOf<T>` works; `TUniquePtr<T>` does not).

## Script-only specifiers

Sometimes you want C++ → AS exposure without Blueprint exposure. Use these on the C++ side:

| Specifier | Effect |
|---|---|
| `ScriptCallable` | Like `BlueprintCallable` but only for script (AS) |
| `ScriptReadWrite` | Like `BlueprintReadWrite` but script-only |
| `ScriptReadOnly` | Like `BlueprintReadOnly` but script-only |

Useful for engine-team APIs that scripters can call but shouldn't pollute the Blueprint node palette.

## Subclassing C++ from AngelScript

```angelscript
class AMyCustomPawn : ALyraCharacter   // C++ parent
{
    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        // does NOT call ALyraCharacter::BeginPlay
        // — Super::BeginPlay() reaches only AS parents
    }
}
```

**`Super::BeginPlay()` does NOT reach the C++ parent.** If you need the parent C++ behavior, the C++ class must expose it as a separate `BlueprintCallable` (e.g. `CallParentBeginPlay`) for AS to invoke explicitly. This is a documented limitation.

For `BlueprintImplementableEvent` overrides, there's no C++ default — the override IS the implementation.

## Exposing AS to C++

C++ can call into AS via reflection (same as it calls into Blueprint):

```cpp
if (UFunction* Fn = ASInstance->FindFunction(FName("DoTheThing")))
{
    ASInstance->ProcessEvent(Fn, &Params);
}
```

This is rare — usually the direction is C++ → AS via an event the AS subscribes to, or AS → C++ by calling a `BlueprintCallable` UFUNCTION.

## Where the project's C++/AS boundary lives

Project conventions vary. Common pattern:

- **C++** owns: replication framework, performance-critical math, plugin/engine glue, type definitions other systems depend on.
- **AS** owns: gameplay logic, designer-facing entities, behaviors that change frequently.

To find the boundary in a new project:

- Grep `Source/` for `UFUNCTION(BlueprintCallable)` — these are the entry points AS will call.
- Grep `Source/` for `UFUNCTION(BlueprintImplementableEvent)` and `BlueprintNativeEvent` — these are the extension points AS subclasses fill.
- Read the existing `Script/*.as` files — they show by example what the project considers idiomatic.

## Common mistakes

- Calling a C++ `UFUNCTION` from AS without `BlueprintCallable` / `ScriptCallable` → not bound, doesn't exist as far as AS is concerned.
- Subclassing a C++ class and expecting `Super::Foo()` to call the C++ implementation → unsupported.
- Using a `UInterface` from AS → not supported. Refactor C++ to use a `UFUNCTION(BlueprintEvent)` on a common base.
- C++ side uses a non-dynamic delegate → not bindable from AS. Convert to `DECLARE_DYNAMIC_MULTICAST_DELEGATE_*` if you need AS access.
- C++ side renames a `UFUNCTION` → AS code that bound by `n"OldName"` silently breaks at runtime. There is no deprecation warning across the boundary. Always grep `Script/` for the old name when renaming a C++ binding.
