# Delegates and Events

Canonical: `https://angelscript.hazelight.se/scripting/delegates/`

Two flavors, mirroring the C++ split:

| Construct | Purpose | API |
|---|---|---|
| `delegate void FFoo(...)` | Single-bind callback | `BindUFunction`, `IsBound`, `ExecuteIfBound`, `Unbind` |
| `event void FBar(...)` | Multicast event | `AddUFunction`, `Broadcast`, `RemoveAll`, `RemoveUFunction` |

## Declaring

```angelscript
// Single-bind delegate (one listener at a time)
delegate void FOnFireDone(AMyActor Caller);

// Multicast event (zero or more listeners)
event void FOnHealthChanged(int32 OldHealth, int32 NewHealth);

class AMyActor : AActor
{
    UPROPERTY()
    FOnHealthChanged OnHealthChanged;

    UPROPERTY()
    FOnFireDone OnFireDone;
}
```

`UPROPERTY()` on the field is required for BP visibility and inspector binding. Without it the delegate/event is C++-side only.

## Binding (consumer side)

```angelscript
class AListener : AActor
{
    UFUNCTION()  // MUST be UFUNCTION — name-bound APIs need reflection
    void HandleHealthChanged(int32 Old, int32 New)
    {
        Print(f"Health: {Old} -> {New}");
    }

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        AMyActor Target = ...;
        // Event (multicast): use AddUFunction
        Target.OnHealthChanged.AddUFunction(this, n"HandleHealthChanged");

        // Delegate (single-bind): use BindUFunction
        Target.OnFireDone.BindUFunction(this, n"HandleFireDone");
    }

    UFUNCTION()
    void HandleFireDone(AMyActor Caller) { ... }
}
```

Two rules that catch out every newcomer:

1. **The bound method MUST be `UFUNCTION()`.** Plain methods are invisible to reflection; the bind silently no-ops.
2. **Use the `n"..."` literal for the name.** `BindUFunction(this, "HandleFireDone")` works but allocates an FName per call; `n"HandleFireDone"` is compile-time interned.

## Broadcasting (producer side)

```angelscript
// Event — call all listeners
OnHealthChanged.Broadcast(OldValue, NewValue);

// Delegate — call the single bound target (or no-op)
OnFireDone.ExecuteIfBound(this);
```

`Execute` (without `IfBound`) on an unbound delegate is undefined-behavior-ish — always prefer `ExecuteIfBound`.

## Unbinding

```angelscript
OnHealthChanged.RemoveUFunction(this, n"HandleHealthChanged");
OnHealthChanged.RemoveAll(this);   // remove all bindings for the target
OnFireDone.Unbind();
```

**Unbind in `EndPlay`** when the listener may outlive the producer (or vice versa). Stale bindings into destroyed objects are a major bug source — UE will silently drop them in most cases, but loud errors in some.

## Dynamic vs non-dynamic

Hazelight AS uses dynamic multicast delegates exclusively (BP-compatible). There is no AS equivalent to `DECLARE_DELEGATE` (non-dynamic), `DECLARE_DELEGATE_RetVal`, etc.

If the C++ side declares a non-dynamic delegate, it is **not bindable from AS**. You'll need a C++ adapter that re-broadcasts via a dynamic event.

## Component-side events from C++

When the C++ side declares:

```cpp
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnHealthChanged, int32, OldHealth, int32, NewHealth);

UPROPERTY(BlueprintAssignable)
FOnHealthChanged OnHealthChanged;
```

The AS side binds with:

```angelscript
SomeComp.OnHealthChanged.AddUFunction(this, n"HandleHealthChanged");
```

The `BlueprintAssignable` specifier on the C++ side is required for AS visibility (same reflection rule as the rest of the binding surface).

## Common mistakes

- Forgetting `UFUNCTION()` on the bound method → silent no-op.
- Using string instead of `n""` literal for the name → works but slow; also typos go undetected at compile time.
- Calling `Execute()` without bind → can crash; use `ExecuteIfBound`.
- Forgetting `UPROPERTY()` on the event field → invisible to BP and the inspector.
- C++ delegate is non-dynamic → not bindable from AS; wrap in C++ first.
- Binding then never unbinding when one side is destroyed → leak / stale-target dispatch.
