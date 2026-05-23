# unreal-engine-angelscript

Agent skill for authoring Hazelight AngelScript (`.as`) gameplay code on Unreal Engine 5.x.

This is the sibling of [`unreal-engine`](../unreal-engine/). Use this skill when the project contains `Script/*.as` files and has the `UnrealEngine-Angelscript` plugin enabled. Use the C++ skill otherwise.

The skill exists because **AngelScript looks like UE C++ but differs in load-bearing ways** — and every LLM that writes UE C++ from memory falls into the same traps:

- No `#include`, no `GENERATED_BODY`, no `->`, no `nullptr`.
- `default` keyword for sub-object configuration.
- `float` is 64-bit (use `float32` for explicit 32-bit).
- `UPROPERTY()` defaults to `EditAnywhere | BlueprintReadWrite`. `UFUNCTION()` defaults to `BlueprintCallable`.
- RPCs are reliable by default (opposite of C++).
- No `GetLifetimeReplicatedProps` to write — the `Replicated` specifier handles it.
- `UInterface` is unsupported in AS.
- `Super::Foo()` only reaches AS parents, not C++ parents.

The skill enforces a verify-before-claim workflow: grep the project `Script/`, grep `Source/` for the C++ binding origin, WebFetch `angelscript.hazelight.se/api`, and only then write the code. If three sources can't confirm a symbol, the agent must say "I cannot verify this" rather than invent it.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Agent-facing entry point; the 8 AS-vs-C++ traps, links to references. |
| `references/cpp-differences.md` | Full AS-vs-C++ language diff. Read once per session. |
| `references/replication.md` | `Replicated` specifier, RPCs, `ReplicationCondition`, RepNotify. |
| `references/delegates-and-events.md` | `delegate` (single-bind) vs `event` (multicast). `BindUFunction`/`AddUFunction` rules. |
| `references/mixins.md` | Extension methods on existing types via `mixin`. |
| `references/literals-and-formatting.md` | `n""` FName literals, `f""` format strings. |
| `references/gameplay-tags.md` | `GameplayTag(n"...")` literal + container ops. |
| `references/editor-only.md` | Editor-only classes + `Meta = (Editor)`. |
| `references/interop-with-cpp.md` | What's bound, what's hidden, subclassing C++ from AS. |
| `references/hot-reload.md` | What survives a reload, what doesn't, how to verify. |
| `references/footguns.md` | Documented limitations + silent-failure modes. |
| `references/api-search-protocol.md` | Exact grep + WebFetch protocol for verifying any AS symbol. |
| `scripts/detect-angelscript.ps1` | Verifies plugin is enabled, counts `.as` files, lists top-level types. |
| `scripts/grep-binding.ps1` | Searches `Script/` + `Source/` for a symbol; flags `NotInAngelscript` hides. |
| `scripts/open-as-docs.ps1` | Prints canonical `angelscript.hazelight.se` URL for a topic. |

## Related skills

- [`unreal-engine`](../unreal-engine/) — UE 5.x C++/Blueprint sibling. Use for module setup, Build.cs, plugin-side C++.
- [`ue-angelscript-tests`](../ue-angelscript-tests/) — Test framework specifics (`Test_*` / `IntegrationTest_*`).
- [`read-ue-logs`](../read-ue-logs/) — Required for verifying script reload + test runs.

## Install

Via skills.sh:

```bash
npx skills add osseous/skills/unreal-engine-angelscript
```

Or symlink the whole monorepo locally — see the parent repo `README.md`.

## Design notes

There is no existing AngelScript skill on skills.sh. This is the first. The design priority is **preventing API hallucination**: the AngelScript surface is small enough that an LLM trying to be helpful will invent plausible-looking calls that don't exist. The SKILL.md leads with the 10 most common traps; the `api-search-protocol.md` reference is mandatory reading before any non-trivial change.

The reference docs are intentionally short and grep-friendly — each file is one focused topic, and the SKILL.md table-of-contents tells the agent which to open and when.
