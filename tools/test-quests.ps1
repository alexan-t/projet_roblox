param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
$configSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Config/QuestConfig.lua') -Raw
$serviceSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Services/QuestService.lua') -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Tests/QuestService.spec.lua') -Raw
$guideSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/shared/Quests/QuestGuide.lua') -Raw -Encoding UTF8

# Le vrai module (et la vraie config) est execute avec un double explicite de DataService.
# Aucun remplacement de logique du service, aucun acces a Studio ou DataStore.
# Le vrai module partage QuestGuide (cibles de guidage connues) est fourni au service et aux tests.
$runnerSource = "local config = (function()`n" + $configSource + "`nend)()`n" + "local QuestGuide = (function()`n" + $guideSource + "`nend)()`n" + @'
local function createService(env)
    local game, script, require, Instance = env.game, env.script, env.require, env.Instance
'@ + "`n" + $serviceSource + "`nend`nlocal runTests = (function()`n" + $testSource + "`nend)()`nrunTests(createService, config, QuestGuide)`n"
$runnerPath = Join-Path $testBuild 'quest-service-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "QuestService tests failed (exit $LASTEXITCODE)" }
