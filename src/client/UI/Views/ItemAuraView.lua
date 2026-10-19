--!strict
-- Planche des 100 équipements (ItemConfig) avec leur aura de rareté (ItemAura), une rangée par rareté
-- dans l'ordre de RarityConfig. Sert à comparer les dix paliers d'un coup d'œil (démo Studio
-- « Equipements » de UIPreviewController) ; aucune règle ni donnée de joueur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ItemAura = require(script.Parent.Parent.ItemAura)
local RarityStyle = require(script.Parent.Parent.RarityStyle)
local UIKit = require(script.Parent.Parent.UIKit)

local C = UITheme.Colors
local S = UITheme.Spacing

local TILE = 52 -- px d'une case d'icône
local GAP = 22 -- px entre deux cases : laisse la place au halo
local LABEL = 150 -- px de la colonne des badges
local SPREAD = 0.6 -- débordement de l'aura entre voisines

local ItemAuraView = {}

local screen: ScreenGui? = nil

function ItemAuraView.Hide()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function ItemAuraView.Show(onClose: (() -> ())?)
	ItemAuraView.Hide()
	local rows: { [string]: { ItemConfig.ItemInfo } } = {}
	local widest = 0
	for _, info in ItemConfig.Ordered do
		local list = rows[info.Rarity] or {}
		rows[info.Rarity] = list
		table.insert(list, info)
		widest = math.max(widest, #list)
	end

	local gui = UIKit.screen("EquipementsAura", 20)
	screen = gui
	local width = LABEL + widest * (TILE + GAP) + 2 * S.L
	local height = #RarityConfig.Tiers * (TILE + GAP) + S.XXL + S.L
	local panel, content = UIKit.window(gui, {
		Name = "Equipements",
		Title = "Équipement · 100 items",
		Size = Vector2.new(width, height),
		OnClose = function()
			ItemAuraView.Hide()
			if onClose then
				onClose()
			end
		end,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)

	for r, tier in RarityConfig.Tiers do
		local y = (r - 1) * (TILE + GAP) + GAP / 2
		local badge = RarityStyle.badge(content, tier.Id)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.fromOffset(0, y + TILE / 2)
		for i, info in rows[tier.Id] or {} do
			local tile = Instance.new("Frame")
			tile.Name = ItemConfig.slotName(info.Index)
			tile.BackgroundColor3 = C.Sand
			tile.BackgroundTransparency = UITheme.Transparency.Art
			tile.Position = UDim2.fromOffset(LABEL + (i - 1) * (TILE + GAP), y)
			tile.Size = UDim2.fromOffset(TILE, TILE)
			tile.Parent = content
			UIKit.corner(tile, UITheme.Radius.Small)
			UIKit.stroke(tile, UITheme.Stroke.Thin)
			if info.Icon then
				local icon = Instance.new("ImageLabel")
				icon.Name = "Icone"
				icon.BackgroundTransparency = 1
				icon.Image = info.Icon
				icon.ScaleType = Enum.ScaleType.Fit
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.Size = UDim2.fromOffset(TILE - 8, TILE - 8)
				icon.Parent = tile
			else
				UIKit.text(tile, string.format("%03d", info.Index), 14)
			end
			ItemAura.apply(tile, info.Rarity, { Spread = SPREAD })
		end
	end
	UIKit.open(panel)
end

return ItemAuraView
