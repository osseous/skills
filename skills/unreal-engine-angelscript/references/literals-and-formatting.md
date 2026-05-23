# Literals and Formatting

## FName literals

```angelscript
FName Tag = n"Board.Object.Pawn";
```

Canonical: `https://angelscript.hazelight.se/scripting/fname-literals/`

- `n"..."` is **compile-time interned**. Zero runtime allocation, typos still allowed (but the same string compiled twice produces the same FName).
- `FName("...")` allocates at runtime. Use only when the string is computed.
- Required form for delegate/event binding (`BindUFunction(this, n"Foo")`).
- Comparison: `if (TagName == n"Foo")` works because FName comparison is integer-fast.

## Formatted strings

```angelscript
FString S = f"Hello {Name}, you have {Score} points (at {Loc.Z :.3})";
```

Canonical: `https://angelscript.hazelight.se/scripting/format-strings/`

Python-style:

- `{Expr}` — value
- `{Expr :spec}` — format spec
- `{Expr =}` — self-labelling: prints `Expr=value`

Format specs:

| Spec | Effect |
|---|---|
| `:.3` | 3 decimal places |
| `:6.2` | width 6, 2 decimals |
| `:x` / `:X` | hex (lower/upper) |
| `:b` | binary |
| `:o` | octal |
| `:e` | scientific |

Use `f""` instead of `FString::Printf("%s %d", *Name, Score)` — clearer, type-safe, no `*FString` deref boilerplate.

## FText vs FString

| Type | Use for |
|---|---|
| `FString` | Internal / non-localized text, log messages, file paths |
| `FText` | UI text, dialogue, anything that ships to players |

Convert with `FText::FromString(MyString)` and `MyText.ToString()`.

## FString idioms

```angelscript
FString S = "raw literal";
FString Path = "Game/" + AssetName + ".uasset";  // + works
FString Upper = S.ToUpper();
bool Has = S.Contains("foo");
TArray<FString> Parts;
S.ParseIntoArray(Parts, ",");
FString Trimmed = S.TrimStartAndEnd();
```

Most C++ FString methods are bound. Grep `Script/` for examples or check the docs `api` browser.

## Print

```angelscript
Print("plain log line");
Print(f"with formatting: {Value}");
PrintWarning("yellow text");
PrintError("red text");
```

These map to UE's `UE_LOG` under the `LogAngelscript` category. The `read-ue-logs` skill picks them up.

For on-screen debug:

```angelscript
PrintToScreen("temporary message", 2.0, FLinearColor::Green);
```

## Common mistakes

- Using `n""` for a runtime-computed name → won't compile; use `FName(...)`.
- Using `f""` with C++ format specifiers (`%s`, `%d`) → wrong; AS uses Python-style `{}`.
- Concatenating heavy text with `+` repeatedly → builds many intermediates; use `f""` for multi-part strings.
- Comparing FName with `Equals` instead of `==` → both work, `==` is idiomatic and faster.
- Putting localized text in `FString` → can't localize later; use `FText` for player-facing strings from day one.
