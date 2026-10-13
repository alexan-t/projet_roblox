param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# 1. Squelette commun (pur) avec la vraie SkeletonConfig.
# 2. AnimationSets reel avec le vrai Skeleton et des doubles de ReplicatedStorage et d'Instance.
# Aucun acces a Studio.
$runner = "local Skeleton = $(Module 'src/shared/Animation/Skeleton.lua')`n" +
	"local SkeletonConfig = $(Module 'src/shared/Config/SkeletonConfig.lua')`n" +
	"local function createAnimationSets(env)`n    local game, script, require = env.game, env.script, env.require`n$(Source 'src/shared/Animation/AnimationSets.lua')`nend`n" +
	"local results = {}`n" +
	"table.insert(results, { pcall($(Module 'src/server/Tests/Skeleton.spec.lua'), Skeleton, SkeletonConfig) })`n" +
	"table.insert(results, { pcall($(Module 'src/server/Tests/AnimationSets.spec.lua'), createAnimationSets, Skeleton) })`n" +
	"for _, r in results do if not r[1] then error(r[2]) end end`n"
$runnerPath = Join-Path $testBuild 'skeleton-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Skeleton tests failed (exit $LASTEXITCODE)" }
