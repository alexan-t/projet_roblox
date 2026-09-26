param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
$serviceSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Services/PlotService.lua') -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Tests/PlotService.spec.lua') -Raw

# Le vrai module est execute avec des doubles explicites des API moteur.
# Aucun remplacement de logique du service, aucun acces a Studio ou DataStore.
$runnerSource = @'
local function createService(env)
    local game, script, require = env.game, env.script, env.require
    local Instance, CFrame, Vector3, task = env.Instance, env.CFrame, env.Vector3, env.task
    local os = env.os
'@ + "`n" + $serviceSource + "`nend`nlocal runTests = (function()`n" + $testSource + "`nend)()`nrunTests(createService)`n"
$runnerPath = Join-Path $testBuild 'plot-service-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "PlotService tests failed (exit $LASTEXITCODE)" }
