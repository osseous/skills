# Build.cs Reference

Every UE module has a `<ModuleName>.Build.cs` file written in C# and executed by UnrealBuildTool. It declares dependencies, defines, include paths, and toolchain options.

Official reference: `https://dev.epicgames.com/documentation/en-us/unreal-engine/build-configuration-for-unreal-engine`

## Minimal template

```csharp
using UnrealBuildTool;

public class MyModule : ModuleRules
{
    public MyModule(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion  = EngineIncludeOrderVersion.Latest;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
        });

        PrivateDependencyModuleNames.AddRange(new string[]
        {
            "Slate",
            "SlateCore",
        });
    }
}
```

## Public vs Private dependencies

| | Used by |
|---|---|
| `PublicDependencyModuleNames` | Headers in `Public/` AND `Private/` AND any downstream module |
| `PrivateDependencyModuleNames` | Headers in `Private/` AND `*.cpp` only — not visible to downstream modules |

Rule: if a header in `Public/` includes a type from another module, that module must be in `PublicDependencyModuleNames`. Otherwise a downstream module that includes our public header gets unresolved symbols.

## Common modules cheat sheet

| Want to use… | Module to add |
|---|---|
| `AActor`, `UWorld`, `UGameInstance` | `Engine` |
| `UUserWidget`, `UCommonButton` | `UMG`, `CommonUI` |
| `SButton`, Slate widgets | `Slate`, `SlateCore` |
| `UAbilitySystemComponent` (GAS) | `GameplayAbilities`, `GameplayTags`, `GameplayTasks` |
| `UInputAction`, `UInputMappingContext` (Enhanced Input) | `EnhancedInput` |
| `FGameplayMessageSubsystem` (Lyra-style) | `GameplayMessageRuntime` |
| AI / behavior trees | `AIModule`, `NavigationSystem` |
| Niagara | `Niagara`, `NiagaraCore` |
| Online subsystem | `OnlineSubsystem`, `OnlineSubsystemUtils` |
| Animation runtime | `AnimGraphRuntime` |
| Editor-only utilities | `UnrealEd`, `EditorStyle`, `EditorWidgets` (wrap in `if (Target.bBuildEditor)`) |

When in doubt: grep the engine source for the header file you need, then look at the owning module's `.Build.cs` for its module name.

## Editor-only dependencies

```csharp
if (Target.bBuildEditor)
{
    PrivateDependencyModuleNames.AddRange(new string[]
    {
        "UnrealEd",
        "EditorStyle",
    });
}
```

Without the guard, the runtime build fails.

## Build settings versions

- `DefaultBuildSettings = BuildSettingsVersion.V5;` — UE 5.4+ default. Older versions opt into older behavior.
- `IncludeOrderVersion = EngineIncludeOrderVersion.Latest;` — IWYU enforcement level. `Unreal5_4` and newer enforce strict IWYU.

If you're working in a UE 5.3 project, the values may be `V4` and `Unreal5_3` — match the rest of the project.

## Target.cs

`<Project>.Target.cs` and `<Project>Editor.Target.cs` declare the executable targets. Edit only when:

- Adding a new module to the build: `ExtraModuleNames.Add("MyNewModule");`
- Setting global defines: `GlobalDefinitions.Add("MY_DEFINE=1");`
- Changing C++ standard: `CppStandard = CppStandardVersion.Cpp20;` (UE 5.4+ default)

## Creating a new module

1. Create `Source/MyModule/MyModule.Build.cs` with the template above.
2. Create `Source/MyModule/Public/` and `Source/MyModule/Private/`.
3. Create `Source/MyModule/MyModule.h` and `MyModule.cpp` with an `IMPLEMENT_MODULE` macro:
   ```cpp
   // MyModule.cpp
   #include "MyModule.h"
   #include "Modules/ModuleManager.h"
   IMPLEMENT_MODULE(FDefaultModuleImpl, MyModule);
   ```
4. Add `MyModule` to the `Modules` array in `<Project>.uproject`.
5. Add to `ExtraModuleNames` in `<Project>.Target.cs` if it's a runtime module.
6. Regenerate project files.

## Common errors

- `Unresolved external symbol UMyType::StaticClass()` → module containing UMyType is missing from `PublicDependencyModuleNames`/`PrivateDependencyModuleNames`.
- `Cannot open include file: 'Foo.h'` → either the path is wrong, or the owning module isn't a dependency.
- `Module not found: MyModule` → not listed in the `.uproject` `Modules` array.
- `LNK2019` after rename → stale Intermediate; delete `Intermediate/` and `Binaries/` for the module.
