-- Окно магазина: оружие и снаряжение
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local function setVp(vp, item, yaw, pitch)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local m = IB.Preview(item)
	Builder.SetupViewport(vp, m, yaw or math.rad(30), pitch or math.rad(15), 1.0)
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
	dmg = { "⚔ Урон", "" },
	radius = { "◎ Радиус", "" },
	gather = { "⛏ Добыча за удар", "" },
	cd = { "⏱ Перезарядка", "с" },
	hp = { "❤ Здоровье", "" },
	def = { "🛡 Защита", "%" },
	scrap = { "⚙ Бонус лома", "%" },
	speed = { "» Скорость", "" },
	jump = { "⇑ Прыжок", "" },
	heal = { "❤ Лечение", "" },
	energy = { "⚡ Заряд роя", "%" },
	cap = { "🎒 Вместимость", "%" },
	conv = { "♻ Батарей с переработки", "%" },
	cspeed = { "⏩ Скорость переработки", "%" },
}
local STAT_ORDER = { "dmg", "radius", "gather", "cd", "hp", "def", "scrap", "speed", "jump", "heal", "energy", "cap", "conv", "cspeed" }
local PCT = { def = true, scrap = true, energy = true, cap = true, conv = true, cspeed = true }
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
		return ("%.2fс"):format(v)
	elseif k == "hp" or k == "speed" or k == "jump" then
		return "+" .. tostring(v)
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
		local fxName = { fire = "поджог", shock = "ударная волна", sparks = "искры", zap = "молнии", plasma = "плазменная дуга" }
		table.insert(lines, ('✨ Эффект: <font color="#FFB020">%s</font>'):format(fxName[item.stats.fx] or item.stats.fx))
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
		detail.grade.Text = ("РАСХОДНИК  •  У тебя: %d  •  хотбар"):format(consumCount(item.id))
		local can1 = d and d.batteries >= item.price
		local can5 = d and d.batteries >= item.price * 5
		detail.action.Text = ("×1 • 🔋%s"):format(U.fmt(item.price))
		detail.action.BackgroundColor3 = can1 and C(60, 150, 40) or C(70, 70, 70)
		detail.action2.Text = ("×5 • 🔋%s"):format(U.fmt(item.price * 5))
		detail.action2.BackgroundColor3 = can5 and C(50, 110, 200) or C(70, 70, 70)
	elseif not isOwned then
		local can = d and d.batteries >= item.price and matsOk
		detail.action.Text = (#mats > 0 and "СКРАФТИТЬ • 🔋 %s" or "КУПИТЬ • 🔋 %s"):format(U.fmt(item.price))
		detail.action.BackgroundColor3 = can and C(60, 150, 40) or C(70, 70, 70)
	elseif isEq and FIXED[item.slot] then
		detail.action.Text = item.slot == "backpack" and "✔ НА СПИНЕ" or "✔ В ХОТБАРЕ"
		detail.action.BackgroundColor3 = C(50, 60, 50)
	elseif isEq then
		detail.action.Text = "СНЯТЬ"
		detail.action.BackgroundColor3 = C(130, 45, 40)
	else
		detail.action.Text = "НАДЕТЬ"
		detail.action.BackgroundColor3 = C(50, 110, 200)
	end
end

local function selectItem(id)
	selected = id
	local item = Shop.ById[id]
	detail.model = setVp(detail.vp, item, 0, math.rad(12))
	-- вращаем вокруг центра габаритов, а не вокруг рукояти
	local bb = detail.model:GetBoundingBox()
	detail.center = CFrame.new(bb.Position)
	detail.rel = detail.center:Inverse() * detail.model:GetPivot()
	for cid, c in pairs(cards) do
		c.stroke.Thickness = cid == id and 4 or 2
	end
	refreshDetail()
end

local function refreshCards()
	for id, c in pairs(cards) do
		local item = c.item
		c.card.Visible = item.slot == tab
		local isOwned = owned(id)
		local isEq = equippedId(item.slot) == id
		if item.stack then
			c.price.Text = ("🔋 %s  •  x%d"):format(U.fmt(item.price), consumCount(id))
			c.price.TextColor3 = T.Battery
		elseif isEq then
			c.price.Text = "✔ НАДЕТО"
			c.price.TextColor3 = T.Accent
		elseif isOwned then
			c.price.Text = "КУПЛЕНО"
			c.price.TextColor3 = C(150, 200, 255)
		else
			c.price.Text = item.price == 0 and "БЕСПЛАТНО" or ("🔋 " .. U.fmt(item.price))
			c.price.TextColor3 = (State.data and State.data.batteries >= item.price) and T.Battery or C(255, 110, 100)
		end
	end
	for key, b in pairs(tabButtons) do
		local on = key == tab
		b.b.BackgroundColor3 = on and C(70, 90, 60) or C(30, 36, 30)
		local eq = equippedId(key)
		b.sub.Text = eq and Shop.ById[eq].name or "— пусто —"
	end
	local d = State.data
	if d then
		local t = Shop.Totals(d.gear)
		detail.totals.Text = ("❤ %d HP   🛡 %d%%\n» +%d скор.   ⚙ +%d%% лома\n🎒 +%d%%   ♻ +%d%% батарей"):format(100 + t.hp, math.floor(t.def * 100 + 0.5), t.speed, math.floor(t.scrap * 100 + 0.5), math.floor(t.cap * 100 + 0.5), math.floor(t.conv * 100 + 0.5))
		detail.balance.Text = "🔋 " .. U.fmt(d.batteries)
	end
end

local function setTab(key)
	tab = key
	refreshCards()
	local first = Shop.BySlot[key][1]
	local pick = first.id
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
		Toast(("✔ Куплено: %s%s"):format(item.name, qty > 1 and (" ×" .. qty) or ""), "good")
		U.play(U.Sounds.pop, 0.7, 1.2)
	else
		Toast(res and res.err or "Ошибка покупки", "bad")
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
			Toast(("✔ Куплено: %s"):format(item.name), "good")
			U.play(U.Sounds.pop, 0.7, 1.2)
		else
			Toast(res and res.err or "Ошибка покупки", "bad")
		end
	else
		if equippedId(item.slot) == item.id and FIXED[item.slot] then
			return
		end
		Remotes.ShopEquip:FireServer(item.id)
	end
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
		Text = "🛒 МАГАЗИН «ПОСЛЕДНИЙ ШАНС»",
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
		win.Visible = false
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
		Text = "МОЙ ПЕРСОНАЖ",
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
		new("UIGridLayout", { CellSize = UDim2.fromOffset(146, 182), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	for _, item in ipairs(Shop.Items) do
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
		Text = "КУПИТЬ",
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
	return win and win.Visible
end

function SUI.Close()
	if win then
		win.Visible = false
	end
end

function SUI.Open(startTab)
	if startTab and Shop.BySlot[startTab] then
		tab = startTab
	end
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.55, 1.15)
	win.Visible = true
	scaleObj.Scale = s * 0.85
	U.tween(scaleObj, 0.25, { Scale = s }, Enum.EasingStyle.Back)
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
	RunService.RenderStepped:Connect(function()
		if win.Visible then
			if detail.model and detail.model.Parent then
				detail.model:PivotTo(detail.center * CFrame.Angles(0, os.clock() * 0.9, 0) * detail.rel)
			end
			if not SUI.InZone() then
				win.Visible = false
			end
		end
	end)
end

return SUI
