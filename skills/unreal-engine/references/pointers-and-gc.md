# Pointers and Garbage Collection

UE has its own GC. Getting the pointer types wrong leads to either crashes (UAF) or leaks (object stays alive forever). UE 5.3 added incremental GC, which made several previously-tolerable patterns crash in cooked builds.

## The decision tree

| You need… | Use |
|---|---|
| Owning reference to a `UObject` from a `UPROPERTY` (UE 5.3+) | `TObjectPtr<UFoo>` |
| Non-owning reference that may outlive its target | `TWeakObjectPtr<UFoo>` |
| Reference to an asset on disk that you don't want to load yet | `TSoftObjectPtr<UFoo>` |
| Reference to a class on disk that you don't want to load yet | `TSoftClassPtr<UFoo>` |
| A class to spawn (loaded, BP-friendly) | `TSubclassOf<UFoo>` |
| A non-UObject value type to share | `TSharedPtr<F...>` / `TSharedRef<F...>` (Slate-style) |
| A `UObject*` parameter passed within a single call | Raw `UFoo*` is fine here |
| An interface implementation | `TScriptInterface<IFoo>` |

## TObjectPtr vs raw pointers (UE 5.3+ rule)

UE 5.0 introduced `TObjectPtr<T>` as a drop-in replacement for `UFoo*`. UE 5.3 made incremental GC the default, which can collect a raw `UFoo*` field between frames if it isn't marked as a UPROPERTY-with-reflection. `TObjectPtr` carries the access barrier that keeps the GC honest.

```cpp
// UE 5.3+
UCLASS()
class UMyComp : public UActorComponent
{
    GENERATED_BODY()
public:
    UPROPERTY()
    TObjectPtr<AActor> CachedActor;   // GOOD

    UPROPERTY()
    AActor* CachedActor;              // STILL COMPILES, crash-prone in cooked
};
```

For **non-UPROPERTY** local variables, raw `UFoo*` is fine — incremental GC only matters for fields persisted across frames.

## TWeakObjectPtr

Use when:
- You cache a reference to something you do not own (player controller, level actor)
- The target may be destroyed before you next access it

```cpp
UPROPERTY()
TWeakObjectPtr<AActor> WeakTarget;

if (AActor* T = WeakTarget.Get()) { /* use T */ }
```

`.Get()` returns `nullptr` if the target has been GC'd or `Destroyed`. **Always null-check.**

## TSoftObjectPtr / TSoftClassPtr

For asset references in data tables, configs, or designer-facing properties where you do not want to force-load the asset at editor open.

```cpp
UPROPERTY(EditAnywhere)
TSoftObjectPtr<USoundCue> Sound;

// Load on demand:
if (USoundCue* S = Sound.LoadSynchronous()) { ... }

// Or async:
FStreamableManager& Streamable = UAssetManager::GetStreamableManager();
Streamable.RequestAsyncLoad(Sound.ToSoftObjectPath(), [WeakThis = TWeakObjectPtr<UMyComp>(this)]() {
    if (UMyComp* T = WeakThis.Get()) { T->OnSoundLoaded(); }
});
```

## TSubclassOf<T>

For "give me a UClass that is a subclass of T". The editor will filter the picker to compatible classes; the runtime gets a `UClass*` you can pass to `SpawnActor<>`.

```cpp
UPROPERTY(EditDefaultsOnly)
TSubclassOf<AActor> ActorClass;

GetWorld()->SpawnActor<AActor>(ActorClass, Loc, Rot);
```

## TScriptInterface<I>

For UInterface references where the BP side needs to inspect both the object and the interface vtable.

```cpp
UPROPERTY(EditAnywhere)
TScriptInterface<IInteractable> Target;

if (Target.GetInterface())
{
    Target->Interact();   // C++ side, via IInteractable
}
```

## TSharedPtr / TSharedRef

For Slate widgets and non-UObject value types. **Do not** use these for `UObject`s — they don't integrate with UE GC.

## GC entry points and lifetime

- Default GC runs every ~60 seconds (configurable). Incremental GC slices the work across frames.
- `MarkAsGarbage()` (UE 5.0+) replaces the old `MarkPendingKill()` — call this if you want a UObject collected on the next GC pass.
- `IsValid(Ptr)` checks both null AND pending-kill. Prefer this over `Ptr != nullptr` for UObject references.

## Common bugs

- **Raw `UFoo*` field with no UPROPERTY** → reference is invisible to GC, target gets collected, you UAF on next access. Fix: add `UPROPERTY()`.
- **`TWeakObjectPtr` without `.Get()` null-check** → null deref. The whole point of weak is that it can become null.
- **`TSharedPtr<UMyObject>`** → wrong type pairing. UObjects manage their own lifetime via GC.
- **Holding `AActor*` from a different world** → cross-world references are invalid; use `TWeakObjectPtr` and check `IsValid()` + `GetWorld() == ThisWorld`.
- **Storing a return value of `SpawnActor` without UPROPERTY** → spawn succeeds, then GC eats it before you use it.
