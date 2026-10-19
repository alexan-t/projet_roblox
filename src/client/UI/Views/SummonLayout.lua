--!strict
-- Géométrie figée du ZIP Invocation.dc.html. UIKit conserve polices, boutons et fenêtres.
local RS = game:GetService("ReplicatedStorage")
local Theme = require(RS.Shared.Config.UITheme)
local UIKit = require(script.Parent.Parent.UIKit)
local Card = require(script.Parent.Parent.HeroCard)
local Rarity = require(script.Parent.Parent.RarityStyle)
local Currency = require(RS.Shared.Config.CurrencyVisualConfig)
local C = Theme.Colors
local Layout = {}
Layout.Card, Layout.UIKit, Layout.Colors = Card, UIKit, C

function Layout.frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = if color then 0 else 1
	if color then f.BackgroundColor3 = color end
	f.Position, f.Size = UDim2.fromOffset(x,y), UDim2.fromOffset(w,h)
	f.Parent = parent
	return f
end
function Layout.text(parent: Instance, value: string, x: number, y: number, w: number, h: number, size: number, color: Color3?): TextLabel
	local dark = color == C.Ink or color == C.InkSoft or color == C.WoodDark
	local t = UIKit.text(parent, value, size, {Color=color,Stroke=not dark})
	local stroke = t:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Thickness = math.max(1, size * .07) end
	t.Position, t.Size = UDim2.fromOffset(x,y), UDim2.fromOffset(w,h)
	t.TextWrapped = true
	return t
end
function Layout.image(parent: Instance, key: string, x: number, y: number, w: number, h: number): ImageLabel
	return Card.image(parent,key,UDim2.fromOffset(w,h),UDim2.fromOffset(x,y))
end
function Layout.ticket(parent: Instance, x: number, y: number, size: number)
	return Layout.image(parent, Currency.Kinds.SummonTicket.Normal,x,y,size,size)
end
function Layout.button(parent: Instance, text: string, x: number, y: number, w: number, h: number, kind: any, callback: () -> ())
	local b = UIKit.button(parent,text,kind,UDim2.fromOffset(w,h),callback)
	b.holder.Name = "Action_"..text:gsub("[^%w]", "")
	b.face.Name = "Face"
	b.holder.Position = UDim2.fromOffset(x,y)
	return b
end
function Layout.ribbon(parent: Instance, key: string, text: string, x: number, y: number, w: number)
	local r = Layout.image(parent,key,x,y,w,w*(if key=="ribbon_taux" then 46/200 else 52/240))
	r.ScaleType = Enum.ScaleType.Stretch
	r.ZIndex = 6
	local t = UIKit.text(r,text,16)
	t.ZIndex = 7
	return r
end
function Layout.guarantee(parent: Instance, x: number, y: number, small: boolean)
	local w,h = if small then 250 else 240, if small then 42 else 52
	local f = UIKit.panel(parent,0,UDim.new(0,10),2)
	f.Position,f.Size = UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
	f.BackgroundColor3 = C.Guarantee
	local stroke = f:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = C.GoldLight end
	Layout.image(f,"seal_garanti",if small then 2 else -12, -4,h+8,h+8)
	Layout.text(f,"PREMIÈRE INVOCATION",h,3,w-h,16,if small then 12 else 14)
	Layout.text(f,"ÉPIQUE GARANTI",h,19,w-h,23,if small then 16 else 19,C.GoldLight)
end
function Layout.percent(p: number): string
	return (string.format("%.5f",p*100):gsub("0+$",""):gsub("%.$",""):gsub("%.",",")) .. " %"
end

function Layout.rates(parent: Instance, data: any, mobile: boolean)
	local width,height = if mobile then 640 else 800, if mobile then 326 else 590
	local layer = Layout.frame(parent,0,0,if mobile then 820 else 1000,if mobile then 354 else 610)
	layer.ZIndex = 20
	layer.Name = "Taux"
	local blocker = UIKit.overlay(layer)
	blocker.BackgroundTransparency = .4
	blocker.Activated:Connect(function() layer:Destroy() end)
	local panel, content = UIKit.window(layer,{Size=Vector2.new(width,height),Title="Taux",OnClose=function() layer:Destroy() end})
	panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
	local background = panel:FindFirstChild("Fond") :: Frame
	background.BackgroundColor3, background.BackgroundTransparency = C.Cream, 0
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1,0,1,-38)
	scroll.BackgroundTransparency, scroll.BorderSizePixel = 1,0
	scroll.CanvasSize = UDim2.fromOffset(0,470)
	scroll.ScrollBarThickness = 6
	scroll.Parent = content
	local column = (width-48)/2
	Layout.text(scroll,"VEDETTES · TAUX AUGMENTÉS",8,8,column-16,30,14,C.WoodDark)
	for i,hero in data.Banner.Featured do
		local y = 44+(i-1)*94
		local card = Card.new(scroll,hero,48,{Effects=false})
		card.Position = UDim2.fromOffset(14,y)
		Layout.text(scroll,hero.Name,70,y,column-78,36,if mobile then 14 else 16,C.Ink)
		Layout.text(scroll,Rarity.name(hero.Rarity).." · "..(if i==1 then "Vedette" else "Secondaire"),70,y+36,column-78,18,12,C.WoodDark)
		Layout.text(scroll,Layout.percent(data.Rates.Heroes[hero.HeroId] or 0),70,y+56,column-78,24,20,C.WoodDark)
		if data.Guarantee and data.GuaranteeRates then
			Layout.text(scroll,"G : "..Layout.percent(data.GuaranteeRates.Heroes[hero.HeroId] or 0),70,y+80,column-78,14,11,C.WoodDark)
		end
	end
	Layout.text(scroll,"PAR RARETÉ",column,8,column-8,30,14,C.WoodDark)
	for i,rate in data.Rates.Tiers do
		local y = 44+(10-i)*36
		Layout.image(scroll,"card_frame_"..i,column+8,y,23,31)
		Layout.text(scroll,Rarity.name(rate.Id),column+36,y,column-150,31,14,Rarity.color(rate.Id))
		Layout.text(scroll,Layout.percent(rate.Probability),column*2-110,y,100,if data.Guarantee then 20 else 31,14,C.WoodDark)
		if data.Guarantee and data.GuaranteeRates then
			local guaranteed = data.GuaranteeRates.Tiers[i]
			Layout.text(scroll,"G : "..Layout.percent(guaranteed.Probability),column*2-110,y+20,100,14,10,C.WoodDark)
		end
	end
	local note = Layout.text(content,"1 invocation = 1 ticket · Première invocation payante : Épique ou mieux",0,0,width-48,32,13,C.WoodDark)
	note.AnchorPoint, note.Position = Vector2.new(0,1), UDim2.fromScale(0,1)
	Layout.text(scroll,if data.Guarantee then "Taux normaux identiques en ×1, ×10 et ×100. G = premier résultat garanti Épique ou mieux ; les résultats suivants du lot utilisent les taux normaux." else "Taux normaux identiques en ×1, ×10 et ×100. Les chances vedettes font partie du taux de leur rareté. La garantie de première invocation a déjà été utilisée.",12,410,width-72,54,14,C.Ink)
	return layer
end
return Layout
