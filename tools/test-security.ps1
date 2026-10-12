param([string]$LuauPath = 'luau')

# Tests de sécurité #12 (voir docs/SECURITY.md). Ils vivent dans les suites des services concernés,
# qui traversent les vrais contrats (remotes, services, sessions) ; ce script les lance et résume
# les cas #12 (préfixe « #12 »). Toute suite en échec fait échouer le script.
$ErrorActionPreference = 'Stop'
$suites = @('test-rewards.ps1', 'test-heroes.ps1', 'test-arena.ps1', 'test-quests.ps1', 'test-playerstate.ps1', 'test-plots.ps1')
$failedSuites = @()
$cases = @()
foreach ($suite in $suites) {
	$output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $suite) -LuauPath $LuauPath 2>&1 | Out-String
	if ($LASTEXITCODE -ne 0) { $failedSuites += $suite }
	$cases += ($output -split "`r?`n") | Where-Object { $_ -match '^(PASS|FAIL) #12' }
}
$cases | ForEach-Object { Write-Output $_ }
$fail = ($cases | Where-Object { $_ -match '^FAIL' }).Count
Write-Output "Security #12: $($cases.Count - $fail) passed, $fail failed"
if ($failedSuites.Count -gt 0 -or $fail -gt 0) { throw "Security tests failed: $($failedSuites -join ', ')" }
