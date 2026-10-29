--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Règles pures du guidage (Shared.Tutorial.TutorialRules) avec la vraie TutorialConfig, puis le vrai
-- TutorialService avec un double de DataService (tools/test-tutorial.ps1).

return function(Rules: any, config: any, createService: any)
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

	------------------------------------------------------------------ config

	test("TutorialConfig: valid (flags, steps, nudges, menu)", function()
		local problems = Rules.problems(config)
		assert(#problems == 0, table.concat(problems, " ; "))
	end)

	test("TutorialConfig: problems() catches a broken config", function()
		local broken = {
			Flags = { "Bag", "Bag", "" },
			FirstOpen = { Nope = { Steps = { { Target = "pas une cible" }, { Target = "Bag.Place", Seconds = 0 } } } },
			Nudges = { { Id = "X", Target = "Menu.Bag", Flag = "Inconnu", Condition = "HasHero" } },
			Menu = { Entries = { { Id = "A", View = "Shop" }, { Id = "A", View = "Soon" }, { Id = "B", View = "Bag", Flag = "Zut" } } },
		}
		local text = table.concat(Rules.problems(broken), "\n")
		for _, expected in { "en double : Bag", "drapeau invalide", "FirstOpen.Nope : drapeau inconnu", "cible invalide",
			"Seconds", "Nudges[1] : drapeau inconnu", "View inconnue", "Id manquant ou en double", "texte Soon", "Menu[3] : drapeau inconnu" } do
			assert(text:find(expected, 1, true), "missing problem: " .. expected .. "\n" .. text)
		end
	end)

	test("TutorialConfig: the six menu entries (2 columns x 3 rows), in order, with a view each", function()
		local ids = {}
		for _, entry in config.Menu.Entries do
			table.insert(ids, entry.Id)
		end
		assert(table.concat(ids, ",") == "Shop,Bag,Index,Guild,Stats,Quest", table.concat(ids, ","))
	end)

	------------------------------------------------------------------ règles

	test("mark: known flag once; unknown, non-string, too long or repeated → refused", function()
		local seen = {}
		assert(Rules.mark(config, seen, "Bag") == true and seen.Bag == true)
		assert(Rules.mark(config, seen, "Bag") == false, "already seen")
		assert(Rules.mark(config, seen, "Gold") == false and seen.Gold == nil, "unknown")
		assert(Rules.mark(config, seen, 42) == false and Rules.mark(config, seen, nil) == false)
		assert(Rules.mark(config, seen, string.rep("a", 100)) == false)
	end)

	test("view: copy with known true flags only", function()
		local saved = { Bag = true, Fake = true, Index = false }
		local view = Rules.view(config, saved)
		assert(view.Bag == true and view.Fake == nil and view.Index == nil)
		view.Stats = true
		assert(saved.Stats == nil, "copy")
		assert(next(Rules.view(config, nil)) == nil)
	end)

	test("firstOpen: steps the first time only; nil once seen or without steps", function()
		local seen = {}
		local steps = Rules.firstOpen(config, seen, "Bag")
		assert(steps and #steps >= 1 and steps[1].Target == "Bag.FirstHero")
		seen.Bag = true
		assert(Rules.firstOpen(config, seen, "Bag") == nil, "no loop on reopen")
		assert(Rules.firstOpen(config, {}, "Stats") == nil, "no step")
		assert(Rules.firstOpen(config, {}, "Unknown") == nil)
	end)

	test("nudges: shown while the flag is unseen AND the condition holds", function()
		assert(#Rules.nudges(config, {}, {}) == 0, "nothing yet")
		assert(#Rules.nudges(config, {}, { HasHero = true }) == 0, "first defense: the quest guides, no nudge")
		local list = Rules.nudges(config, {}, { HasHero = true, FirstVictory = true })
		assert(#list == 1 and list[1].Target == "Menu.Bag" and list[1].Source == "Nudge")
		assert(#Rules.nudges(config, { Bag = true }, { FirstVictory = true }) == 0, "bag opened once: gone")
	end)

	test("badges: never all at once for a brand-new hero owner (no visual spam)", function()
		local shown = 0
		for _, entry in config.Menu.Entries do
			if Rules.badge(entry, {}, { HasHero = true }) then shown += 1 end
		end
		assert(shown == 1, "only the bag: " .. shown)
	end)

	test("badge: ! while unseen and condition true; entries without flag never", function()
		local bag, shop
		for _, entry in config.Menu.Entries do
			if entry.Id == "Bag" then bag = entry elseif entry.Id == "Shop" then shop = entry end
		end
		assert(Rules.badge(bag, {}, { HasHero = true }) == true)
		assert(Rules.badge(bag, {}, {}) == false, "no hero yet")
		assert(Rules.badge(bag, { Bag = true }, { HasHero = true }) == false)
		assert(Rules.badge(shop, {}, { HasHero = true }) == false)
	end)

	test("pick: one arrow at a time, FirstOpen > Quest > Nudge, only available targets", function()
		local all = {
			{ Source = "Nudge", Target = "Menu.Bag" },
			{ Source = "Quest", Target = "Hotbar.Slot" },
			{ Source = "FirstOpen", Target = "Bag.Place" },
		}
		local yes = function() return true end
		assert(Rules.pick(all, yes).Source == "FirstOpen")
		local noBag = function(t: string) return t ~= "Bag.Place" end
		assert(Rules.pick(all, noBag).Source == "Quest", "unavailable target skipped")
		assert(Rules.pick({ all[1] }, yes).Source == "Nudge")
		assert(Rules.pick({}, yes) == nil and Rules.pick(all, function() return false end) == nil)
		local twins = { { Source = "Quest", Target = "A.One" }, { Source = "Quest", Target = "A.Two" } }
		assert(Rules.pick(twins, yes).Target == "A.One", "stable order")
	end)

	------------------------------------------------------------------ premier équipement

	test("equipment: new flag, earlier flags kept in order (never renamed)", function()
		local flags = table.concat(config.Flags, ",")
		assert(flags:find("^Bag,Expedition,Summon,SummonBanners,Index,Stats,Currencies,Quests,") ~= nil, flags)
		assert(table.find(config.Flags, "Equipment") ~= nil)
	end)

	test("equipment: tab -> hero -> first item -> Équiper, captions of 2 to 4 words", function()
		local entry = config.FirstOpen.Equipment
		assert(entry.Screen == "Bag" and entry.Condition == "HasEquipment")
		local targets = {}
		for _, step in entry.Steps do
			table.insert(targets, step.Target)
			local words = 0
			for word in string.gmatch(step.Text, "[^%s!%?%.]+") do
				words += 1
			end
			-- « Équipe-le ! » compte pour deux mots (verbe + pronom)
			if step.Text:find("-", 1, true) then words += 1 end
			assert(words >= 2 and words <= 4, step.Text)
		end
		assert(table.concat(targets, ",") == "Bag.EquipmentTab,Bag.EquipHero,Bag.FirstItem,Bag.EquipAction", table.concat(targets, ","))
		-- les actions du joueur attendent son clic : une durée écoulée sauterait toute la suite
		local s = entry.Steps
		assert(s[1].Hold == true and s[3].Hold == true and s[4].Hold == true and s[2].Hold == nil, "tab, item, Équiper: Hold")
	end)

	test("hasEquipment: an owned hero AND a known item worn by nobody", function()
		local items = { item_004 = { Name = "Épée" } }
		assert(Rules.hasEquipment(1, { { ItemId = "item_004" } }, items) == true)
		assert(Rules.hasEquipment(0, { { ItemId = "item_004" } }, items) == false, "no hero")
		assert(Rules.hasEquipment(1, { { ItemId = "item_004", EquippedBy = "H1" } }, items) == false, "already worn")
		assert(Rules.hasEquipment(1, { { ItemId = "inconnu" } }, items) == false, "not in the catalogue")
		assert(Rules.hasEquipment(1, {}, items) == false and Rules.hasEquipment(1, nil, items) == false, "no item: never blocks")
	end)

	test("equipment: a successful server inventory assignment is required to finish the guidance", function()
		local items = { item_004 = { Name = "Heaume" } }
		local free = { { ItemId = "item_004" } }
		local worn = { { ItemId = "item_004", EquippedBy = "H1" } }
		assert(Rules.hasEquipped(1, free, items) == false, "received but not equipped")
		assert(Rules.hasEquipped(1, worn, items) == true, "server confirms a wearer")
		assert(Rules.hasEquipped(0, worn, items) == false, "no owned hero")
		assert(Rules.hasEquipped(1, { { ItemId = "unknown", EquippedBy = "H1" } }, items) == false, "unknown item")
		assert(Rules.hasEquipped(1, { { ItemId = "item_004", EquippedBy = "" } }, items) == false, "no wearer")
		assert(Rules.hasEquipped(1, nil, items) == false, "server view unavailable")
		local seen = {} -- closing the bag early must not mark Equipment
		local open = function(key: string): boolean return key == "Bag" end
		assert(Rules.followUp(config, seen, { HasEquipment = true }, open) == "Equipment", "reopens")
		seen.Equipment = true -- only after the inventory confirmation
		assert(Rules.followUp(config, seen, { HasEquipment = true }, open) == nil, "finished")
	end)

	test("equipment: Done = Equipped, flag only from the server view, never from the opening", function()
		assert(config.FirstOpen.Equipment.Done == "Equipped")
		local seen = {}
		assert(#Rules.done(config, seen, { HasEquipment = true }) == 0, "item received, nothing worn: not finished")
		assert(#Rules.done(config, seen, { HasEquipment = true, Equipped = false }) == 0, "Équiper refused by the server")
		local list = Rules.done(config, seen, { Equipped = true })
		assert(#list == 1 and list[1] == "Equipment", "server confirms a worn item")
		assert(#Rules.done(config, { Equipment = true }, { Equipped = true }) == 0, "marked once")
		-- seules les entrées avec Done : les découvertes ordinaires ne passent jamais par là
		for _, key in Rules.done(config, {}, { Equipped = true, HasEquipment = true, HasHero = true, FirstVictory = true }) do
			assert(config.FirstOpen[key].Done ~= nil, key)
		end
	end)

	test("resume: furthest displayed step, nil when nothing is displayed", function()
		local steps = config.FirstOpen.Equipment.Steps
		local function shown(...)
			local set = {}
			for _, id in { ... } do set[id] = true end
			return function(id: string): boolean return set[id] == true end
		end
		-- autre onglet de la Sacoche : seul l'onglet Équipement est affiché
		assert(Rules.resume(steps, shown("Bag.EquipmentTab")) == 1, "closed before « Ton équipement »")
		-- onglet Équipement déjà ouvert (la Sacoche s'en souvient) : héros et objets affichés
		assert(Rules.resume(steps, shown("Bag.EquipHero", "Bag.FirstItem")) == 3, "closed after « Ton équipement » / « Ton héros »")
		-- objet déjà choisi : reprise directement sur « Équiper »
		assert(Rules.resume(steps, shown("Bag.EquipHero", "Bag.FirstItem", "Bag.EquipAction")) == 4, "closed just before Équiper")
		assert(Rules.resume(steps, shown()) == nil, "nothing displayed: wait, never finish")
	end)

	test("equipment scenarios: interruptions, refusal, reconnection, already equipped, no hero", function()
		local open = function(key: string): boolean return key == "Bag" end
		local item = { item_004 = { Name = "Heaume" } }
		local free = { { ItemId = "item_004" } }
		local worn = { { ItemId = "item_004", EquippedBy = "H1" } }
		local function conditionsFor(heroes: number, entries: any)
			return {
				HasHero = heroes >= 1,
				FirstVictory = true,
				HasEquipment = Rules.hasEquipment(heroes, entries, item),
				Equipped = Rules.hasEquipped(heroes, entries, item),
			}
		end
		-- 1. premier objet reçu : une seule flèche et un seul « ! », sur le Sac
		local seen = { Bag = true }
		local c = conditionsFor(1, free)
		local nudges = Rules.nudges(config, seen, c)
		assert(#nudges == 1 and nudges[1].Target == "Menu.Bag", "one arrow on the bag")
		-- 2. Sacoche ouverte puis fermée à n'importe quelle étape : rien n'est enregistré, tout reste disponible
		for _, closedAt in { "before tab", "after tab", "after item", "before Équiper" } do
			assert(#Rules.done(config, seen, c) == 0, closedAt)
			assert(seen.Equipment == nil, closedAt)
			assert(Rules.followUp(config, seen, c, open) == "Equipment", "reopened: " .. closedAt)
			assert(#Rules.nudges(config, seen, c) == 1, "bag closed: arrow back on the bag " .. closedAt)
		end
		-- 3. clic « Équiper » refusé : la vue serveur ne change pas, le guidage continue
		assert(#Rules.done(config, seen, conditionsFor(1, free)) == 0, "refused")
		-- 4. déconnexion : le serveur ne renvoie que les drapeaux enregistrés (Equipment absent)
		local reloaded = Rules.view(config, { Bag = true, Equipment = false })
		assert(reloaded.Equipment == nil and Rules.followUp(config, reloaded, c, open) == "Equipment", "reconnection: guidance back")
		-- 5. équipement réussi (vue serveur) : drapeau, plus de flèche ni de relance
		local ok = conditionsFor(1, worn)
		for _, key in Rules.done(config, seen, ok) do
			assert(Rules.mark(config, seen, key))
		end
		assert(seen.Equipment == true)
		assert(Rules.followUp(config, seen, conditionsFor(1, free), open) == nil, "never replayed, even with a new item")
		assert(#Rules.nudges(config, seen, conditionsFor(1, free)) == 0, "no bag arrow any more")
		-- 6. joueur déjà équipé au démarrage : terminé dès le chargement, sans guidage
		local veteran = { Bag = true }
		assert(#Rules.done(config, veteran, conditionsFor(2, worn)) == 1, "already equipped at start")
		-- 7. sans héros ou sans objet : ni guidage, ni flèche, ni drapeau
		for _, case in { conditionsFor(0, free), conditionsFor(1, {}), conditionsFor(1, nil) } do
			assert(Rules.followUp(config, { Bag = true }, case, open) == nil)
			assert(#Rules.nudges(config, { Bag = true }, case) == 0)
			assert(#Rules.done(config, { Bag = true }, case) == 0)
		end
	end)

	test("problems: Done needs a Screen and a last Hold step", function()
		local broken = {
			Flags = { "Bag", "Part", "Loose" },
			FirstOpen = {
				Bag = { Steps = {} },
				Part = { Done = "X", Steps = { { Target = "Bag.Item", Hold = true } } },
				Loose = { Screen = "Bag", Done = "X", Steps = { { Target = "Bag.Item", Seconds = 3 } } },
			},
			Nudges = {},
			Menu = { Entries = {} },
		}
		local text = table.concat(Rules.problems(broken), "\n")
		assert(text:find("FirstOpen.Part : Done sans Screen", 1, true), text)
		assert(text:find("FirstOpen.Loose : Done, dernière étape sans Hold", 1, true), text)
		assert(#Rules.problems(config) == 0, table.concat(Rules.problems(config), "\n"))
	end)

	test("followUp: Sacoche open + item to equip, after the bag discovery; never without an item", function()
		local open = function(key: string) return key == "Bag" end
		local closed = function() return false end
		assert(Rules.followUp(config, {}, { HasEquipment = true }, open) == "Equipment")
		assert(Rules.followUp(config, {}, { HasEquipment = false }, open) == nil, "no compatible item: nothing")
		assert(Rules.followUp(config, {}, { HasEquipment = true }, closed) == nil, "bag closed")
		assert(Rules.followUp(config, { Equipment = true }, { HasEquipment = true }, open) == nil, "seen once")
	end)

	test("nudges: item to equip -> one arrow on the bag button, even with OpenBag", function()
		local list = Rules.nudges(config, { Bag = true }, { HasHero = true, HasEquipment = true })
		assert(#list == 1 and list[1].Target == "Menu.Bag", "bag opened before: the equipment nudge")
		assert(#Rules.nudges(config, { Bag = true, Equipment = true }, { HasEquipment = true }) == 0, "guidance seen: gone")
		local both = Rules.nudges(config, {}, { HasHero = true, FirstVictory = true, HasEquipment = true })
		local picked = Rules.pick(both, function() return true end)
		assert(picked and picked.Target == "Menu.Bag", "same target: a single arrow")
		-- 1-5 : premier équipement et quête à récupérer en même temps → la flèche reste sur le Sac
		local claim = Rules.nudges(config, { Bag = true }, { HasHero = true, QuestClaimable = true, HasEquipment = true })
		local first = Rules.pick(claim, function() return true end)
		assert(#claim == 2 and first and first.Target == "Menu.Bag", "equipment before the quest reminder")
	end)

	test("badge: new equipment lights only the bag (one badge at a time)", function()
		local conditions = { HasHero = true, HasEquipment = true }
		local lit = {}
		for _, entry in config.Menu.Entries do
			if Rules.badge(entry, { Bag = true }, conditions, config) then table.insert(lit, entry.Id) end
		end
		assert(table.concat(lit, ",") == "Bag", table.concat(lit, ","))
		local shown = 0
		for _, entry in config.Menu.Entries do
			if Rules.badge(entry, {}, conditions, config) then shown += 1 end
		end
		assert(shown == 1, "new player with an item: only the bag " .. shown)
		for _, entry in config.Menu.Entries do
			assert(not Rules.badge(entry, { Bag = true, Equipment = true }, conditions, config), "seen: no badge " .. entry.Id)
		end
	end)

	test("problems: Screen must be another known first-open, Condition needs a Screen", function()
		local broken = {
			Flags = { "Bag", "Part", "Lost" },
			FirstOpen = {
				Bag = { Steps = {} },
				Part = { Screen = "Nope", Condition = "X", Steps = { { Target = "Bag.Item" } } },
				Lost = { Condition = "X", Steps = { { Target = "Bag.Item", Hold = true, Seconds = 3 } } },
			},
			Nudges = {},
			Menu = { Entries = {} },
		}
		local text = table.concat(Rules.problems(broken), "\n")
		assert(text:find("FirstOpen.Part : Screen inconnu", 1, true), text)
		assert(text:find("FirstOpen.Lost : Condition sans Screen", 1, true), text)
		assert(text:find("FirstOpen.Lost[1] : Hold vaut true, sans Seconds", 1, true), text)
	end)

	------------------------------------------------------------------ service

	local function fixture(): any
		local env: any = { data = {} }
		local function inst(className: string): any
			local i: any = { ClassName = className, Name = className, children = {} }
			function i:FindFirstChild(n: string): any
				for _, c in self.children do if c.Name == n then return c end end
				return nil
			end
			if className == "RemoteEvent" then
				local handlers = {}
				i.OnServerEvent = { Connect = function(_s: any, f: any) table.insert(handlers, f) end }
				function i:fire(...: any) for _, f in handlers do f(...) end end
			end
			return setmetatable({}, {
				__index = i,
				__newindex = function(t: any, k: string, v: any)
					i[k] = v
					if k == "Parent" and typeof(v) == "table" and v.children then table.insert(v.children, t) end
				end,
			})
		end
		local replicated = inst("ReplicatedStorage")
		replicated.Shared = { Config = { TutorialConfig = config }, Tutorial = { TutorialRules = Rules } }
		local players = { PlayerRemoving = { Connect = function(_s: any, f: any) env.removing = f end } }
		env.Instance = { new = inst }
		env.game = { GetService = function(_s: any, name: string): any
			if name == "Players" then return players end
			assert(name == "ReplicatedStorage", name)
			return replicated
		end }
		local dataService: any = {}
		function dataService:GetData(p: any): any return env.data[p] end
		env.script = { Parent = { DataService = dataService } }
		env.require = function(m: any): any return m end
		env.clock = 0
		env.os = { clock = function() return env.clock end }
		function env.player(name: string, tutorial: any?): any
			local p: any = { Name = name, attributes = { DataLoaded = true } }
			function p:GetAttribute(k: string): any return self.attributes[k] end
			env.data[p] = { Currencies = { Gold = 0 }, Tutorial = tutorial }
			return p
		end
		function env.start(): any
			local s = createService(env)
			s:Start()
			local remotes = replicated:FindFirstChild("Remotes")
			env.get = remotes:FindFirstChild("GetTutorialSeen")
			env.mark = remotes:FindFirstChild("MarkTutorialSeen")
			return s
		end
		return env
	end

	test("service: mark a known flag, read it back; unknown ignored; no game effect", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { Seen = {} })
		e.mark:fire(p, "Bag")
		e.clock += 1
		e.mark:fire(p, "Gold")
		e.clock += 1
		e.mark:fire(p, { "Bag" })
		local view = e.get.OnServerInvoke(p)
		assert(view.Bag == true and view.Gold == nil)
		assert(e.data[p].Tutorial.Seen.Bag == true and e.data[p].Tutorial.Seen.Gold == nil)
		assert(e.data[p].Currencies.Gold == 0)
	end)

	test("service: old profile without Tutorial gets an empty table; nil before data", function()
		local e = fixture()
		e.start()
		local p = e.player("A", nil)
		local view = e.get.OnServerInvoke(p)
		assert(view and next(view) == nil)
		assert(typeof(e.data[p].Tutorial.Seen) == "table")
		p.attributes.DataLoaded = nil
		assert(e.get.OnServerInvoke(p) == nil)
		e.mark:fire(p, "Index")
		assert(e.data[p].Tutorial.Seen.Index == nil, "not loaded: ignored")
	end)

	test("service: marks sent too fast are ignored; players are independent", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A", { Seen = {} }), e.player("B", { Seen = {} })
		assert(s:MarkSeen(a, "Bag") == true)
		assert(s:MarkSeen(a, "Index") == false, "throttled")
		assert(s:MarkSeen(b, "Index") == true, "other player")
		e.clock += 1
		assert(s:MarkSeen(a, "Index") == true)
		local va, vb = e.get.OnServerInvoke(a), e.get.OnServerInvoke(b)
		assert(va.Bag and va.Index and vb.Index and not vb.Bag)
		e.removing(a)
	end)

	print(`Tutorial: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} Tutorial test(s) failed`)
	end
end
