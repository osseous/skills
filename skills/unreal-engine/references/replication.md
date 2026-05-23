# Replication

UE replication is opt-in per property. Default actor behavior is server-only. Getting this wrong silently — values not updating on clients, RPCs running on the wrong machine — is a top-five UE bug class.

Official: `https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine`

## Enabling replication on an actor

```cpp
AMyActor::AMyActor()
{
    bReplicates = true;
    bAlwaysRelevant = false;       // default: relevance check applies
    SetReplicateMovement(true);    // separate channel for transform
    NetUpdateFrequency = 100.f;    // Hz, target
    MinNetUpdateFrequency = 2.f;   // Hz, floor under load
    bNetLoadOnClient = true;       // for placed actors
}
```

## Replicated properties

Three steps, all required:

```cpp
// 1. Declare the property
UPROPERTY(Replicated)
int32 Health = 100;

// 2. Or with RepNotify
UPROPERTY(ReplicatedUsing = OnRep_Health)
int32 Health = 100;

UFUNCTION()                         // RepNotify MUST be UFUNCTION
void OnRep_Health(int32 OldHealth);

// 3. Register in GetLifetimeReplicatedProps
#include "Net/UnrealNetwork.h"      // for DOREPLIFETIME

void AMyActor::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(AMyActor, Health);
}
```

Skip step 3 and the property silently does not replicate.

## Conditional replication

```cpp
DOREPLIFETIME_CONDITION(AMyActor, AmmoCount, COND_OwnerOnly);
DOREPLIFETIME_CONDITION_NOTIFY(AMyActor, SkinId, COND_SkipOwner, REPNOTIFY_Always);
```

Common `ELifetimeCondition` values:

| Condition | Replicates to |
|---|---|
| `COND_None` | All clients (default) |
| `COND_OwnerOnly` | Only the owning client |
| `COND_SkipOwner` | All except the owner |
| `COND_SimulatedOnly` | Only simulated proxies |
| `COND_AutonomousOnly` | Only autonomous proxy |
| `COND_InitialOnly` | Once, on first replication |
| `COND_Custom` | Toggled at runtime via `DOREPLIFETIME_ACTIVE_OVERRIDE` |

## RepNotify semantics

- `REPNOTIFY_OnChanged` (default): `OnRep_X` fires only when the value differs from the local value before replication.
- `REPNOTIFY_Always`: fires every time the property is replicated, even if unchanged. Use for client-side effects that must re-trigger on respawn.

RepNotify does **not** fire on the server. If the server needs the same callback, call it manually after setting the value.

## RPCs

```cpp
UFUNCTION(Server, Reliable, WithValidation)
void ServerDoThing(FVector Loc);

UFUNCTION(Client, Reliable)
void ClientShowMessage(const FString& Msg);

UFUNCTION(NetMulticast, Unreliable)
void MulticastPlayEffect();
```

Implementations go in `_Implementation`:

```cpp
bool AMyActor::ServerDoThing_Validate(FVector Loc)
{
    return Loc.SizeSquared() < FMath::Square(10000.f);
}

void AMyActor::ServerDoThing_Implementation(FVector Loc)
{
    // runs on server
}
```

| Specifier | Runs on | Called from |
|---|---|---|
| `Server` | Server | Owning client (must have Owner that's a PlayerController) |
| `Client` | Owning client | Server |
| `NetMulticast` | Server + all clients | Server only |

**Unreliable is the default.** Use `Reliable` for state changes; reserve `Unreliable` for cosmetic/high-frequency events.

`WithValidation` is **mandatory** on `Server` RPCs. The `_Validate` function gates execution server-side; returning `false` disconnects the client. Use it to bound parameters.

## FFastArraySerializer

For replicating containers efficiently (delta only on adds/removes/changes), use `FFastArraySerializer` + `FFastArraySerializerItem`. This is the canonical pattern for inventory, ability sets, and command histories.

```cpp
USTRUCT()
struct FMyItem : public FFastArraySerializerItem
{
    GENERATED_BODY()
    UPROPERTY()
    int32 ItemId = 0;
    void PreReplicatedRemove(const struct FMyItemList& Owner);
    void PostReplicatedAdd(const struct FMyItemList& Owner);
    void PostReplicatedChange(const struct FMyItemList& Owner);
};

USTRUCT()
struct FMyItemList : public FFastArraySerializer
{
    GENERATED_BODY()
    UPROPERTY()
    TArray<FMyItem> Items;

    bool NetDeltaSerialize(FNetDeltaSerializeInfo& DeltaParms)
    {
        return FastArrayDeltaSerialize<FMyItem, FMyItemList>(Items, DeltaParms, *this);
    }
};

template<>
struct TStructOpsTypeTraits<FMyItemList> : public TStructOpsTypeTraitsBase2<FMyItemList>
{
    enum { WithNetDeltaSerializer = true };
};
```

See `Source/Engine/Public/Net/Serialization/FastArraySerializer.h` in the engine for the canonical reference.

## Authority checks

```cpp
if (HasAuthority())  { /* server */ }
if (GetLocalRole() == ROLE_AutonomousProxy) { /* owning client */ }
if (GetLocalRole() == ROLE_SimulatedProxy)  { /* other clients */ }
```

Use these guards inside RPC implementations and event handlers — they make intent explicit even when the framework already gates dispatch.

## Common mistakes

- Declaring `UPROPERTY(Replicated)` but forgetting `DOREPLIFETIME` → silent no-op.
- Marking a `Server` RPC without `WithValidation` → compile error in shipping, warning in development.
- Calling `Server*` RPC from a server-side context → no-op, runs locally.
- Calling `NetMulticast` from a client → no-op.
- Putting heavy work in a `RepNotify` → blocks the network thread on dispatch; defer with a timer.
- Assuming RepNotify fires on the server → it doesn't. Mirror manually if needed.
- Replicating large containers as `TArray<T>` instead of `FFastArraySerializer` → bandwidth waste; UE re-sends the whole array on any change.
