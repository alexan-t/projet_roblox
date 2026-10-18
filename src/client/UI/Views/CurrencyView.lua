--!strict
-- Monnaies du joueur (HUD, en haut au centre) — pack « Quêtes HUD » / « Monnaies », docs/UI_DESIGN_SYSTEM.md.
-- Présentation seulement : les montants viennent de PlayerData.Currencies (serveur, CurrencyController).
--   Une capsule sombre arrondie (WoodDeep, contour Ink) par monnaie ; l'icône PNG « _small » du pack
--   (CurrencyVisualConfig) dépasse à gauche ; montant en Fredoka contouré. Mesures : UITheme.Pack.Currency.
--   Gain : le montant défile (Count, 0,4 s) et l'icône fait un pop. Perte : défile sans pop.
--   Guidage : chaque capsule est la cible « Currency.<Clé> » ; un gain d'or signale « Currencies »
--   (TutorialController : la toute première fois, une flèche montre la capsule d'or).
--   Les icônes sont aussi les points d'arrivée des récompenses qui volent (CurrencyView.IconOf).
-- API : CurrencyView.Set(currencies, animate?) ; CurrencyView.Hide() ; CurrencyView.IconOf(clé) -> GuiObject?
--   currencies = { Gold: number?, Gems: number?, SummonTickets: number? } (monnaie absente : inchangée)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local UIKit = require(script.Parent.Parent.UIKit)

local PACK = UITheme.Pack.Currency
local Colors = UITheme.Colors

export type Currencies = { Gold: number?, Gems: number?, SummonTickets: number? }

local CurrencyView = {}

type Entry = { pill: Frame, icon: ImageLabel, amount: TextLabel, value: NumberValue }
local screen: ScreenGui? = nil
local entries: { [string]: Entry } = {}

local function format(value: number): string
	local n = math.floor(value + 0.5)
	-- milliers séparés par une espace (lecture rapide)
	local text = tostring(n)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
end
CurrencyView.format = format

local function build()
	local s = UIKit.screen("MonnaiesHUD", 2)
	screen = s
	local row = Instance.new("Frame")
	row.Name = "Monnaies"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, PACK.Top)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, PACK.Height)
	row.BackgroundTransparency = 1
	row.Parent = s
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, PACK.Gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	-- place pour l'icône qui dépasse à gauche de la première capsule
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, -PACK.IconLeft)
	padding.Parent = row
	for index, kind in CurrencyVisualConfig.Order do
		local visual = CurrencyVisualConfig.Kinds[kind]
		local pill = Instance.new("Frame")
		pill.Name = visual.Currency
		pill.LayoutOrder = index
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, PACK.Height)
		pill.BackgroundColor3 = Colors.WoodDeep
		pill.BackgroundTransparency = PACK.Fill
		pill.Parent = row
		UIKit.corner(pill, UITheme.Radius.Pill)
		UIKit.stroke(pill, UITheme.Stroke.Regular)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, PACK.PadLeft)
		pad.PaddingRight = UDim.new(0, PACK.PadRight)
		pad.Parent = pill
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icone"
		icon.BackgroundTransparency = 1
		icon.Image = visual.Small
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(0, 0.5)
		-- la marge gauche de la capsule est retirée : position absolue depuis son bord gauche
		icon.Position = UDim2.new(0, PACK.IconLeft - PACK.PadLeft, 0.5, 0)
		icon.Size = UDim2.fromOffset(PACK.Icon, PACK.Icon)
		icon.ZIndex = 2
		icon.Parent = pill
		local amount = UIKit.text(pill, "0", UITheme.Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
		amount.Name = "Montant"
		amount.AutomaticSize = Enum.AutomaticSize.X
		amount.Size = UDim2.new(0, PACK.ValueMin, 1, 0)
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(v)
			amount.Text = format(v)
		end)
		value.Parent = pill
		entries[visual.Currency] = { pill = pill, icon = icon, amount = amount, value = value }
		GuideTargets.register(`Currency.{visual.Currency}`, pill) -- guidage : Currency.Gold, Currency.Gems...
	end
end

function CurrencyView.Set(currencies: Currencies, animate: boolean?)
	if not screen then
		build()
	end
	for key, entry in entries do
		local target = (currencies :: any)[key]
		if typeof(target) == "number" and target ~= entry.value.Value then
			local gain = target > entry.value.Value
			if animate then
				UIKit.tween(entry.value, UITheme.Animation.Count, { Value = target })
				if gain then
					UIKit.pop(entry.icon)
					if key == "Gold" then
						GuideTargets.open("Currencies")
					end
				end
			else
				entry.value.Value = target
				entry.amount.Text = format(target)
			end
		end
	end
end

-- Icône d'une monnaie dans le HUD (clé de PlayerData.Currencies ou de récompense), point d'arrivée des
-- récompenses qui volent ; nil si le HUD n'est pas construit.
function CurrencyView.IconOf(kind: string): GuiObject?
	local visual = CurrencyVisualConfig.visual(kind)
	local entry = if visual then entries[visual.Currency] else nil
	return if entry then entry.icon else nil
end

-- Petit rebond de l'icône d'une monnaie (arrivée d'une récompense qui vole).
function CurrencyView.Bump(kind: string)
	local icon = CurrencyView.IconOf(kind)
	if icon then
		UIKit.pop(icon)
	end
end

function CurrencyView.Hide()
	local s = screen
	if s then
		s:Destroy()
	end
	screen = nil
	table.clear(entries)
end

return CurrencyView
