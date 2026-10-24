param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }

# La vraie règle du nom de store (module pur) passée à sa spec.
$runnerSource = "local storeName = (function()`n" + (Source 'src/server/Data/StoreName.lua') + "`nend)()`nlocal runTests = (function()`n" + (Source 'src/server/Tests/StoreName.spec.lua') + "`nend)()`nrunTests(storeName)`n"
$runnerPath = Join-Path $testBuild 'storename-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "StoreName tests failed (exit $LASTEXITCODE)" }
