# Replication in AngelScript

The AngelScript binding generator handles `GetLifetimeReplicatedProps` for you. The specifier on the `UPROPERTY` is sufficient.

Canonical: `https://angelscript.hazelight.se/scripting/networking-features/`

## Enabling replication

```angelscript
class AMyActor : AActor
{
    default bReplicates = true;
    default bAlwaysRelevant = false;
    default NetUpdateFrequency = 100.0;
}
```

## Replicated properties

```angelscript
UPROPERTY(Replicated)
int32 Health = 100;

UPROPERTY(Replicated, ReplicatedUsing = OnRep_Health)
int32 Health = 100;

UFUNCTION()
void OnRep_Health(int32 OldHealth)
{
    Print(f"Health changed from {OldHealth} to {Health}");
}
```

**Do NOT write `GetLifetimeReplicatedProps`** — there is no such hook in AS. The plugin emits it from the specifier.

## Replication conditions

```angelscript
UPROPERTY(Replicated, ReplicationCondition = OwnerOnly)
int32 AmmoCount;

UPROPERTY(Replicated, ReplicationCondition = SkipOwner, ReplicatedUsing = OnRep_Skin)
int32 SkinId;
```

| `ReplicationCondition` | Replicates to |
|---|---|
| (omitted) | All clients |
| `OwnerOnly` | Owning client only |
| `SkipOwner` | All except owner |
| `SimulatedOnly` | Simulated proxies |
| `AutonomousOnly` | Autonomous proxy |
| `InitialOnly` | First replication only |
| `Custom` | Toggled at runtime — rarely used from AS |

## RPCs

```angelscript
UFUNCTION(Server)
void ServerDoThing(FVector Loc)       // reliable by default
{
    // runs on server
}

UFUNCTION(Server, Unreliable)
void ServerJiggle(FVector Loc) { ... }

UFUNCTION(Client)
void ClientShowMessage(const FString& Msg) { ... }

UFUNCTION(NetMulticast, Unreliable)
void MulticastPlayEffect() { ... }
```

| Specifier | Runs on | Called from |
|---|---|---|
| `Server` | Server | Owning client |
| `Client` | Owning client | Server |
| `NetMulticast` | Server + all clients | Server |

**Reliable is the default in AS** (opposite of C++). Add `Unreliable` for cosmetic/high-frequency events.

**Validation is implicit on `Server` RPCs.** The plugin generates a validate stub; if you need real bounds-checking, do it as the first lines of the function body and `return` early.

## Authority checks

```angelscript
if (HasAuthority()) { ... }       // server side
if (GetLocalRole() == ENetRole::ROLE_AutonomousProxy) { ... }
if (GetLocalRole() == ENetRole::ROLE_SimulatedProxy)  { ... }
```

Available on `AActor` and any actor component.

## RepNotify semantics

- Default: fires only when the replicated value differs from the local value pre-replication.
- `REPNOTIFY_Always` (UE C++ behavior) is **not** directly exposed in AS — if you need always-fire, mirror manually in a separate function called from both the server-side setter and the RepNotify.
- RepNotify does NOT fire on the server. If the server needs the same callback, call it manually after setting the value.

## Command-pattern replication

If the project uses an append-only command pattern (`FFastArraySerializer` + a command-history struct) — as Lyra and AbsurdChess do — that infrastructure lives in C++. From AS, you emit commands via the C++ `UFUNCTION` that wraps the append; you do not write `FFastArraySerializer` types in AS directly (USTRUCTs in AS don't support custom net delta serializers).

Grep the project for `EmitCommand` / `AddCommand` / `BoardStateComponent` style entry points and use those.

## Common mistakes

- Writing a `GetLifetimeReplicatedProps()` function in AS → does nothing.
- Forgetting `default bReplicates = true;` → properties don't replicate even with the specifier.
- Calling a `Server*` RPC from a server context → no-op, runs locally.
- Adding `Reliable` explicitly — it's the default; harmless but noise.
- Using `WithValidation` in AS — not a thing; validation is implicit.
- Expecting RepNotify to fire on the server — it doesn't.
- Trying to declare `FFastArraySerializer` in AS — not supported. Wrap in C++.
