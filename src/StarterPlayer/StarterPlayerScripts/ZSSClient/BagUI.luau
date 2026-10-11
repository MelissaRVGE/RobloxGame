-- Рюкзак (открываемое окно с находками), часы дня/ночи, полоска босса, бафф скорости, награда за босса
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Items = require(Shared.ItemsConfig)
local Icons = require(Shared.Icons)
local Buffs = require(Shared.BuffsConfig)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)
local DayNight = require(script.Parent.DayNight)

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local BagUI = {}
local api
local win, scaleObj
local grid, slots = nil, {}
local selected
local det = {}
local capBar, capText, lvlText, upBtn, kindsText, matsText
local clock = {}
local bossBar = {}
local buff = {}

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

local function titleLabel(parent, text, size, pos, color, font)
	return new("TextLabel", {
		Position = pos,
		Size = size,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.GothamBlack,
		Text = text,
		TextScaled = true,
		TextColor3 = color or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	}, { U.textStroke(C(0, 0, 0), 1.5) })
end

-- ===== ОКНО РЮКЗАКА =====
local function bagList(d)
	local list = {}
	for id, n in pairs(d.bag or {}) do
		local it = Items.ById[id]
		if it and n > 0 then
			table.insert(list, { item = it, n = n })
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = Items.Tiers[a.item.tier].order, Items.Tiers[b.item.tier].order
		if ta ~= tb then
			return ta > tb
		end
		return a.item.index < b.item.index
	end)
	return list
end

local function showDetails(entry)
	selected = entry and entry.item.id or nil
	if not entry then
		det.empty.Visible = true
		det.box.Visible = false
		return
	end
	local it = entry.item
	local tier = Items.Tiers[it.tier]
	det.empty.Visible = false
	det.box.Visible = true
	if det.shownId ~= it.id then
		-- другой предмет: иконка мягко «выпрыгивает»
		det.shownId = it.id
		det.icon.ImageTransparency = 1
		U.tween(det.icon, 0.25, { ImageTransparency = 0 })
		local sc = det.icon:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = det.icon })
		sc.Scale = 0.7
		U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	det.icon.Image = Icons.items[it.id] or ""
	det.glow.ImageColor3 = tier.color
	det.name.Text = it.name
	det.name.TextColor3 = tier.color:Lerp(C(255, 255, 255), 0.25)
	det.tier.Text = tier.name:upper() .. "  •  x" .. entry.n
	det.tier.TextColor3 = tier.color
	det.desc.Text = it.desc
	det.value.Text = "Цена продажи: 🔋 " .. U.fmt(it.value)
	det.use.Visible = it.use ~= nil
	det.sellAll.Text = ("ПРОДАТЬ ВСЕ (🔋 %s)"):format(U.fmt(it.value * entry.n))
	U.tween(det.stroke, 0.2, { Color = tier.color })
end

function BagUI.Refresh(d)
	d = d or State.data
	if not d or not win then
		return
	end
	local ratio = math.clamp(d.scrap / math.max(d.capacity, 1), 0, 1)
	U.tween(capBar, 0.25, { Size = UDim2.fromScale(math.max(ratio, 0.02), 1) })
	capText.Text = ("Лом: %s / %s"):format(U.fmt(d.scrap), U.fmt(d.capacity))
	lvlText.Text = ("УРОВЕНЬ РЮКЗАКА: %d / %d"):format(d.bagLevel, Config.MaxBagLevel)
	if d.bagCost then
		local mats = Config.BagMats[d.bagLevel]
		local okMats = true
		local parts = {}
		for id, need in pairs(mats or {}) do
			local have = d.bag and d.bag[id] or 0
			if have < need then
				okMats = false
			end
			table.insert(parts, ("%s %d/%d"):format(Items.ById[id] and Items.ById[id].name or id, have, need))
		end
		upBtn.Text = ("⬆ УЛУЧШИТЬ — 🔋 %s"):format(U.fmt(d.bagCost))
		upBtn.BackgroundColor3 = (d.batteries >= d.bagCost and okMats) and T.Accent or C(70, 80, 70)
		if matsText then
			matsText.Text = #parts > 0 and ("🧰 " .. table.concat(parts, "  •  ")) or ""
			matsText.TextColor3 = okMats and C(170, 255, 140) or C(255, 170, 150)
		end
	else
		upBtn.Text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		upBtn.BackgroundColor3 = C(70, 80, 70)
	end
	local list = bagList(d)
	kindsText.Text = ("ПРЕДМЕТЫ: %d / %d слотов"):format(#list, Items.BagSlots)
	local selEntry
	for i, s in ipairs(slots) do
		local e = list[i]
		s.entry = e
		if e then
			local tier = Items.Tiers[e.item.tier]
			if s.iconId ~= e.item.id then
				s.iconId = e.item.id
				s.icon.ImageTransparency = 1
				U.tween(s.icon, 0.25, { ImageTransparency = 0 })
			end
			s.icon.Image = Icons.items[e.item.id] or ""
			s.icon.Visible = true
			s.count.Text = "x" .. e.n
			U.tween(s.stroke, 0.18, { Color = tier.color }) -- толщину рамки задаёт цикл ниже
			U.tween(s.bg, 0.18, { BackgroundColor3 = U.darken(tier.color, 0.22) })
			s.shine.Visible = tier.order >= 4
			if e.item.id == selected then
				selEntry = e
			end
		else
			s.icon.Visible = false
			s.iconId = nil
			s.count.Text = ""
			U.tween(s.stroke, 0.18, { Color = C(55, 62, 55), Thickness = 1.5 })
			U.tween(s.bg, 0.18, { BackgroundColor3 = C(24, 28, 24) })
			s.shine.Visible = false
		end
	end
	if not selEntry then
		selEntry = list[1]
	end
	showDetails(selEntry)
	for _, s in ipairs(slots) do
		if s.entry then
			U.tween(s.stroke, 0.18, { Thickness = s.entry.item.id == selected and 4 or 2 })
		end
	end
end

local function act(action)
	if not selected then
		return
	end
	local ok, res = pcall(function()
		return Remotes.BagAction:InvokeServer(action, selected)
	end)
	if ok and res then
		if res.ok then
			api.toast(res.msg or "Готово", "good")
			U.play(U.Sounds.pop, 0.5, 1.4)
		else
			api.toast(res.err or "Не получилось", "bad")
		end
	end
end

local function buildWindow()
	win = new("Frame", {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 520),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, { U.corner(18), U.stroke(C(80, 170, 255), 3), U.grad(C(255, 255, 255), C(160, 170, 175), 90) })
	scaleObj = api.addScale(win)
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = C(24, 40, 60), Parent = win }, { U.corner(18), U.grad(C(255, 255, 255), C(150, 170, 200), 90) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.bag, Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(12, 7), Parent = header })
	local title = titleLabel(header, "РЮКЗАК", UDim2.new(0, 240, 0, 34), UDim2.fromOffset(70, 6), C(255, 255, 255))
	new("UIGradient", { Color = ColorSequence.new(C(190, 230, 255), C(80, 170, 255)), Rotation = 90, Parent = title })
	kindsText = titleLabel(header, "", UDim2.new(0, 300, 0, 16), UDim2.fromOffset(72, 40), T.Muted, Enum.Font.GothamBold)
	local close = api.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = T.Danger,
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 20,
		TextColor3 = C(255, 255, 255),
		Parent = header,
	}, function()
		api.closeWindow(win, scaleObj)
	end)
	U.corner(10).Parent = close

	-- левая колонка: лом + подробности
	local left = new("Frame", { Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(300, 432), BackgroundColor3 = T.Panel, Parent = win }, { U.corner(14), U.stroke(C(60, 70, 60), 1.5) })
	lvlText = titleLabel(left, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 10), C(150, 210, 255))
	local capBg = new("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 30), BackgroundColor3 = C(10, 12, 10), Parent = left }, { U.corner(9), U.stroke(C(70, 80, 70), 1.5) })
	capBar = new("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = C(255, 255, 255), Parent = capBg }, { U.corner(9), U.grad(C(170, 255, 90), C(70, 160, 30), 90) })
	capText = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = C(255, 255, 255), ZIndex = 3, Parent = capBg }, { U.textStroke(C(0, 0, 0), 1.6) })
	upBtn = api.button({
		Position = UDim2.fromOffset(12, 72),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundColor3 = T.Accent,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = C(20, 30, 10),
		Text = "",
		Parent = left,
	}, function()
		Remotes.UpgradeBag:FireServer()
	end)
	U.corner(10).Parent = upBtn
	matsText = new("TextLabel", { Position = UDim2.fromOffset(12, 110), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, TextColor3 = T.Muted, Text = "", Parent = left })

	local box = new("Frame", { Position = UDim2.fromOffset(12, 144), Size = UDim2.new(1, -24, 1, -156), BackgroundColor3 = C(20, 24, 20), Parent = left }, { U.corner(12) })
	det.stroke = U.stroke(C(80, 90, 80), 2)
	det.stroke.Parent = box
	det.empty = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		TextSize = 15,
		TextColor3 = T.Muted,
		Text = "Рюкзак пуст.\n\nСобирай лом и убивай зомби — иногда в кучах попадаются редкие находки. Ночью их вдвое больше!",
		Parent = box,
	}, { U.pad(14) })
	det.box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = box })
	det.glow = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0.5, -65, 0, -6), ImageTransparency = 0.3, Parent = det.box })
	det.icon = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0.5, -48, 0, 10), ZIndex = 3, Parent = det.box })
	det.name = new("TextLabel", { Position = UDim2.fromOffset(8, 110), Size = UDim2.new(1, -16, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Parent = det.box }, { U.textStroke(C(0, 0, 0), 1.8) })
	det.tier = new("TextLabel", { Position = UDim2.fromOffset(8, 136), Size = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 13, Parent = det.box })
	det.desc = new("TextLabel", { Position = UDim2.fromOffset(10, 156), Size = UDim2.new(1, -20, 0, 48), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextWrapped = true, TextSize = 13, TextColor3 = T.Text, TextYAlignment = Enum.TextYAlignment.Top, Parent = det.box })
	det.value = new("TextLabel", { Position = UDim2.fromOffset(10, 204), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Battery, Parent = det.box })
	local function actBtn(text, y, color, tcolor, action)
		local b = api.button({ Position = UDim2.new(0, 10, 1, y), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = color, Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = tcolor, Text = text, Parent = det.box }, function()
			act(action)
		end)
		U.corner(8).Parent = b
		return b
	end
	det.use = actBtn("✔ ИСПОЛЬЗОВАТЬ", -104, C(80, 200, 255), C(10, 25, 40), "use")
	det.sell = actBtn("ПРОДАТЬ 1", -70, T.Hazard, C(40, 25, 0), "sell")
	det.sellAll = actBtn("ПРОДАТЬ ВСЕ", -36, C(235, 120, 40), C(40, 15, 0), "sellall")

	-- сетка предметов 5x4
	grid = new("Frame", { Position = UDim2.fromOffset(328, 74), Size = UDim2.fromOffset(478, 432), BackgroundColor3 = T.Panel, Parent = win }, {
		U.corner(14),
		U.stroke(C(60, 70, 60), 1.5),
		U.pad(10),
		new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, Items.BagSlots do
		local s = {}
		s.bg = api.button({ BackgroundColor3 = C(24, 28, 24), Text = "", LayoutOrder = i, Parent = grid }, function()
			if s.entry then
				selected = s.entry.item.id
				BagUI.Refresh()
			end
		end)
		U.corner(12).Parent = s.bg
		s.stroke = U.stroke(C(55, 62, 55), 1.5)
		s.stroke.Parent = s.bg
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(130, 130, 130)), Parent = s.bg })
		s.shine = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", Size = UDim2.fromScale(1, 1), ImageTransparency = 0.5, Visible = false, Parent = s.bg })
		s.icon = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, -32, 0, 8), Visible = false, ZIndex = 3, Parent = s.bg })
		s.count = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), Size = UDim2.fromOffset(60, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = s.bg }, { U.textStroke(C(0, 0, 0), 1.6) })
		slots[i] = s
	end
end

function BagUI.Toggle()
	if U.isOpen(win, scaleObj) then
		api.closeWindow(win, scaleObj)
	else
		if api.closeOthers then
			api.closeOthers()
		end
		BagUI.Refresh()
		api.openWindow(win, scaleObj)
	end
end

function BagUI.Close()
	if win then
		api.closeWindow(win, scaleObj)
	end
end

function BagUI.IsOpen()
	return U.isOpen(win, scaleObj)
end

-- ===== ЧАСЫ ДЕНЬ/НОЧЬ =====
local function buildClock()
	local f = new("Frame", {
		Name = "DayClock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(250, 44),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
		Parent = api.gui,
	}, { U.corner(22), U.grad(C(255, 255, 255), C(170, 170, 170), 90) })
	clock.frame = f
	clock.scale = api.addScale(f)
	clock.stroke = U.stroke(C(255, 200, 80), 2.5)
	clock.stroke.Parent = f
	clock.icon = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.sun, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(4, 2), Parent = f })
	clock.title = new("TextLabel", { Position = UDim2.fromOffset(48, 3), Size = UDim2.new(1, -56, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 230, 140), Parent = f }, { U.textStroke(C(0, 0, 0), 1.5) })
	clock.sub = new("TextLabel", { Position = UDim2.fromOffset(48, 23), Size = UDim2.new(1, -56, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Text, Parent = f })
	local pbg = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 3), Size = UDim2.new(1, -40, 0, 4), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.4, Parent = f }, { U.round() })
	clock.prog = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C(255, 200, 80), Parent = pbg }, { U.round() })
end

local function updateClock()
	local night, left, frac = DayNight.Info()
	if night then
		clock.icon.Image = Icons.moon
		clock.title.Text = "НОЧЬ  •  УРОН И НАГРАДЫ x2"
		clock.title.TextColor3 = C(190, 170, 255)
		clock.sub.Text = "Рассвет через " .. fmtTime(left)
		clock.stroke.Color = C(150, 120, 255)
		clock.prog.BackgroundColor3 = C(150, 120, 255)
	else
		clock.icon.Image = Icons.sun
		clock.title.Text = "ДЕНЬ"
		clock.title.TextColor3 = C(255, 230, 140)
		clock.sub.Text = "Ночь наступит через " .. fmtTime(left)
		clock.stroke.Color = left < 60 and C(255, 120, 60) or C(255, 200, 80)
		clock.prog.BackgroundColor3 = C(255, 200, 80)
	end
	clock.prog.Size = UDim2.fromScale(math.clamp(1 - frac, 0, 1), 1)
	clock.icon.Rotation = night and 0 or (os.clock() * 10) % 360
end

-- ===== ПОЛОСКА БОССА =====
local function buildBossBar()
	local f = new("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(560, 64),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = api.gui,
	})
	bossBar.frame = f
	bossBar.scale = api.addScale(f)
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.boss, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(-8, 4), ZIndex = 3, Parent = f })
	bossBar.name = new("TextLabel", { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -60, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255), Text = "", Parent = f }, { U.textStroke(C(40, 0, 0), 2), U.grad(C(255, 220, 140), C(255, 80, 50), 90) })
	local bg = new("Frame", { Position = UDim2.fromOffset(40, 28), Size = UDim2.new(1, -40, 0, 24), BackgroundColor3 = C(20, 8, 8), Parent = f }, { U.corner(8), U.stroke(C(0, 0, 0), 2) })
	bossBar.ghost = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 230, 200), BackgroundTransparency = 0.3, Parent = bg }, { U.corner(8) })
	bossBar.fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), ZIndex = 2, Parent = bg }, { U.corner(8), U.grad(C(255, 110, 70), C(160, 10, 20), 90) })
	bossBar.text = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = C(255, 255, 255), ZIndex = 3, Parent = bg }, { U.textStroke(C(0, 0, 0), 1.6) })
	bossBar.sub = new("TextLabel", { Position = UDim2.fromOffset(40, 54), Size = UDim2.new(1, -40, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C(255, 200, 190), Parent = f }, { U.textStroke(C(0, 0, 0), 1.2) })
	bossBar.ghostRatio = 1
end

local bossField
for _, f in ipairs(Config.Fields) do
	if f.boss then
		bossField = f
	end
end

local function updateBossBar(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local near = false
	if bossField and hrp then
		local c = bossField.center
		near = Vector3.new(hrp.Position.X - c.X, 0, hrp.Position.Z - c.Z).Magnitude < bossField.size / 2 + 30
	end
	-- полоска босса плавно выезжает / сворачивается
	if near ~= bossBar.shown then
		bossBar.shown = near
		if near then
			local sc = bossBar.scale
			U.openPanel(bossBar.frame, sc, sc:GetAttribute("Animating") and sc:GetAttribute("BaseScale") or sc.Scale)
		else
			U.closePanel(bossBar.frame, bossBar.scale)
		end
	end
	if not near then
		return
	end
	-- заполнение догоняет реальное HP плавно, а не прыжком
	local function fillTo(r)
		local cur = bossBar.fill.Size.X.Scale
		bossBar.fill.Size = UDim2.fromScale(cur + (r - cur) * math.min(1, (dt or 0.016) * 12), 1)
	end
	local zf = workspace:FindFirstChild("Zombies")
	local boss = zf and zf:FindFirstChild("Boss_Colossus")
	local hum = boss and boss:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		local r = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		fillTo(r)
		bossBar.ghostRatio = math.max(r, bossBar.ghostRatio - dt * 0.15)
		if bossBar.ghostRatio < r then
			bossBar.ghostRatio = r
		end
		bossBar.ghost.Size = UDim2.fromScale(bossBar.ghostRatio, 1)
		bossBar.name.Text = "☠ " .. (boss:GetAttribute("BossName") or "БОСС"):upper() .. (workspace:GetAttribute("ZSS_Night") and "  •  НОЧЬЮ БЬЁТ x2" or "")
		bossBar.text.Text = U.fmt(math.ceil(hum.Health)) .. " / " .. U.fmt(hum.MaxHealth) .. ("  (%.1f%%)"):format(r * 100)
		bossBar.sub.Text = ""
	else
		local at = workspace:GetAttribute("ZSS_BossRespawn") or 0
		fillTo(0)
		bossBar.ghostRatio = math.max(0, bossBar.ghostRatio - (dt or 0.016) * 0.6)
		bossBar.ghost.Size = UDim2.fromScale(bossBar.ghostRatio, 1)
		bossBar.name.Text = "☠ КОЛОСС ПОВЕРЖЕН"
		bossBar.text.Text = at > 0 and ("Возродится через " .. fmtTime(at - workspace:GetServerTimeNow())) or ""
		bossBar.sub.Text = ""
	end
end

-- ===== АКТИВНЫЕ БАФФЫ: квадратные плитки над полоской здоровья (как в Bee Swarm Simulator) =====
-- тёмная шторка опускается сверху по мере того, как истекает время; в углах — секунды и множитель
local TILE = 54
local function buildBuff()
	local f = new("Frame", {
		Name = "Buffs",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(6 * (TILE + 8), TILE + 22),
		BackgroundTransparency = 1,
		Parent = api.gui,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	buff.frame = f
	buff.scale = api.addScale(f)
	buff.chips = {}
	for _, b in ipairs(Buffs.List) do
		if b.time > 0 then
			-- держатель с запасом сверху под «прыжок» при новой ступени
			local holder = new("Frame", { Name = b.id, LayoutOrder = b.index, Size = UDim2.fromOffset(TILE, TILE + 18), BackgroundTransparency = 1, Visible = false, Parent = f })
			local scale = new("UIScale", { Parent = holder })
			local glow = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = b.color, ImageTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -TILE / 2), Size = UDim2.fromOffset(TILE * 1.9, TILE * 1.9), ZIndex = 1, Parent = holder })
			-- тень
			new("Frame", { Position = UDim2.new(0, 0, 1, -TILE + 3), Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.55, ZIndex = 1, Parent = holder }, { U.corner(12) })
			local tile = new("CanvasGroup", { Position = UDim2.new(0, 0, 1, -TILE), Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = C(255, 255, 255), ZIndex = 2, Parent = holder }, {
				U.corner(12),
				new("UIGradient", { Rotation = 90, Color = ColorSequence.new(b.color:Lerp(C(255, 255, 255), 0.15), b.color:Lerp(C(0, 0, 0), 0.55)) }),
			})
			-- блик сверху
			new("Frame", { Size = UDim2.new(1, 0, 0.45, 0), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 2, Parent = tile })
			local icon = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.buffs[b.id] or Icons.speed, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(TILE - 12, TILE - 12), ZIndex = 3, Parent = tile })
			-- шторка истекшего времени
			local shade = new("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 4, Parent = tile })
			local edge = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = tile })
			local stroke = U.stroke(b.color:Lerp(C(255, 255, 255), 0.35), 2.5)
			stroke.Parent = tile
			-- секунды (сверху слева) и множитель (снизу справа)
			local sec = new("TextLabel", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(TILE - 8, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 13, Text = "", TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = tile }, { U.textStroke(C(0, 0, 0), 1.6) })
			local mult = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1), Size = UDim2.fromOffset(TILE - 4, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, Text = "", TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = tile }, { U.textStroke(C(0, 0, 0), 2) })
			-- точки-ступени под плиткой (до 10)
			local pipsRow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(TILE, 8), BackgroundTransparency = 1, Parent = holder }, {
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 1) }),
			})
			local pips = {}
			for k = 1, Buffs.MaxStacks do
				pips[k] = new("Frame", { Size = UDim2.fromOffset(4, 6), BackgroundColor3 = b.color, BackgroundTransparency = 0.8, BorderSizePixel = 0, LayoutOrder = k, Parent = pipsRow }, { U.corner(2) })
			end
			-- подсказка по наведению
			local tip = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(190, 40), BackgroundColor3 = C(18, 20, 26), BackgroundTransparency = 0.08, Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, Text = "", TextColor3 = C(255, 255, 255), Visible = false, ZIndex = 20, Parent = holder }, { U.corner(8), U.stroke(b.color, 1.5) })
			holder.MouseEnter:Connect(function()
				U.fadeVisible(tip, true, 0.15)
			end)
			holder.MouseLeave:Connect(function()
				U.fadeVisible(tip, false, 0.15)
			end)
			buff.chips[b.id] = { frame = holder, scale = scale, glow = glow, icon = icon, shade = shade, edge = edge, stroke = stroke, sec = sec, mult = mult, pips = pips, tip = tip, def = b, stacks = 0, untilT = 0, bump = 0 }
		end
	end
end

local function updateBuff(dt)
	local now = workspace:GetServerTimeNow()
	for id, c in pairs(buff.chips or {}) do
		local b = c.def
		local untilT = player:GetAttribute("ZSS_Buff_" .. id) or 0
		local left = untilT - now
		local stacks = left > 0 and (player:GetAttribute("ZSS_BuffN_" .. id) or 1) or 0
		if left > 0 then
			if not c.frame.Visible or c.leaving then
				-- появление: ячейка раздвигает соседей и выпрыгивает с пружинкой
				if not c.frame.Visible then
					c.scale.Scale = 0.3
					c.frame.Size = UDim2.fromOffset(0, TILE + 18)
				end
				c.leaving = false
				c.frame.Visible = true
				U.tween(c.frame, 0.25, { Size = UDim2.fromOffset(TILE, TILE + 18) }, Enum.EasingStyle.Quart)
				U.tween(c.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			if c.untilT > 0 and (stacks > c.stacks or untilT > c.untilT + 0.5) then
				-- новая ступень / продление: толчок и вспышка
				c.bump = 1
				if stacks > c.stacks and c.stacks > 0 then
					U.play(U.Sounds.tick, 0.35, 1 + stacks * 0.06)
				end
			end
			c.stacks, c.untilT = stacks, untilT
			local frac = 1 - math.clamp(left / b.time, 0, 1)
			c.shade.Size = UDim2.fromScale(1, frac)
			c.edge.Position = UDim2.fromScale(0, frac)
			c.edge.Visible = frac > 0.02 and frac < 0.98
			c.sec.Text = left >= 10 and tostring(math.floor(left)) or ("%.1f"):format(left)
			local m = 1 + b.per * stacks
			c.mult.Text = Buffs.MultText(m)
			if c.pipStacks ~= stacks then
				c.pipStacks = stacks
				for k, pip in ipairs(c.pips) do
					U.tween(pip, 0.2, { BackgroundTransparency = k <= stacks and 0 or 0.8 })
				end
			end
			c.tip.Text = ("%s  %d/%d\n%s %s • %.1f сек"):format(b.name, stacks, Buffs.MaxStacks, b.desc, Buffs.MultText(m), left)
			-- осталось мало времени — плитка мигает
			local blink = left < 3 and (0.5 + 0.5 * math.sin(now * 14)) or 1
			c.icon.ImageTransparency = 0.35 * (1 - blink)
			c.bump = math.max(0, c.bump - (dt or 0.016) * 3.2)
			if c.scale.Scale > 0.99 or c.bump > 0 then
				c.scale.Scale = 1 + 0.18 * math.sin(c.bump * math.pi) * c.bump
			end
			c.glow.ImageTransparency = 0.75 - 0.45 * c.bump - (stacks >= Buffs.MaxStacks and 0.15 * (0.5 + 0.5 * math.sin(now * 4)) or 0)
			c.glow.Rotation = now * 30
			c.stroke.Color = c.stroke.Color:Lerp(stacks >= Buffs.MaxStacks and C(255, 230, 120) or b.color:Lerp(C(255, 255, 255), 0.35), math.min(1, (dt or 0.016) * 10))
		elseif c.frame.Visible and not c.leaving then
			-- исчезновение: плитка сжимается, соседи плавно сдвигаются
			c.leaving = true
			c.stacks, c.untilT, c.bump, c.pipStacks = 0, 0, 0, nil
			U.tween(c.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			U.tween(c.frame, 0.25, { Size = UDim2.fromOffset(0, TILE + 18) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			local token = {}
			c.leaveToken = token
			task.delay(0.25, function()
				if c.leaving and c.leaveToken == token then
					c.leaving = false
					c.frame.Visible = false
				end
			end)
		end
	end
end

-- ===== НАГРАДА ЗА БОССА =====
function BagUI.ShowBossReward(d)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 250),
		BackgroundColor3 = C(30, 12, 12),
		ZIndex = 40,
		Parent = api.gui,
	}, { U.corner(20), U.stroke(C(255, 190, 60), 3), U.grad(C(255, 255, 255), C(150, 120, 120), 90) })
	local sc = api.addScale(f)
	sc:SetAttribute("Animating", true)
	local target = sc.Scale
	sc.Scale = target * 0.3
	U.tween(sc, 0.4, { Scale = target }, Enum.EasingStyle.Back)
	sc:SetAttribute("BaseScale", target)
	task.delay(0.41, function()
		sc:SetAttribute("Animating", nil)
	end)
	local function dismiss()
		U.closePanel(f, sc)
		task.delay(0.25, function()
			f:Destroy()
		end)
	end
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.boss, Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, -36, 0, -40), ZIndex = 41, Parent = f })
	local t = new("TextLabel", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "КОЛОСС ПОВЕРЖЕН!", TextColor3 = C(255, 255, 255), ZIndex = 41, Parent = f }, { U.textStroke(C(60, 0, 0), 2.5) })
	new("UIGradient", { Color = ColorSequence.new(C(255, 240, 150), C(255, 120, 40)), Rotation = 90, Parent = t })
	new("TextLabel", { Position = UDim2.fromOffset(10, 72), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, Text = ("Твой вклад в урон: %.1f%%"):format((d.share or 0) * 100), TextColor3 = T.Muted, ZIndex = 41, Parent = f })
	local row = new("Frame", { Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 0, 46), BackgroundTransparency = 1, ZIndex = 41, Parent = f }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 24) }) })
	local function reward(icon, text, color)
		local r = new("Frame", { Size = UDim2.fromOffset(170, 46), BackgroundTransparency = 1, ZIndex = 41, Parent = row })
		new("ImageLabel", { BackgroundTransparency = 1, Image = icon, Size = UDim2.fromOffset(44, 44), ZIndex = 42, Parent = r })
		new("TextLabel", { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = r }, { U.textStroke(C(0, 0, 0), 2) })
	end
	reward(Icons.gem, "+" .. U.fmt(d.gems), C(120, 230, 255))
	reward(Icons.battery, "+" .. U.fmt(d.batteries), T.Battery)
	new("TextLabel", { Position = UDim2.fromOffset(16, 150), Size = UDim2.new(1, -32, 0, 56), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextWrapped = true, TextSize = 14, Text = (#(d.items or {}) > 0) and ("Находки: " .. table.concat(d.items, ", ")) or "Рюкзак переполнен — предметы не поместились", TextColor3 = C(255, 230, 200), ZIndex = 41, Parent = f })
	local ok = api.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(160, 34), BackgroundColor3 = C(255, 190, 60), Font = Enum.Font.GothamBlack, TextSize = 16, Text = "ЗАБРАТЬ", TextColor3 = C(40, 20, 0), ZIndex = 42, Parent = f }, function()
		dismiss()
	end)
	U.corner(10).Parent = ok
	U.play(U.Sounds.pop, 0.8, 0.9)
	task.delay(12, function()
		if f.Parent then
			dismiss()
		end
	end)
end

function BagUI.ApplyLayout(mobile)
	if bossBar.frame then
		bossBar.frame.Position = mobile and UDim2.new(0.5, 0, 0, 96) or UDim2.new(0.5, 0, 0, 12)
	end
	if clock.frame then
		-- на телефоне сверху справа вкладки — часы ставим под панелью ресурсов
		clock.frame.AnchorPoint = mobile and Vector2.new(0, 0) or Vector2.new(0.5, 0)
		clock.frame.Position = mobile and UDim2.new(0, 12, 0, 104) or UDim2.new(0.5, 0, 0, 8)
		if bossBar.frame then
			bossBar.frame.Position = mobile and UDim2.new(0.5, 0, 0, 96) or UDim2.new(0.5, 0, 0, 60)
		end
	end
	if buff.frame then
		buff.frame.Position = mobile and UDim2.new(0.5, 0, 1, -122) or UDim2.new(0.5, 0, 1, -128)
	end
end

function BagUI.Init(a)
	api = a
	buildWindow()
	-- часы дня/ночи убраны из HUD (цикл работает, ночь видно по освещению)
	buildBossBar()
	buildBuff()
	State.Changed:Connect(function(d)
		if win.Visible then
			BagUI.Refresh(d)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		updateBossBar(dt)
		updateBuff(dt)
	end)
end

return BagUI
