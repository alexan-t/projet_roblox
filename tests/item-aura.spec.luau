-- Test du vrai module Luau, sans Studio. Lancé par tests/test-item-aura.ps1.
return function(Config, RarityConfig, ItemConfig)
	local passed = 0
	local function test(name, run)
		run()
		passed += 1
		print("PASS " .. name)
	end
	test("forRarity: nil, unknown and empty IDs fall back to Commun", function()
		for _, id in { "", "unknown", "commun" } do
			assert(Config.forRarity(id) == Config.Tiers.Commun)
		end
		assert(Config.forRarity(nil) == Config.Tiers.Commun)
		assert(Config.forRarity() == Config.Tiers.Commun)
	end)
	test("forRarity: exact tier returned for all ten rarities", function()
		assert(#RarityConfig.Tiers == 10)
		for _, tier in RarityConfig.Tiers do
			assert(Config.forRarity(tier.Id) == Config.Tiers[tier.Id], tier.Id)
		end
	end)
	test("all 100 items resolve to their own tier, without fallback", function()
		assert(#ItemConfig.Ordered == 100)
		for _, item in ItemConfig.Ordered do
			assert(Config.Tiers[item.Rarity], item.Id)
			assert(Config.forRarity(item.Rarity) == Config.Tiers[item.Rarity], item.Id)
		end
	end)
	test("shared tier settings reject accidental mutation", function()
		assert(table.isfrozen(Config))
		assert(table.isfrozen(Config.Tiers))
		for _, aura in Config.Tiers do
			assert(table.isfrozen(aura))
			assert(not pcall(function() aura.Fill = 1 end))
		end
	end)
	test("global settings keep gradients, halo pulse and compact spread valid", function()
		for _, value in { Config.Shade, Config.SheenAlpha, Config.HaloInner, Config.HaloOuter, Config.CompactSpread } do
			assert(value > 0 and value < 1)
		end
		assert(Config.HaloInner < Config.HaloOuter)
		assert(Config.PulseAmount > 0 and Config.PulseAmount < 1)
		assert(Config.Compact > 0)
		assert(#Config.RayAlpha == 2)
		for _, alpha in Config.RayAlpha do
			assert(alpha >= 0 and alpha <= 1)
		end
		for _, aura in Config.Tiers do
			for k = 1, aura.Halo do
				local alpha = Config.HaloInner + (Config.HaloOuter - Config.HaloInner) * k / aura.Halo
				assert(alpha - 0.05 >= 0 and alpha + 0.05 <= 1)
			end
		end
	end)
	print(string.format("ItemAura runtime: %d passed, 0 failed", passed))
end
