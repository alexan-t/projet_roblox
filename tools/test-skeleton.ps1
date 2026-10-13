param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Squelette commun (pur) avec la vraie SkeletonConfig. Aucun acces a Studio.
$runner = "local Skeleton = $(Module 'src/shared/Animation/Skeleton.lua')`n" +
	"local SkeletonConfig = $(Module 'src/shared/Config/SkeletonConfig.lua')`n" +
	"local ok, err = pcall($(Module 'src/shared/Tests/Skeleton.spec.lua'), Skeleton, SkeletonConfig)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'skeleton-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Skeleton tests failed (exit $LASTEXITCODE)" }
