--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Doubles limités au cycle de vie ; la physique doit être validée dans Studio.

return function(createService: any)
	local function fixture(count: number): any
		local env: any = { queue = {}, waiting = {}, instances = {}, ready = {}, callbacks = {}, warnings = {}, now = 0 }
		local function defer(fn: any, ...: any)
			table.insert(env.queue, { thread = coroutine.create(fn), args = table.pack(...) })
		end
		function env.step()
			local item = table.remove(env.queue, 1)
			assert(item, "Empty scheduler")
			local ok, result = coroutine.resume(item.thread, table.unpack(item.args, 1, item.args.n))
			assert(ok, tostring(result))
			if coroutine.status(item.thread) ~= "dead" then
				if result == "frame" then
					env.now += 1 / 60
					table.insert(env.queue, { thread = item.thread, args = table.pack(1 / 60) })
				else
					table.insert(env.waiting, item)
				end
			end
		end
		function env.flush()
			local steps = 0
			while #env.queue > 0 do
				steps += 1
				assert(steps < 10000, "Unbounded scheduler wait")
				env.step()
			end
		end
		function env.wake()
			for _, item in env.waiting do
				table.insert(env.queue, { thread = item.thread, args = table.pack() })
			end
			env.waiting = {}
			env.flush()
		end
		local function signal(): any
			local event: any = { listeners = {} }
			function event:Connect(fn: any): any
				local connection: any = { Connected = true, callback = fn }
				function connection:Disconnect() self.Connected = false end
				table.insert(self.listeners, connection)
				return connection
			end
			function event:Fire(...: any)
				for _, connection in self.listeners do
					if connection.Connected then
						local args = table.pack(...)
						defer(function()
							-- Disconnect annule aussi les invocations moteur en attente.
							if connection.Connected then connection.callback(table.unpack(args, 1, args.n)) end
						end)
					end
				end
			end
			return event
		end
		local methods: any = {}
		function methods:IsA(class: string): boolean
			return self.ClassName == class or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
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
		function methods:WaitForChild(name: string, _timeout: number): any
			local child = self:FindFirstChild(name)
			if child then return child end
			coroutine.yield()
			return self:FindFirstChild(name)
		end
		function methods:IsDescendantOf(parent: any): boolean
			local node = self.Parent
			while node do
				if node == parent then return true end
				node = node.Parent
			end
			return false
		end
		function methods:GetFullName(): string return self.Name end
		function methods:GetAttribute(name: string): any return self.attributes[name] end
		function methods:GetAttributeChangedSignal(name: string): any
			if not self.signals[name] then self.signals[name] = signal() end
			return self.signals[name]
		end
		function methods:SetAttribute(name: string, value: any)
			local changed = self.attributes[name] ~= value
			self.attributes[name] = value
			if changed and self.signals[name] then self.signals[name]:Fire() end
		end
		function methods:Destroy()
			for _, child in self:GetChildren() do child:Destroy() end
			self.Parent = nil
			self.destroyed = true
		end
		function methods.PivotTo(self: any, cf: any)
			self.pivot = cf
			self.moves = (self.moves or 0) + 1
		end
		function methods:Kick(message: string) self.kicked = message end
		function env.new(class: string, name: string?, parent: any): any
			local instance: any = setmetatable({ ClassName = class, Name = name or class,
				Parent = parent, attributes = {}, signals = {}, Anchored = true }, { __index = methods })
			if class == "BindableEvent" then
				instance.Event = signal()
				function instance:Fire(...: any)
					local args = table.pack(...)
					for index = 1, args.n do
						local value = args[index]
						-- Roblox copie les tables transmises ; les Instances gardent leur identité.
						-- Une copie du premier niveau suffit pour détecter une comparaison de référence.
						if type(value) == "table" and getmetatable(value) == nil then
							args[index] = table.clone(value)
						end
					end
					self.Event:Fire(table.unpack(args, 1, args.n))
				end
			end
			table.insert(env.instances, instance)
			return instance
		end
		local cfMeta: any = {}
		local function cf(x: number, y: number, z: number): any
			return setmetatable({ x = x, y = y, z = z }, cfMeta)
		end
		cfMeta.__mul = function(a: any, b: any): any return cf(a.x + b.x, a.y + b.y, a.z + b.z) end
		env.CFrame = { new = cf }
		env.Vector3 = { zero = {} }
		env.Instance = { new = function(class: string): any return env.new(class, nil, nil) end }
		env.task = { defer = defer, spawn = defer, wait = function(): number
			return coroutine.yield("frame")
		end }
		env.os = { clock = function(): number return env.now end }
		env.players = env.new("Players", "Players", nil)
		env.players.PlayerRemoving = signal()
		env.workspace = env.new("Workspace", "Workspace", nil)
		env.folder = env.new("Folder", "Plots", env.workspace)
		env.data = {}
		function env.data:GetData(player: any): any return env.ready[player] end
		function env.data:OnPlayerReady(callback: any)
			table.insert(env.callbacks, callback)
			for player in env.ready do defer(callback, player, env.ready[player]) end
		end
		local log = { debug = function() end, warn = function(_scope: string, message: string)
			table.insert(env.warnings, message)
		end }
		local replicated = { Shared = { Utils = { Log = log } } }
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, Workspace = env.workspace, ReplicatedStorage = replicated })[name]
		end }
		env.script = { Parent = { DataService = env.data } }
		env.require = function(module: any): any return module end
		function env.plot(id: any): any
			local plot = env.new("Model", "Plot_" .. tostring(id), env.folder)
			plot:SetAttribute("PlotId", id)
			local spawn = env.new("Part", "Spawn", plot)
			spawn.CFrame = cf(if typeof(id) == "number" then id * 100 else 0, 0, 0)
			return plot
		end
		for id = count, 1, -1 do env.plot(id) end -- Découverte volontairement non triée.
		function env.player(id: number): any
			local player = env.new("Player", "Player_" .. id, env.players)
			player.UserId = id
			player.CharacterAdded = signal()
			return player
		end
		function env.character(player: any, withRoot: boolean): any
			local character = env.new("Model", "Character", env.workspace)
			if withRoot then env.new("Part", "HumanoidRootPart", character) end
			player.Character = character
			player.CharacterAdded:Fire(character)
			return character
		end
		function env.load(player: any)
			env.ready[player] = { Kingdom = { VisualState = 2 } }
			player:SetAttribute("DataLoaded", true)
			for _, callback in env.callbacks do defer(callback, player, env.ready[player]) end
		end
		function env.leave(player: any)
			env.players.PlayerRemoving:Fire(player)
			player.Parent = nil
			env.ready[player] = nil
			env.flush()
		end
		function env.start(): any
			env.service = createService(env)
			env.service:Init()
			env.service:Start()
			env.flush()
			return env.service
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

	for _, capacity in { 8, 12 } do
		test(`{capacity} distinct plots, deterministic order, overflow`, function()
			local e = fixture(capacity)
			local s = e.start()
			local seen = {}
			for id = 1, capacity do
				local p = e.player(id)
				e.load(p)
				e.flush()
				local plot = s:GetPlot(p)
				assert(plot and not seen[plot])
				seen[plot] = true
				assert(p:GetAttribute("PlotId") == id and s:GetOwner(plot) == p)
				assert(plot:GetAttribute("OwnerUserId") == p.UserId)
			end
			local extra = e.player(99)
			e.load(extra)
			e.flush()
			assert(extra.kicked and not s:GetPlot(extra) and not s:GetRuntime(extra))
		end)
	end
	test("ready replay, duplicate callback, data unchanged", function()
		local e = fixture(2)
		local p = e.player(1)
		e.load(p)
		local data = e.ready[p]
		local s = e.start()
		local runtime = s:GetRuntime(p)
		e.callbacks[1](p)
		assert(s:GetRuntime(p) == runtime and p:GetAttribute("PlotId") == 1)
		assert(e.ready[p] == data and data.Kingdom.VisualState == 2 and data.PlotId == nil)
	end)
	test("leave clears runtime and ownership, preserves scenery, reuses plot", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		local plot, runtime = s:GetPlot(p), s:GetRuntime(p)
		local scenery = e.new("Model", "Scenery", plot)
		local kingdom = e.new("Model", "Kingdom", runtime)
		e.leave(p)
		assert(runtime.destroyed and kingdom.destroyed and not scenery.destroyed)
		assert(not plot:GetAttribute("OwnerUserId") and not p:GetAttribute("PlotId"))
		assert(not s:GetPlot(p) and not s:GetOwner(plot) and not s:GetRuntime(p))
		assert(not p.CharacterAdded.listeners[1].Connected)
		local nextPlayer = e.player(2)
		e.load(nextPlayer)
		e.flush()
		assert(s:GetPlot(nextPlayer) == plot and s:GetRuntime(nextPlayer) ~= runtime)
		e.leave(p) -- Une deuxième libération ne touche pas le nouveau propriétaire.
		assert(s:GetOwner(plot) == nextPlayer)
	end)
	test("existing character, respawn and return from expedition", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		local first = e.character(p, true)
		e.load(p)
		e.flush()
		assert(first.moves == 1 and first.pivot.x == 100 and first.pivot.y == 4)
		local second = e.character(p, true)
		e.flush()
		assert(second.moves == 1 and first.moves == 1)
		assert(s:TeleportToPlot(p) and second.moves == 2)
		assert(second:FindFirstChild("HumanoidRootPart").AssemblyLinearVelocity == e.Vector3.zero)
	end)
	test("delayed root cannot teleport departed player onto reused plot", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		local char = e.character(p, false)
		e.load(p)
		e.flush()
		assert(#e.waiting == 1)
		e.leave(p)
		local nextPlayer = e.player(2)
		e.load(nextPlayer)
		e.flush()
		e.new("Part", "HumanoidRootPart", char)
		e.wake()
		assert(not char.moves and s:GetPlot(nextPlayer))
	end)
	test("stale respawn and missing root timeout", function()
		local e = fixture(1)
		e.start()
		local p = e.player(1)
		local old = e.character(p, false)
		e.load(p)
		e.flush()
		local current = e.character(p, true)
		e.flush()
		e.new("Part", "HumanoidRootPart", old)
		e.wake()
		assert(not old.moves and current.moves == 1)
		local missing = e.character(p, false)
		e.flush()
		e.wake() -- Simule l'expiration du timeout sans root.
		assert(not missing.moves and #e.waiting == 0)
	end)
	test("session loss releases plot before PlayerRemoving", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		local runtime = s:GetRuntime(p)
		e.ready[p] = nil
		p:SetAttribute("DataLoaded", nil)
		e.flush()
		assert(not s:GetPlot(p) and runtime.destroyed)
		e.leave(p)
	end)
	test("unready and departed players never reserve a plot", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.callbacks[1](p)
		assert(not s:GetPlot(p) and not p.kicked and not s:TeleportToPlot(p))
		e.load(p)
		e.leave(p) -- Départ avant le callback différé de DataService.
		assert(not s:GetPlot(p))
	end)
	test("invalid assets rejected without deleting authored content", function()
		local e = fixture(0)
		e.plot(1)
		e.plot(1)
		e.plot(-1)
		e.plot(0)
		e.plot(1.5)
		e.plot(math.huge)
		e.plot(-math.huge)
		e.plot(0 / 0)
		e.plot("2")
		e.plot(false)
		e.plot(nil)
		e.plot(3):FindFirstChild("Spawn"):Destroy()
		e.plot(4):FindFirstChild("Spawn").Anchored = false
		local authored = e.plot(5)
		local runtime = e.new("Folder", "Runtime", authored)
		e.plot(6):FindFirstChild("Spawn").ClassName = "SpawnLocation"
		e.plot(8):FindFirstChild("Spawn").ClassName = "Folder"
		e.new("Part", "NotAPlotModel", e.folder):SetAttribute("PlotId", 9)
		local valid = e.plot(7)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(s:GetPlot(p) == valid and not runtime.destroyed)
		assert(#e.warnings >= 12)
	end)
	test("missing folder fails clearly without blocking service startup", function()
		local e = fixture(0)
		e.folder:Destroy()
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(p.kicked and not s:GetPlot(p) and #e.warnings == 2)
	end)
	test("assignment listeners receive new and existing owners, disconnect replay", function()
		local e = fixture(2)
		local s = e.start()
		local calls = 0
		local connection = s:OnPlotAssigned(function() calls += 1 end)
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(calls == 1)
		connection:Disconnect()
		s:OnPlotAssigned(function(player: any, plot: any)
			assert(player == p and plot == s:GetPlot(p))
			calls += 1
		end)
		e.flush()
		assert(calls == 2)
		local cancelled = s:OnPlotAssigned(function() error("Disconnected replay fired") end)
		cancelled:Disconnect()
		e.flush()
	end)
	test("queued callbacks ignore departed owners", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		e.players.PlayerRemoving:Fire(p)
		s:OnPlotAssigned(function() error("Stale owner reported") end)
		e.flush()
	end)
	for _, capacity in { 8, 12 } do
		test(`{capacity} concurrent ready callbacks reserve before character waits`, function()
			local e = fixture(capacity)
			local s = e.start()
			local players = {}
			for id = 1, capacity + 1 do
				local p = e.player(id)
				e.character(p, false)
				table.insert(players, p)
				e.load(p)
			end
			e.flush()
			local seen = {}
			for id = 1, capacity do
				local plot = s:GetPlot(players[id])
				assert(plot and not seen[plot] and players[id]:GetAttribute("PlotId") == id)
				seen[plot] = true
			end
			assert(players[capacity + 1].kicked and #e.waiting == capacity)
		end)
	end
	test("replay ahead of removal handler does not report departed player", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		s:OnPlotAssigned(function() error("Departed player reported before release") end)
		e.leave(p) -- Notification dans la queue AVANT PlayerRemoving.
	end)
	test("live notification ahead of removal handler ignores departed player", function()
		local e = fixture(1)
		local s = e.start()
		s:OnPlotAssigned(function() error("Departed player reported by event") end)
		local p = e.player(1)
		e.load(p)
		e.step() -- L'attribution déclenche l'événement, sans livrer son callback.
		e.leave(p)
	end)
	test("data loss blocks notifications and teleport before deferred release", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		local char = e.character(p, true)
		e.load(p)
		e.flush()
		s:OnPlotAssigned(function() error("Unready player reported before release") end)
		p:SetAttribute("DataLoaded", nil)
		assert(not s:TeleportToPlot(p), "Teleport after DataLoaded loss")
		assert(not s:GetPlot(p) and not s:GetRuntime(p))
		e.flush()
		assert(char.moves == 1)
	end)
	test("profile loss blocks notifications even while DataLoaded is stale", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		s:OnPlotAssigned(function() error("Inactive profile reported") end)
		e.ready[p] = nil
		e.flush()
	end)
	test("ready callback requires DataLoaded as well as profile", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		p:SetAttribute("DataLoaded", false)
		e.flush()
		assert(not s:GetPlot(p) and not p:GetAttribute("PlotId"))
	end)
	test("CharacterAdded before parenting waits for Workspace and default spawn", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		local char = e.character(p, true)
		char.Parent = nil
		e.step() -- CharacterAdded programme la téléportation.
		e.task.defer(function()
			char.Parent = e.workspace
			char:PivotTo(e.CFrame.new(999, 0, 0)) -- Spawn moteur.
		end)
		e.flush()
		assert(char.pivot.x == 100 and s:GetPlot(p))
	end)
	test("character never parented has a bounded wait", function()
		local e = fixture(1)
		e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		local char = e.character(p, true)
		char.Parent = nil
		e.flush()
		assert(not char.moves and #e.queue == 0 and #e.waiting == 0)
	end)
	local invalidations = {
		{ name = "deleted model", mutate = function(_e: any, plot: any) plot:Destroy() end },
		{ name = "deleted spawn", mutate = function(_e: any, plot: any) plot:FindFirstChild("Spawn"):Destroy() end },
		{ name = "unanchored spawn", mutate = function(_e: any, plot: any) plot:FindFirstChild("Spawn").Anchored = false end },
		{ name = "renamed spawn", mutate = function(_e: any, plot: any) plot:FindFirstChild("Spawn").Name = "OldSpawn" end },
		{ name = "moved model", mutate = function(e: any, plot: any) plot.Parent = e.workspace end },
		{ name = "detached folder", mutate = function(e: any, _plot: any) e.folder.Parent = nil end },
		{ name = "changed id", mutate = function(_e: any, plot: any) plot:SetAttribute("PlotId", 99) end },
		{ name = "deleted runtime", mutate = function(_e: any, plot: any) plot:FindFirstChild("Runtime"):Destroy() end },
	}
	for _, invalidation in invalidations do
		test("assigned plot invalidated: " .. invalidation.name, function()
			local e = fixture(1)
			local s = e.start()
			local p = e.player(1)
			e.character(p, true)
			e.load(p)
			e.flush()
			local plot = s:GetPlot(p)
			s:OnPlotAssigned(function() error("Invalid plot reported") end)
			invalidation.mutate(e, plot)
			assert(not s:TeleportToPlot(p), "Teleport to invalid plot")
			assert(not s:GetPlot(p) and not s:GetRuntime(p) and not s:GetOwner(plot), "Invalid assignment exposed")
			e.flush()
			e.leave(p)
			assert(not plot:GetAttribute("OwnerUserId"))
		end)
	end
	test("free plot invalidated after Init is skipped", function()
		local e = fixture(2)
		local s = e.start()
		e.folder:FindFirstChild("Plot_1"):FindFirstChild("Spawn").Anchored = false
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(p:GetAttribute("PlotId") == 2 and s:GetPlot(p))
	end)
	test("Runtime added after Init is preserved and skipped", function()
		local e = fixture(2)
		local s = e.start()
		local runtime = e.new("Folder", "Runtime", e.folder:FindFirstChild("Plot_1"))
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(p:GetAttribute("PlotId") == 2 and not runtime.destroyed and s:GetPlot(p))
	end)
	test("old replay cannot report a new assignment of the same model", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		local previousRuntime = s:GetRuntime(p)
		p:SetAttribute("DataLoaded", nil)
		local calls = 0
		s:OnPlotAssigned(function() calls += 1 end) -- Capture l'ancienne attribution.
		e.step() -- Libération, avant livraison du replay.
		e.load(p)
		e.callbacks[1](p) -- Callback prêt immédiat, comme task.spawn dans DataService.
		e.flush()
		assert(calls == 1 and previousRuntime.destroyed and s:GetRuntime(p) ~= previousRuntime)
	end)
	test("leave during spawn settling cannot move old character after reuse", function()
		local e = fixture(1)
		local s = e.start()
		local p = e.player(1)
		local char = e.character(p, true)
		e.load(p)
		e.step() -- Attribution.
		e.step() -- Téléportation suspendue pour laisser finir le spawn moteur.
		assert(not char.moves)
		e.leave(p)
		local nextPlayer = e.player(2)
		e.load(nextPlayer)
		e.flush()
		assert(not char.moves and s:GetPlot(nextPlayer))
	end)
	test("invalid Workspace.Plots class refuses allocation", function()
		local e = fixture(1)
		e.folder.ClassName = "Model"
		local s = e.start()
		local p = e.player(1)
		e.load(p)
		e.flush()
		assert(p.kicked and not s:GetPlot(p))
	end)
	assert(failed == 0, `PlotService: {failed} failed, {passed} passed`)
	print(`PlotService: {passed} tests passed`)
end
