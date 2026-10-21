--!strict
-- Porte du boss (docs/ZONES.md § Porte du boss) : mise en scène locale de la structure d'où sort le boss.
-- Le décor de zone peut contenir un modèle « PorteBoss » (tools/studio-zones-assets.luau, Zone 4 :
-- la Porte-Fournaise). Avant l'entrée du boss :
--   1. la forge s'allume (pièces à attribut Lueur → couleur LueurAllumee, lumières plus fortes) et les
--      marteaux mécaniques frappent leur enclume (étincelles) ;
--   2. les chaînes se tendent (tremblement, puis les contrepoids remontent) ;
--   3. les battants s'ouvrent lentement vers l'arène, fumée et braises jaillissent de la fournaise ;
-- le boss sort ensuite de l'embrasure (EnemyPresentationController, entrée Walk) ; la porte se referme après.
-- Purement visuel et local à ce client (CFrame, couleurs, émetteurs de pièces ancrées du décor) : aucune règle.
-- Structure attendue (toutes les parties sont facultatives) :
--   Battants/<Model> (pivot : pièce Charniere, attribut Sens = ±1), Chaines/<Model> (Poulie en haut),
--   Marteaux/<Model> (Axe = pivot, Bras = partie mobile), Effets/Foyer (ParticleEmitter Fumee et Braises).

local RunService = game:GetService("RunService")

local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local BossGate = {}

local OPEN_ANGLE = math.rad(100) -- ouverture des battants
local CHAIN_LIFT = 3 -- course des contrepoids (studs)
local HAMMER_STRIKE = 0.78 -- rad : bras levé → tête sur l'enclume
local LIGHT_BOOST = 3 -- facteur de luminosité des lumières des lueurs une fois allumées

type Saved = { part: BasePart, cframe: CFrame }
type Glow = { part: BasePart, color: Color3, lit: Color3, transparency: number, lights: { { light: PointLight, brightness: number } } }
type Rig = {
	leaves: { { hinge: CFrame, sign: number, parts: { Saved } } },
	chains: { { top: number, parts: { Saved } } },
	hammers: { { axis: CFrame, parts: { Saved } } },
	glows: { Glow },
	smoke: ParticleEmitter?,
	sparks: ParticleEmitter?,
	center: Vector3,
	token: number,
}

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

-- appelle step(alpha) pendant `duration` secondes, puis step(1) ; s'arrête (sans step(1)) si alive() devient faux
local function run(duration: number, step: (number) -> (), alive: () -> boolean)
	local start = os.clock()
	while duration > 0 and alive() do
		local a = (os.clock() - start) / duration
		if a >= 1 then
			break
		end
		step(a)
		RunService.Heartbeat:Wait()
	end
	if alive() then
		step(1)
	end
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function saved(root: Instance, skip: string?): { Saved }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= skip then
			table.insert(list, { part = d, cframe = d.CFrame })
		end
	end
	return list
end

local function children(gate: Model, name: string): { Instance }
	local folder = gate:FindFirstChild(name)
	return if folder then folder:GetChildren() else {}
end

local function rigOf(gate: Model): Rig
	local rig = rigs[gate]
	if rig then
		return rig
	end
	local new: Rig = { leaves = {}, chains = {}, hammers = {}, glows = {}, center = gate:GetPivot().Position, token = 0 }
	for _, leaf in children(gate, "Battants") do
		local hinge = leaf:FindFirstChild("Charniere")
		if hinge and hinge:IsA("BasePart") then
			local sign = if leaf:GetAttribute("Sens") == -1 then -1 else 1
			table.insert(new.leaves, { hinge = hinge.CFrame, sign = sign, parts = saved(leaf, "Charniere") })
		end
	end
	for _, chain in children(gate, "Chaines") do
		local pulley = chain:FindFirstChild("Poulie")
		if pulley and pulley:IsA("BasePart") then
			table.insert(new.chains, { top = pulley.Position.Y, parts = saved(chain, "Poulie") })
		end
	end
	for _, hammer in children(gate, "Marteaux") do
		local axis, arm = hammer:FindFirstChild("Axe"), hammer:FindFirstChild("Bras")
		if axis and axis:IsA("BasePart") and arm then
			table.insert(new.hammers, { axis = axis.CFrame, parts = saved(arm) })
		end
	end
	for _, d in gate:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lueur") == true then
			local lit = d:GetAttribute("LueurAllumee")
			local glow: Glow = {
				part = d,
				color = d.Color,
				lit = if typeof(lit) == "Color3" then lit else d.Color,
				transparency = d.Transparency,
				lights = {},
			}
			for _, l in d:GetChildren() do
				if l:IsA("PointLight") then
					table.insert(glow.lights, { light = l, brightness = l.Brightness })
				end
			end
			table.insert(new.glows, glow)
		end
	end
	local effects = gate:FindFirstChild("Effets")
	local hearth = effects and effects:FindFirstChild("Foyer")
	if hearth then
		new.smoke = hearth:FindFirstChild("Fumee") :: ParticleEmitter?
		new.sparks = hearth:FindFirstChild("Braises") :: ParticleEmitter?
	end
	rigs[gate] = new
	return new
end

------------------------------------------------------------------ poses (alpha 0 = repos, 1 = ouvert / allumé)

local function setLeaves(rig: Rig, a: number)
	for _, leaf in rig.leaves do
		local turn = leaf.hinge * CFrame.Angles(0, leaf.sign * OPEN_ANGLE * a, 0) * leaf.hinge:Inverse()
		for _, s in leaf.parts do
			s.part.CFrame = turn * s.cframe
		end
	end
end

local function setChains(rig: Rig, lift: number, jitter: number)
	for _, chain in rig.chains do
		local offset = Vector3.new(math.sin(os.clock() * 60) * jitter, lift, 0)
		for _, s in chain.parts do
			s.part.CFrame = s.cframe + offset
			-- les maillons passés au-dessus de la poulie s'enroulent (cachés)
			s.part.LocalTransparencyModifier = if s.cframe.Position.Y + lift > chain.top then 1 else 0
		end
	end
end

local function setHammers(rig: Rig, a: number)
	for _, hammer in rig.hammers do
		local turn = hammer.axis * CFrame.Angles(HAMMER_STRIKE * a, 0, 0) * hammer.axis:Inverse()
		for _, s in hammer.parts do
			s.part.CFrame = turn * s.cframe
		end
	end
end

local function setGlow(rig: Rig, a: number)
	for _, g in rig.glows do
		g.part.Color = g.color:Lerp(g.lit, a)
		g.part.Transparency = g.transparency * (1 - a)
		for _, l in g.lights do
			l.light.Brightness = l.brightness * (1 + (LIGHT_BOOST - 1) * a)
		end
	end
end

local function emit(emitter: ParticleEmitter?, count: number)
	if emitter then
		emitter:Emit(count)
	end
end

------------------------------------------------------------------ API

-- Porte du boss du décor de zone (ou nil : la zone n'en a pas).
function BossGate.find(zone: Instance?): Model?
	local gate = zone and zone:FindFirstChild("PorteBoss", true)
	return if gate and gate:IsA("Model") then gate else nil
end

-- Ouvre la porte en `duration` secondes (bloquant). alive() faux : la mise en scène s'arrête où elle en est.
function BossGate.open(gate: Model, duration: number, alive: () -> boolean)
	local rig = rigOf(gate)
	rig.token += 1
	local token = rig.token
	local live = function(): boolean
		return token == rig.token and gate.Parent ~= nil and alive()
	end
	-- 1. la forge s'allume, les marteaux frappent
	AudioController.Play("Impact", { Position = rig.center, Pitch = 0.45, Volume = 0.6 })
	run(duration * 0.3, function(a)
		setGlow(rig, smooth(a))
		setHammers(rig, if a < 0.7 then smooth(a / 0.7) else 1)
		setChains(rig, 0, 0.08 * a)
	end, live)
	emit(rig.sparks, 25)
	AudioController.Play("Impact", { Position = rig.center, Pitch = 0.8, Volume = 0.7 })
	-- 2 et 3. les chaînes se tendent, les battants s'ouvrent lentement, fumée et braises
	emit(rig.smoke, 30)
	run(duration * 0.7, function(a)
		local e = smooth(a)
		setLeaves(rig, e)
		setChains(rig, CHAIN_LIFT * e, 0.06 * (1 - a))
		setHammers(rig, 1 - smooth(math.min(a * 2, 1)))
		if a > 0.4 and a < 0.45 then
			emit(rig.sparks, 2)
		end
	end, live)
	emit(rig.smoke, 20)
	emit(rig.sparks, 30)
end

-- Referme la porte et éteint la forge (non bloquant). Sans effet si une nouvelle ouverture a commencé.
function BossGate.close(gate: Model, duration: number)
	local rig = rigOf(gate)
	rig.token += 1
	local token = rig.token
	task.spawn(function()
		run(duration, function(a)
			local e = 1 - smooth(a)
			setLeaves(rig, e)
			setChains(rig, CHAIN_LIFT * e, 0)
			setGlow(rig, e)
		end, function(): boolean
			return token == rig.token and gate.Parent ~= nil
		end)
	end)
end

-- Remet la porte au repos immédiatement (intro annulée, changement de zone).
function BossGate.reset(gate: Model)
	local rig = rigOf(gate)
	rig.token += 1
	setLeaves(rig, 0)
	setChains(rig, 0, 0)
	setHammers(rig, 0)
	setGlow(rig, 0)
end

return BossGate
