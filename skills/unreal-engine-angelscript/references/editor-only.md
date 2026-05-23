# Editor-Only Script

Canonical: `https://angelscript.hazelight.se/scripting/editor-script/`

AngelScript can author editor utilities — asset import helpers, in-editor tools, blueprint function libraries that only run in the editor.

## Editor-only class

```angelscript
UCLASS(Meta = (Editor))
class UMyEditorTool : UObject
{
    UFUNCTION(CallInEditor)
    void DoTheThing()
    {
        Print("Running editor-only logic");
    }
}
```

Editor-only classes are stripped from cooked (shipping) builds — they never ship with the game.

## Editor-only Blueprint function library

```angelscript
class UMyEditorLib : UBlueprintFunctionLibrary
{
    UFUNCTION(BlueprintCallable, Meta = (Editor))
    static void AnalyzeSelection()
    {
        TArray<UObject> Selected = EditorUtilityLibrary::GetSelectionSet();
        // ...
    }
}
```

The `Meta = (Editor)` keeps the function out of cooked builds.

## Editor-only blocks

For mixed-mode classes that have one or two editor-only methods, gate at runtime:

```angelscript
UFUNCTION()
void SomeMethod()
{
    if (Editor)
    {
        // editor-only branch
    }
}
```

The `Editor` global resolves to true only inside the editor process. The branch is stripped via dead-code elimination in cooked builds.

## Asset registry access

```angelscript
TArray<UObject> Assets;
EditorAssetLibrary::GetAssetsByPath("/Game/Items/", Assets, /*Recursive=*/true);
```

`EditorAssetLibrary` and `EditorUtilityLibrary` are the main entry points. Both are C++ — grep for them in the engine source to find their full method surface, or check `angelscript.hazelight.se/api`.

## Running editor scripts

- **CallInEditor** button — appears in the Details panel when a `UFUNCTION(CallInEditor)` is on the selected actor / utility.
- **Editor Utility Widget** — a `UEditorUtilityWidget` that hosts an AS-callable button.
- **Console command** — if the function is marked `Exec`, you can call it from the editor console.

## Asset placement convention

Editor-only `.as` files conventionally live under `Script/Editor/` to keep them separate. The plugin still scans them, but the directory makes intent obvious to other contributors.

## Common mistakes

- Forgetting `Meta = (Editor)` → editor logic ships to players.
- Calling `EditorAssetLibrary` in a runtime path → fails in cooked builds (the type isn't there).
- Trying to use editor-only types in a `default` block of a runtime class → cook failure.
- `if (Editor)` guards work for branching, but not for *type usage* — if you reference an editor-only type anywhere in a runtime class, cooking fails. Split into a separate editor-only class.
