param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Repères de rareté (pur) : vraie UITheme (avec des doubles des types moteur) contre la vraie RarityConfig.
$stubs = "local function value(...) return { ... } end`n" +
	"local Color3 = { fromHex = function(hex) return hex end, new = value }`n" +
	"local Font = { new = value }`n" +
	"local UDim = { new = value }`n" +
	"local UDim2 = { new = value, fromOffset = value, fromScale = value }`n" +
	"local TweenInfo = { new = value }`n" +
	"local Enum = setmetatable({}, { __index = function(_, group) return setmetatable({}, { __index = function(_, item) return group .. '.' .. item end }) end })`n"
$runner = $stubs +
	"local UITheme = $(Module 'src/shared/Config/UITheme.lua')`n" +
	"local RarityConfig = $(Module 'src/shared/Config/RarityConfig.lua')`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/RarityMark.spec.lua'), UITheme, RarityConfig)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'ui-theme-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "UI theme tests failed (exit $LASTEXITCODE)" }
