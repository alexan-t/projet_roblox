--!strict
-- Peint la rareté sur les 100 cartes de la vitrine Équipement (Studio EDIT), selon la décision du
-- 16 octobre (docs/ITEMS.md § 2 de la PR #61, arbitrée le 18 octobre) :
--   - zone d'illustration teintée de la couleur de rareté à RarityTint (0,6) ;
--   - contour de cette zone dans la couleur de rareté, Stroke.Regular (prisme pour Transcendant) ;
--   - cadre extérieur inchangé (Ink), icône jamais teintée.
-- Le libellé de la rangée (« Légendaire (18) »…) porte le nom de la rareté : la couleur n'est pas seule.
-- Valeurs recopiées de src/shared/Config/UITheme.lua (Rarity, RarityPrism, Stroke.Regular) : la copie
-- de UITheme dans Studio peut être en retard sur Git. Relancer après une mise à jour de ces valeurs.
-- Idempotent ; les valeurs d'origine de la zone sont gardées en attributs (FondOrigine…) ; une seule
-- étape d'annulation (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- UITheme.Rarity (clés = RarityConfig.Id) et libellés RarityConfig.Name (attribut « Rarete »).
local RARITY: { [string]: Color3 } = {
	["Commun"] = hex("#B9B0A3"),
	["Peu commun"] = hex("#6CC04A"),
	["Rare"] = hex("#46A2EC"),
	["Épique"] = hex("#A45BE0"),
	["Légendaire"] = hex("#F5C542"),
	["Mythique"] = hex("#FF5A8A"),
	["Maudit"] = hex("#7B2FA8"),
	["Suprême"] = hex("#EAF3FF"),
	["Calamité"] = hex("#D2321E"),
	["Transcendant"] = hex("#7FF7E8"), -- teinte de repli, le prisme est sur le contour
}
local PRISM = { hex("#FF7A7A"), hex("#FFD36B"), hex("#7FF7A0"), hex("#7FF7E8"), hex("#8FA8FF"), hex("#E08CFF") }
local RARITY_TINT = 0.6 -- Transparency.RarityTint
local STROKE_REGULAR = 3 -- UITheme.Stroke.Regular

local slots = workspace.Bestiaire.Inventaire.Equipement.Panneau.Affichage.Fond.Emplacements

local recording = ChangeHistoryService:TryBeginRecording("Vitrine Équipement : couleurs de rareté")
local painted, problems = 0, {}
for _, card in slots:GetChildren() do
	if not card.Name:match("^Item_%d+$") then
		continue
	end
	local rarity = card:GetAttribute("Rarete")
	local color = RARITY[rarity :: any]
	local art = card:FindFirstChild("Illustration")
	if not color or not (art and art:IsA("GuiObject")) then
		table.insert(problems, `{card.Name} ({tostring(rarity)})`)
		continue
	end
	if art:GetAttribute("FondOrigine") == nil then
		art:SetAttribute("FondOrigine", art.BackgroundColor3)
		art:SetAttribute("TransparenceOrigine", art.BackgroundTransparency)
	end
	art.BackgroundColor3 = color
	art.BackgroundTransparency = RARITY_TINT

	local stroke = art:FindFirstChild("Rarete") :: UIStroke?
	if not stroke then
		local new = Instance.new("UIStroke")
		new.Name = "Rarete"
		new.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		new.Parent = art
		stroke = new
	end
	assert(stroke)
	stroke.Thickness = STROKE_REGULAR
	local gradient = stroke:FindFirstChildWhichIsA("UIGradient")
	if rarity == "Transcendant" then
		stroke.Color = Color3.new(1, 1, 1)
		if not gradient then
			gradient = Instance.new("UIGradient")
			gradient.Parent = stroke
		end
		local keys = {}
		for i, c in PRISM do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#PRISM - 1), c))
		end
		gradient.Color = ColorSequence.new(keys)
		gradient.Rotation = 45 -- figé dans la vitrine ; en jeu, RarityStyle.prism le fait tourner
	else
		stroke.Color = color
		if gradient then
			gradient:Destroy()
		end
	end
	painted += 1
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(`Vitrine Équipement : {painted} cartes peintes`)
if #problems > 0 then
	warn("Rareté inconnue ou carte incomplète : " .. table.concat(problems, ", "))
end
