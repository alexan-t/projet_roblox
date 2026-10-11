param([string]$LuauPath = 'luau')
# HeroService : héros de départ, invocation, HeroObtained. Voir tools/test-heroes.ps1.
& (Join-Path $PSScriptRoot 'test-heroes.ps1') -LuauPath $LuauPath -Suite summon
