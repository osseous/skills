# Discovery Protocol

Run this at the start of every session that will touch UE code. Outputs feed every later decision: engine version gates pointer rules, module list gates Build.cs edits, framework detection gates which sibling reference doc to read.

## 1. Locate the project root

The project root is the directory containing exactly one `*.uproject` file. If invoked from a subdirectory, walk parents until found. If multiple `*.uproject` files exist (a monorepo), the user must disambiguate — do not guess.

## 2. Parse engine version

```powershell
# scripts/detect-engine.ps1 does this for you
$uproj = Get-ChildItem -Filter *.uproject | Select-Object -First 1
$json  = Get-Content $uproj.FullName -Raw | ConvertFrom-Json
$engineAssoc = $json.EngineAssociation   # "5.7", "{GUID}", or "{installed}"
```

- A bare `"5.7"` means the launcher-installed engine of that minor version.
- A `{GUID}` means a source build registered in the Windows registry under `HKCU:\SOFTWARE\Epic Games\Unreal Engine\Builds`.
- A `{installed}` token means a project-local engine — look in the launcher manifest.

**Always resolve to a concrete `5.x` number before applying version-gated rules.** UE 5.0, 5.3, 5.5, 5.7 each shipped breaking changes.

## 3. Enumerate modules

```powershell
Get-ChildItem -Path Source -Recurse -Filter *.Build.cs |
  ForEach-Object { $_.Directory.Name }
```

For each module, open the `*.Build.cs` and note `PublicDependencyModuleNames` + `PrivateDependencyModuleNames`. This is the canonical answer to "what modules can I include headers from here?".

## 4. Detect frameworks

Grep for telltale signals:

| Signal | Framework |
|---|---|
| `LyraGame` module, `ULyraExperienceDefinition` references | Lyra |
| `ModularGameplayActors` / `GameFeatures` plugin enabled in `*.uproject` | Modular Gameplay + Game Features |
| `GameplayAbilities` plugin enabled | GAS |
| `EnhancedInput` plugin enabled | Enhanced Input (default in UE 5.1+) |
| `CommonUI` plugin enabled | Common UI |
| `MotionMatching` / `PoseSearch` references | Motion Matching (UE 5.4+) |
| `Plugins/Angelscript/` or `Script/*.as` | Hazelight AngelScript — switch to `unreal-engine-angelscript` skill |

Use `Glob` for `Plugins/**/*.uplugin` to enumerate all plugins.

## 5. Detect source-control model

- `.git/` present → git workflow available
- `.p4config` / `.p4ignore` present → Perforce. Do **not** assume `git log` works; use `p4 changes` / `p4 annotate`.
- Neither → ask the user

## 6. Locate the engine source for grepping

Even with a binary build, the engine headers are on disk under:

- Launcher build (Windows default): `C:\Program Files\Epic Games\UE_5.7\Engine\Source\`
- Source build: per-build install dir; resolve via registry GUID from step 2.

The skill's helper `scripts/find-uclass.ps1` uses this path to grep for engine symbols. If the path is missing, `WebFetch` `dev.epicgames.com/documentation` is the fallback.

## 7. Record the findings

Hand the user (or yourself, before continuing) a one-line summary:

> Project: `<name>` · UE `5.7` · Modules: `<list>` · Frameworks: `<list>` · VCS: `<git|p4>`

This is the baseline for every API claim you make in the session.
