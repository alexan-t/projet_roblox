param([string]$LuauPath = 'luau')
# Migrations des données joueur (v1 -> v2). Voir tools/test-heroes.ps1.
& (Join-Path $PSScriptRoot 'test-heroes.ps1') -LuauPath $LuauPath -Suite migrations
