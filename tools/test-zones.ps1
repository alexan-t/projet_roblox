param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
$configSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Config/StageConfig.lua') -Raw
$serviceSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Services/ZoneService.lua') -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Tests/ZoneService.spec.lua') -Raw

# Le vrai module (et la vraie config) est execute avec des doubles explicites
# de DataService, PlotService, QuestService et des API moteur utilisees.
$runnerSource = "local config = (function()`n" + $configSource + "`nend)()`n" + @'
local function createService(env)
    local game, script, require, Instance = env.game, env.script, env.require, env.Instance
'@ + "`n" + $serviceSource + "`nend`nlocal runTests = (function()`n" + $testSource + "`nend)()`nrunTests(createService, config)`n"
$runnerPath = Join-Path $testBuild 'zone-service-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "ZoneService tests failed (exit $LASTEXITCODE)" }
