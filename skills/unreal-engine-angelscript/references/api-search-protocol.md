# AS API Search Protocol

For any AngelScript symbol, function, or specifier you are about to write — follow this protocol before committing to a signature.

## The four sources, in order

### 1. Project `Script/` grep

```
Grep pattern="\b<Symbol>\b" path="Script" output_mode="content" -n
```

If a teammate has used the symbol, the call form is in their code. Read that.

### 2. Project C++ `Source/` grep (for bindings)

AS is reflection-driven: most AS API surface mirrors C++ `BlueprintCallable` / `BlueprintReadWrite` declarations.

```
Grep pattern="\b<Symbol>\b" path="Source" type="cpp" output_mode="content" -n -B 2 -A 2
```

Pay attention to:

- `meta = (NotInAngelscript)` / `NoAutoAngelscriptBind` → hidden from AS even if BP-visible.
- The UFUNCTION specifier — only `BlueprintCallable`/`BlueprintPure`/`ScriptCallable` cross to AS.
- The class — if the owning UCLASS is not `BlueprintType`, sub-typing from AS may be limited.

### 3. Hazelight docs WebFetch

Canonical URLs:

| Topic | URL |
|---|---|
| API browser (all bound types) | `https://angelscript.hazelight.se/api` |
| Language vs C++ | `https://angelscript.hazelight.se/scripting/cpp-differences/` |
| Functions and events | `https://angelscript.hazelight.se/scripting/functions-and-events/` |
| Properties and accessors | `https://angelscript.hazelight.se/scripting/properties-and-accessors/` |
| Networking (replication, RPC) | `https://angelscript.hazelight.se/scripting/networking-features/` |
| Delegates and events | `https://angelscript.hazelight.se/scripting/delegates/` |
| Mixins | `https://angelscript.hazelight.se/scripting/mixin-methods/` |
| FName literals | `https://angelscript.hazelight.se/scripting/fname-literals/` |
| Format strings | `https://angelscript.hazelight.se/scripting/format-strings/` |
| Gameplay tags | `https://angelscript.hazelight.se/scripting/gameplaytags/` |
| Editor-only | `https://angelscript.hazelight.se/scripting/editor-script/` |
| Script tests | `https://angelscript.hazelight.se/scripting/script-tests/` |
| Subsystems | `https://angelscript.hazelight.se/scripting/subsystems/` |
| Automatic bindings | `https://angelscript.hazelight.se/cpp-bindings/automatic-bindings/` |
| Mixin libraries from C++ | `https://angelscript.hazelight.se/cpp-bindings/mixin-libraries/` |
| Limitations / known issues | `https://angelscript.hazelight.se/project/development-status/` |

### 4. Engine-fork source grep

If the binding might come from the plugin itself (`UnrealEngine-Angelscript`), grep the fork:

- Repo: `https://github.com/Hazelight/UnrealEngine-Angelscript` (branch `angelscript-master`)
- Plugin source: under `Engine/Plugins/Angelscript/Source/` in the fork.

WebFetch a path like:
`https://github.com/Hazelight/UnrealEngine-Angelscript/blob/angelscript-master/Engine/Plugins/Angelscript/Source/AngelscriptCode/Public/AngelscriptManager.h`

### 5. Last resort: ask the user

If four sources can't confirm, surface the uncertainty:

> I couldn't verify `<Symbol>` in the project `Script/`, project `Source/`, the Hazelight docs, or the plugin source. Can you confirm the binding you're thinking of, or paste a working call site?

## Specifier verification

AS specifiers are NOT the same set as C++ specifiers. Examples:

- AS: `UPROPERTY(NotEditable)`. C++ has no such specifier.
- AS: `UPROPERTY(Replicated, ReplicationCondition = OwnerOnly)`. C++ uses `DOREPLIFETIME_CONDITION` separately.
- AS: `UFUNCTION(BlueprintEvent)`. C++ uses `BlueprintImplementableEvent` or `BlueprintNativeEvent`.
- AS: `UFUNCTION(BlueprintOverride)`. C++ uses `_Implementation` suffix on the function name.

When in doubt, grep `Script/` for the specifier and read the docs page for the relevant feature.

## Common hallucination traps

- `UFUNCTION(BlueprintImplementableEvent)` in AS → wrong; AS uses `UFUNCTION(BlueprintEvent)`.
- `GENERATED_BODY()` in AS → doesn't exist.
- `Super::BeginPlay()` calling C++ parent → doesn't work.
- `GetLifetimeReplicatedProps()` in AS → no such hook.
- `nullptr` in AS → use `null`.
- `->` operator in AS → use `.`.
- C++-style format specifiers in `f""` strings (`%s`, `%d`) → AS uses Python `{}`.
- `n"DynamicValue"` for a runtime FName → `n""` is a literal only.
