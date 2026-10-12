--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai PlayerStateService avec un double de DataService (tools/test-playerstate.ps1).

return function(createService: any)
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

	local function fixture(): any
		local env: any = { data = {} }
		local function inst(className: string): any
			local i: any = { ClassName = className, Name = className, children = {} }
			function i:FindFirstChild(n: string): any
				for _, c in self.children do if c.Name == n then return c end end
				return nil
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
		env.Instance = { new = inst }
		env.game = { GetService = function(_s: any, name: string): any
			assert(name == "ReplicatedStorage", name)
			return replicated
		end }
		local dataService: any = {}
		function dataService:GetData(p: any): any return env.data[p] end
		env.script = { Parent = { DataService = dataService } }
		env.require = function(m: any): any return m end
		function env.player(name: string, currencies: any?): any
			local p: any = { Name = name, attributes = { DataLoaded = true } }
			function p:GetAttribute(k: string): any return self.attributes[k] end
			env.data[p] = {
				DataVersion = 2,
				Currencies = currencies or { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 1, FirstClears = { ["1-1"] = true } },
				Heroes = { H1 = { HeroId = "ecuyer_du_rempart", Level = 1 } },
				Hotbar = {}, Quests = {}, Kingdom = { Level = 1, VisualState = 2 },
			}
			return p
		end
		function env.start(): any
			local s = createService(env)
			s:Start()
			local remotes = replicated:FindFirstChild("Remotes")
			env.get = remotes and remotes:FindFirstChild("GetCurrencies")
			return s
		end
		return env
	end

	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end

	test("GetCurrencies: exactly Gold, Gems, SummonTickets from the server data", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { Gold = 100, Gems = 10, SummonTickets = 1 })
		local view = e.get.OnServerInvoke(p)
		assert(view.Gold == 100 and view.Gems == 10 and view.SummonTickets == 1)
		assert(count(view) == 3, "only the three currencies")
		assert(view.Heroes == nil and view.Quests == nil and view.Progression == nil, "never PlayerData")
	end)

	test("GetCurrencies: a read-only copy (editing it changes nothing), always re-read", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { Gold = 5, Gems = 0, SummonTickets = 1 })
		local view = e.get.OnServerInvoke(p)
		view.SummonTickets = 99
		assert(e.data[p].Currencies.SummonTickets == 1, "copy, not a reference")
		e.data[p].Currencies.SummonTickets = 0 -- ticket consommé par une invocation (serveur)
		assert(e.get.OnServerInvoke(p).SummonTickets == 0, "fresh server value")
		assert(view ~= e.data[p].Currencies)
	end)

	test("GetCurrencies: nil before the data is loaded", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		p.attributes.DataLoaded = nil
		assert(e.get.OnServerInvoke(p) == nil)
		local ghost: any = { Name = "B", GetAttribute = function() return true end }
		assert(e.get.OnServerInvoke(ghost) == nil, "no profile")
	end)

	test("two players: independent currencies", function()
		local e = fixture()
		e.start()
		local a = e.player("A", { Gold = 100, Gems = 10, SummonTickets = 0 })
		local b = e.player("B", { Gold = 0, Gems = 0, SummonTickets = 3 })
		local va, vb = e.get.OnServerInvoke(a), e.get.OnServerInvoke(b)
		assert(va.Gold == 100 and va.SummonTickets == 0 and vb.Gold == 0 and vb.SummonTickets == 3)
	end)

	print(`PlayerStateService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} PlayerStateService test(s) failed`)
	end
end
