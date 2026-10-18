param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Module([string]$path) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8
    "(function()`n$source`nend)()"
}
$runner = "local Config = $(Module 'src/shared/Config/ItemAuraConfig.lua')`n" +
    "local RarityConfig = $(Module 'src/shared/Config/RarityConfig.lua')`n" +
    "local ItemConfig = $(Module 'src/shared/Config/ItemConfig.lua')`n" +
    "local run = $(Module 'tests/item-aura.spec.luau')`nrun(Config, RarityConfig, ItemConfig)`n"
$runnerPath = Join-Path $testBuild 'item-aura-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Item aura tests failed (exit $LASTEXITCODE)" }
