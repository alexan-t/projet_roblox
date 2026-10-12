param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }

# Le vrai PlayerStateService avec un double explicite de DataService et des API moteur minimales.
$runnerSource = @'
local function createService(env)
    local game, script, require, Instance = env.game, env.script, env.require, env.Instance
'@ + "`n" + (Source 'src/server/Services/PlayerStateService.lua') + "`nend`nlocal runTests = (function()`n" + (Source 'src/server/Tests/PlayerStateService.spec.lua') + "`nend)()`nrunTests(createService)`n"
$runnerPath = Join-Path $testBuild 'playerstate-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "PlayerStateService tests failed (exit $LASTEXITCODE)" }
