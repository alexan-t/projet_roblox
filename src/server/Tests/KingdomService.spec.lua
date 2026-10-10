--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai KingdomService avec des doubles des API Roblox, de PlotService et de DataService.
-- Le rendu, la physique et la réplication doivent être validés dans Studio.

return function(createService: any, config: any)
	local function vector(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z }, {
			__add = function(a: any, b: any): any return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
			__sub = function(a: any, b: any): any return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__eq = function(a: any, b: any): boolean
				return math.abs(a.X - b.X) < 1e-6 and math.abs(a.Y - b.Y) < 1e-6 and math.abs(a.Z - b.Z) < 1e-6
			end,
			__index = function(v: any, key: string): any
				local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
				if key == "Magnitude" then return m end
				if key == "Unit" then return vector(v.X / m, v.Y / m, v.Z / m) end
				return nil
			end,
		})
	end
	local function cframe(position: any, look: any): any
		return { Position = position, LookVector = look }
	end

	local function fixture(): any
		local env: any = { instances = {}, warnings = {}, callbacks = {}, plots = {}, runtimes = {}, data = {} }
		local methods: any = {}
		local bases: any = { Part = "BasePart", MeshPart = "BasePart" }
		function methods:IsA(class: string): boolean
			return self.ClassName == class or bases[self.ClassName] == class or class == "Instance"
		end
		function methods:GetChildren(): any
			local children = {}
			for _, instance in env.instances do
				if instance.Parent == self then table.insert(children, instance) end
			end
			return children
		end
		function methods:FindFirstChild(name: string): any
			for _, child in self:GetChildren() do
				if child.Name == name then return child end
			end
			return nil
		end
		function methods.GetFullName(self: any): string
			return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
		end
		function methods:GetAttribute(name: string): any return self.attributes[name] end
		function methods:SetAttribute(name: string, value: any) self.attributes[name] = value end
		function methods:Destroy()
			for _, child in self:GetChildren() do child:Destroy() end
			self.Parent = nil
			self.destroyed = true
		end
		function methods.PivotTo(self: any, cf: any)
			self.pivot = cf
			self.moves += 1
		end
		function methods:Clone(): any
			if self.Archivable == false then return nil end
			local copy = env.new(self.ClassName, self.Name, nil)
			copy.attributes = table.clone(self.attributes)
			copy.CFrame, copy.Position, copy.sourceOf = self.CFrame, self.Position, self
			for _, child in self:GetChildren() do
				child:Clone().Parent = copy
			end
			return copy
		end
		function env.new(class: string, name: string, parent: any, attributes: any?): any
			local instance: any = setmetatable({ ClassName = class, Name = name, Parent = parent,
				attributes = attributes or {}, moves = 0, Archivable = true }, { __index = methods })
			table.insert(env.instances, instance)
			return instance
		end
		function env.part(name: string, parent: any, position: any): any
			local part = env.new("Part", name, parent)
			part.Position = position
			-- Repère couché comme EmplacementCentral dans la DEV : l'axe haut de la pièce est horizontal.
			part.CFrame = cframe(position, vector(0, 0, -1))
			return part
		end

		env.serverStorage = env.new("ServerStorage", "ServerStorage", nil)
		local assets = env.new("Folder", "Assets", env.serverStorage)
		env.states = env.new("Folder", "RoyaumeEtats", assets)
		env.heroAssets = env.new("Folder", "Heros", assets)
		function env.state(visualState: any, markerCount: number): any
			local model = env.new("Model", "Etat" .. tostring(visualState), env.states, { VisualState = visualState })
			env.new("Part", "Decor", model)
			local markers = env.new("Folder", "Heros", env.new("Folder", "Emplacements", model))
			-- Création dans le désordre pour vérifier le tri Heros_2 < Heros_10.
			for index = markerCount, 1, -1 do
				env.part("Heros_" .. index, markers, vector(visualState * 1000 + index, 0, 0))
			end
			return model
		end
		function env.heroAsset(heroId: string): any
			return env.new("Model", heroId, env.heroAssets, { HeroId = heroId })
		end
		env.state(1, 3)
		env.state(2, 12)
		env.heroAsset("Chevalier")
		env.heroAsset("Archere")

		env.workspace = env.new("Workspace", "Workspace", nil)
		function env.plotModel(id: number): any
			local plot = env.new("Model", "Plot_" .. id, env.workspace, { PlotId = id })
			env.part("Decor", plot, vector(0, 0, 0))
			local anchor = env.part("EmplacementCentral", env.new("Model", "Royaume", plot), vector(id * 100, 5, 0))
			-- Repère tourné et incliné : seule sa direction horizontale (1, 0, 0) doit compter.
			anchor.CFrame = cframe(anchor.Position, vector(0.6, -0.8, 0))
			return plot
		end

		-- Doubles des services : mêmes garanties publiques que PlotService / DataService.
		local plotService: any = {}
		function plotService:GetRuntime(player: any): any
			local runtime = env.runtimes[player]
			return if runtime and runtime.Parent == env.plots[player] and not runtime.destroyed then runtime else nil
		end
		function plotService:GetPlot(player: any): any
			return if plotService:GetRuntime(player) then env.plots[player] else nil
		end
		function plotService:OnPlotAssigned(callback: any)
			table.insert(env.callbacks, callback)
		end
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end

		function env.player(name: string): any
			return { Name = name }
		end
		function env.load(player: any, visualState: any, heroes: any?)
			env.data[player] = { Kingdom = { Level = 1, VisualState = visualState }, Heroes = heroes or {} }
		end
		function env.assign(player: any, plot: any)
			env.plots[player] = plot
			env.runtimes[player] = env.new("Folder", "Runtime", plot)
			for _, callback in env.callbacks do callback(player, plot) end
		end
		function env.leave(player: any)
			if env.runtimes[player] then env.runtimes[player]:Destroy() end
			env.runtimes[player], env.plots[player], env.data[player] = nil, nil, nil
		end

		local log = { debug = function() end, warn = function(_scope: string, message: string)
			table.insert(env.warnings, message)
		end }
		local replicated = { Shared = { Utils = { Log = log }, Types = { PlayerDataTypes = {} } } }
		env.game = { GetService = function(_self: any, name: string): any
			return ({ ReplicatedStorage = replicated, ServerStorage = env.serverStorage })[name]
		end }
		env.script = { Parent = { DataService = dataService, PlotService = plotService,
			Parent = { Config = { KingdomConfig = config } } } }
		env.require = function(module: any): any return module end
		env.Instance = { new = function(class: string): any return env.new(class, class, nil) end }
		env.Vector3 = { new = vector }
		env.CFrame = {
			new = function(position: any): any return cframe(position, vector(0, 0, -1)) end,
			lookAt = function(position: any, target: any): any return cframe(position, (target - position).Unit) end,
		}
		function env.start(): any
			env.service = createService(env)
			env.service:Start()
			return env.service
		end
		function env.kingdoms(player: any): { any }
			local found = {}
			local runtime = env.runtimes[player]
			if runtime then
				for _, child in runtime:GetChildren() do
					if child.Name == "Kingdom" then table.insert(found, child) end
				end
			end
			return found
		end
		function env.heroes(player: any): { [string]: any }
			local found = {}
			local folder = env.runtimes[player] and env.runtimes[player]:FindFirstChild("Heroes")
			for _, child in (if folder then folder:GetChildren() else {}) do
				local id = child:GetAttribute("HeroInstanceId")
				assert(not found[id], "duplicate hero " .. tostring(id))
				found[id] = child
			end
			return found
		end
		function env.count(map: any): number
			local n = 0
			for _ in map do n += 1 end
			return n
		end
		return env
	end

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

	test("plot assigned with data creates state 1 on the anchor, under Runtime", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		local plot = e.plotModel(1)
		e.load(p, 1)
		e.assign(p, plot)
		local list = e.kingdoms(p)
		assert(#list == 1, "one kingdom")
		local kingdom = list[1]
		assert(kingdom.Parent == e.runtimes[p] and kingdom.ClassName == "Model")
		assert(kingdom:GetAttribute("VisualState") == 1 and kingdom.sourceOf.Name == "Etat1")
		assert(kingdom.pivot.Position == vector(100, 5, 0), "pivot on anchor")
		assert(kingdom.pivot.LookVector == vector(1, 0, 0), "horizontal orientation of the anchor")
		assert(e.service:GetKingdom(p) == kingdom)
		assert(plot:FindFirstChild("Decor") and plot:FindFirstChild("Royaume"), "plot scenery untouched")
	end)

	test("no data or no plot: nothing created, later Refresh succeeds", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local plot = e.plotModel(1)
		e.assign(p, plot)
		assert(#e.kingdoms(p) == 0 and s:Refresh(p) == false)
		e.load(p, 1)
		assert(s:Refresh(p) == true and #e.kingdoms(p) == 1)
		local q = e.player("B")
		e.load(q, 1)
		assert(s:Refresh(q) == false and s:GetKingdom(q) == nil)
	end)

	test("state 2 created directly", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		e.load(p, 2)
		e.assign(p, e.plotModel(1))
		local list = e.kingdoms(p)
		assert(#list == 1 and list[1]:GetAttribute("VisualState") == 2 and list[1].sourceOf.Name == "Etat2")
	end)

	test("refresh 1 -> 2 replaces without duplicate", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		local old = e.kingdoms(p)[1]
		e.data[p].Kingdom.VisualState = 2
		assert(s:Refresh(p) == true)
		local list = e.kingdoms(p)
		assert(#list == 1 and list[1] ~= old and old.destroyed)
		assert(list[1]:GetAttribute("VisualState") == 2)
		e.data[p].Kingdom.VisualState = 1
		assert(s:Refresh(p) and #e.kingdoms(p) == 1 and e.kingdoms(p)[1]:GetAttribute("VisualState") == 1)
	end)

	test("repeated refresh of the same state keeps the instance", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		local kingdom = e.kingdoms(p)[1]
		for _ = 1, 3 do assert(s:Refresh(p) == true) end
		assert(#e.kingdoms(p) == 1 and e.kingdoms(p)[1] == kingdom and kingdom.moves == 1)
	end)

	test("player left: refresh and stale notification do nothing", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local plot = e.plotModel(1)
		e.load(p, 1)
		e.assign(p, plot)
		local kingdom = e.kingdoms(p)[1]
		e.leave(p)
		assert(kingdom.destroyed, "kingdom destroyed with Runtime")
		assert(s:Refresh(p) == false)
		e.callbacks[1](p, plot) -- ancienne notification livrée après le départ
		assert(#plot:GetChildren() == 2, "only permanent scenery left: " .. #plot:GetChildren())
	end)

	test("Runtime destroyed before refresh: nothing parented to it", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		local plot = e.plotModel(1)
		e.assign(p, plot)
		local runtime = e.runtimes[p]
		runtime:Destroy()
		e.data[p].Kingdom.VisualState = 2
		assert(s:Refresh(p) == false and s:GetKingdom(p) == nil)
		assert(#runtime:GetChildren() == 0)
	end)

	test("plot reassigned to another player gets a fresh kingdom", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local plot = e.plotModel(1)
		e.load(a, 2)
		e.assign(a, plot)
		local old = e.kingdoms(a)[1]
		e.leave(a)
		e.load(b, 1)
		e.assign(b, plot)
		local list = e.kingdoms(b)
		assert(#list == 1 and list[1] ~= old and old.destroyed and list[1]:GetAttribute("VisualState") == 1)
		assert(s:GetKingdom(a) == nil)
	end)

	test("missing states folder: warning, no crash", function()
		local e = fixture()
		local s = e.start()
		e.states:Destroy()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		assert(#e.kingdoms(p) == 0 and s:Refresh(p) == false and #e.warnings >= 1)
	end)

	test("missing plot anchor: warning, no kingdom", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local plot = e.plotModel(1)
		plot:FindFirstChild("Royaume"):Destroy()
		e.load(p, 1)
		e.assign(p, plot)
		assert(#e.kingdoms(p) == 0 and s:Refresh(p) == false and #e.warnings >= 1)
	end)

	test("invalid or unknown VisualState keeps the current kingdom", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		local kingdom = e.kingdoms(p)[1]
		for _, bad in { 0, -1, 1.5, "2", 99 } :: { any } do
			local before = #e.warnings
			e.data[p].Kingdom.VisualState = bad
			assert(s:Refresh(p) == false, "refused " .. tostring(bad))
			assert(#e.warnings == before + 1, "one warning for " .. tostring(bad))
			assert(#e.kingdoms(p) == 1 and e.kingdoms(p)[1] == kingdom and not kingdom.destroyed)
		end
	end)

	test("invalid assets keep the current kingdom", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		local kingdom = e.kingdoms(p)[1]
		local function expectRefused(label: string)
			assert(s:Refresh(p) == false, label)
			assert(#e.kingdoms(p) == 1 and e.kingdoms(p)[1] == kingdom and not kingdom.destroyed, label)
		end
		e.new("Folder", "PasUnModele", e.states, { VisualState = 3 })
		e.data[p].Kingdom.VisualState = 3
		expectRefused("not a Model")
		e.state(2, 1)
		e.data[p].Kingdom.VisualState = 2
		expectRefused("duplicate VisualState")
		local e2 = fixture()
		local s2 = e2.start()
		local q = e2.player("B")
		e2.load(q, 1)
		e2.assign(q, e2.plotModel(1))
		local first = e2.kingdoms(q)[1]
		for _, child in e2.states:GetChildren() do
			if child:GetAttribute("VisualState") == 2 then child.Archivable = false end
		end
		e2.data[q].Kingdom.VisualState = 2
		assert(s2:Refresh(q) == false and #e2.kingdoms(q) == 1 and e2.kingdoms(q)[1] == first, "not archivable")
	end)

	test("several players: independent kingdoms, changing A never touches B", function()
		local e = fixture()
		local s = e.start()
		local a, b, c = e.player("A"), e.player("B"), e.player("C")
		e.load(a, 1)
		e.load(b, 1)
		e.load(c, 2)
		e.assign(a, e.plotModel(1))
		e.assign(b, e.plotModel(2))
		e.assign(c, e.plotModel(3))
		local kb, kc = e.kingdoms(b)[1], e.kingdoms(c)[1]
		assert(kb ~= e.kingdoms(a)[1] and kb.pivot.Position == vector(200, 5, 0))
		e.data[a].Kingdom.VisualState = 2
		assert(s:Refresh(a))
		assert(e.kingdoms(b)[1] == kb and kb.moves == 1 and not kb.destroyed and kb:GetAttribute("VisualState") == 1)
		assert(e.kingdoms(c)[1] == kc and kc.moves == 1)
		assert(e.kingdoms(a)[1].pivot.Position == vector(100, 5, 0))
		e.leave(a)
		assert(not kb.destroyed and not kc.destroyed)
	end)

	test("rejoin builds a new clean instance", function()
		local e = fixture()
		e.start()
		local a = e.player("A")
		local plot = e.plotModel(1)
		e.load(a, 1, { h1 = { HeroId = "Chevalier", Level = 1 } })
		e.assign(a, plot)
		local oldKingdom, oldHero = e.kingdoms(a)[1], e.heroes(a).h1
		e.leave(a)
		e.load(a, 1, { h1 = { HeroId = "Chevalier", Level = 1 } })
		e.assign(a, plot)
		local list = e.kingdoms(a)
		assert(#list == 1 and list[1] ~= oldKingdom and oldKingdom.destroyed)
		assert(e.heroes(a).h1 ~= oldHero and oldHero.destroyed)
	end)

	test("owned heroes are placed on the markers in stable order", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		e.load(p, 2, { b = { HeroId = "Archere", Level = 3 }, a = { HeroId = "Chevalier", Level = 1 } })
		e.assign(p, e.plotModel(1))
		local heroes = e.heroes(p)
		assert(e.count(heroes) == 2)
		assert(heroes.a:GetAttribute("HeroId") == "Chevalier" and heroes.b:GetAttribute("HeroId") == "Archere")
		assert(heroes.a.Parent == e.runtimes[p]:FindFirstChild("Heroes"))
		-- Repères du royaume cloné : Heros_1 puis Heros_2, malgré leur création dans le désordre.
		assert(heroes.a.pivot.Position == vector(2001, 0, 0) and heroes.b.pivot.Position == vector(2002, 0, 0))
	end)

	test("acquisition order: legacy GUID ids (any case) first, then timestamped H_T ids by date", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		-- Cas réel : starter migré au GUID minuscule, héros invoqués ensuite (horodatés).
		local starter = "H_da438c65-08a1-4019-acf1-43f55de460c5"
		local later = "H_T17916378700001_ffffffff"
		local summoned = "H_T17916378680002_00000000"
		e.load(p, 2, {
			[later] = { HeroId = "Archere", Level = 1 },
			[starter] = { HeroId = "Chevalier", Level = 1 },
			[summoned] = { HeroId = "Archere", Level = 1 },
		})
		e.assign(p, e.plotModel(1))
		local heroes = e.heroes(p)
		assert(heroes[starter].pivot.Position == vector(2001, 0, 0), "legacy starter on Heros_1")
		assert(heroes[summoned].pivot.Position == vector(2002, 0, 0), "first summon on Heros_2")
		assert(heroes[later].pivot.Position == vector(2003, 0, 0), "later summon on Heros_3")
	end)

	test("hero added then refresh, no duplicate across refreshes", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1, { a = { HeroId = "Chevalier", Level = 1 } })
		e.assign(p, e.plotModel(1))
		local first = e.heroes(p).a
		e.data[p].Heroes.c = { HeroId = "Archere", Level = 1 }
		assert(s:Refresh(p))
		assert(s:Refresh(p), "second refresh")
		local heroes = e.heroes(p)
		assert(e.count(heroes) == 2 and heroes.a == first and heroes.c:GetAttribute("HeroId") == "Archere")
	end)

	test("heroes removed, changed, beyond markers, missing asset, moved with the state", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1, {
			a = { HeroId = "Chevalier", Level = 1 },
			b = { HeroId = "Archere", Level = 1 },
			c = { HeroId = "Chevalier", Level = 1 },
		})
		e.assign(p, e.plotModel(1))
		local heroes = e.heroes(p)
		local a, b = heroes.a, heroes.b
		e.data[p].Heroes.b = nil
		e.data[p].Heroes.a.HeroId = "Archere"
		assert(s:Refresh(p))
		heroes = e.heroes(p)
		assert(b.destroyed and a.destroyed and heroes.b == nil and heroes.a:GetAttribute("HeroId") == "Archere")
		-- 5 héros pour 3 repères en état 1 : les 3 premiers sont affichés, avec un avertissement.
		e.data[p].Heroes.d = { HeroId = "Chevalier", Level = 1 }
		e.data[p].Heroes.e = { HeroId = "Chevalier", Level = 1 }
		e.data[p].Heroes.f = { HeroId = "Chevalier", Level = 1 }
		local before = #e.warnings
		assert(s:Refresh(p) == false, "beyond markers is a partial failure")
		heroes = e.heroes(p)
		assert(e.count(heroes) == 3 and heroes.f == nil and #e.warnings > before)
		-- Asset absent pour un HeroId : ce héros est ignoré, les autres restent.
		e.data[p].Heroes.a.HeroId = "Inconnu"
		assert(s:Refresh(p) == false)
		heroes = e.heroes(p)
		assert(heroes.a == nil and heroes.c and heroes.d)
		-- Passage à l'état 2 : les héros restent et suivent les repères du nouveau royaume.
		local keptC = heroes.c
		e.data[p].Kingdom.VisualState = 2
		assert(s:Refresh(p) == false, "hero 'Inconnu' still has no asset")
		heroes = e.heroes(p)
		assert(heroes.c == keptC and keptC.pivot.Position.X > 2000 and e.count(heroes) == 4)
		e.data[p].Heroes.a = nil
		assert(s:Refresh(p) == true, "every owned hero is displayed again")
	end)

	test("Refresh is true only when the kingdom and every owned hero are displayed", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.load(p, 1)
		e.assign(p, e.plotModel(1))
		assert(s:Refresh(p) == true, "no hero owned + valid kingdom")
		e.data[p].Heroes.a = { HeroId = "Chevalier", Level = 1 }
		e.data[p].Heroes.b = { HeroId = "Archere", Level = 1 }
		assert(s:Refresh(p) == true, "all heroes valid")
		local kingdom, a, b = e.kingdoms(p)[1], e.heroes(p).a, e.heroes(p).b

		-- 2 héros possédés, 1 sans asset : l'autre reste affiché, le royaume aussi, résultat false.
		e.data[p].Heroes.b.HeroId = "SansAsset"
		assert(s:Refresh(p) == false, "hero without asset")
		assert(e.heroes(p).a == a and not a.destroyed and e.heroes(p).b == nil and b.destroyed)
		assert(e.kingdoms(p)[1] == kingdom and not kingdom.destroyed, "valid kingdom kept on partial failure")
		e.data[p].Heroes.b = nil

		-- 4 héros pour 3 repères : les 3 premiers restent affichés, résultat false.
		e.data[p].Heroes.c = { HeroId = "Archere", Level = 1 }
		e.data[p].Heroes.d = { HeroId = "Archere", Level = 1 }
		e.data[p].Heroes.e = { HeroId = "Archere", Level = 1 }
		assert(s:Refresh(p) == false, "heroes beyond markers")
		local shown = e.heroes(p)
		assert(e.count(shown) == 3 and shown.a == a and shown.e == nil)
		assert(e.kingdoms(p)[1] == kingdom and not kingdom.destroyed)

		-- Royaume invalide : toujours false, même avec des héros valides, et rien n'est retiré.
		e.data[p].Heroes.e = nil
		assert(s:Refresh(p) == true)
		e.data[p].Kingdom.VisualState = 99
		assert(s:Refresh(p) == false, "invalid kingdom")
		assert(e.kingdoms(p)[1] == kingdom and e.heroes(p).a == a and e.count(e.heroes(p)) == 3)
	end)

	print(`KingdomService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} KingdomService test(s) failed`)
	end
end
