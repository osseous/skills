# Animation

UE animation has three runtime layers:

- **Animation Blueprint (ABP)** — visual state-machine + AnimGraph; per-character; runs on workers.
- **AnimInstance** (C++) — the underlying class an ABP inherits from. Holds replicated/native variables, exposes them to the graph.
- **Control Rig** (UE 5.x) — runtime rigging, IK, post-process pose modification.

UE 5.4 added **Motion Matching** (`PoseSearch`) and made it production-ready in Lyra's Sample.

Official: `https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-system-in-unreal-engine`

## UAnimInstance basics

```cpp
UCLASS()
class UMyAnimInstance : public UAnimInstance
{
    GENERATED_BODY()
public:
    virtual void NativeInitializeAnimation() override;
    virtual void NativeUpdateAnimation(float Delta) override;
    virtual void NativeThreadSafeUpdateAnimation(float Delta) override;   // worker-thread safe

    UPROPERTY(BlueprintReadOnly, Category = "Anim")
    float Speed = 0.f;

    UPROPERTY(BlueprintReadOnly, Category = "Anim")
    bool bIsInAir = false;

private:
    UPROPERTY(Transient)
    TWeakObjectPtr<class ACharacter> Owner;
};
```

`NativeUpdateAnimation` runs on the game thread (you can call UObject APIs).
`NativeThreadSafeUpdateAnimation` runs on a worker thread (no UObject mutations; cache values into thread-safe fields).

**Prefer the thread-safe variant** for AnimGraph blend params — game-thread updates serialize the whole anim system on a single thread.

## ABP and AnimGraph

The ABP asset is bound to your AnimInstance C++ class via `AnimInstance Class` in the BP defaults. The AnimGraph reads the instance's `BlueprintReadOnly` properties and drives state machines, blends, IK.

Common patterns:

- **State machine** — locomotion (Idle, Walk, Run, Jump). One state per pose.
- **Blend space** — speed × direction → 2D-blended pose. `UBlendSpace` asset.
- **Layered blend per bone** — upper-body holds weapon idle while lower-body plays locomotion. `Layered Blend Per Bone` node.

## Notifies

`UAnimNotify` and `UAnimNotifyState` subclasses fire from animation playback timestamps:

```cpp
UCLASS()
class UAnimNotify_Footstep : public UAnimNotify
{
    GENERATED_BODY()
    virtual void Notify(USkeletalMeshComponent* Mesh, UAnimSequenceBase* Anim, const FAnimNotifyEventReference& Ref) override;
};
```

Notifies run on the game thread, even when the anim updates on a worker.

## Control Rig

C++ inheritance from `UControlRig` is rare in game code — Control Rig is authored visually in the Control Rig editor and invoked via `Control Rig` post-process AnimGraph node. Use for procedural IK (foot placement, hand IK on weapon grip).

## Motion Matching (UE 5.4+)

Replaces blend spaces + state machines with a database-driven pose search. Requires `PoseSearch` plugin enabled. The Lyra Game Animation Sample is the canonical reference.

Don't bolt onto an existing project lightly — Motion Matching wants the whole locomotion pipeline.

## ABP performance

| Setting | Impact |
|---|---|
| `Use Multi-Threaded Animation Update` | On by default; requires anim updates to be thread-safe |
| `URO (Update Rate Optimization)` | LOD-based update throttling; check `LookAtVariableFrameStepping` if anims stutter at distance |
| `Always Tick Pose and Refresh Bones` | Off by default; on costs CPU but fixes "invisible character" pose bugs |

Profile via `stat anim` and `Animation Insights` (UE 5.0+).

## Common mistakes

- Reading from `Owner` in `NativeThreadSafeUpdateAnimation` → race. Cache values into a `FAnimInstanceProxy` or thread-safe field.
- Modifying anim state from gameplay code → use BP variables on the AnimInstance, set via `Cast<UMyAnimInstance>(Mesh->GetAnimInstance())`.
- Forgetting `bRespectNetworkRoles` on a replicated anim variable → simulated proxies see stale values.
- Adding a notify to an asset shared across characters → fires for all of them; scope notifies to specific assets.
- Calling `Montage_Play` on the server but not replicating → only the server plays. Use `PlayMontage` ability task (GAS) or replicate manually via RPC.
