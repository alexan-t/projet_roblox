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

	test("TutorialConfig: the five menu entries, in order, with a view each", function()
		local ids = {}
		for _, entry in config.Menu.Entries do
			table.insert(ids, entry.Id)
		end
		assert(table.concat(ids, ",") == "Shop,Bag,Index,Guild,Stats", table.concat(ids, ","))
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
