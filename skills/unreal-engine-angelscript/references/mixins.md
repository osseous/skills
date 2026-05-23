# Mixins

Canonical: `https://angelscript.hazelight.se/scripting/mixin-methods/`

Mixins are extension methods. The first parameter is treated as the implicit `this`. They let you add behavior to any type — including C++ types — without subclassing or modifying the original.

## Syntax

```angelscript
mixin void Teleport(AActor Self, FVector Loc)
{
    Self.ActorLocation = Loc;
}

// Usage — exactly as if it were a member method
SomeActor.Teleport(FVector(0, 0, 100));
```

The function name (`Teleport`) becomes a callable member of the type of the first parameter (`AActor`).

## Mixins on structs

For struct types, take the first parameter by reference (`&`):

```angelscript
mixin float MagnitudeSquared(FVector& Vec)
{
    return Vec.X * Vec.X + Vec.Y * Vec.Y + Vec.Z * Vec.Z;
}

FVector V(1, 2, 3);
float Mag = V.MagnitudeSquared();
```

Without the `&`, you'd be mutating a copy.

## Mixins with return values

```angelscript
mixin AActor FindClosestActor(AActor Self, TArray<AActor> Candidates)
{
    AActor Best = null;
    float BestSq = MAX_flt;
    for (AActor C : Candidates)
    {
        if (C == Self) continue;
        float Sq = (C.ActorLocation - Self.ActorLocation).SizeSquared();
        if (Sq < BestSq) { BestSq = Sq; Best = C; }
    }
    return Best;
}
```

## File layout

Put mixin functions in a dedicated `.as` file (e.g. `Script/Utils/ActorMixins.as`). They are global functions — the project sees them everywhere automatically.

## Mixins from C++

The Hazelight plugin can also expose C++ mixin libraries to AS via the `cpp-bindings/mixin-libraries/` mechanism. See `https://angelscript.hazelight.se/cpp-bindings/mixin-libraries/`. Useful for surfacing C++-only utilities (e.g. complex spatial queries) as extension methods on AS-visible types.

## When NOT to mixin

- **Stateful behavior** → use a component or a subclass. Mixins are pure functions.
- **Per-instance configuration** → mixins have no `default` block. Use a real class.
- **Overriding an existing member** → mixins can't shadow built-in methods. If `AActor` already has a `Foo()` method, your `mixin Foo(AActor, ...)` will lose to it.

## Naming convention

PascalCase, verb-first, just like UE methods (`Teleport`, `FindClosestActor`, `IsInAir`). The function name becomes the call-site method name; treat it as part of the public surface of the type it extends.

## Common mistakes

- Forgetting `&` on a struct receiver → mutates a copy; caller sees no change.
- Defining a mixin with a name that collides with a real member → real member wins silently.
- Stateful "static" data in a mixin via global vars → fragile; prefer a singleton subsystem instead.
- Long mixin chains as a substitute for a real class → if your "extension method" needs three other extension methods to do its job, build a class.
