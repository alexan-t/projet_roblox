--!strict
-- Monnaies du joueur (HUD, en haut au centre) — issue #19, docs/UI_DESIGN_SYSTEM.md § 6 Monnaies.
-- Présentation seulement : les montants viennent de PlayerData.Currencies (serveur).
--   Une pastille HUD par monnaie, l'icône 3D déborde à gauche, montant en Label.
--   Gain : le montant défile (Count, 0,4 s) et l'icône fait un pop. Perte : défile sans pop.
-- API : CurrencyView.Set(currencies, animate?) ; CurrencyView.Hide().
--   currencies = { Gold: number?, Gems: number?, SummonTickets: number? } (monnaie absente : inchangée)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local PILL = Vector2.new(150, 44)
local ICON = 54
-- En haut au centre : la barre de Roblox y est libre (menu à gauche, liste des joueurs à droite).
local TOP = 12

-- Ordre d'affichage (de gauche à droite) et icône de chaque monnaie.
local KINDS = {
	{ Key = "Gold", Icon = "Or" },
	{ Key = "Gems", Icon = "Gemmes" },
	{ Key = "SummonTickets", Icon = "Ticket" },
}

export type Currencies = { Gold: number?, Gems: number?, SummonTickets: number? }

local CurrencyView = {}

type Entry = { pill: Frame, icon: Frame, amount: TextLabel, value: NumberValue }
local screen: ScreenGui? = nil
local entries: { [string]: Entry } = {}

local function format(value: number): string
	local n = math.floor(value + 0.5)
	-- milliers séparés par une espace (lecture rapide)
	local text = tostring(n)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
end

local function build()
	local s = UIKit.screen("MonnaiesHUD", 2)
	screen = s
	local row = Instance.new("Frame")
	row.Name = "Monnaies"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, TOP)
	row.Size = UDim2.fromOffset(#KINDS * (PILL.X + Spacing.XL), PILL.Y)
	row.BackgroundTransparency = 1
	row.Parent = s
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, Spacing.XL)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	for index, kind in KINDS do
		local pill = UIKit.pill(row, PILL)
		pill.Name = kind.Key
		pill.LayoutOrder = index
		local icon = Instance.new("Frame")
		icon.Name = "Icone"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, -ICON / 3, 0.5, 0) -- l'icône déborde à gauche (effet chunky)
		icon.Size = UDim2.fromOffset(ICON, ICON)
		icon.ZIndex = 2
		icon.Parent = pill
		Icons.viewport(icon, kind.Icon)
		local amount = UIKit.text(pill, "0", Typography.Size.Label, { Align = Enum.TextXAlignment.Right })
		amount.Position = UDim2.fromOffset(0, 0)
		amount.Size = UDim2.new(1, -Spacing.L, 1, 0)
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(v)
			amount.Text = format(v)
		end)
		value.Parent = pill
		entries[kind.Key] = { pill = pill, icon = icon, amount = amount, value = value }
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
					UIKit.bump(entry.icon)
				end
			else
				entry.value.Value = target
				entry.amount.Text = format(target)
			end
		end
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
