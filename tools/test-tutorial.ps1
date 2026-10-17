param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }

# Regles pures et vraie TutorialConfig, puis le vrai TutorialService avec un double de DataService
# et des API moteur minimales (horloge comprise). Aucun acces a Studio ou DataStore.
$runnerSource = "local Rules = (function()`n" + (Source 'src/shared/Tutorial/TutorialRules.lua') + "`nend)()`n" +
    "local config = (function()`n" + (Source 'src/shared/Config/TutorialConfig.lua') + "`nend)()`n" + @'
local function createService(env)
    local game, script, require, Instance, os = env.game, env.script, env.require, env.Instance, env.os
'@ + "`n" + (Source 'src/server/Services/TutorialService.lua') + "`nend`nlocal runTests = (function()`n" + (Source 'src/server/Tests/Tutorial.spec.lua') + "`nend)()`nrunTests(Rules, config, createService)`n"
$runnerPath = Join-Path $testBuild 'tutorial-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Tutorial tests failed (exit $LASTEXITCODE)" }
