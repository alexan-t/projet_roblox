param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$name, [string]$path) { return "local $name = (function()`n" + (Source $path) + "`nend)()`n" }

# Logique d'affichage de la Sacoche, avec la vraie HeroConfig et les dispositions d'UITheme.Pack.Sacoche
# (UITheme lu tel quel : Color3 / Vector2 / Enum / TweenInfo remplaces par des doubles minimaux).
$shims = @"
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local Color3 = { fromHex = function(h) return h end, fromRGB = function(r, g, b) return { r, g, b } end, new = function(r, g, b) return { r, g, b } end }
local function anyEnum() return setmetatable({}, { __index = function() return 0 end }) end
local Enum = setmetatable({}, { __index = function() return anyEnum() end })
local TweenInfo = { new = function(...) return { ... } end }
local UDim = { new = function(a, b) return { a, b } end }
local UDim2 = { new = function(...) return { ... } end, fromOffset = function(...) return { ... } end, fromScale = function(...) return { ... } end }
local Font = { new = function(...) return { ... } end, fromEnum = function(...) return { ... } end, fromName = function(...) return { ... } end }
local NumberSequence = { new = function(...) return { ... } end }
local ColorSequence = { new = function(...) return { ... } end }

"@
$runnerSource = $shims +
    (Module 'Model' 'src/shared/Sacoche/SacocheModel.lua') +
    (Module 'HeroConfig' 'src/shared/Config/HeroConfig.lua') +
    (Module 'UITheme' 'src/shared/Config/UITheme.lua') +
    "local runTests = (function()`n" + (Source 'src/server/Tests/Sacoche.spec.lua') + "`nend)()`n" +
    "runTests(Model, HeroConfig, UITheme.Pack.Sacoche)`n"
$runnerPath = Join-Path $testBuild 'sacoche-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Sacoche tests failed (exit $LASTEXITCODE)" }
