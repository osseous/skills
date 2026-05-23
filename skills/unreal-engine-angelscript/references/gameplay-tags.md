# Gameplay Tags in AngelScript

Canonical: `https://angelscript.hazelight.se/scripting/gameplaytags/`

Tag literals in AS use a dedicated `GameplayTag(...)` constructor + `n""` FName literal.

## Declaring + using a tag

```angelscript
// At-use literal
FGameplayTag MyTag = GameplayTag(n"Board.Object.Pawn");

// Or globally cached
const FGameplayTag TAG_Pawn = GameplayTag(n"Board.Object.Pawn");

if (Container.HasTag(TAG_Pawn)) { ... }
```

`GameplayTag(n"...")` resolves at startup against the registered tag set. **If the tag isn't registered**, the call returns an invalid tag and you'll see a `LogGameplayTags` warning on first use.

## Registering tags

Tags must exist in:

- `Config/DefaultGameplayTags.ini`, or
- A `UDataTable` row of type `FGameplayTagTableRow` referenced by the project's gameplay tag settings.

If a tag is missing, register it (don't paper over with a string). The `Project Settings > Project > GameplayTags` UI is the editor entry point.

## Tag containers

```angelscript
FGameplayTagContainer Container;
Container.AddTag(TAG_Pawn);
Container.AddTag(GameplayTag(n"Board.Object.Wall"));
Container.RemoveTag(TAG_Pawn);

if (Container.HasTag(TAG_Pawn)) { ... }
if (Container.HasAny(OtherContainer)) { ... }
if (Container.HasAll(OtherContainer)) { ... }
```

For hierarchical tags (`Board.Object.Pawn` is a child of `Board.Object`):

```angelscript
if (Container.HasTagExact(TAG_Pawn))    { ... }  // exact match only
if (Container.HasTag(TAG_Object))       { ... }  // parent match — true if any child present
```

Default `HasTag` is parent-aware; `HasTagExact` is the exact-match opt-in.

## Tag-based dispatch (project convention)

If the project uses tag-based behavior (as AbsurdChess does — `Block.Traversable` instead of `bool bBlocksMovement`), prefer tag queries to enum/bool fields when adding new state. Reasons:

- Composable: multiple states can coexist on one entity.
- Designer-friendly: data tables can author the set without code changes.
- Diff-friendly: adding a new state doesn't require touching every conditional.

## Common mistakes

- Calling `GameplayTag("Board.Object.Pawn")` (without `n""`) → works but allocates an FName per call.
- Building a tag from a runtime FName via `FGameplayTag::RequestGameplayTag(SomeFName, false)` → returns an invalid tag silently if the name isn't registered. Always check `IsValid()` on the returned tag.
- Using `HasTagExact` when you wanted parent-aware match → misses children. Default to `HasTag` unless you specifically need exact.
- Adding a tag at runtime without registering in config → warning in log, tag is unusable. Always register tags up front.
