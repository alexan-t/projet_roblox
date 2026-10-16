param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Catalogue des icônes (pur) : vraie IconConfig contre docs/UI_DESIGN_SYSTEM.md § 7.
$runner = "local IconConfig = $(Module 'src/shared/Config/IconConfig.lua')`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/IconConfig.spec.lua'), IconConfig)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'icon-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Icon tests failed (exit $LASTEXITCODE)" }
