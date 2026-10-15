param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Mise en scene du combat et guidage (pur) : vraie EnemyPresentationConfig, PresentationFlow, RewardBagGuard,
# OutroGate, QuestGuide. Vector3 : double minimal (X, Y, Z, operateurs, Magnitude).
# Color3 n'existe pas hors Roblox : un double minimal (fromHex) suffit, typeof(...) ~= "Color3".
$runner = "local Color3 = { fromHex = function(hex) return { hex = hex } end }`n" +
	"VectorMeta = {}`n" +
	"VectorMeta.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, VectorMeta) end`n" +
	"VectorMeta.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, VectorMeta) end`n" +
	"VectorMeta.__mul = function(a, n) return setmetatable({ X = a.X * n, Y = a.Y * n, Z = a.Z * n }, VectorMeta) end`n" +
	"VectorMeta.__div = function(a, n) return setmetatable({ X = a.X / n, Y = a.Y / n, Z = a.Z / n }, VectorMeta) end`n" +
	"VectorMeta.__index = function(v, k) if k == 'Magnitude' then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end return nil end`n" +
	"local function vector(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, VectorMeta) end`n" +
	"local Config = (function()`n    local Color3 = Color3`n$(Source 'src/shared/Config/EnemyPresentationConfig.lua')`nend)()`n" +
	"local PresentationFlow = $(Module 'src/client/Combat/PresentationFlow.lua')`n" +
	"local RewardBagGuard = $(Module 'src/client/Combat/RewardBagGuard.lua')`n" +
	"local OutroGate = $(Module 'src/client/Combat/OutroGate.lua')`n" +
	"local QuestGuide = $(Module 'src/shared/Quests/QuestGuide.lua')`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/CombatPresentation.spec.lua'), Config, PresentationFlow, RewardBagGuard, OutroGate, QuestGuide, vector)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'presentation-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Presentation tests failed (exit $LASTEXITCODE)" }
