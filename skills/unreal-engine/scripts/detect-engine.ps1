#requires -Version 5.1
<#
.SYNOPSIS
    Detects the engine version, modules, and frameworks in use by the nearest UE project.

.DESCRIPTION
    Walks up from -StartDir (default: PWD) looking for a *.uproject. Parses it for
    engine association, plugins, and modules. Lists each Source/*.Build.cs and its
    declared dependencies. Detects common frameworks (Lyra, GAS, Enhanced Input,
    Common UI, AngelScript) by inspecting plugins and module names.

    Output is one human-readable summary, plus -Format json for programmatic use.

.PARAMETER StartDir
    Directory to start searching from. Defaults to PWD.

.PARAMETER Format
    'text' (default) or 'json'.

.EXAMPLE
    powershell -NoProfile -File scripts/detect-engine.ps1
.EXAMPLE
    powershell -NoProfile -File scripts/detect-engine.ps1 -Format json
#>
param(
    [string]$StartDir = (Get-Location).Path,
    [ValidateSet('text','json')]
    [string]$Format   = 'text'
)

$ErrorActionPreference = 'Stop'

function Find-UProject {
    param([string]$From)
    $dir = (Resolve-Path $From).Path
    while ($true) {
        $u = Get-ChildItem -LiteralPath $dir -Filter *.uproject -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($u) { return $u }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { return $null }
        $dir = $parent
    }
}

function Resolve-EngineAssociation {
    param([string]$Assoc)
    if ([string]::IsNullOrWhiteSpace($Assoc)) { return @{ Kind='unknown'; Version='?' } }
    if ($Assoc -match '^\d+\.\d+$') {
        return @{ Kind='launcher'; Version=$Assoc; Path="C:\Program Files\Epic Games\UE_$Assoc" }
    }
    if ($Assoc -match '^\{[0-9A-Fa-f-]+\}$') {
        try {
            $reg = Get-ItemProperty -Path 'HKCU:\SOFTWARE\Epic Games\Unreal Engine\Builds' -ErrorAction SilentlyContinue
            if ($reg -and $reg.$Assoc) {
                return @{ Kind='source'; Version='source'; Path=$reg.$Assoc }
            }
        } catch {}
        return @{ Kind='source'; Version='source'; Path='?' }
    }
    return @{ Kind='other'; Version=$Assoc }
}

function Get-Modules {
    param([string]$ProjRoot)
    $srcDir = Join-Path $ProjRoot 'Source'
    if (-not (Test-Path $srcDir)) { return @() }
    Get-ChildItem -LiteralPath $srcDir -Recurse -Filter *.Build.cs -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Directory.Name
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $pub  = [regex]::Matches($text, 'PublicDependencyModuleNames\.AddRange\(\s*new\s+string\[\]\s*\{([^}]*)\}') |
                ForEach-Object { $_.Groups[1].Value } |
                ForEach-Object { [regex]::Matches($_, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } } |
                Select-Object -Unique
        $priv = [regex]::Matches($text, 'PrivateDependencyModuleNames\.AddRange\(\s*new\s+string\[\]\s*\{([^}]*)\}') |
                ForEach-Object { $_.Groups[1].Value } |
                ForEach-Object { [regex]::Matches($_, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } } |
                Select-Object -Unique
        [PSCustomObject]@{
            Name             = $name
            BuildCs          = $_.FullName
            PublicDeps       = @($pub)
            PrivateDeps      = @($priv)
        }
    }
}

function Detect-Frameworks {
    param([string]$ProjRoot, $UProjectData, [array]$Modules)
    $hits = New-Object System.Collections.Generic.List[string]
    $allDeps = $Modules | ForEach-Object { $_.PublicDeps + $_.PrivateDeps } | Select-Object -Unique
    $pluginNames = @()
    if ($UProjectData.Plugins) {
        $pluginNames = @($UProjectData.Plugins | Where-Object { $_.Enabled -ne $false } | ForEach-Object { $_.Name })
    }

    if ($pluginNames -contains 'GameplayAbilities' -or $allDeps -contains 'GameplayAbilities') { $hits.Add('GAS') }
    if ($pluginNames -contains 'EnhancedInput'    -or $allDeps -contains 'EnhancedInput')    { $hits.Add('Enhanced Input') }
    if ($pluginNames -contains 'CommonUI'         -or $allDeps -contains 'CommonUI')         { $hits.Add('Common UI') }
    if ($pluginNames -contains 'ModelViewViewModel' -or $allDeps -contains 'ModelViewViewModel') { $hits.Add('MVVM') }
    if ($pluginNames -contains 'GameFeatures'     -or $allDeps -contains 'GameFeatures')     { $hits.Add('Game Features') }
    if ($pluginNames -contains 'ModularGameplay'  -or $allDeps -contains 'ModularGameplay')  { $hits.Add('Modular Gameplay') }
    if ($Modules.Name -contains 'LyraGame')                                                  { $hits.Add('Lyra') }
    if ($pluginNames -match 'Angelscript' -or (Test-Path (Join-Path $ProjRoot 'Script'))) {
        $asFiles = Get-ChildItem -LiteralPath (Join-Path $ProjRoot 'Script') -Recurse -Filter *.as -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($asFiles) { $hits.Add('Hazelight AngelScript (use unreal-engine-angelscript skill)') }
    }
    if ($pluginNames -contains 'PoseSearch') { $hits.Add('Motion Matching') }
    return $hits
}

function Detect-Vcs {
    param([string]$ProjRoot)
    if (Test-Path (Join-Path $ProjRoot '.git'))      { return 'git' }
    if (Test-Path (Join-Path $ProjRoot '.p4config')) { return 'perforce' }
    if (Test-Path (Join-Path $ProjRoot '.p4ignore')) { return 'perforce' }
    return 'unknown'
}

$uproj = Find-UProject -From $StartDir
if (-not $uproj) {
    Write-Error "No *.uproject found searching upward from '$StartDir'."
    exit 1
}
$projRoot = $uproj.Directory.FullName
$projData = Get-Content -LiteralPath $uproj.FullName -Raw | ConvertFrom-Json
$engine   = Resolve-EngineAssociation -Assoc $projData.EngineAssociation
$modules  = Get-Modules -ProjRoot $projRoot
$fw       = Detect-Frameworks -ProjRoot $projRoot -UProjectData $projData -Modules $modules
$vcs      = Detect-Vcs -ProjRoot $projRoot

$result = [PSCustomObject]@{
    ProjectName       = $uproj.BaseName
    ProjectRoot       = $projRoot
    UProject          = $uproj.FullName
    EngineAssociation = $projData.EngineAssociation
    EngineKind        = $engine.Kind
    EngineVersion     = $engine.Version
    EnginePath        = $engine.Path
    Modules           = $modules
    Frameworks        = $fw
    Vcs               = $vcs
}

if ($Format -eq 'json') {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "Project:     $($result.ProjectName)"
    Write-Output "Root:        $($result.ProjectRoot)"
    Write-Output "Engine:      $($result.EngineKind) $($result.EngineVersion)  ($($result.EnginePath))"
    Write-Output "VCS:         $($result.Vcs)"
    Write-Output "Modules:     $($modules.Name -join ', ')"
    Write-Output "Frameworks:  $($fw -join ', ')"
    Write-Output ''
    foreach ($m in $modules) {
        Write-Output "  -- $($m.Name) --"
        Write-Output "     Public:  $($m.PublicDeps  -join ', ')"
        Write-Output "     Private: $($m.PrivateDeps -join ', ')"
    }
}
