param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Catalogue des ressources (pur) : vraie ResourceConfig contre docs/RESOURCES.md § 2.
$runner = "local ResourceConfig = $(Module 'src/shared/Config/ResourceConfig.lua')`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/ResourceConfig.spec.lua'), ResourceConfig)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'resource-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Resource tests failed (exit $LASTEXITCODE)" }
