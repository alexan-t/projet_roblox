--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Logique d'affichage de la Sacoche (Shared.Sacoche.SacocheModel) avec la vraie HeroConfig et les
-- dispositions réelles d'UITheme.Pack.Sacoche : tools/test-sacoche.ps1.

return function(Model: any, HeroConfig: any, Pack: any)
	local passed, failed = 0, 0
	local function test(name: string, run: () -> ())
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS " .. name)
		else
			failed += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end
	local function v2(x: number, y: number): any
		return { X = x, Y = y }
	end
	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 0.01
	end

	------------------------------------------------------------------ centrage

	test("centering: X is always the middle of the screen (no left offset), Y the middle of HUD..hotbar", function()
		for _, case in { { 1920, 1080, 80, 960 }, { 1366, 768, 70, 660 }, { 1180, 820, 70, 712 }, { 844, 390, 0, 300 } } do
			local w, h, top, bottom = case[1], case[2], case[3], case[4]
			local device = Model.device(w, h)
			local L = if device == "phone" then Pack.Phone else Pack.Wide
			local window = if device == "tablet" then Pack.Tablet.Window else L.Window
			local f = Model.frame(v2(w, h), top, bottom, window, Pack.Margin, Pack.MinScale, Pack.MaxScale)
			assert(f.X == w / 2, `{w}x{h}: centered horizontally`)
			assert(near(f.Y, (top + Pack.Margin + bottom - Pack.Margin) / 2), `{w}x{h}: centered between HUD and hotbar`)
			assert(window.Y * f.Scale <= (bottom - top) - 2 * Pack.Margin + 0.01 or f.Scale == Pack.MinScale, `{w}x{h}: fits vertically`)
			assert(window.X * f.Scale <= w - 2 * Pack.Margin + 0.01 or f.Scale == Pack.MinScale, `{w}x{h}: fits horizontally`)
		end
	end)

	test("centering: 1920x1080 keeps a large window; tiny zone falls back to the whole screen", function()
		local f = Model.frame(v2(1920, 1080), 80, 960, Pack.Wide.Window, Pack.Margin, Pack.MinScale, Pack.MaxScale)
		assert(f.Scale > 1.1 and f.Scale <= Pack.MaxScale, tostring(f.Scale))
		local g = Model.frame(v2(1000, 600), 500, 520, Pack.Wide.Window, Pack.Margin, Pack.MinScale, Pack.MaxScale)
		assert(g.X == 500 and near(g.Y, 300), "whole screen when HUD..hotbar is too narrow")
	end)

	test("device: phone 844x390, tablet 1180x820, pc 1920x1080", function()
		assert(Model.device(844, 390) == "phone" and Model.device(1180, 820) == "tablet" and Model.device(1920, 1080) == "pc")
	end)

	test("layouts: the mockup's winL / winTop are not tokens (centered window only)", function()
		for _, L in { Pack.Wide, Pack.Tablet, Pack.Phone } do
			assert(L.WinL == nil and L.winL == nil and L.WinTop == nil, "no left-anchored position")
		end
	end)

	------------------------------------------------------------------ cartes

	local heroes = {
		A = { Id = "A", HeroId = "ecuyer_du_rempart", Level = 3, XP = 75, XPToNext = 150, MaxLevel = 20, MaxHealth = 165, AttackDamage = 18 },
		B = { Id = "B", HeroId = "tireuse_des_faubourgs", Level = 2, XP = 40, XPToNext = 125, MaxLevel = 20 },
		C = { Id = "C", HeroId = "ecuyer_du_rempart", Level = 1, XP = 0, XPToNext = 100, MaxLevel = 20 },
		D = { Id = "D", HeroId = "chevalier_du_lierre", Level = 20, XP = 0, XPToNext = 0, MaxLevel = 20 },
	}
	local function ctx(extra: any?): any
		local c = { Infos = HeroConfig.Heroes, Placed = { A = true }, Hotbar = { "A", "B", "C", "", "", "", "", "", "", "" }, New = { D = true } }
		for k, v in extra or {} do c[k] = v end
		return c
	end

	test("cards: catalogue order then level; key, Posé, Nouveau from real state; short name", function()
		local list = Model.cards(heroes, ctx({ Selected = "B" }))
		local ids = {}
		for _, c in list do table.insert(ids, c.Id) end
		assert(table.concat(ids, ",") == "A,C,B,D", table.concat(ids, ","))
		assert(list[1].Key == "1" and list[1].Edge == "Posé" and list[1].Short == "Écuyer")
		assert(list[3].Key == "3" == false and list[3].Key == "2" and list[3].Selected, "B is shortcut 2 and selected")
		assert(list[4].Edge == "Nouveau" and list[4].Key == nil and list[4].Short == "Chevalier")
	end)

	test("cards: filters Posés / Raccourcis and accent-aware search", function()
		assert(#Model.cards(heroes, ctx({ Filter = "placed" })) == 1)
		assert(#Model.cards(heroes, ctx({ Filter = "hotbar" })) == 3)
		local found = Model.cards(heroes, ctx({ Query = "  écuyer " }))
		assert(#found == 2 and found[1].HeroId == "ecuyer_du_rempart")
		assert(#Model.cards(heroes, ctx({ Query = "zzz" })) == 0)
		assert(Model.keyLabel(10) == "0" and Model.keyLabel(nil) == nil)
	end)

	------------------------------------------------------------------ fiche

	test("detail: real rarity, level, XP, PV / ATK from the server view (nothing computed here)", function()
		local d = Model.detail(heroes.A, HeroConfig.Heroes.ecuyer_du_rempart, ctx())
		assert(d.Name == "Écuyer du Rempart" and d.Rarity == "Commun" and d.Level == 3)
		assert(d.XPText == "75 / 150" and near(d.XPRatio, 0.5) and not d.Max)
		assert(d.MaxHealth == 165 and d.AttackDamage == 18)
		local b = Model.detail(heroes.B, HeroConfig.Heroes.tireuse_des_faubourgs, ctx())
		assert(b.MaxHealth == nil and b.AttackDamage == nil, "absent from the view: no invented stat")
		local m = Model.detail(heroes.D, HeroConfig.Heroes.chevalier_du_lierre, ctx())
		assert(m.Max and m.XPText == "Niveau max" and m.XPRatio == 1)
	end)

	test("CTA: one main action — Placer (free) / Retirer de l'arène (placed) / disabled in combat", function()
		local free = Model.detail(heroes.B, nil, ctx())
		assert(free.Primary.Action == "Place" and free.Primary.Label == "Placer" and free.Primary.Breathe and free.Primary.Enabled)
		local placed = Model.detail(heroes.A, nil, ctx())
		assert(placed.Primary.Action == "Remove" and placed.Primary.Label == "Retirer de l'arène" and not placed.Primary.Breathe)
		local combat = Model.detail(heroes.B, nil, ctx({ InCombat = true }))
		assert(combat.Primary.Enabled == false and combat.Primary.Action == "None")
		assert(Model.detail(heroes.B, nil, ctx({ Busy = true })).Primary.Enabled == false)
	end)

	test("secondary: Raccourci X state; add -> pick a slot, remove when assigned", function()
		local inBar = Model.detail(heroes.B, nil, ctx())
		assert(inBar.Key == "2" and inBar.Secondary.Action == "ClearHotbar")
		local states = {}
		for _, s in inBar.States do table.insert(states, s.Label) end
		assert(table.concat(states, ",") == "Disponible,Raccourci 2", table.concat(states, ","))
		local out = Model.detail(heroes.D, nil, ctx())
		assert(out.Key == nil and out.Secondary.Action == "PickHotbar" and out.Secondary.Label == "Ajouter au raccourci")
		assert(Model.detail(heroes.A, nil, ctx()).States[1].Label == "Posé dans l'arène")
	end)

	test("detail (#73): PV / ATK stay the server's FINAL stats; the equipment part comes from EquipmentBonus", function()
		local equipped = table.clone(heroes.A)
		equipped.MaxHealth, equipped.AttackDamage = 195, 22
		equipped.EquipmentBonus = { MaxHealth = 30, AttackDamage = 4 }
		local d = Model.detail(equipped, HeroConfig.Heroes.ecuyer_du_rempart, ctx())
		assert(d.MaxHealth == 195 and d.AttackDamage == 22, "final stats shown as sent, never recomputed")
		assert(d.HealthBonus == 30 and d.AttackBonus == 4)
		local bare = Model.detail(heroes.A, HeroConfig.Heroes.ecuyer_du_rempart, ctx())
		assert(bare.HealthBonus == 0 and bare.AttackBonus == 0, "no EquipmentBonus in the view: 0, nothing invented")
		equipped.EquipmentBonus = { MaxHealth = 0 / 0, AttackDamage = "4" }
		local junk = Model.detail(equipped, nil, ctx())
		assert(junk.HealthBonus == 0 and junk.AttackBonus == 0, "invalid bonus values are ignored")
	end)

	test("equipment (#73): new texts reach 14 real px on PC, tablet and phone 844x390; touch targets >= 44", function()
		local keys = { "DollStatSize", "DollTagSize", "BadgeSize", "EquipNameSize", "EquipTextSize", "EquipNoteSize", "EquipCtaSize",
			"ItemNameSize", "ItemLineSize" }
		-- zones libres réalistes (HUD du haut, hotbar) : mêmes repères que SacocheView.Layout
		for _, case in { { 1920, 1080, 80, 960 }, { 1366, 768, 70, 660 }, { 1180, 820, 70, 712 }, { 844, 390, 0, 300 } } do
			local w, h, top, bottom = case[1], case[2], case[3], case[4]
			local device = Model.device(w, h)
			local L = table.clone(if device == "phone" then Pack.Phone else Pack.Wide)
			if device == "tablet" then
				for key, value in Pack.Tablet do L[key] = value end
			end
			local margin = if device == "phone" then Pack.Margin / 2 else Pack.Margin
			local zoneTop = if device == "phone" then 0 else top - L.TabTop
			local f = Model.frame(v2(w, h), zoneTop, bottom, L.Window, margin, Pack.MinScale, Pack.MaxScale)
			for _, key in keys do
				assert(L[key] >= 14, `{w}x{h}: {key} = {L[key]} px`)
				if device ~= "pc" then
					assert(L[key] * f.Scale >= 14 - 1e-6, `{w}x{h}: {key} = {L[key] * f.Scale} real px at scale {f.Scale}`)
				end
			end
			for _, key in { "EquipCtaHeight", "BackWidth", "SlotSize", "FilterHeight" } do
				assert(L[key] >= 44, `{w}x{h}: {key} = {L[key]} < 44`)
			end
		end
	end)

	test("equipment (#73): item cards hold name x2, rarity, slot and bonus lines; the phone detail fits its panel", function()
		for name, L in { Wide = Pack.Wide, Phone = Pack.Phone } do
			local need = 5 + L.ItemArt + 3 + 2 * math.ceil(L.ItemNameSize * 1.15) + 3 * math.ceil(L.ItemLineSize * 1.2)
			assert(need <= L.ItemCellH, `{name}: card needs {need} px, cell is {L.ItemCellH}`)
			-- détail (#73) dans le panneau de la poupée : en-tête, 4 lignes (bonus, état, PV, ATK), actions
			local panel = L.Window.Y - L.Pad.Top - L.Pad.Bottom - (if name == "Wide" then L.TabHeightOn + L.Gap else 0)
			local area = panel - (10 + 44 + 8) - 10
			local body = L.EquipIcon + L.EquipGap + 2 + 4 * math.ceil(L.EquipTextSize * 1.2) + 3 * L.EquipGap + L.EquipCtaHeight + 5 + L.EquipGap
			assert(body <= area, `{name}: detail needs {body} px, panel has {area}`)
			-- coins de la poupée (PV, ATK, compteur) : deux lignes dans la hauteur d'un emplacement
			assert(2 * math.ceil(L.DollStatSize * 1.15) <= L.SlotSize, `{name}: corner stats taller than a slot`)
		end
	end)

	print(`Sacoche: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} Sacoche test(s) failed`)
	end
end
