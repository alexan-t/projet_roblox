param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }

# Regles pures de l'interface (panneau Quetes) : aucun acces a Studio.
$runnerSource = "local QuestLog = (function()`n" + (Source 'src/shared/Quests/QuestLog.lua') + "`nend)()`n" +
    "local runTests = (function()`n" + (Source 'src/server/Tests/QuestLog.spec.lua') + "`nend)()`nrunTests(QuestLog)`n"
$runnerPath = Join-Path $testBuild 'ui-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "UI tests failed (exit $LASTEXITCODE)" }
