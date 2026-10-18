param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$name, [string]$path) { return "local $name = (function()`n" + (Source $path) + "`nend)()`n" }

# Apercu des stages (vraies configs serveur) et logique d'affichage de la fenetre Expedition.
$runnerSource = (Module 'StagePreview' 'src/server/Arena/StagePreview.lua') +
    (Module 'Model' 'src/shared/Expedition/ExpeditionModel.lua') +
    (Module 'StageConfig' 'src/server/Config/StageConfig.lua') +
    (Module 'RewardConfig' 'src/server/Config/RewardConfig.lua') +
    (Module 'EliteConfig' 'src/server/Config/EliteConfig.lua') +
    (Module 'HeroProgressionConfig' 'src/server/Config/HeroProgressionConfig.lua') +
    "local runTests = (function()`n" + (Source 'src/server/Tests/Expedition.spec.lua') + "`nend)()`n" +
    "runTests(StagePreview, Model, { Stages = StageConfig, Rewards = RewardConfig, Elite = EliteConfig, Progression = HeroProgressionConfig })`n"
$runnerPath = Join-Path $testBuild 'expedition-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Expedition tests failed (exit $LASTEXITCODE)" }
