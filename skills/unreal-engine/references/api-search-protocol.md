# API Search Protocol

The single most common LLM failure mode in UE work is **hallucinating a function name that sounds plausible but does not exist**. This file is the exact verification protocol to follow before stating a signature.

## The protocol

For any UE type, function, or specifier you are about to write:

1. **Grep the project Source/** for the symbol.
2. If absent, **grep the engine headers** under the resolved engine path (see `discovery-protocol.md` §6).
3. If still absent, **WebFetch the official docs URL** for the symbol.
4. If still absent, **stop and say "I cannot verify this symbol — does it exist in your codebase?"** Do not write the line.

## Step 1 — Project grep

```
Grep pattern="\b<Symbol>\b" type="cpp" output_mode="files_with_matches"
```

This finds every project usage. If a teammate has already used it, the signature is in their code — read that.

## Step 2 — Engine header grep

```
Grep pattern="\b<Symbol>\b" path="<engine-path>/Engine/Source/Runtime" type="h" output_mode="content" -n -A 5
```

If it's an engine type, the declaration is in a runtime header. Read the surrounding 5 lines for the actual signature.

For editor-only symbols, also search `Engine/Source/Editor`.
For plugin symbols, also search `Engine/Plugins`.

## Step 3 — Official docs WebFetch

Canonical URL patterns:

| Symbol kind | URL pattern |
|---|---|
| Class API page | `https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/<Module>/<...>/<Class>` |
| UPROPERTY specifier | `https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-uproperty-specifiers` |
| UFUNCTION specifier | `https://dev.epicgames.com/documentation/en-us/unreal-engine/ufunctions-in-unreal-engine` |
| UCLASS specifier | `https://dev.epicgames.com/documentation/en-us/unreal-engine/uclass-specifiers` |
| USTRUCT specifier | `https://dev.epicgames.com/documentation/en-us/unreal-engine/ustructs-in-unreal-engine` |
| UMETA specifier | `https://dev.epicgames.com/documentation/en-us/unreal-engine/umeta-specifiers` |
| Build.cs reference | `https://dev.epicgames.com/documentation/en-us/unreal-engine/build-configuration-for-unreal-engine` |
| Module API hub | `https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/<Module>` |

If WebFetch returns a 404 on a guessed URL, that does not prove the symbol doesn't exist — try a Google-style query via WebSearch: `"<Symbol>" site:dev.epicgames.com`.

## Step 4 — Last resort: ask the user

If three sources have failed to confirm the symbol, you must not invent it. Say:

> I couldn't verify `<Symbol>` in the project source, engine headers (`<path>`), or the official docs. Can you confirm the API you're thinking of, or paste a usage from your code?

This is cheap (one user turn) compared to writing a non-compiling change.

## Common hallucination traps

- `UGameplayStatics::SpawnActorAtLocation` — does **not** exist. The real API is `SpawnActorFromClass` (with `FTransform`) or `World->SpawnActor<>()`.
- `AActor::GetWorldLocation()` — does **not** exist on `AActor`. It's `GetActorLocation()`.
- `FString::FromInt(int32)` — exists, but `FString::FromFloat` does not. Use `FString::SanitizeFloat`.
- Replication: there is no `OnReplicated_Foo()` convention. Replication callbacks are bound by name match to a property's `ReplicatedUsing=OnRep_Foo`; **the callback must be a UFUNCTION**.
- `FObjectFinder<T>` — exists only in **constructors**. Cannot be called from runtime functions.
- `TSharedRef::IsValid()` — does **not** exist; `TSharedRef` is always valid by definition. You're thinking of `TSharedPtr`.

When in doubt, grep.

## Specifier verification

UE silently ignores unknown specifiers. If you write `UPROPERTY(BlueprintReadOnly, EditAnywere)` (typo), no error — the property simply isn't editable. Always cross-check specifier spellings against the official spec page.

A useful Grep over the engine to confirm a specifier is real:

```
Grep pattern="UPROPERTY\([^)]*\b<Specifier>\b" path="<engine>/Engine/Source" type="h" output_mode="count"
```

Zero matches in engine headers → almost certainly not a real specifier.
