#requires -Version 5.1
<#
.SYNOPSIS
    Print canonical Hazelight AngelScript docs URLs for a topic.

.PARAMETER Topic
    A topic keyword. Recognized:
      api, cpp-differences, properties, functions, networking, replication, rpc,
      delegates, events, mixins, fname, format, gameplay-tags, tags, editor,
      script-tests, tests, subsystems, automatic-bindings, mixin-libraries,
      development-status, footguns, limitations

.EXAMPLE
    powershell -NoProfile -File scripts/open-as-docs.ps1 -Topic replication
.EXAMPLE
    powershell -NoProfile -File scripts/open-as-docs.ps1 -Topic fname
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Topic
)

$base = 'https://angelscript.hazelight.se'

$urls = @{
    'api'                = "$base/api"
    'cpp-differences'    = "$base/scripting/cpp-differences/"
    'differences'        = "$base/scripting/cpp-differences/"
    'properties'         = "$base/scripting/properties-and-accessors/"
    'accessors'          = "$base/scripting/properties-and-accessors/"
    'functions'          = "$base/scripting/functions-and-events/"
    'events'             = "$base/scripting/delegates/"
    'networking'         = "$base/scripting/networking-features/"
    'replication'        = "$base/scripting/networking-features/"
    'rpc'                = "$base/scripting/networking-features/"
    'delegates'          = "$base/scripting/delegates/"
    'mixins'             = "$base/scripting/mixin-methods/"
    'fname'              = "$base/scripting/fname-literals/"
    'format'             = "$base/scripting/format-strings/"
    'gameplay-tags'      = "$base/scripting/gameplaytags/"
    'tags'               = "$base/scripting/gameplaytags/"
    'editor'             = "$base/scripting/editor-script/"
    'script-tests'       = "$base/scripting/script-tests/"
    'tests'              = "$base/scripting/script-tests/"
    'subsystems'         = "$base/scripting/subsystems/"
    'automatic-bindings' = "$base/cpp-bindings/automatic-bindings/"
    'mixin-libraries'    = "$base/cpp-bindings/mixin-libraries/"
    'precompiled'        = "$base/cpp-bindings/precompiled-data/"
    'development-status' = "$base/project/development-status/"
    'footguns'           = "$base/project/development-status/"
    'limitations'        = "$base/project/development-status/"
    'installation'       = "$base/getting-started/installation/"
}

$key = $Topic.ToLowerInvariant()
if ($urls.ContainsKey($key)) {
    Write-Output ("Docs: {0}" -f $urls[$key])
    return
}

Write-Output "Unknown topic '$Topic'. Available topics:"
$urls.Keys | Sort-Object | ForEach-Object { Write-Output "  - $_" }
Write-Output ""
Write-Output "Or browse the docs root: $base"
Write-Output "Or use the API browser:  $base/api"
