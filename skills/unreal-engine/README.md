# unreal-engine

Agent skill for working in Unreal Engine 5.x C++/Blueprint projects without hallucinating API surface.

The skill enforces a discovery-then-search workflow:

1. **Discover** — at session start, parse the `*.uproject`, list modules, detect frameworks (Lyra, GAS, Enhanced Input, Common UI, AngelScript), pin the engine version.
2. **Search before claim** — before stating any UE type/function/specifier, grep the project `Source/`, grep the resolved engine headers, then WebFetch `dev.epicgames.com/documentation`. If three sources can't confirm a symbol, the agent must say "I cannot verify this" rather than invent it.
3. **Verify by running** — the project's tests + the editor, with logs read by hand (use the sibling `read-ue-logs` skill). Compilation is necessary, not sufficient.

If the project uses Hazelight AngelScript, use the sibling **`unreal-engine-angelscript`** skill instead — AngelScript syntax differs from C++ in load-bearing ways.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Agent-facing entry point; links to references and scripts. |
| `references/discovery-protocol.md` | Session-start checklist. |
| `references/api-search-protocol.md` | Exact grep + WebFetch protocol for verifying any symbol. |
| `references/cpp-style.md` | UCLASS/USTRUCT/UFUNCTION specifier tables. |
| `references/pointers-and-gc.md` | `TObjectPtr`/`TWeakObjectPtr`/`TSoftObjectPtr` decision tree. |
| `references/iwyu-and-includes.md` | IWYU rules, header layout, `*.generated.h` ordering. |
| `references/build-cs.md` | Build.cs / Target.cs cheat sheet, common module names. |
| `references/replication.md` | RepNotify, RPC, FastArray, conditional replication. |
| `references/gas.md` | Gameplay Ability System essentials. |
| `references/lyra.md` | Lyra Experiences, GameFeatures, Modular Gameplay. |
| `references/enhanced-input.md` | Input actions / mapping contexts. |
| `references/umg-slate.md` | UMG / Common UI / MVVM. |
| `references/animation.md` | AnimInstance, ABP, Motion Matching. |
| `scripts/detect-engine.ps1` | Parses `.uproject` → engine version + modules + frameworks. |
| `scripts/find-uclass.ps1` | Greps project Source/ + engine Source/ for a symbol. |
| `scripts/open-epic-docs.ps1` | Prints canonical `dev.epicgames.com` URL for a symbol. |

## Install

Via skills.sh:

```bash
npx skills add osseous/skills/unreal-engine
```

Or symlink the whole monorepo locally — see the parent repo `README.md`.

## Design notes

The five existing UE skills on skills.sh (sickn33, dstn2000, quodsoler) each cover slices of the surface but share a common weakness: they teach API patterns without forcing the agent to verify the API exists in the project's engine version. This skill front-loads the verification step.

The other key gap they share is a missing "stop and ask" instruction — every UE skill should explicitly tell the agent that, when a symbol cannot be located via grep or docs, the right move is to surface uncertainty to the user, not to write a plausible-looking guess. That instruction is at the top of `SKILL.md`.
