-- À exécuter dans Studio EDIT (Rojo connecté), place « test ». Assets uniquement, aucun Source de script.
-- Base du rendu des icônes PNG (docs/UI_DESIGN_SYSTEM.md § 7, « Produire et livrer une icône PNG ») :
-- 1. Si Workspace.AtelierIcones n'existe pas : le crée au-dessus du Bestiaire, avec le modèle provisoire
--    d'Icons.lua de chaque icône d'IconConfig (sans la silhouette Ink, le contour se cuit dans le PNG),
--    agrandi, en rangée. Une seule étape ChangeHistoryService (Ctrl+Z). Ne remplace jamais un atelier
--    existant (les modèles retravaillés y restent).
-- 2. Imprime l'état de chaque icône (PNG livré ou modèle provisoire) et l'objet à rendre.
-- Correspondance IconConfig ↔ modèles d'Icons.lua : node tests/icons.test.mjs.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local IconConfig = require(ReplicatedStorage.Shared.Config.IconConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(StarterPlayer.StarterPlayerScripts.Client.UI.Icons)

local SCALE = 4 -- un modèle d'icône fait ~2,5 studs : agrandi pour le travail et le rendu
local STEP = 14 -- studs entre deux icônes
local LIFT = 12 -- studs au-dessus du Bestiaire

local function build(): Model
	local _, size = workspace.Bestiaire:GetBoundingBox()
	local origin = workspace.Bestiaire:GetPivot() * CFrame.new(0, size.Y / 2 + LIFT, 0)
	local atelier = Instance.new("Model")
	atelier.Name = "AtelierIcones"
	atelier:SetAttribute("Source", "src/shared/Config/IconConfig.lua")
	for index, info in IconConfig.Ordered do
		local model = Icons.model(info.Id)
		model.Name = info.Id
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Color == UITheme.Stroke.Color then
				part:Destroy() -- silhouette Ink du ViewportFrame
			end
		end
		model:SetAttribute("IconId", info.Id)
		model:ScaleTo(SCALE)
		model:PivotTo(origin * CFrame.new((index - (#IconConfig.Ordered + 1) / 2) * STEP, 0, 0))
		model.Parent = atelier
	end
	return atelier
end

if workspace:FindFirstChild("AtelierIcones") then
	print("AtelierIcones existe déjà : rien n'est recréé.")
else
	local recording = ChangeHistoryService:TryBeginRecording("AtelierIcones")
	local atelier = build()
	atelier.Parent = workspace
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print(`AtelierIcones créé : {#atelier:GetChildren()} modèles.`)
end

local missing = 0
for _, info in IconConfig.Ordered do
	local state = if info.Image then `PNG {info.Image}` else "modèle provisoire (PNG à produire)"
	print(`{info.Id} ({info.Group}) : {state} — {info.Hook}`)
	if info.Image == nil then
		missing += 1
	end
end
print(`{#IconConfig.Ordered - missing}/{#IconConfig.Ordered} icônes livrées en PNG.`)
