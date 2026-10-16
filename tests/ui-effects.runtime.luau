--!strict
-- API temporelles réelles, hors moteur : aucun rendu ni callback visuel simulé.
return function(theme, rarity, ultimateFactory, summonFactory, rarityStyleFactory)
    local passed = 0
    local function check(name, fn)
        fn()
        passed += 1
        print("PASS " .. name)
    end
    local function close(actual, expected)
        assert(math.abs(actual - expected) < 1e-9, tostring(actual) .. " ~= " .. tostring(expected))
    end
    local function load(factory, config)
        local storage = { Shared = {
            Config = { UITheme = config, RarityConfig = rarity },
            Animation = { AnimationSets = {} },
        } }
        local game = { GetService = function(_, name)
            return if name == "ReplicatedStorage" then storage else {}
        end }
        local identityRequire = function(module) return module end
        local style = rarityStyleFactory(game, { Parent = { UIKit = {} } }, identityRequire)
        local script = { Parent = { AudioController = {}, Parent = { UI = { RarityStyle = style, UIKit = {} } } } }
        return factory(game, script, function(module) return module end)
    end
    check("theme and all effect groups reject mutations", function()
        assert(table.isfrozen(theme) and table.isfrozen(theme.Effects))
        assert(not pcall(function() theme.Effects.New = {} end))
        for _, group in theme.Effects do
            assert(table.isfrozen(group))
            for key, value in group do
                assert(type(value) == "number" and value > 0 and value < math.huge)
                assert(not pcall(function() group[key] = -1 end))
            end
        end
    end)
    local ultimate = load(ultimateFactory, theme)
    check("ultimate impact at default speed, x1 and x2", function()
        close(ultimate.IMPACT_DELAY, 0.45)
        close(ultimate.ImpactDelay(), 0.45)
        close(ultimate.ImpactDelay(1), 0.45)
        close(ultimate.ImpactDelay(2), 0.225)
    end)
    local summon = load(summonFactory, theme)
    check("summon charge and duration for all ten hero rarities", function()
        for rank, tier in rarity.Tiers do
            local charge = 1.2 + 0.2 * (rank - 1)
            close(summon.Charge(tier.Id), charge)
            close(summon.Duration(tier.Id), charge + 0.45 + 0.6)
        end
    end)
    check("summon defaults for absent and unknown rarities", function()
        close(summon.Charge(), 1.2)
        close(summon.Charge("Unknown"), 1.2)
        close(summon.Duration(), 2.25)
        close(summon.Duration("Unknown"), 2.25)
    end)
    check("APIs follow changed theme tokens rather than former literals", function()
        local changed = table.clone(theme)
        changed.Effects = table.clone(theme.Effects)
        changed.Effects.Ultimate = table.clone(theme.Effects.Ultimate)
        changed.Effects.Ultimate.AnimationImpact = 0.8
        changed.Effects.Ultimate.Travel = 0.4
        changed.Effects.Summon = table.clone(theme.Effects.Summon)
        changed.Effects.Summon.Charge = 0.7
        changed.Effects.Summon.ChargePerRank = 0.1
        changed.Effects.Summon.Flight = 0.2
        changed.Effects.Summon.Reveal = 0.3
        local u = load(ultimateFactory, changed)
        local s = load(summonFactory, changed)
        close(u.ImpactDelay(2), 0.6)
        for rank, tier in rarity.Tiers do
            close(s.Charge(tier.Id), 0.7 + 0.1 * (rank - 1))
            close(s.Duration(tier.Id), 1.2 + 0.1 * (rank - 1))
        end
    end)
    print("UI effects runtime: " .. passed .. " passed, 0 failed")
end
