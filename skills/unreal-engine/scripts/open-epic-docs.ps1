#requires -Version 5.1
<#
.SYNOPSIS
    Print canonical dev.epicgames.com documentation URLs for a UE symbol or topic.
    Feed the URL to WebFetch to verify a signature without guessing.

.PARAMETER Symbol
    The symbol or topic. Prefixes recognized:
      U*, A*, F*, E*, I*, S*, T*    — treated as a type name
      UPROPERTY, UFUNCTION, UCLASS, USTRUCT, UMETA — specifier docs
      build, replication, gas, lyra, enhanced-input, umg, mvvm, animation — topic pages

.EXAMPLE
    powershell -NoProfile -File scripts/open-epic-docs.ps1 -Symbol UAbilitySystemComponent
.EXAMPLE
    powershell -NoProfile -File scripts/open-epic-docs.ps1 -Symbol UPROPERTY
.EXAMPLE
    powershell -NoProfile -File scripts/open-epic-docs.ps1 -Symbol replication
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Symbol
)

$base = 'https://dev.epicgames.com/documentation/en-us/unreal-engine'

$specifiers = @{
    'UPROPERTY'  = "$base/unreal-engine-uproperty-specifiers"
    'UFUNCTION'  = "$base/ufunctions-in-unreal-engine"
    'UCLASS'     = "$base/uclass-specifiers"
    'USTRUCT'    = "$base/ustructs-in-unreal-engine"
    'UMETA'      = "$base/umeta-specifiers"
    'UENUM'      = "$base/uenum-specifiers"
    'UINTERFACE' = "$base/uinterface-specifiers"
}

$topics = @{
    'build'            = "$base/build-configuration-for-unreal-engine"
    'replication'      = "$base/networking-overview-for-unreal-engine"
    'rpc'              = "$base/remote-procedure-calls-in-unreal-engine"
    'gas'              = "$base/gameplay-ability-system-for-unreal-engine"
    'lyra'             = "$base/lyra-sample-game-in-unreal-engine"
    'enhanced-input'   = "$base/enhanced-input-in-unreal-engine"
    'umg'              = "$base/umg-ui-designer-for-unreal-engine"
    'common-ui'        = "$base/common-ui-plugin-in-unreal-engine"
    'mvvm'             = "$base/umg-viewmodel"
    'animation'        = "$base/animation-system-in-unreal-engine"
    'motion-matching'  = "$base/motion-matching-in-unreal-engine"
    'control-rig'      = "$base/control-rig-in-unreal-engine"
    'game-features'    = "$base/game-features-and-modular-gameplay-in-unreal-engine"
    'modular-gameplay' = "$base/modular-gameplay-actors-in-unreal-engine"
    'iwyu'             = "$base/include-what-you-use-iwyu-for-unreal-engine-programming"
    'gameplay-tags'    = "$base/using-gameplay-tags-in-unreal-engine"
}

$key = $Symbol.Trim()
$keyLower = $key.ToLowerInvariant()

if ($specifiers.ContainsKey($key)) {
    Write-Output "Specifier docs: $($specifiers[$key])"
    return
}

if ($topics.ContainsKey($keyLower)) {
    Write-Output "Topic docs: $($topics[$keyLower])"
    return
}

# Heuristic: looks like a UE type
if ($key -match '^[UAFEISTL][A-Z][A-Za-z0-9_]+$') {
    Write-Output "Likely API URL patterns to try with WebFetch (UE auto-generates per-symbol pages):"
    Write-Output "  $base/API/Runtime/Engine/$key"
    Write-Output "  $base/API/Runtime/CoreUObject/UObject/$key"
    Write-Output "  $base/API/Runtime/GameplayAbilities/$key"
    Write-Output ""
    Write-Output "If those 404, fall back to WebSearch:"
    Write-Output "  ""$key"" site:dev.epicgames.com"
    return
}

Write-Output "No canonical URL pattern matched. Try:"
Write-Output "  WebSearch: ""$key"" site:dev.epicgames.com"
Write-Output "  Or browse the topic index at: $base"
