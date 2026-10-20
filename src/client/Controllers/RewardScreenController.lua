--!strict
-- Écran de fin de combat et récompenses (présentation, côté client) — issue #17, « Effets Reward Screen ».
-- Suit docs/UI_DESIGN_SYSTEM.md (§ 6 Récompenses, § 8 Animations, § 10 Victoire / Défaite) ; toutes les
-- valeurs de style viennent de UITheme. Ne décide d'aucune récompense : RewardService (#9) les fournit.
-- Déroulé (victoire) :
--   1. voile Ink à Overlay (jamais d'écran noir) ;
--   2. « Victoire ! » (Hero, Gold, contour 4) en pop, rayons dorés lents derrière, étincelles ;
--   3. badge « Première victoire » si FirstClear ;
--   4. cartes de récompense en cascade (pop décalé de 0,05 s), monnaie 3D du pack qui tourne dans la carte
--      (CurrencyFx.Preview, modèles ReplicatedStorage.Assets.Currencies ; nom : CurrencyVisualConfig),
--      quantité qui défile (Count) puis pop de l'icône ; badge « Nouveau » sur une récompense nouvelle ;
--   5. section « Héros » (#68) : chaque héros engagé (portrait, nom, Nv., « +25 XP », barre qui se
--      remplit) ; montée de niveau : « NIVEAU SUPÉRIEUR ! », « Nv.1 → Nv.2 », pop et lueur dorée.
--      Valeurs du serveur (CombatEnded.HeroProgression), jamais calculées ici. Possible même sans carte de
--      récompense (stages sans récompense de stage) ;
--   6. butin (#72, CombatEnded.Loot, JAMAIS mélangé à Rewards) : carte « meilleur objet » (ItemCard, rareté en
--      texte) + « +N équipements », puis une ligne de pastilles de ressources compacte (icône + ×n, cadre neutre,
--      aucune rareté) + « +N autres », puis « Ajoutées à ta Sacoche » ; UN seul son pour tout le butin ;
--      Overflow : message honnête (équipement non ajouté, Sacoche pleine). Aucune ligne si le butin est vide ;
--   7. bouton principal « Continuer » en dernier.
-- Mise en page : la hauteur du contenu est CALCULÉE (Shared.Sacoche.LootModel.layout, mesures UITheme.Pack.Reward)
-- et l'échelle tient compte des DEUX axes de l'écran (LootModel.fit).
-- Défaite : titre Error, sans rayons ni étincelles, sans butin.
-- API : RewardScreenController.Show(data, onContinue?) ; RewardScreenController.Hide().
--   data = { Result: "Victory" | "Defeat", FirstClear: boolean?,
--            Rewards: { { Kind: "Gold" | "Gems" | "SummonTicket", Amount: number, New: boolean? } },
--            Loot: { Items: { { InstanceId, ItemId } }, Resources: { { ResourceId, Amount } }, Overflow: boolean? }?,
--            Heroes: { { InstanceId, HeroId, XPGranted, LevelBefore, LevelAfter, XP, XPToNext, MaxLevel } }? }
-- Démonstration Studio : attribut Workspace.ApercuEcranRecompenses = true (l'écran s'affiche, puis
--   revient 2 s après « Continuer ») ; trois cas se succèdent : ressources seules, équipement + ressources + XP,
--   beaucoup de ressources + Sacoche pleine.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local InventoryModel = require(ReplicatedStorage.Shared.Sacoche.InventoryModel)
local LootModel = require(ReplicatedStorage.Shared.Sacoche.LootModel)
local CurrencyFx = require(script.Parent.Parent.UI.CurrencyFx)
local GuideTargets = require(script.Parent.Parent.UI.GuideTargets)
local Icons = require(script.Parent.Parent.UI.Icons)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local RarityStyle = require(script.Parent.Parent.UI.RarityStyle)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Animation = UITheme.Animation
local Spacing = UITheme.Spacing
local PACK = UITheme.Pack.Reward

local CARD_SIZE = PACK.CardSize
local CASCADE = 0.05 -- décalage entre deux cartes (design system)
local RAY_COUNT = 12
local RAY_LENGTH = 230 -- px, du centre du titre au bout d'un rayon
local SPARKS = 10

export type Reward = { Kind: string, Amount: number, New: boolean? }
-- Silent : le son du résultat a déjà été joué (annonce « VICTOIRE ! » de l'outro de combat).
-- Progression d'un héros engagé (vue serveur, CombatEnded.HeroProgression).
export type HeroProgress = { InstanceId: string, HeroId: string, XPGranted: number, LevelBefore: number, LevelAfter: number, XP: number, XPToNext: number, MaxLevel: number }
-- Loot : CombatEnded.Loot tel que reçu (lu et validé par LootModel.parse, jamais mélangé à Rewards).
export type ScreenData = { Result: string, FirstClear: boolean?, Rewards: { Reward }?, Silent: boolean?, Heroes: { HeroProgress }?, Loot: any? }

local HERO_CHIP = PACK.HeroChip
-- Petits textes de l'écran affiché et leur taille de base : grossis à chaque mise à l'échelle pour rester
-- lisibles (LootModel.textSize, au moins PACK.MinText px réels).
local smallTexts: { { Label: TextLabel, Base: number } } = {}
local function small(label: TextLabel, base: number): TextLabel
	table.insert(smallTexts, { Label = label, Base = base })
	return label
end
local LOOT_CONTEXT: LootModel.Context = {
	Items = ItemConfig.Items,
	Resources = ResourceConfig.Resources,
	RankOf = RarityStyle.rank,
	SlotNames = ItemConfig.SlotTypeNames,
}

local RewardScreenController = {}

local current: ScreenGui? = nil

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UITheme.Stroke.Color
	s.Thickness = thickness
	s.LineJoinMode = UITheme.Stroke.LineJoin
	s.ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Texte Fredoka clair contouré Ink (règle du design system pour tout texte sur fond transparent).
local function label(parent: Instance, text: string, size: number, color: Color3?, strokeSize: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Typography.Display
	l.TextSize = size
	l.TextColor3 = color or Colors.TextLight
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	l.Parent = parent
	if strokeSize then
		stroke(l, strokeSize)
	end
	return l
end

local function popIn(object: GuiObject, delay: number, peak: number?)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = object
	task.delay(delay, function()
		if not scale.Parent then
			return
		end
		local up = tween(scale, TweenInfo.new(Animation.Toast.Time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = peak or Animation.Scale.Pop })
		up.Completed:Wait()
		if scale.Parent then
			tween(scale, TweenInfo.new(Animation.Toast.Time * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		end
	end)
end

local function badge(parent: GuiObject, text: string, color: Color3): Frame
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, 0, 0, 0)
	b.Size = UDim2.fromOffset(84, 24)
	b.BackgroundColor3 = color
	b.ZIndex = 5
	b.Parent = parent
	corner(b, UITheme.Radius.Pill)
	stroke(b, UITheme.Stroke.Thin)
	local l = label(b, text, Typography.Size.Caption, Colors.TextLight, Typography.TextStroke.Small)
	l.ZIndex = 6
	return b
end

local function card(parent: Instance, reward: Reward, index: number, start: number)
	local visual = CurrencyVisualConfig.visual(reward.Kind)
	local frame = Instance.new("Frame")
	frame.Name = "Carte_" .. reward.Kind
	frame.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	frame.BackgroundColor3 = Colors.Cream
	frame.BackgroundTransparency = UITheme.Transparency.PanelStrong
	frame.LayoutOrder = index
	frame.Parent = parent
	corner(frame, UITheme.Radius.Medium)
	local border = stroke(frame, UITheme.Stroke.Regular)
	if reward.New then
		border.Color = Colors.Selected
		border.Thickness = UITheme.Stroke.Thick
	end

	-- grande zone d'illustration (≥ 60 % de la hauteur), sable semi-transparent
	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S + 6)
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.62, 0)
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.PanelStrong
	art.Parent = frame
	corner(art, UITheme.Radius.Small)
	local viewport = CurrencyFx.Preview(reward.Kind, art)

	local name = label(frame, if visual then visual.Label else reward.Kind, Typography.Size.Label, Colors.InkSoft)
	name.Position = UDim2.new(0, Spacing.S, 0.62, Spacing.S + 6)
	name.Size = UDim2.new(1, -2 * Spacing.S, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local amount = label(frame, "×0", Typography.Size.Heading, Colors.TextLight, Typography.TextStroke.Medium)
	amount.AnchorPoint = Vector2.new(1, 1)
	amount.Position = UDim2.new(1, -Spacing.S, 1, -Spacing.XS)
	amount.Size = UDim2.fromOffset(90, 30)
	amount.TextXAlignment = Enum.TextXAlignment.Right

	if reward.New then
		badge(frame, "Nouveau", Colors.RoyalRed)
	end

	local appear = start + (index - 1) * CASCADE
	popIn(frame, appear)
	AudioController.Play("Recompense", { Delay = appear, Pitch = 1 + 0.06 * (index - 1) }) -- carte qui apparaît (#18)
	-- la quantité défile (Count, 0,4 s) une fois la carte posée, puis l'icône fait un pop
	task.delay(appear + Animation.Toast.Time, function()
		if not amount.Parent then
			return
		end
		local counter = Instance.new("NumberValue")
		counter.Changed:Connect(function(value)
			amount.Text = "×" .. tostring(math.floor(value + 0.5))
		end)
		local roll = tween(counter, Animation.Count, { Value = reward.Amount })
		roll.Completed:Connect(function()
			counter:Destroy()
			if viewport.Parent then
				local s = Instance.new("UIScale")
				s.Parent = viewport
				local up = tween(s, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = Animation.Scale.Pop })
				up.Completed:Connect(function()
					tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				end)
			end
		end)
	end)
end

-- Bouton principal « chunky » : face dégradée or + lèvre plus sombre (design system § 6).
local function primaryButton(parent: Instance, text: string, onClick: () -> ()): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Continuer"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(220, 56 + UITheme.Shadow.ButtonLip)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local lip = Instance.new("Frame")
	lip.Position = UDim2.fromOffset(0, UITheme.Shadow.ButtonLip)
	lip.Size = UDim2.new(1, 0, 1, -UITheme.Shadow.ButtonLip)
	lip.BackgroundColor3 = Colors.GoldDeep:Lerp(Colors.Ink, 0.35)
	lip.Parent = holder
	corner(lip, UITheme.Radius.Medium)
	stroke(lip, UITheme.Stroke.Regular)
	local face = Instance.new("TextButton")
	face.AutoButtonColor = false
	face.Text = ""
	face.Size = UDim2.new(1, 0, 1, -UITheme.Shadow.ButtonLip)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = holder
	corner(face, UITheme.Radius.Medium)
	stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Colors.GoldLight, Colors.GoldDeep)
	gradient.Rotation = 90
	gradient.Parent = face
	local l = label(face, text, Typography.Size.Button, Colors.TextLight, Typography.TextStroke.Medium)
	l.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	face.MouseEnter:Connect(function()
		tween(scale, Animation.Hover, { Scale = Animation.Scale.Hover })
	end)
	face.MouseLeave:Connect(function()
		tween(scale, Animation.Hover, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.MouseButton1Down:Connect(function()
		tween(scale, Animation.Press, { Scale = Animation.Scale.Pressed })
		face.Position = UDim2.fromOffset(0, UITheme.Shadow.ButtonLip) -- la face descend sur la lèvre
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
		tween(scale, Animation.Hover, { Scale = 1 })
	end)
	face.Activated:Connect(onClick)
	return holder
end

local function rays(parent: Instance): Frame
	-- Un GuiObject tourne autour de son propre centre : chaque rayon est donc un carré transparent
	-- centré sur le titre, qui porte un faisceau fin partant du centre vers le haut.
	local holder = Instance.new("Frame")
	holder.Name = "Rayons"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(RAY_LENGTH * 2, RAY_LENGTH * 2)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	for i = 1, RAY_COUNT do
		local arm = Instance.new("Frame")
		arm.Size = UDim2.fromScale(1, 1)
		arm.BackgroundTransparency = 1
		arm.Rotation = (i - 1) * 360 / RAY_COUNT
		arm.Parent = holder
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0)
		beam.Position = UDim2.fromScale(0.5, 0)
		beam.Size = UDim2.new(0, if i % 2 == 0 then 22 else 34, 0.5, 0)
		beam.BackgroundColor3 = Colors.GoldLight
		beam.BorderSizePixel = 0
		beam.Parent = arm
		-- plein près du centre, effacé vers l'extérieur ; pas de reflet glossy
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.7),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		fade.Parent = beam
	end
	return holder
end

local function sparkles(parent: Instance, delay: number)
	local random = Random.new()
	for i = 1, SPARKS do
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Rotation = 45
		local size = random:NextInteger(10, 18)
		spark.Size = UDim2.fromOffset(size, size)
		spark.Position = UDim2.new(0.5, random:NextInteger(-230, 230), 0, random:NextInteger(20, 150))
		spark.BackgroundColor3 = if i % 3 == 0 then Colors.TextLight else Colors.GoldLight
		spark.ZIndex = 4
		spark.Parent = parent
		stroke(spark, UITheme.Stroke.Thin)
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = spark
		task.delay(delay + random:NextNumber(0, 0.5), function()
			if not scale.Parent then
				return
			end
			local up = tween(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			up.Completed:Wait()
			task.wait(0.1)
			if scale.Parent then
				tween(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			end
		end)
	end
end

-- Pastille de ressource : icône du catalogue + « ×n », cadre NEUTRE (aucune rareté, aucune couleur de
-- rareté pour une ressource). Sans icône publiée : deux lettres du nom.
local function resourceChip(parent: Instance, resource: LootModel.Resource, order: number): Frame
	local chip = UIKit.subPanel(parent, UDim2.fromOffset(PACK.ChipSize.X, PACK.ChipSize.Y))
	chip.Name = `Ressource_{resource.ResourceId}`
	chip.LayoutOrder = order
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(Spacing.XS + 2, (PACK.ChipSize.Y - PACK.ChipIcon) / 2)
	icon.Size = UDim2.fromOffset(PACK.ChipIcon, PACK.ChipIcon)
	icon.Parent = chip
	if resource.Icon then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = resource.Icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = icon
	else
		UIKit.text(icon, InventoryModel.initials(resource.Name), Typography.Size.Caption, { Color = Colors.TextLight })
	end
	local left = Spacing.XS + 2 + PACK.ChipIcon + Spacing.XS
	local amount = small(UIKit.text(chip, `×{resource.AmountText}`, PACK.ChipAmountSize, { Align = Enum.TextXAlignment.Left }), PACK.ChipAmountSize)
	amount.Name = "Quantite"
	amount.Position = UDim2.fromOffset(left, 0)
	amount.Size = UDim2.new(1, -left - Spacing.XS, 1, 0)
	return chip
end

-- Bloc « butin » (#72) : meilleur objet, ligne de pastilles, légende, message de dépassement. Retourne la durée
-- de l'apparition (s). UN seul son pour tout le bloc.
local function lootBlock(root: Frame, loot: LootModel.Parsed, chips: { Shown: { LootModel.Resource }, More: number }, layout: LootModel.Layout, start: number): number
	local center = layout.Width / 2
	local step = 0
	local function appear(object: GuiObject)
		popIn(object, start + step * CASCADE)
		step += 1
	end
	local best = loot.Best
	if best then
		local head = if loot.MoreItems > 0 then "Meilleur équipement" else "Équipement obtenu"
		local band = ItemCard.create(root, best, {
			Variant = "Band", NameSize = PACK.BandNameSize, LineSize = PACK.BandLineSize, ArtSize = PACK.BandArt,
			Head = head, Size = UDim2.fromOffset(PACK.BandSize.X, PACK.BandSize.Y),
		})
		local texts = band:FindFirstChild("Textes")
		for _, text in if texts then texts:GetChildren() else {} do
			if text:IsA("TextLabel") then
				small(text, text.TextSize) -- mention, nom, ligne : empilés, ils se décalent en grossissant
			end
		end
		band.AnchorPoint = Vector2.new(0.5, 0)
		band.Position = UDim2.fromOffset(center, layout.BandY)
		if loot.MoreItems > 0 then
			local more = small(UIKit.text(band, LootModel.moreItemsText(loot.MoreItems), PACK.BandMoreSize, { Color = Colors.GoldLight, Align = Enum.TextXAlignment.Right }), PACK.BandMoreSize)
			more.Name = "PlusEquipements"
			more.AnchorPoint = Vector2.new(1, 0.5)
			more.Position = UDim2.new(1, -Spacing.M, 0.5, 0)
			more.Size = UDim2.fromOffset(150, 30)
		end
		appear(band)
	end
	if #chips.Shown > 0 or chips.More > 0 then
		local row = Instance.new("Frame")
		row.Name = "Ressources"
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.fromOffset(center, layout.ChipsY)
		row.Size = UDim2.fromOffset(PACK.ChipRowWidth, PACK.ChipSize.Y)
		row.BackgroundTransparency = 1
		row.Parent = root
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, PACK.ChipGap)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		for index, resource in chips.Shown do
			appear(resourceChip(row, resource, index))
		end
		if chips.More > 0 then
			local more = UIKit.subPanel(row, UDim2.fromOffset(PACK.ChipSize.X, PACK.ChipSize.Y))
			more.Name = "PlusRessources"
			more.LayoutOrder = #chips.Shown + 1
			small(UIKit.text(more, LootModel.moreResourcesText(chips.More), PACK.ChipMoreSize, { Color = Colors.TextMuted }), PACK.ChipMoreSize)
			appear(more)
		end
	end
	local gained = best ~= nil or #chips.Shown > 0
	if gained then
		local caption = small(UIKit.text(root, "Ajoutées à ta Sacoche", PACK.CaptionSize, { Color = Colors.TextMuted }), PACK.CaptionSize)
		caption.Name = "Legende"
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.fromOffset(center, layout.CaptionY)
		caption.Size = UDim2.fromOffset(PACK.ChipRowWidth, PACK.CaptionHeight)
		popIn(caption, start + step * CASCADE)
		step += 1
	end
	if loot.Overflow then
		local note = small(UIKit.text(root, "Sacoche pleine : équipement non ajouté", PACK.NoteSize, { Color = Colors.TextMuted }), PACK.NoteSize)
		note.Name = "SacochePleine"
		note.AnchorPoint = Vector2.new(0.5, 0)
		note.Position = UDim2.fromOffset(center, layout.NoteY)
		note.Size = UDim2.fromOffset(PACK.ChipRowWidth, PACK.NoteHeight)
		note.TextWrapped = true
		popIn(note, start + step * CASCADE)
		step += 1
	end
	if gained then
		AudioController.Play("Recompense", { Delay = start, Pitch = 1.12 }) -- un seul son pour toute la ligne
	end
	return step * CASCADE + Animation.Toast.Time
end

function RewardScreenController.Hide()
	local gui = current
	if not gui then
		return
	end
	current = nil
	local root = gui:FindFirstChild("Contenu") :: Frame?
	local veil = gui:FindFirstChild("Voile") :: Frame?
	if root then
		local scale = root:FindFirstChildOfClass("UIScale")
		local base = if scale then scale.Scale else 1
		if scale then
			tween(scale, Animation.Close, { Scale = base * Animation.Scale.OpenFrom })
		end
		for _, item in root:GetDescendants() do
			if item:IsA("GuiObject") then
				tween(item, Animation.Close, { BackgroundTransparency = 1 })
			end
			if item:IsA("TextLabel") then
				tween(item, Animation.Close, { TextTransparency = 1 })
			end
			if item:IsA("UIStroke") then
				tween(item, Animation.Close, { Transparency = 1 })
			end
			if item:IsA("ViewportFrame") or item:IsA("ImageLabel") then
				tween(item, Animation.Close, { ImageTransparency = 1 })
			end
		end
	end
	if veil then
		tween(veil, Animation.Close, { BackgroundTransparency = 1 })
	end
	task.delay(Animation.Close.Time + 0.05, function()
		gui:Destroy()
	end)
end

-- Un héros engagé : portrait, nom, niveau, « +XP », barre ; la barre part de l'XP d'avant le combat et
-- se remplit ; une montée de niveau la remplit, puis repart du nouveau niveau, avec l'annonce.
local function heroChip(parent: Instance, entry: HeroProgress, index: number, start: number)
	local info = HeroConfig.Heroes[entry.HeroId]
	local levelUp = entry.LevelAfter > entry.LevelBefore
	local chip = UIKit.subPanel(parent, UDim2.fromOffset(HERO_CHIP.X, HERO_CHIP.Y))
	chip.Name = `Heros_{index}`
	chip.LayoutOrder = index
	local border = chip:FindFirstChildOfClass("UIStroke")
	local art = Instance.new("Frame")
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.Art
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S)
	art.Size = UDim2.fromOffset(HERO_CHIP.Y - 2 * Spacing.S, HERO_CHIP.Y - 2 * Spacing.S)
	art.Parent = chip
	corner(art, UITheme.Radius.Small)
	local model = Icons.heroModel(entry.HeroId)
	if model then
		UIKit.portrait(art, model)
	end
	local left = HERO_CHIP.Y + Spacing.XS
	local name = UIKit.text(chip, if info then info.Name else entry.HeroId, Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
	name.Position = UDim2.fromOffset(left, Spacing.S)
	name.Size = UDim2.new(1, -left - Spacing.S, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local level = UIKit.text(chip, `Nv.{entry.LevelBefore}`, Typography.Size.Heading, { Align = Enum.TextXAlignment.Left })
	level.Position = UDim2.fromOffset(left, 34)
	level.Size = UDim2.fromOffset(90, 28)
	local gain = UIKit.text(chip, `+{entry.XPGranted} XP`, Typography.Size.Heading, { Color = Colors.GoldLight, Align = Enum.TextXAlignment.Right })
	gain.Position = UDim2.new(1, -Spacing.S - 110, 0, 34)
	gain.Size = UDim2.fromOffset(110, 28)
	local bar = UIKit.bar(chip, { Color = Colors.Progress, Size = UDim2.new(1, -left - Spacing.S, 0, 14) })
	bar.Frame.Position = UDim2.fromOffset(left, 70)
	local need = entry.XPToNext
	local maxed = entry.LevelAfter >= entry.MaxLevel
	local ratio = if maxed then 1 elseif need > 0 then entry.XP / need else 0
	local before = if levelUp or maxed or need <= 0 then 0 else math.max(entry.XP - entry.XPGranted, 0) / need
	bar.Set(before)
	local note = UIKit.text(chip, if maxed then "Niveau max" else `{entry.XP} / {need} XP`, Typography.Size.Caption, { Color = Colors.TextMuted, Align = Enum.TextXAlignment.Left })
	note.Position = UDim2.fromOffset(left, 90)
	note.Size = UDim2.new(1, -left - Spacing.S, 0, 18)
	popIn(chip, start + (index - 1) * CASCADE)
	task.delay(start + (index - 1) * CASCADE + Animation.Toast.Time, function()
		if not chip.Parent then
			return
		end
		if not levelUp then
			bar.Set(ratio, true)
			return
		end
		-- montée de niveau : la barre se remplit, le niveau change, annonce dorée
		bar.Set(1, true)
		task.wait(Animation.Count.Time)
		if not chip.Parent then
			return
		end
		bar.Set(0)
		bar.Set(ratio, true)
		level.Text = `Nv.{entry.LevelBefore} → Nv.{entry.LevelAfter}`
		level.Size = UDim2.fromOffset(170, 28)
		level.TextColor3 = Colors.GoldLight
		gain.Visible = false
		local up = UIKit.badge(chip, "NIVEAU SUPÉRIEUR !", Colors.Gold)
		up.AnchorPoint = Vector2.new(0.5, 0.5)
		up.Position = UDim2.new(0.5, 0, 0, 0)
		up.ZIndex = 5
		UIKit.popIn(up, 0, 1.15)
		UIKit.pop(chip)
		if border then
			border.Color = Colors.Gold
			border.Thickness = UITheme.Stroke.Thick
			tween(border, Animation.Pulse, { Color = Colors.GoldLight })
		end
		AudioController.Play("Recompense")
	end)
end

-- Affiche l'écran ; onContinue est appelé au clic sur « Continuer » (après la fermeture).
function RewardScreenController.Show(data: ScreenData, onContinue: (() -> ())?)
	RewardScreenController.Hide()
	local player = Players.LocalPlayer
	local victory = data.Result == "Victory"
	if not data.Silent then
		AudioController.Play(if victory then "Victoire" else "Defaite") -- (#18)
	end
	local rewards = data.Rewards or {}
	local heroes = if victory then data.Heroes or {} else {}
	-- butin (#72) : lu à part de Rewards (monnaies), victoire seulement ; entrées inconnues ignorées
	local loot = if victory then LootModel.parse(data.Loot, LOOT_CONTEXT) else nil
	local chips = LootModel.chips(if loot then loot.Resources else {}, LootModel.chipSlots(PACK))
	local hasLoot = loot ~= nil and not loot.Empty
	local layout = LootModel.layout({
		Cards = #rewards,
		Heroes = #heroes,
		Band = hasLoot and loot ~= nil and loot.Best ~= nil,
		Chips = #chips.Shown + (if chips.More > 0 then 1 else 0),
		Caption = hasLoot and loot ~= nil and (loot.Best ~= nil or #loot.Resources > 0),
		Note = hasLoot and loot ~= nil and loot.Overflow,
	}, PACK)

	local gui = Instance.new("ScreenGui")
	gui.Name = "EcranRecompenses"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	current = gui

	local veil = Instance.new("Frame")
	veil.Name = "Voile"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Colors.Ink
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	tween(veil, Animation.Fade, { BackgroundTransparency = UITheme.Transparency.Overlay })

	local root = Instance.new("Frame")
	root.Name = "Contenu"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(layout.Width, layout.Height) -- hauteur calculée (LootModel.layout)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local camera = Workspace.CurrentCamera
	table.clear(smallTexts)
	local function fit()
		-- tailles en px pour un écran de 1080 px, réduites si le contenu ne tient pas sur l'un des deux axes ;
		-- contenu centré entre le bas des monnaies et le haut de la hotbar (jamais par-dessus)
		local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		-- AbsolutePosition est mesurée sous la barre de Roblox ; cet écran ignore l'inset : on l'ajoute
		local inset = GuiService:GetGuiInset().Y
		local top = 0
		for _, key in { "Gold", "Gems", "SummonTickets" } do
			local pill = GuideTargets.get(`Currency.{key}`)
			if pill then
				top = math.max(top, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y + inset)
			end
		end
		local bar = GuideTargets.get("Hotbar.Bar")
		local bottom = if bar then bar.AbsolutePosition.Y + inset else viewport.Y
		local placed = LootModel.place(viewport, Vector2.new(layout.Width, layout.Height), PACK, top, bottom)
		uiScale.Scale = placed.Scale
		root.Position = UDim2.new(0.5, 0, 0, placed.Y)
		for _, entry in smallTexts do
			entry.Label.TextSize = LootModel.textSize(entry.Base, placed.Scale, PACK)
		end
	end
	fit()
	if camera then
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		gui.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end

	-- titre et décor
	local titleY = layout.TitleY
	local centerX = layout.Width / 2
	if victory then
		local r = rays(root)
		r.Position = UDim2.fromOffset(centerX, titleY)
		popIn(r, 0.05, 1)
		local spin = tween(r, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
		gui.Destroying:Connect(function()
			spin:Cancel()
		end)
		sparkles(root, 0.25)
	end
	local titleFrame = Instance.new("Frame")
	titleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	titleFrame.Position = UDim2.fromOffset(centerX, titleY)
	titleFrame.Size = UDim2.fromOffset(560, 80)
	titleFrame.BackgroundTransparency = 1
	titleFrame.ZIndex = 3
	titleFrame.Parent = root
	local title = label(titleFrame, if victory then "Victoire !" else "Défaite…", Typography.Size.Hero, if victory then Colors.Gold else Colors.Error, Typography.TextStroke.Large)
	title.ZIndex = 3
	popIn(titleFrame, 0.1)

	if victory and data.FirstClear then
		local first = badge(root, "Première victoire", Colors.RoyalRed)
		first.Size = UDim2.fromOffset(170, 30)
		first.Position = UDim2.fromOffset(centerX, titleY + 58)
		popIn(first, 0.35)
	end

	-- cartes de récompense en cascade
	local cards = Instance.new("Frame")
	cards.Name = "Cartes"
	cards.AnchorPoint = Vector2.new(0.5, 0)
	cards.Position = UDim2.fromOffset(centerX, layout.CardsY)
	cards.Size = UDim2.fromOffset(PACK.ChipRowWidth, CARD_SIZE.Y + 20)
	cards.BackgroundTransparency = 1
	cards.Parent = root
	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.FillDirection = Enum.FillDirection.Horizontal
	cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardsLayout.Padding = UDim.new(0, Spacing.XL)
	cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardsLayout.Parent = cards
	local cardsStart = 0.45
	for index, reward in rewards do
		card(cards, reward, index, cardsStart)
	end

	-- butin (#72) : sous les monnaies, avant les héros
	local lootStart = cardsStart + #rewards * CASCADE + (if #rewards > 0 then Animation.Toast.Time else 0)
	local lootDuration = 0
	if loot and hasLoot then
		lootDuration = lootBlock(root, loot, chips, layout, lootStart)
	end

	-- héros engagés et leur XP (sous le butin ; sans carte, juste sous le titre)
	local heroesY = layout.HeroesY
	local heroesStart = lootStart + lootDuration
	if #heroes > 0 then
		local section = Instance.new("Frame")
		section.Name = "Heros"
		section.AnchorPoint = Vector2.new(0.5, 0)
		section.Position = UDim2.fromOffset(centerX, heroesY)
		section.Size = UDim2.fromOffset(layout.Width - 2 * PACK.SideMargin, layout.HeroesHeight)
		section.BackgroundTransparency = 1
		section.Parent = root
		local heading = small(UIKit.text(section, "Héros", Typography.Size.Label, { Color = Colors.TextMuted }), Typography.Size.Label)
		heading.Size = UDim2.new(1, 0, 0, PACK.HeroHeading - 4)
		popIn(heading, heroesStart)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, PACK.HeroHeading)
		row.Size = UDim2.new(1, 0, 0, layout.HeroesHeight - PACK.HeroHeading)
		row.Parent = section
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Wraps = false -- une seule ligne : LootModel.layout élargit l'écran pour tous les héros
		rowLayout.Padding = UDim.new(0, PACK.HeroGap)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		for index, entry in heroes do
			heroChip(row, entry, index, heroesStart + 0.1)
		end
	end

	-- bouton principal en dernier
	local buttonDelay = cardsStart + #rewards * CASCADE + Animation.Toast.Time + Animation.Count.Time + lootDuration
		+ (if #heroes > 0 then #heroes * CASCADE + Animation.Count.Time else 0)
	local button = primaryButton(root, "Continuer", function()
		RewardScreenController.Hide()
		if onContinue then
			task.delay(Animation.Close.Time, onContinue)
		end
	end)
	button.Position = UDim2.fromOffset(centerX, layout.ButtonY) -- sous le dernier bloc affiché (défaite : sous le titre)
	popIn(button, if #rewards > 0 or #heroes > 0 or lootDuration > 0 then buttonDelay else 0.45, 1.06)

	fit() -- petits textes créés : leur taille suit l'échelle
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Démonstration Studio (attribut Workspace.ApercuEcranRecompenses) : trois cas se succèdent. Ids pris dans
-- ItemConfig / ResourceConfig (aucun objet inventé) ; sert à la recette visuelle, jamais à une attribution.
local DEMO_HEROES = {
	{ InstanceId = "Demo1", HeroId = "ecuyer_du_rempart", XPGranted = 35, LevelBefore = 1, LevelAfter = 2, XP = 10, XPToNext = 125, MaxLevel = 20 },
	{ InstanceId = "Demo2", HeroId = "tireuse_des_faubourgs", XPGranted = 35, LevelBefore = 1, LevelAfter = 1, XP = 60, XPToNext = 100, MaxLevel = 20 },
}
local DEMOS: { ScreenData } = {
	{ -- 1. ressources seules, sans équipement
		Result = "Victory",
		Rewards = { { Kind = "Gold", Amount = 80 } },
		Loot = {
			Items = {},
			Resources = { { ResourceId = "resource_011", Amount = 3 }, { ResourceId = "resource_021", Amount = 2 } },
			Overflow = false,
		},
	},
	{ -- 2. équipement + ressources + XP
		Result = "Victory",
		FirstClear = true,
		Rewards = {
			{ Kind = "Gold", Amount = 120 },
			{ Kind = "Gems", Amount = 15 },
			{ Kind = "SummonTicket", Amount = 1, New = true },
		},
		Loot = {
			Items = { { InstanceId = "I_TDemo1", ItemId = "item_015" }, { InstanceId = "I_TDemo2", ItemId = "item_001" } },
			Resources = { { ResourceId = "resource_012", Amount = 4 }, { ResourceId = "resource_023", Amount = 2 }, { ResourceId = "resource_030", Amount = 1 } },
			Overflow = false,
		},
		Heroes = DEMO_HEROES,
	},
	{ -- 3. beaucoup de ressources (« +N autres ») et Sacoche pleine
		Result = "Victory",
		Rewards = { { Kind = "Gold", Amount = 200 } },
		Loot = {
			Items = {},
			Resources = {
				{ ResourceId = "resource_011", Amount = 12 }, { ResourceId = "resource_012", Amount = 3 }, { ResourceId = "resource_013", Amount = 5 },
				{ ResourceId = "resource_021", Amount = 7 }, { ResourceId = "resource_022", Amount = 1 }, { ResourceId = "resource_023", Amount = 2 },
				{ ResourceId = "resource_024", Amount = 4 }, { ResourceId = "resource_025", Amount = 1 },
			},
			Overflow = true,
		},
		Heroes = DEMO_HEROES,
	},
}

local function runDemo()
	local index = 0
	while Workspace:GetAttribute("ApercuEcranRecompenses") == true do
		index = index % #DEMOS + 1
		local closed = false
		RewardScreenController.Show(DEMOS[index], function()
			closed = true
		end)
		while not closed and Workspace:GetAttribute("ApercuEcranRecompenses") == true do
			task.wait(0.2)
		end
		task.wait(2)
	end
	RewardScreenController.Hide()
end

function RewardScreenController:Start()
	if not RunService:IsStudio() then
		return
	end
	local running = false
	local function check()
		if Workspace:GetAttribute("ApercuEcranRecompenses") == true and not running then
			running = true
			task.spawn(function()
				task.wait(1.5)
				runDemo()
				running = false
			end)
		end
	end
	Workspace:GetAttributeChangedSignal("ApercuEcranRecompenses"):Connect(check)
	check()
end

return RewardScreenController
