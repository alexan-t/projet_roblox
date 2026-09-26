param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
$configSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Config/KingdomConfig.lua') -Raw
$serviceSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Services/KingdomService.lua') -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Tests/KingdomService.spec.lua') -Raw

# Le vrai module (et la vraie config) est execute avec des doubles explicites des API moteur.
# Aucun remplacement de logique du service, aucun acces a Studio ou DataStore.
$runnerSource = "local config = (function()`n" + $configSource + "`nend)()`n" + @'
local function createService(env)
    local game, script, require = env.game, env.script, env.require
    local Instance, CFrame, Vector3 = env.Instance, env.CFrame, env.Vector3
'@ + "`n" + $serviceSource + "`nend`nlocal runTests = (function()`n" + $testSource + "`nend)()`nrunTests(createService, config)`n"
$runnerPath = Join-Path $testBuild 'kingdom-service-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "KingdomService tests failed (exit $LASTEXITCODE)" }
