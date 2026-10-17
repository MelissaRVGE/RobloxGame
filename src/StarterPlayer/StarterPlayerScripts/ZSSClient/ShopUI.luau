-- Окно магазина: оружие и снаряжение
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Shop = require(Shared.ShopConfig)
local IB = require(Shared.ItemBuilder)
local Builder = require(Shared.DroneBuilder)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)
local Items = require(Shared.ItemsConfig)
local Icons = require(Shared.Icons)

-- рецепт: { {id, have, need}, ... }, хватает ли всего
local function matsStatus(item)
	local d = State.data
	local list, ok = {}, true
	for id, need in pairs(item.mats or {}) do
		local have = d and d.bag and d.bag[id] or 0
		if have < need then
			ok = false
		end
		table.insert(list, { id = id, have = have, need = need })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list, ok
end

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local SUI = {}
local gui, win, scaleObj
local tab = "weapon"
local selected
local cards = {}
local tabButtons = {}
local detail = {}
local busy = false
local Toast = function() end
local gridLayout

-- ===== 2D-карточки расходников =====
-- Своя палитра, строка эффекта и анимация у каждого расходника, который продаётся в магазине.
local CW, CH = 225, 268
local CELL_GEAR, CELL_CONSUM = UDim2.fromOffset(146, 182), UDim2.fromOffset(CW, CH)
local CONSUM_ART = {
	medkit = { color = C(255, 85, 95), anim = "beat", line = function(st)
		return ("❤ +%d health instantly"):format(st.heal)
	end },
	energycell = { color = C(70, 200, 255), anim = "charge", line = function(st)
		return ("⚡ +%d%% charge to the whole swarm"):format(math.floor(st.energy * 100 + 0.5))
	end },
	grenade = { color = C(150, 215, 70), anim = "shake", line = function(st)
		return ("💥 %d damage • radius %d"):format(st.dmg, st.radius)
	end },
	adrenaline = { color = C(255, 90, 190), anim = "dash", line = function(st)
		return ("» +%d Speed Boost stacks"):format(st.stacks)
	end },
}
local DEF_ART = { color = C(255, 200, 80), anim = "beat", line = function()
	return ""
end }
local function artOf(item)
	return CONSUM_ART[item.id] or DEF_ART
end

local function setVp(vp, item, yaw, pitch)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local m = IB.Preview(item)
	-- броня, перчатки и ботинки вытянуты по высоте: подводим камеру ближе, чтобы модель заполняла карточку
	local wear = item.slot == "armor" or item.slot == "gloves" or item.slot == "boots"
	Builder.SetupViewport(vp, m, yaw or math.rad(30), pitch or math.rad(15), wear and 0.85 or 1.0)
	return m
end

local function btn(props, onClick)
	local b = new("TextButton", props)
	b.AutoButtonColor = false
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		U.tween(b, 0.12, { BackgroundColor3 = base:Lerp(C(255, 255, 255), 0.15) })
	end)
	b.MouseLeave:Connect(function()
		U.tween(b, 0.12, { BackgroundColor3 = base })
	end)
	b.Activated:Connect(function()
		U.play(U.Sounds.tick, 0.4, 1.3)
		if onClick then
			onClick()
		end
	end)
	if props.Text == "X" and onClick then
		U.hitPad(b, function()
			U.play(U.Sounds.tick, 0.4, 1.3)
			onClick()
		end)
	end
	return b
end

local function owned(id)
	local d = State.data
	return d and d.items and d.items[id] == true
end

local function equippedId(slot)
	local d = State.data
	return d and d.gear and d.gear[slot]
end

local STAT_LABELS = {
	dmg = { "⚔ Damage", "" },
	radius = { "◎ Radius", "" },
	gather = { "⛏ Gather per Hit", "" },
	cd = { "⏱ Cooldown", "s" },
	hp = { "❤ Health", "" },
	def = { "🛡 Defense", "%" },
	scrap = { "⚙ Scrap Bonus", "%" },
	speed = { "» Speed", "" },
	jump = { "⇑ Jump", "" },
	heal = { "❤ Healing", "" },
	energy = { "⚡ Swarm Charge", "%" },
	cap = { "🎒 Capacity", "%" },
	conv = { "♻ Recycling Batteries", "%" },
	cspeed = { "⏩ Recycling Speed", "%" },
}
local STAT_ORDER = { "dmg", "radius", "gather", "cd", "hp", "def", "scrap", "speed", "jump", "heal", "energy", "cap", "conv", "cspeed" }
local PCT = { def = true, scrap = true, energy = true, cap = true, conv = true, cspeed = true }
-- доп. характеристики в стиле BSS (общий список в ShopConfig)
for _, k in ipairs(Shop.StatOrder) do
	local sd = Shop.StatDefs[k]
	STAT_LABELS[k] = { sd[1], sd.suffix or "" }
	PCT[k] = sd.pct or nil
	if not table.find(STAT_ORDER, k) then
		table.insert(STAT_ORDER, k)
	end
end
-- слоты, которые нельзя снять (только заменить)
local FIXED = { weapon = true, tool = true, backpack = true }

local function consumCount(id)
	local d = State.data
	return d and d.consum and d.consum[id] or 0
end

local function fmtStat(k, v)
	if PCT[k] then
		return ("+%d%%"):format(math.floor(v * 100 + 0.5))
	elseif k == "cd" then
		return ("%.2fs"):format(v)
	elseif k == "hp" or k == "speed" or k == "jump" or k == "regen" then
		return "+" .. tostring(v) .. STAT_LABELS[k][2]
	end
	return tostring(v)
end

local function statsText(item)
	local cur = equippedId(item.slot)
	local curItem = cur and Shop.ById[cur]
	local lines = {}
	for _, k in ipairs(STAT_ORDER) do
		local v = item.stats[k]
		if v and k ~= "fx" then
			local line = ("%s: <b>%s</b>"):format(STAT_LABELS[k][1], fmtStat(k, v))
			if curItem and curItem ~= item then
				local cv = curItem.stats[k] or 0
				local diff = v - cv
				local better = (k == "cd") and diff < 0 or (k ~= "cd" and diff > 0)
				if math.abs(diff) > 1e-6 then
					local ds = PCT[k] and ("%+d%%"):format(math.floor(diff * 100 + 0.5)) or (k == "cd" and ("%+.2f"):format(diff) or ("%+g"):format(diff))
					line ..= (' <font color="%s">(%s)</font>'):format(better and "#8CFF5A" or "#FF6A5A", ds)
				end
			end
			table.insert(lines, line)
		end
	end
	if item.stats.fx and item.stats.fx ~= "none" then
		local fxName = { fire = "burn", shock = "shockwave", sparks = "sparks", zap = "lightning", plasma = "plasma arc" }
		table.insert(lines, ('✨ Effect: <font color="#FFB020">%s</font>'):format(fxName[item.stats.fx] or item.stats.fx))
	end
	return table.concat(lines, "\n")
end

local function refreshDetail()
	local item = selected and Shop.ById[selected]
	if not item then
		return
	end
	local g = Shop.Grades[item.grade]
	detail.name.Text = item.name
	detail.grade.Text = g.name:upper()
	detail.grade.TextColor3 = g.color
	detail.stroke.Color = g.color
	detail.desc.Text = item.desc
	detail.stats.Text = statsText(item)
	local d = State.data
	-- материалы для крафта
	for _, c in ipairs(detail.mats:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local mats, matsOk = matsStatus(item)
	local showMats = #mats > 0 and not owned(item.id)
	detail.mats.Visible = showMats
	if showMats then
		for i, mt in ipairs(mats) do
			local enough = mt.have >= mt.need
			local cell = new("Frame", { Size = UDim2.fromOffset(46, 46), BackgroundColor3 = enough and C(30, 60, 25) or C(70, 25, 22), LayoutOrder = i, Parent = detail.mats }, { U.corner(8), U.stroke(enough and C(130, 230, 60) or C(255, 90, 80), 1.5) })
			new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.items[mt.id] or "", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(6, 1), Parent = cell })
			new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, 0), Size = UDim2.fromOffset(44, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = enough and C(190, 255, 150) or C(255, 170, 160), Text = mt.have .. "/" .. mt.need, ZIndex = 3, Parent = cell }, { U.textStroke(C(0, 0, 0), 1.2) })
		end
	end
	local isOwned = owned(item.id)
	local isEq = equippedId(item.slot) == item.id
	detail.action2.Visible = item.stack == true
	detail.action.Size = item.stack and UDim2.new(0.5, -14, 0, 50) or UDim2.new(1, -20, 0, 50)
	if item.stack then
		detail.grade.Text = ("CONSUMABLE  •  You have: %d  •  hotbar"):format(consumCount(item.id))
		local can1 = d and d.batteries >= item.price
		local can5 = d and d.batteries >= item.price * 5
		detail.action.Text = ("×1 • 🔋%s"):format(U.fmt(item.price))
		detail.action.BackgroundColor3 = can1 and C(60, 150, 40) or C(70, 70, 70)
		detail.action2.Text = ("×5 • 🔋%s"):format(U.fmt(item.price * 5))
		detail.action2.BackgroundColor3 = can5 and C(50, 110, 200) or C(70, 70, 70)
	elseif not isOwned then
		local can = d and d.batteries >= item.price and matsOk
		detail.action.Text = (#mats > 0 and "CRAFT • 🔋 %s" or "BUY • 🔋 %s"):format(U.fmt(item.price))
		detail.action.BackgroundColor3 = can and C(60, 150, 40) or C(70, 70, 70)
	elseif isEq and FIXED[item.slot] then
		detail.action.Text = item.slot == "backpack" and "✔ ON YOUR BACK" or "✔ IN HOTBAR"
		detail.action.BackgroundColor3 = C(50, 60, 50)
	elseif isEq then
		detail.action.Text = "UNEQUIP"
		detail.action.BackgroundColor3 = C(130, 45, 40)
	else
		detail.action.Text = "EQUIP"
		detail.action.BackgroundColor3 = C(50, 110, 200)
	end
end

local function setDetailArt(item)
	local a = detail.art
	local col = artOf(item).color
	a.root.Visible = true
	a.icon.Image = Icons[item.id] or ""
	U.tween(a.rays, 0.3, { ImageColor3 = col })
	U.tween(a.glow, 0.3, { ImageColor3 = col })
	U.tween(a.stroke, 0.3, { Color = col })
	a.root.BackgroundColor3 = col:Lerp(C(14, 12, 10), 0.8)
	-- иконка мягко «выпрыгивает» при выборе
	a.popScale.Scale = 0.55
	U.tween(a.popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	a.icon.ImageTransparency = 1
	U.tween(a.icon, 0.25, { ImageTransparency = 0 })
	a.anim = artOf(item).anim
end

local function selectItem(id)
	selected = id
	local item = Shop.ById[id]
	if item.stack then
		-- расходник: в панели та же 2D-картинка, что и на карточке
		for _, c in ipairs(detail.vp:GetChildren()) do
			if c:IsA("Model") then
				c:Destroy()
			end
		end
		detail.model = nil
		setDetailArt(item)
	else
		detail.art.root.Visible = false
		detail.model = setVp(detail.vp, item, 0, math.rad(12))
		-- вращаем вокруг центра габаритов, а не вокруг рукояти
		local bb = detail.model:GetBoundingBox()
		detail.center = CFrame.new(bb.Position)
		detail.rel = detail.center:Inverse() * detail.model:GetPivot()
	end
	for cid, c in pairs(cards) do
		if c.big then
			U.tween(c.stroke, 0.2, { Thickness = cid == id and 4 or 2, Transparency = cid == id and 0 or 0.15 })
		else
			U.tween(c.stroke, 0.15, { Thickness = cid == id and 4 or 2 })
		end
	end
	refreshDetail()
end

local function refreshCards()
	for id, c in pairs(cards) do
		local item = c.item
		c.card.Visible = item.slot == tab
		local isOwned = owned(id)
		local isEq = equippedId(item.slot) == id
		if c.big then
			local can = State.data and State.data.batteries >= item.price
			c.price.Text = "🔋 " .. U.fmt(item.price)
			if c.can ~= can then
				c.can = can
				U.gradTo(c.priceGrad, can and C(110, 235, 90) or C(120, 115, 110), can and C(30, 150, 50) or C(60, 58, 55), 0.25)
				U.tween(c.priceStroke, 0.25, { Color = can and C(200, 255, 170) or C(150, 145, 140) })
			end
			local n = consumCount(id)
			if n ~= c.count then
				if c.count and n > c.count then
					U.pulseScale(c.badge, 1.35, 0.08, 0.35)
				end
				c.count = n
				c.badge.Text = "×" .. n
				U.fadeVisible(c.badge, n > 0, 0.2)
			end
		elseif item.stack then
			c.price.Text = ("🔋 %s  •  x%d"):format(U.fmt(item.price), consumCount(id))
			c.price.TextColor3 = T.Battery
		elseif isEq then
			c.price.Text = "✔ EQUIPPED"
			c.price.TextColor3 = T.Accent
		elseif isOwned then
			c.price.Text = "OWNED"
			c.price.TextColor3 = C(150, 200, 255)
		else
			c.price.Text = item.price == 0 and "FREE" or ("🔋 " .. U.fmt(item.price))
			c.price.TextColor3 = (State.data and State.data.batteries >= item.price) and T.Battery or C(255, 110, 100)
		end
	end
	for key, b in pairs(tabButtons) do
		local on = key == tab
		U.tween(b.b, 0.15, { BackgroundColor3 = on and C(70, 90, 60) or C(30, 36, 30) })
		local eq = equippedId(key)
		b.sub.Text = eq and Shop.ById[eq].name or "— empty —"
	end
	local d = State.data
	if d then
		local t = Shop.Totals(d.gear)
		detail.totals.Text = ("❤ %d HP   🛡 %d%%\n» +%d speed   ⚙ +%d%% scrap\n🎒 +%d%%   ♻ +%d%% batteries"):format(100 + t.hp, math.floor(t.def * 100 + 0.5), t.speed, math.floor(t.scrap * 100 + 0.5), math.floor(t.cap * 100 + 0.5), math.floor(t.conv * 100 + 0.5))
		detail.balance.Text = "🔋 " .. U.fmt(d.batteries)
	end
end

local function setTab(key)
	local changed = tab ~= key or not win.Visible
	tab = key
	gridLayout.CellSize = key == "consumable" and CELL_CONSUM or CELL_GEAR
	refreshCards()
	if changed then
		-- карточки новой вкладки появляются волной с лёгкой пружинкой
		local list = {}
		for _, c in pairs(cards) do
			if c.card.Visible then
				table.insert(list, c)
			end
		end
		table.sort(list, function(a, b)
			return a.card.LayoutOrder < b.card.LayoutOrder
		end)
		for i, c in ipairs(list) do
			local sc = c.card:FindFirstChild("TabPop") or new("UIScale", { Name = "TabPop", Parent = c.card })
			sc.Scale = 0.6
			task.delay(math.min(i, 12) * 0.02, function()
				U.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
	local pick
	for _, it in ipairs(Shop.BySlot[key]) do
		if not it.noShop then
			pick = it.id
			break
		end
	end
	local eq = equippedId(key)
	if eq then
		pick = eq
	end
	selectItem(pick)
end

local function buy(item, qty)
	busy = true
	local ok, res = pcall(function()
		return Remotes.ShopBuy:InvokeServer(item.id, qty)
	end)
	busy = false
	if ok and res and res.ok then
		Toast(("✔ Bought: %s%s"):format(item.name, qty > 1 and (" ×" .. qty) or ""), "good")
		U.play(U.Sounds.pop, 0.7, 1.2)
		local c = cards[item.id]
		if c and c.big then
			c.celebrate(qty)
		end
		if detail.art.root.Visible then
			detail.art.jump = os.clock()
			detail.art.burst = os.clock()
		end
	else
		Toast(res and res.err or "Purchase error", "bad")
	end
end

local function onAction2()
	local item = selected and Shop.ById[selected]
	if item and item.stack and not busy then
		buy(item, 5)
	end
end

local function onAction()
	local item = selected and Shop.ById[selected]
	if not item or busy then
		return
	end
	if item.stack then
		buy(item, 1)
		return
	end
	if not owned(item.id) then
		busy = true
		local ok, res = pcall(function()
			return Remotes.ShopBuy:InvokeServer(item.id)
		end)
		busy = false
		if ok and res and res.ok then
			Toast(("✔ Bought: %s"):format(item.name), "good")
			U.play(U.Sounds.pop, 0.7, 1.2)
		else
			Toast(res and res.err or "Purchase error", "bad")
		end
	else
		if equippedId(item.slot) == item.id and FIXED[item.slot] then
			return
		end
		Remotes.ShopEquip:FireServer(item.id)
	end
end


local function sparkleAt(parent, pos, color, z)
	local sp = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.twinkle,
		ImageColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(22, 22),
		ZIndex = z or 8,
		Parent = parent,
	})
	local sc = new("UIScale", { Scale = 0.25, Parent = sp })
	U.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	U.tween(sp, 0.25, { Rotation = 90 })
	task.delay(0.3, function()
		U.tween(sc, 0.35, { Scale = 0.2 })
		U.tween(sp, 0.35, { ImageTransparency = 1, Rotation = 180 })
	end)
	Debris:AddItem(sp, 0.7)
end

-- большая 2D-карточка расходника: лучи и свечение цвета предмета, «живая» иконка,
-- рамка редкости, счётчик в рюкзаке и кнопка-цена
local function buildConsumCard(grid, item)
	local art = artOf(item)
	local col = art.color
	local g = Shop.Grades[item.grade]
	local card = { item = item, big = true, ph = item.index * 0.73, fx = {} }
	-- ячейка сетки (её UIScale — волна появления вкладки)
	local cell = new("Frame", { Size = UDim2.fromOffset(CW, CH), BackgroundTransparency = 1, LayoutOrder = item.index, Visible = false, Parent = grid })
	-- рамка редкости + масштаб наведения
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = cell }, { U.corner(16) })
	card.scale = U.scaleOf(holder)
	card.stroke = U.stroke(g.color, 2, 0.15)
	card.stroke.Parent = holder
	local root = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(255, 255, 255),
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		Parent = holder,
	}, {
		U.corner(16),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(C(22, 18, 14), 0.68), C(18, 15, 12)) }),
	})

	-- витрина: тёмное окно с лучами и свечением
	local stage = new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 150),
		BackgroundColor3 = col:Lerp(C(10, 9, 8), 0.82),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = root,
	}, { U.corner(12), U.stroke(col, 1.5, 0.55) })
	card.stage = stage
	card.rays = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.dn.rays,
		ImageColor3 = col,
		ImageTransparency = 0.55,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		ZIndex = 2,
		Parent = stage,
	})
	card.glow = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.glow,
		ImageColor3 = col,
		ImageTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(190, 190),
		ZIndex = 3,
		Parent = stage,
	})
	card.glowScale = U.scaleOf(card.glow)
	-- пол витрины: мягкая тень под предметом
	new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.glow,
		ImageColor3 = C(0, 0, 0),
		ImageTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(130, 26),
		ZIndex = 3,
		Parent = stage,
	})
	-- обёртка иконки: UIScale обёртки — покадровая анимация, UIScale иконки — наведение
	local wrap = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -2),
		Size = UDim2.fromOffset(112, 112),
		ZIndex = 5,
		Parent = stage,
	})
	card.wrapScale = new("UIScale", { Parent = wrap })
	card.icon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons[item.id] or "",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Parent = wrap,
	})
	card.iconScale = U.scaleOf(card.icon)

	-- особые слои анимаций
	if art.anim == "dash" then
		for k = 1, 4 do
			local ln = new("Frame", { BackgroundColor3 = col:Lerp(C(255, 255, 255), 0.4), BackgroundTransparency = 0.3, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30 + k * 7, 4), ZIndex = 4, Parent = stage }, { U.round() })
			table.insert(card.fx, ln)
		end
	elseif art.anim == "beat" then
		for k = 1, 3 do
			local pl = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "+", TextSize = 22, TextColor3 = col:Lerp(C(255, 255, 255), 0.35), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(24, 24), ZIndex = 4, Parent = stage }, { U.textStroke(C(60, 0, 10), 1.2, 0.3) })
			table.insert(card.fx, pl)
		end
	else
		for k = 1, 3 do
			local sp = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = col:Lerp(C(255, 255, 255), 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), ZIndex = 6, Parent = stage })
			table.insert(card.fx, sp)
		end
	end
	-- блик, пробегающий по карточке
	card.sheen = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.4, 0, 0.5, 0), Size = UDim2.new(0, 28, 2, 0), Rotation = 22, BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 9, Parent = root })
	card.nextSheen = os.clock() + 1 + item.index % 4 * 0.6

	-- плашка редкости и счётчик «в рюкзаке»
	new("TextLabel", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = g.color,
		Font = Enum.Font.GothamBlack,
		Text = g.name:upper(),
		TextSize = 11,
		TextColor3 = C(20, 18, 14),
		ZIndex = 7,
		Parent = stage,
	}, { U.corner(10), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	card.badge = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(46, 22),
		BackgroundColor3 = C(0, 0, 0),
		BackgroundTransparency = 0.35,
		Font = Enum.Font.GothamBlack,
		Text = "×0",
		TextSize = 14,
		TextColor3 = C(255, 255, 255),
		Visible = false,
		ZIndex = 7,
		Parent = stage,
	}, { U.corner(11), U.stroke(col, 1.5, 0.2) })

	new("TextLabel", {
		Position = UDim2.fromOffset(10, 164),
		Size = UDim2.new(1, -20, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = item.name,
		TextScaled = true,
		TextColor3 = C(255, 255, 255),
		ZIndex = 5,
		Parent = root,
	}, { U.textStroke(C(0, 0, 0), 1.6), new("UITextSizeConstraint", { MaxTextSize = 21 }) })
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 192),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = art.line(item.stats),
		TextScaled = true,
		TextColor3 = col:Lerp(C(255, 255, 255), 0.45),
		ZIndex = 5,
		Parent = root,
	}, { U.textStroke(C(0, 0, 0), 1.2), new("UITextSizeConstraint", { MaxTextSize = 14 }) })

	-- цена (покупка — кнопками в панели справа)
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 40),
		BackgroundColor3 = C(255, 255, 255),
		ZIndex = 5,
		Parent = root,
	}, { U.corner(12) })
	card.pill = pill
	card.priceGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(110, 235, 90), C(30, 150, 50)), Parent = pill })
	card.can = true
	card.priceStroke = U.stroke(C(200, 255, 170), 2, 0.2)
	card.priceStroke.Parent = pill
	card.price = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🔋 " .. U.fmt(item.price),
		TextSize = 20,
		TextColor3 = C(255, 255, 255),
		ZIndex = 6,
		Parent = pill,
	}, { U.textStroke(C(0, 40, 10), 1.6) })

	-- наведение: карточка приподнимается, иконка крупнее, лучи и свечение ярче
	root.MouseEnter:Connect(function()
		card.hover = true
		U.tween(card.scale, 0.22, { Scale = 1.04 }, Enum.EasingStyle.Back)
		U.tween(card.iconScale, 0.28, { Scale = 1.14 }, Enum.EasingStyle.Back)
		U.tween(card.glow, 0.22, { ImageTransparency = 0.08 })
		U.tween(card.rays, 0.3, { ImageTransparency = 0.25 })
		if selected ~= item.id then
			U.tween(card.stroke, 0.22, { Thickness = 3, Transparency = 0 })
		end
		U.play(U.Sounds.hover, 0.15, 1.15)
	end)
	root.MouseLeave:Connect(function()
		card.hover = false
		U.tween(card.scale, 0.22, { Scale = 1 })
		U.tween(card.iconScale, 0.28, { Scale = 1 })
		U.tween(card.glow, 0.22, { ImageTransparency = 0.3 })
		U.tween(card.rays, 0.3, { ImageTransparency = 0.55 })
		if selected ~= item.id then
			U.tween(card.stroke, 0.22, { Thickness = 2, Transparency = 0.15 })
		end
	end)
	root.MouseButton1Down:Connect(function()
		U.tween(card.scale, 0.07, { Scale = 0.97 })
	end)
	root.Activated:Connect(function()
		U.tween(card.scale, 0.35, { Scale = card.hover and 1.04 or 1 }, Enum.EasingStyle.Back)
		U.play(U.Sounds.tick, 0.4, 1.3)
		card.jump = os.clock()
		for _ = 1, 4 do
			sparkleAt(stage, UDim2.new(0.5 + (math.random() - 0.5) * 0.6, 0, 0.5 + (math.random() - 0.5) * 0.6, 0), col:Lerp(C(255, 255, 255), 0.4))
		end
		selectItem(item.id)
	end)

	-- покупка: прыжок иконки, вспышка свечения и россыпь искр
	function card.celebrate(qty)
		card.jump = os.clock()
		U.pulseScale(pill, 1.08, 0.08, 0.35)
		card.burst = os.clock()
		for _ = 1, 4 + qty * 2 do
			local a = math.random() * math.pi * 2
			sparkleAt(stage, UDim2.new(0.5 + math.cos(a) * 0.32, 0, 0.5 + math.sin(a) * 0.36, 0), col:Lerp(C(255, 255, 255), 0.35))
		end
	end
	card.card = cell
	return card
end

-- покадровая анимация 2D-картинки (карточка и панель справа)
local function animArt(o, anim, t, dt, ph)
	local rot, sc, raySpeed, glowSc = 0, 1, 16, 1
	if anim == "beat" then
		-- сердцебиение: два толчка и пауза
		local k = (t + ph) % 1.3
		local b = math.exp(-((k - 0.1) / 0.06) ^ 2) + 0.6 * math.exp(-((k - 0.34) / 0.06) ^ 2)
		sc = 1 + 0.07 * b
		glowSc = 1 + 0.18 * b
		rot = math.sin(t * 1.2 + ph) * 3
		for i, pl in ipairs(o.fx) do
			local q = (t * 0.45 + i / 3 + ph) % 1
			pl.Position = UDim2.fromScale(0.5 + (i - 2) * 0.28 + math.sin(q * 6 + i) * 0.03, 0.85 - q * 0.7)
			pl.TextTransparency = math.abs(q - 0.5) * 2
			pl.Rotation = math.sin(q * 6 + i) * 15
		end
	elseif anim == "charge" then
		-- заряд: лучи быстрее, свечение мерцает, искры по орбите
		raySpeed = 60
		sc = 1 + 0.03 * math.sin(t * 4 + ph)
		rot = math.sin(t * 1.6 + ph) * 4
		glowSc = 1 + 0.08 * math.sin(t * 11) + 0.05 * math.sin(t * 17 + 1)
		for i, sp in ipairs(o.fx) do
			local a = t * 1.8 + i * math.pi * 2 / 3
			sp.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.36)
			sp.Rotation = t * 140 + i * 40
			sp.ImageTransparency = 0.15 + 0.5 * (0.5 + 0.5 * math.sin(a))
		end
	elseif anim == "shake" then
		-- граната раз в 2.4 с вздрагивает, вокруг вспыхивают искры
		local k = ((t + ph) % 2.4) / 0.5
		if k < 1 then
			rot = math.sin(k * math.pi * 6) * 10 * (1 - k)
			sc = 1 + math.sin(k * math.pi) * 0.06
			glowSc = 1 + math.sin(k * math.pi) * 0.25
		else
			rot = math.sin(t * 1.4 + ph) * 2
		end
		for i, sp in ipairs(o.fx) do
			local q = (((t + ph) % 2.4) / 0.9 + i * 0.12)
			local a = i * 2.1 + 0.6
			sp.Position = UDim2.fromScale(0.5 + math.cos(a) * (0.18 + q * 0.18), 0.5 + math.sin(a) * (0.2 + q * 0.2))
			sp.ImageTransparency = q < 1 and math.clamp(q * 1.2, 0, 1) or 1
			sp.Rotation = q * 180
		end
	elseif anim == "dash" then
		-- адреналин: шприц наклонён «в рывке», позади летят полосы скорости
		rot = -8 + math.sin(t * 6 + ph) * 3
		sc = 1 + 0.03 * math.sin(t * 6 + ph)
		raySpeed = 30
		for i, ln in ipairs(o.fx) do
			local q = (t * 1.4 + i * 0.27) % 1
			ln.Position = UDim2.fromScale(0.42 - q * 0.38, (40 + i * 18) / 150)
			ln.BackgroundTransparency = 0.2 + 0.8 * q
		end
	end
	-- прыжок по клику/покупке
	if o.jump then
		local k = (t - o.jump) / 0.5
		if k < 1 then
			sc *= 1 + math.sin(k * math.pi) * 0.16
			rot += math.sin(k * math.pi * 2) * 12 * (1 - k)
		else
			o.jump = nil
		end
	end
	-- вспышка свечения после покупки
	if o.burst then
		local k = (t - o.burst) / 0.6
		if k < 1 then
			glowSc *= 1 + 0.5 * (1 - k) ^ 2
		else
			o.burst = nil
		end
	end
	o.icon.Rotation = rot
	o.wrapScale.Scale = sc
	o.glowScale.Scale = glowSc
	o.rays.Rotation = (o.rays.Rotation + raySpeed * dt) % 360
end

local function build()
	gui = new("ScreenGui", { Name = "ZSS_Shop", ResetOnSpawn = false, DisplayOrder = 11, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	win = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(980, 640),
		BackgroundColor3 = C(22, 18, 14),
		Visible = false,
		Parent = gui,
	}, { U.corner(18), U.stroke(T.Hazard, 3), U.grad(C(255, 255, 255), C(160, 150, 140), 90) })
	scaleObj = new("UIScale", { Parent = win })

	-- шапка
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = C(40, 32, 22), ClipsDescendants = true, Parent = win }, { U.corner(18) })
	new("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C(40, 32, 22), BorderSizePixel = 0, Parent = header })
	for k = 0, 30 do
		new("Frame", { Position = UDim2.new(0, k * 34 - 10, 1, -6), Size = UDim2.fromOffset(16, 6), BackgroundColor3 = k % 2 == 0 and C(240, 180, 20) or C(20, 20, 20), BorderSizePixel = 0, Parent = header })
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(0, 560, 1, -6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🛒 LAST CHANCE SHOP",
		TextSize = 24,
		TextColor3 = C(255, 220, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	}, { U.textStroke(C(0, 0, 0), 2) })
	detail.balance = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 0),
		Size = UDim2.new(0, 220, 1, -6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🔋 0",
		TextSize = 26,
		TextColor3 = T.Battery,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	}, { U.textStroke(C(0, 0, 0), 2) })
	local close = btn({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -3),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = T.Danger,
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 22,
		TextColor3 = C(255, 255, 255),
		Parent = header,
	}, function()
		SUI.Close()
	end)
	U.corner(12).Parent = close

	-- вкладки
	local tabs = new("Frame", {
		Position = UDim2.fromOffset(14, 74),
		Size = UDim2.fromOffset(170, 400),
		BackgroundTransparency = 1,
		Parent = win,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, s in ipairs(Shop.Slots) do
		local b = btn({
			Size = UDim2.fromOffset(170, 46),
			BackgroundColor3 = C(30, 36, 30),
			Text = "",
			LayoutOrder = i,
			Parent = tabs,
		}, function()
			setTab(s.key)
		end)
		U.corner(12).Parent = b
		U.stroke(T.Hazard, 1.5, 0.4).Parent = b
		new("TextLabel", {
			Position = UDim2.fromOffset(10, 2),
			Size = UDim2.new(1, -16, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = s.icon .. " " .. s.name,
			TextSize = 18,
			TextColor3 = C(255, 230, 180),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = b,
		}, { U.textStroke(C(0, 0, 0), 1.5) })
		local sub = new("TextLabel", {
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -18, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "",
			TextSize = 12,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = b,
		})
		tabButtons[s.key] = { b = b, sub = sub }
	end
	-- итоговые характеристики
	local totals = new("Frame", {
		Position = UDim2.new(0, 14, 1, -152),
		Size = UDim2.fromOffset(170, 138),
		BackgroundColor3 = C(14, 12, 10),
		Parent = win,
	}, { U.corner(12), U.stroke(T.AccentDark, 1.5), U.pad(10) })
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "MY CHARACTER",
		TextSize = 13,
		TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = totals,
	})
	detail.totals = new("TextLabel", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = totals,
	})

	-- сетка товаров
	local grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(196, 74),
		Size = UDim2.new(0, 470, 1, -88),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Hazard,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		Parent = win,
	}, {
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	gridLayout = new("UIGridLayout", { CellSize = CELL_GEAR, CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, item in ipairs(Shop.Items) do
		if item.noShop then
			continue -- выпадает только с зомби и босса, в магазине не продаётся
		end
		if item.stack then
			cards[item.id] = buildConsumCard(grid, item)
			continue
		end
		local g = Shop.Grades[item.grade]
		local card = btn({
			BackgroundColor3 = U.darken(g.color, 0.2),
			Text = "",
			LayoutOrder = item.index,
			Visible = false,
			Parent = grid,
		}, function()
			selectItem(item.id)
		end)
		U.corner(12).Parent = card
		local st = U.stroke(g.color, 2)
		st.Parent = card
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(80, 80, 80)), Parent = card })
		local vp = new("ViewportFrame", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 112),
			BackgroundTransparency = 1,
			Ambient = C(160, 160, 160),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			Parent = card,
		})
		setVp(vp, item)
		new("TextLabel", {
			Position = UDim2.new(0, 6, 0, 118),
			Size = UDim2.new(1, -12, 0, 32),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = item.name,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = C(255, 255, 255),
			Parent = card,
		}, { U.textStroke(C(0, 0, 0), 1.5), new("UITextSizeConstraint", { MaxTextSize = 15 }) })
		local price = new("TextLabel", {
			Position = UDim2.new(0, 6, 1, -28),
			Size = UDim2.new(1, -12, 0, 22),
			BackgroundColor3 = C(0, 0, 0),
			BackgroundTransparency = 0.4,
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextSize = 14,
			TextColor3 = T.Battery,
			Parent = card,
		}, { U.corner(6) })
		cards[item.id] = { card = card, stroke = st, price = price, item = item }
	end

	-- детали
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 74),
		Size = UDim2.new(0, 296, 1, -88),
		BackgroundColor3 = C(34, 28, 22),
		Parent = win,
	}, { U.corner(14) })
	detail.stroke = U.stroke(T.Hazard, 2)
	detail.stroke.Parent = panel
	detail.vp = new("ViewportFrame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 180),
		BackgroundColor3 = C(60, 55, 48),
		Ambient = C(160, 160, 160),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		Parent = panel,
	}, { U.corner(12) })
	-- 2D-витрина расходника (поверх 3D-превью)
	do
		local a = { fx = {}, orbit = {} }
		a.root = new("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 180),
			BackgroundColor3 = C(20, 16, 14),
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 3,
			Parent = panel,
		}, { U.corner(12) })
		a.grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(90, 90, 90)), Parent = a.root })
		a.stroke = U.stroke(C(255, 255, 255), 1.5, 0.45)
		a.stroke.Parent = a.root
		a.rays = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.dn.rays, ImageTransparency = 0.45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 380), ZIndex = 3, Parent = a.root })
		a.glow = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(230, 230), ZIndex = 4, Parent = a.root })
		a.glowScale = U.scaleOf(a.glow)
		new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = C(0, 0, 0), ImageTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(160, 30), ZIndex = 4, Parent = a.root })
		a.wrap = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -2), Size = UDim2.fromOffset(138, 138), ZIndex = 6, Parent = a.root })
		a.popScale = new("UIScale", { Parent = a.wrap })
		local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = a.wrap })
		a.wrapScale = new("UIScale", { Parent = inner })
		a.icon = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 6, Parent = inner })
		for _ = 1, 3 do
			table.insert(a.orbit, new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.twinkle, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 7, Parent = a.root }))
		end
		detail.art = a
	end
	detail.name = new("TextLabel", {
		Position = UDim2.fromOffset(12, 196),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = C(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}, { U.textStroke(C(0, 0, 0), 2), new("UITextSizeConstraint", { MaxTextSize = 22 }) })
	detail.grade = new("TextLabel", {
		Position = UDim2.fromOffset(12, 224),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	detail.desc = new("TextLabel", {
		Position = UDim2.fromOffset(12, 246),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	-- материалы крафта (иконки находок)
	detail.mats = new("Frame", {
		Position = UDim2.new(0, 10, 1, -116),
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local statBox = new("Frame", {
		Position = UDim2.fromOffset(10, 288),
		Size = UDim2.new(1, -20, 1, -412),
		BackgroundColor3 = C(18, 15, 12),
		Parent = panel,
	}, { U.corner(10), U.stroke(T.Hazard, 1.2, 0.4), U.pad(8) })
	detail.stats = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		RichText = true,
		TextSize = 14,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		Parent = statBox,
	})
	detail.action = btn({
		Position = UDim2.new(0, 10, 1, -60),
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundColor3 = C(60, 150, 40),
		Font = Enum.Font.GothamBlack,
		Text = "BUY",
		TextSize = 19,
		TextColor3 = C(255, 255, 255),
		Parent = panel,
	}, onAction)
	U.corner(12).Parent = detail.action
	U.stroke(C(255, 255, 255), 2, 0.3).Parent = detail.action
	U.textStroke(C(0, 0, 0), 1.5).Parent = detail.action
	detail.action2 = btn({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 1, -60),
		Size = UDim2.new(0.5, -14, 0, 50),
		BackgroundColor3 = C(50, 110, 200),
		Font = Enum.Font.GothamBlack,
		Text = "×5",
		TextSize = 18,
		TextColor3 = C(255, 255, 255),
		Visible = false,
		Parent = panel,
	}, onAction2)
	U.corner(12).Parent = detail.action2
	U.stroke(C(255, 255, 255), 2, 0.3).Parent = detail.action2
	U.textStroke(C(0, 0, 0), 1.5).Parent = detail.action2
end

function SUI.IsOpen()
	return U.isOpen(win, scaleObj)
end

function SUI.Close()
	if win then
		U.closePanel(win, scaleObj)
	end
end

function SUI.Open(startTab)
	if startTab and Shop.BySlot[startTab] then
		tab = startTab
	end
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.4, 1.15)
	U.openPanel(win, scaleObj, s)
	U.play(U.Sounds.whoosh, 0.25, 1.6)
	setTab(tab)
end

function SUI.InZone()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and (hrp.Position - Config.ShopZone.center).Magnitude <= Config.ShopZone.radius + 8
end

function SUI.Init(toastFn)
	Toast = toastFn or Toast
	build()
	State.Changed:Connect(function()
		if win.Visible then
			refreshCards()
			refreshDetail()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if win.Visible then
			local t = os.clock()
			if tab == "consumable" then
				for _, c in pairs(cards) do
					if c.big and c.card.Visible then
						animArt(c, artOf(c.item).anim, t, dt, c.ph)
						if t >= c.nextSheen then
							c.nextSheen = t + 3.5 + math.random() * 1.5
							c.sheen.Position = UDim2.new(-0.4, 0, 0.5, 0)
							U.tween(c.sheen, 0.75, { Position = UDim2.new(1.4, 0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
						end
					end
				end
			end
			local a = detail.art
			if a.root.Visible then
				animArt(a, a.anim, t, dt, 0)
				-- в панели вокруг предмета медленно кружат искры его цвета
				for i, sp in ipairs(a.orbit) do
					local ang = t * 0.9 + i * math.pi * 2 / 3
					sp.Position = UDim2.fromScale(0.5 + math.cos(ang) * 0.3, 0.5 + math.sin(ang) * 0.36)
					sp.Rotation = t * 90 + i * 40
					sp.ImageTransparency = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(ang))
					sp.ImageColor3 = a.glow.ImageColor3:Lerp(C(255, 255, 255), 0.5)
				end
			end
			if detail.model and detail.model.Parent then
				detail.model:PivotTo(detail.center * CFrame.Angles(0, os.clock() * 0.9, 0) * detail.rel)
			end
			if not SUI.InZone() then
				SUI.Close()
			end
		end
	end)
end

return SUI
