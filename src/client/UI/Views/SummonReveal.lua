--!strict
-- États du reveal du prototype final : timers visuels uniquement, résultats déjà attribués.
local RunService = game:GetService("RunService")
local Rarity = require(script.Parent.Parent.RarityStyle)
local RarityConfig = require(game.ReplicatedStorage.Shared.Config.RarityConfig)
local L = require(script.Parent.SummonLayout)
local UIKit,Card,C = L.UIKit,L.Card,L.Colors
local Reveal = {}
function Reveal.show(batch: any, options: any, mount: any, hide: () -> ())
	local opts = options or {}
	local quantity,results = batch.Quantity,batch.Results
	local phase,all = 0,false
	local started = os.clock()
	local lastCount = -1
	local root: Frame? = nil
	local mobile = false
	local alive = true
	local connection: RBXScriptConnection? = nil
	local draw: () -> ()
	local groups,byId = {},{}
	local rarityCounts = {}
	for _,hero in results do
		rarityCounts[hero.Rarity] = (rarityCounts[hero.Rarity] or 0) + 1
		local group = byId[hero.HeroId or hero.Name]
		if not group then group=table.clone(hero); group.Count=0; byId[hero.HeroId or hero.Name]=group; table.insert(groups,group) end
		group.Count += 1
		group.New = group.New or hero.New
	end
	table.sort(groups,function(a,b)
		local ar,br = Rarity.rank(a.Rarity),Rarity.rank(b.Rarity)
		return if ar~=br then ar>br elseif a.Count~=b.Count then a.Count>b.Count else a.Name<b.Name
	end)
	local function finish(again: boolean?)
		if not alive then return end
		alive=false
		if connection then connection:Disconnect() end
		hide()
		if again and opts.OnAgain then opts.OnAgain() elseif opts.OnContinue then opts.OnContinue() end
	end
	local function skip()
		if (quantity==1 and phase<4) or (quantity==10 and phase<3) or (quantity==100 and phase==0) then
			phase=if quantity==1 then 4 elseif quantity==10 then 3 else 1
			draw()
		elseif quantity~=100 then
			finish()
		end
	end
	local function footer(parent: Frame, y: number)
		local w = if mobile then 820 else 1000
		local primary = L.button(parent,"Continuer",w/2-210,y,200,if mobile then 52 else 54,"Secondary",function() finish() end)
		primary.label.TextSize=if mobile then 18 else 22
		if opts.OnAgain then
			local again=L.button(parent,"Encore ×"..quantity,w/2+10,y,200,if mobile then 52 else 54,"Primary",function() finish(true) end)
			again.setEnabled(batch.Tickets>=quantity)
			again.label.TextSize=if mobile then 18 else 22
			again.label.Size=UDim2.new(1,-70,1,0)
			L.ticket(again.face,132,if mobile then 5 else 12,24)
			L.text(again.face,tostring(quantity),158,if mobile then 4 else 10,38,26,16)
		end
	end
	local function chips(parent: Frame, y: number, seen: number?)
		local w = if mobile then 820 else 1000
		local counts = rarityCounts
		if seen then
			counts = {}
			for i=1,seen do local id=results[i].Rarity; counts[id]=(counts[id] or 0)+1 end
		end
		local items = {}
		for id,n in counts do table.insert(items,{Id=id,Count=n}) end
		table.sort(items,function(a,b) return Rarity.rank(a.Id)<Rarity.rank(b.Id) end)
		local row = L.frame(parent,20,y,w-40,32)
		row.Name = "Repartition"
		local layout = Instance.new("UIListLayout")
		layout.FillDirection,layout.HorizontalAlignment = Enum.FillDirection.Horizontal,Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0,8)
		layout.Parent = row
		local cellWidth=math.min(if mobile then 75 else 92,(w-40-8*math.max(0,#items-1))/math.max(1,#items))
		for index,item in items do
			local cell = L.frame(row,0,0,cellWidth,24)
			cell.LayoutOrder=index
			local dot=L.frame(cell,0,7,10,10,Rarity.color(item.Id));UIKit.corner(dot,UDim.new(0,3))
			L.text(cell,Rarity.name(item.Id).." "..item.Count,14,0,cellWidth-14,24,if mobile then 10 else 12)
		end
	end
	draw=function()
		local host=root
		if not host or not host.Parent then return end
		local old=host:FindFirstChild("RevealContent")
		if old then old:Destroy() end
		local w,h=if mobile then 820 else 1000,if mobile then 354 else 610
		local content=L.frame(host,0,0,w,h)
		content.Name="RevealContent"
		local endY=h-(if mobile then 54 else 60)
		if quantity==1 then
			local hero=results[1]
			local col=Rarity.color(hero.Rarity)
			if phase<4 then
				local p=if mobile then 250 else 480
				local portal=L.image(content,"portal",(w-p)/2,(h-p)/2,p,p)
				portal.ImageTransparency=if phase>=2 then .55 else 0
				if phase==1 then
					local flash=L.frame(content,0,0,w,h,C.TextLight)
					UIKit.tween(flash,TweenInfo.new(.25),{BackgroundTransparency=1})
				end
				if phase>=2 then
					local rays=L.image(content,"rays",(w-p)/2,(h-p)/2,p,p)
					rays.ImageColor3=if phase>=3 then col else C.CurrencyGems
					L.image(content,"hero_placeholder",(w-p*.5)/2,(h-p*.7)/2,p*.5,p*.7)
				end
				if phase>=3 then L.text(content,string.upper(Rarity.name(hero.Rarity)),0,endY-30,w,40,32,col) end
				L.text(content,"Toucher pour passer",0,h-28,w,24,14,C.TextMuted)
			else
				local cw=if mobile then 150 else 236
				local card=Card.new(content,hero,cw)
				card.Position=UDim2.fromOffset((w-cw)/2,if mobile then (if hero.Guaranteed then 94 else 70) else 122)
				UIKit.popIn(card,0)
				if hero.Guaranteed then L.ribbon(content,"ribbon_garanti","ÉPIQUE GARANTI",w/2-120,if mobile then -8 else 18,240) end
				L.text(content,string.upper(Rarity.name(hero.Rarity)),0,if mobile then (if hero.Guaranteed then 46 else 26) else 80,w,28,if mobile then 22 else 34,col)
				footer(content,endY)
			end
		elseif quantity==10 then
			if phase<2 then
				local p=if mobile then 230 else 400
				L.image(content,"portal",(w-p)/2,(h-p)/2,p,p)
				if phase==1 then local f=L.frame(content,0,0,w,h,C.TextLight); UIKit.tween(f,TweenInfo.new(.2),{BackgroundTransparency=1}) end
			else
				L.text(content,"INVOCATION ×10",0,0,w,36,if mobile then 24 else 34,C.GoldLight)
				local cw,gap=if mobile then 92 else 150,if mobile then 10 else 18
				local gridW=5*cw+4*gap
				local token=content
				for i,hero in results do
					local x=(w-gridW)/2+((i-1)%5)*(cw+gap)
					local y=40+math.floor((i-1)/5)*(cw*266/200+gap)
					local cell=L.frame(content,x,y,cw,cw*266/200)
					local card=Card.new(cell,hero,cw,{Effects=not mobile})
					local back=L.image(cell,"card_back",0,0,cw,cw*266/200)
					back.ZIndex=10
					card.Visible=phase==3
					back.Visible=phase~=3
					if phase<3 then
						local delay=.07*(i-1)+(if Rarity.rank(hero.Rarity)>=5 then .6 else 0)
						task.delay(delay,function()
							if not token.Parent then return end
							back.AnchorPoint,back.Position=Vector2.new(.5,0),UDim2.fromOffset(cw/2,0)
							local flip=UIKit.tween(back,TweenInfo.new(.35),{Size=UDim2.fromOffset(0,cw*266/200)})
							flip.Completed:Wait()
							if not token.Parent then return end
							back.Visible=false; card.Visible=true; UIKit.popIn(card,0,1.08)
						end)
					end
				end
				if phase==3 then footer(content,endY) else L.text(content,"Toucher pour tout révéler",0,h-28,w,24,14,C.TextMuted) end
			end
		else
			if phase==0 then
				local p=if mobile then 230 else 360
				L.image(content,"portal",(w-p)/2,(h-p)/2-20,p,p)
				local count=L.text(content,"0 / 100",0,h/2-35,w,70,if mobile then 42 else 68,C.GoldLight)
				count.Name="Compteur"
				L.text(content,"100 INVOCATIONS",0,h-146,w,36,if mobile then 22 else 34,C.GoldLight)
				local bar=L.frame(content,w/2-(if mobile then 210 else 280),h-104,if mobile then 420 else 560,16,C.WoodDeep)
				bar.Name="BarreRarites"
				bar.ClipsDescendants=true
				UIKit.corner(bar,UDim.new(1,0));UIKit.stroke(bar,2)
				for rank=1,10 do
					local segment=L.frame(bar,0,0,0,16,Rarity.color(RarityConfig.Tiers[rank].Id))
					segment.Name="Rang"..rank
				end
				chips(content,h-78,0)
				L.text(content,"Toucher pour passer",0,h-28,w,24,14,C.TextMuted)
			elseif phase==1 then
				L.text(content,"MEILLEURS RÉSULTATS",0,4,w,40,if mobile then 26 else 36,C.GoldLight)
				local best={}
				for _,g in groups do if Rarity.rank(g.Rarity)>=4 and #best<5 then table.insert(best,g) end end
				if #best==0 then for i=1,math.min(3,#groups) do table.insert(best,groups[i]) end end
				local main,other=if mobile then 122 else 200,if mobile then 100 else 160
				local rowW=main+(#best-1)*(other+18)
				local x=(w-rowW)/2
				local bestCount=0
				for i,hero in best do
					local cw=if i==1 then main else other
					local card=Card.new(content,hero,cw)
					card.Position=UDim2.fromOffset(x,if mobile then 58+(main-cw)*.66 else 110+(main-cw)*.66)
					UIKit.popIn(card,.1*i)
					x+=cw+18;bestCount+=hero.Count
				end
				L.text(content,"+ "..(100-bestCount).." autres héros",0,if mobile then 236 else 414,w,30,18,C.TextMuted)
				chips(content,if mobile then 268 else 452)
				local show=L.button(content,"Voir les 100 résultats",w/2+10,endY,290,if mobile then 52 else 54,"Primary",function() phase=2;draw() end)
				show.label.TextSize=18
				local done=L.button(content,"Terminer",w/2-210,endY,200,if mobile then 52 else 54,"Secondary",function() finish() end)
				done.label.TextSize=18
			else
				L.text(content,"100 HÉROS INVOQUÉS",0,0,w,40,if mobile then 24 else 34,C.GoldLight)
				local grouped=L.button(content,"Regroupés ("..#groups..")",18,44,210,38,"Tab",function() all=false;draw() end)
				grouped.setSelected(not all);grouped.label.TextSize=16
				local individual=L.button(content,"Tous (100)",240,44,180,38,"Tab",function() all=true;draw() end)
				individual.setSelected(all);individual.label.TextSize=16
				local sideW=if mobile then 165 else 210
				local scroll=Instance.new("ScrollingFrame")
				scroll.Name="Resultats"
				scroll.BackgroundTransparency,scroll.BorderSizePixel=1,0
				scroll.Position,scroll.Size=UDim2.fromOffset(16,92),UDim2.fromOffset(w-sideW-42,h-188)
				scroll.ScrollBarThickness=6
				scroll.Parent=content
				local list=if all then table.clone(results) else groups
				if all then table.sort(list,function(a,b) return Rarity.rank(a.Rarity)>Rarity.rank(b.Rarity) end) end
				local cols=if all then 10 elseif mobile then 6 else 6
				local cw=(w-sideW-54)/cols-8
				local ch=if all then 62 else cw*266/200+22
				for i,hero in list do
					local x=((i-1)%cols)*(cw+8)+4
					local y=math.floor((i-1)/cols)*(ch+12)+8
					if all then
						local cell=L.frame(scroll,x,y,cw,ch,C.WoodDeep)
						UIKit.corner(cell,UDim.new(0,7));UIKit.stroke(cell,2,Rarity.color(hero.Rarity))
						L.text(cell,hero.Name,2,3,cw-4,ch-6,10)
						cell:SetAttribute("InstanceId",hero.InstanceId)
					else
						local card=Card.new(scroll,hero,cw,{Effects=false});card.Position=UDim2.fromOffset(x,y)
					end
				end
				scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(#list/cols)*(ch+12)+12)
				local side=L.frame(content,w-sideW-10,92,sideW,h-166,C.WoodDeep)
				UIKit.corner(side,UDim.new(0,10))
				local counts={}
				for _,hero in results do counts[hero.Rarity]=(counts[hero.Rarity] or 0)+1 end
				local row=0
				for _,g in groups do
					if counts[g.Rarity] then
						L.text(side,Rarity.name(g.Rarity).."  "..counts[g.Rarity],6,8+row*(if mobile then 18 else 26),sideW-12,if mobile then 18 else 26,if mobile then 12 else 15,Rarity.color(g.Rarity))
						counts[g.Rarity]=nil;row+=1
					end
				end
				local newCount=0
				for _,group in groups do if group.New then newCount+=1 end end
				L.text(content,if newCount>0 then tostring(newCount).." nouveaux héros ajoutés à l’Index" else "Tous les exemplaires sont ajoutés à ta collection",16,h-88,w-sideW-42,22,if mobile then 12 else 14,C.TextMuted)
				footer(content,endY)
			end
		end
	end
	local host,veil=mount("Revelation",function(newRoot: Frame,isMobile: boolean) root=newRoot;mobile=isMobile;draw() end)
	host.Destroying:Connect(function() alive=false;if connection then connection:Disconnect() end end)
	veil.Activated:Connect(skip)
	connection=RunService.RenderStepped:Connect(function()
		if not alive then return end
		local elapsed=os.clock()-started
		local target=phase
		if quantity==1 and phase<4 then target=if elapsed>=2.5 then 4 elseif elapsed>=1.9 then 3 elseif elapsed>=1.15 then 2 elseif elapsed>=.9 then 1 else 0
		elseif quantity==10 and phase<3 then target=if elapsed>=3.3 then 3 elseif elapsed>=.9 then 2 elseif elapsed>=.7 then 1 else 0
		elseif quantity==100 and phase==0 then
			if elapsed>=2 then target=1 end
			local counter=host:FindFirstChild("Compteur",true)
			local count=math.clamp(math.floor((elapsed-.5)/.022)*2,0,100)
			if counter and counter:IsA("TextLabel") then counter.Text=tostring(count) end
			if count~=lastCount then
				lastCount=count
				local content=host:FindFirstChild("RevealContent") :: Frame
				local previous=content:FindFirstChild("Repartition")
				if previous then previous:Destroy() end
				chips(content,(if mobile then 354 else 610)-78,count)
			end
			local bar=host:FindFirstChild("BarreRarites",true)
			if bar then
				local counts={}
				for i=1,count do local rank=Rarity.rank(results[i].Rarity);counts[rank]=(counts[rank] or 0)+1 end
				local offset=0
				for rank=1,10 do
					local segment=bar:FindFirstChild("Rang"..rank) :: Frame
					local fraction=(counts[rank] or 0)/100
					segment.Position,segment.Size=UDim2.fromScale(offset,0),UDim2.fromScale(fraction,1)
					offset+=fraction
				end
			end
		end
		if target>phase then phase=target;draw() end
	end)
end
return Reveal
