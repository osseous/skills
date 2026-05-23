# UMG, Slate, Common UI, MVVM

UE has three UI stacks layered on each other:

- **Slate** — the underlying C++ widget framework. `SButton`, `SCompoundWidget`, retained- and immediate-mode rendering.
- **UMG** — designer-friendly wrapper. `UUserWidget` (BP-extendable), `UButton`, etc. Each UMG widget wraps a Slate widget.
- **Common UI** — opinionated UMG layer for input-routed, controller-friendly UIs. `UCommonButtonBase`, `UCommonActivatableWidget`, navigation stack management.
- **MVVM (UE 5.1+)** — view-model binding plugin. `UMVVMViewModelBase`, BP-friendly bindings.

For new code, prefer the highest layer that fits: **MVVM > Common UI > UMG > Slate**. Hand-rolling Slate from C++ in shippable game UI is rare.

## Required modules

```csharp
PublicDependencyModuleNames.AddRange(new[] {
    "UMG",
    "Slate",
    "SlateCore",
});

// Optional:
PrivateDependencyModuleNames.AddRange(new[] {
    "CommonUI",
    "CommonInput",
    "ModelViewViewModel",   // MVVM plugin
});
```

## UUserWidget lifecycle

```
NativeOnInitialized()         — once, on construction, before any binding
NativePreConstruct()          — designer-time + runtime; safe for visual tweaks
NativeConstruct()             — added to viewport / parent; safe for input + tick setup
NativeTick(MyGeo, Delta)      — every frame while displayed
NativeDestruct()              — removed from viewport
NativeOnFocusReceived(...)    — input focus events
```

`NativeOnInitialized` is the right place to subscribe to gameplay events. `NativeConstruct` is too late if you need to set up before the first paint.

## BindWidget

UMG-side `Hierarchy`-defined sub-widgets can be auto-bound to C++ members:

```cpp
UCLASS()
class UMyWidget : public UUserWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(meta = (BindWidget))
    TObjectPtr<UButton> ConfirmButton;

    UPROPERTY(meta = (BindWidget, OptionalWidget = true))
    TObjectPtr<UTextBlock> OptionalLabel;
};
```

The widget BP must contain a child named `ConfirmButton` of type `UButton` (or compatible). Build fails at editor open if a required binding is missing.

## Common UI essentials

- `UCommonActivatableWidget` — base for screens; `BP_OnActivated`/`BP_OnDeactivated` callbacks; integrates with `UCommonUIActionRouterBase` for input-stack routing.
- `UCommonActivatableWidgetStack` — push/pop screens; only the top of the stack receives input.
- Input actions are mapped via `UCommonInputActionDataBase` data assets, not Enhanced Input directly.
- Designer-side: `Designer Preferences > Common UI Settings` exposes default ui input.

Common UI is mandatory for controller-friendly UIs (focus, back-button, gamepad nav). Without it, you must hand-roll `OnNavigation` overrides.

## MVVM essentials

```cpp
UCLASS(BlueprintType)
class UMyViewModel : public UMVVMViewModelBase
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadWrite, FieldNotify, Setter, Getter)
    int32 Score = 0;

    void IncrementScore() { UE_MVVM_SET_PROPERTY_VALUE(Score, Score + 1); }
};
```

`FieldNotify` makes the property bindable. `UE_MVVM_SET_PROPERTY_VALUE` triggers the change broadcast.

In the widget BP, use the MVVM panel to bind the view model field to a UMG widget property. No C++ wiring per binding.

## Slate (when you must)

```cpp
class SMyWidget : public SCompoundWidget
{
public:
    SLATE_BEGIN_ARGS(SMyWidget) {}
        SLATE_ARGUMENT(FText, Label)
    SLATE_END_ARGS()

    void Construct(const FArguments& InArgs)
    {
        ChildSlot
        [
            SNew(STextBlock).Text(InArgs._Label)
        ];
    }
};
```

Slate-only code lives outside UMG and cannot be reflected. Use for tools, editor extensions, and runtime overlays that need precision control.

## Common mistakes

- `BindWidget` name mismatch → silent or build error depending on Optional flag.
- Calling `AddToViewport` from a non-game thread → crash.
- Animating UMG via Tick instead of `UWidgetAnimation` → janky; UMG anims interpolate on the render thread.
- `NativeConstruct` called multiple times when widget is re-added → make idempotent.
- Common UI back-button not working → no `UCommonUIActionRouterBase` configured, or screen not in an activatable stack.
- MVVM binding fires before view model is set → check `GetViewModel<>()` before reads.
- Holding a `TSharedPtr<SWidget>` in a `UPROPERTY` → wrong; Slate uses `TSharedRef/TSharedPtr` and UObject doesn't own them. Use UMG instead.
