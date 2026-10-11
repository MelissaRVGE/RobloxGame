-- Инвентарь (B): персонаж в 3D с надетым снаряжением, ячейки снаряжения, характеристики с баффами,
-- хранилище всех купленных вещей и находок. Наведение на любой предмет показывает его характеристики.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Items = require(Shared.ItemsConfig)
local Shop = require(Shared.ShopConfig)
local IB = require(Shared.ItemBuilder)
local Builder = require(Shared.DroneBuilder)
local Icons = require(Shared.Icons)
local Buffs = require(Shared.BuffsConfig)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local Inv = {}
local api
local win, scaleObj, body, fitScale

-- ===== РАЗМЕТКА =====
local W, H = 1100, 580
-- персонаж — посередине окна: окошко у центра экрана, и перспектива камеры не растягивает модель
-- (у края широкого экрана близкий объект виден сбоку и заметно расплывается вширь)
local MID = { x = 14, y = 72, w = 300, h = 494 }
local LEFT = { x = 324, y = 72, w = 400, h = 494 }
local RIGHT = { x = 734, y = 72, w = 352, h = 494 }
local SLOT = 76
-- окошко, сквозь которое виден 3D-персонаж (в координатах левой панели)
local HOLE = { x = 100, y = 12, w = 200, h = 380 }
local CELL = Vector2.new(74, 86)

local SLOT_DEFS = {
	{ key = "helmet", name = "Шлем", icon = "⛑", side = 0, row = 0 },
	{ key = "armor", name = "Броня", icon = "🛡", side = 0, row = 1 },
	{ key = "gloves", name = "Перчатки", icon = "🧤", side = 0, row = 2 },
	{ key = "boots", name = "Ботинки", icon = "🥾", side = 0, row = 3 },
	{ key = "weapon", name = "Оружие", icon = "⚔", side = 1, row = 0 },
	{ key = "tool", name = "Инструмент", icon = "⛏", side = 1, row = 1 },
	{ key = "backpack", name = "Рюкзак", icon = "🎒", side = 1, row = 2 },
}
local SLOT_NAME = {}
for _, s in ipairs(Shop.Slots) do
	SLOT_NAME[s.key] = s
end
-- слоты, которые нельзя снять (только заменить другим предметом)
local FIXED = { weapon = true, tool = true, backpack = true }

local STAT_LABELS = {
	dmg = "⚔ Урон",
	radius = "◎ Радиус удара",
	gather = "⛏ Добыча за удар",
	cd = "⏱ Удар раз в",
	hp = "❤ Здоровье",
	def = "🛡 Защита",
	scrap = "⚙ Бонус лома",
	speed = "» Скорость",
	jump = "⬆ Прыжок",
	heal = "❤ Лечение",
	energy = "⚡ Заряд роя",
	cap = "🎒 Вместимость",
	conv = "♻ Батарей с переработки",
	cspeed = "⏩ Скорость переработки",
	stacks = "» Ступени ускорения",
}
local STAT_ORDER = { "dmg", "radius", "gather", "cd", "hp", "def", "scrap", "speed", "jump", "cap", "conv", "cspeed", "heal", "energy", "stacks" }
local PCT = { def = true, scrap = true, energy = true, cap = true, conv = true, cspeed = true }

local function fmtNum(v)
	if math.abs(v - math.floor(v)) < 0.001 then
		return U.fmt(v)
	end
	return (("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
end

local function fmtStat(k, v)
	if PCT[k] then
		return ("+%d%%"):format(math.floor(v * 100 + 0.5))
	elseif k == "cd" then
		return ("%.2f с"):format(v)
	elseif k == "speed" or k == "jump" or k == "hp" or k == "heal" or k == "stacks" then
		return "+" .. fmtNum(v)
	end
	return fmtNum(v)
end

local function fmtDelta(k, d)
	if PCT[k] then
		return ("%+d%%"):format(math.floor(d * 100 + (d >= 0 and 0.5 or -0.5)))
	elseif k == "cd" then
		return ("%+.2f с"):format(d)
	end
	return (d >= 0 and "+" or "-") .. fmtNum(math.abs(d))
end

local function gradeOf(item)
	return Shop.Grades[item.grade or 1] or Shop.Grades[1]
end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	if s >= 60 then
		return ("%d:%02d"):format(math.floor(s / 60), s % 60)
	end
	return s .. "с"
end

local function label(parent, props, stroke)
	props.BackgroundTransparency = 1
	props.Parent = parent
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or T.Text
	return new("TextLabel", props, stroke and { U.textStroke(C(0, 0, 0), stroke) } or nil)
end

local function setVp(vp, item)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local m = IB.Preview(item)
	local wear = item.slot == "armor" or item.slot == "gloves" or item.slot == "boots"
	Builder.SetupViewport(vp, m, math.rad(30), math.rad(15), wear and 0.85 or 1.0)
end

local function itemVp(parent, props)
	props.BackgroundTransparency = 1
	props.Ambient = C(165, 165, 165)
	props.LightDirection = Vector3.new(-0.4, -1, 0.6)
	props.Parent = parent
	return new("ViewportFrame", props)
end

-- ======================================================================
-- ПОДСКАЗКА: карточка рядом с предметом, плавно появляется и переезжает между ячейками
-- ======================================================================
local tip = {}

local function buildTip()
	tip.holder = new("Frame", {
		Name = "InvTooltip",
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 300,
		Parent = api.gui,
	})
	tip.scale = api.addScale(tip.holder)
	tip.card = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C(16, 19, 24),
		GroupTransparency = 1,
		ZIndex = 300,
		Parent = tip.holder,
	}, { U.corner(12), U.grad(C(255, 255, 255), C(175, 180, 190), 90) })
	tip.pop = U.scaleOf(tip.card)
	tip.stroke = U.stroke(C(120, 120, 120), 2)
	tip.stroke.Parent = tip.holder
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = tip.holder })
	tip.body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 301,
		Parent = tip.card,
	}, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})
	-- цветная полоса сверху
	tip.band = new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, ZIndex = 305, Parent = tip.card })
end

local function tipText(order, text, size, color, font, wrap)
	return new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, wrap and 0 or size + 4),
		AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.GothamBold,
		Text = text,
		TextSize = size,
		TextWrapped = wrap or false,
		TextColor3 = color or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 302,
		Parent = tip.body,
	})
end

local function tipLine(order, name, value, color, delta, deltaColor)
	local row = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.95, ZIndex = 302, Parent = tip.body }, { U.corner(5) })
	new("TextLabel", { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0.6, -6, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, Text = name, TextColor3 = C(200, 208, 200), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303, Parent = row })
	new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, delta and -64 or -6, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 14, Text = value, TextColor3 = color or C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 303, Parent = row })
	if delta then
		new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.fromOffset(58, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, Text = delta, TextColor3 = deltaColor, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 303, Parent = row })
	end
end

local function tipSep(order)
	new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 302, Parent = tip.body })
end

-- spec = { title, color, sub, lines = { {name, value, color, delta, deltaColor} }, desc, footer, footerColor }
local function placeTip(anchor, instant)
	if not anchor or not anchor.Parent then
		return
	end
	local gp = api.gui.AbsolutePosition
	local gs = api.gui.AbsoluteSize
	local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	local ts = tip.holder.AbsoluteSize
	local gap = 10
	local x = ap.X + as.X + gap
	if x + ts.X > gp.X + gs.X - 6 then
		x = ap.X - gap - ts.X
	end
	local y = math.clamp(ap.Y, gp.Y + 6, gp.Y + gs.Y - ts.Y - 6)
	local pos = UDim2.fromOffset(math.floor(x - gp.X + 0.5), math.floor(y - gp.Y + 0.5))
	if instant then
		tip.holder.Position = pos
	else
		U.tween(tip.holder, 0.14, { Position = pos }, Enum.EasingStyle.Quart)
	end
end

local function showTip(anchor, spec)
	tip.token = (tip.token or 0) + 1
	tip.anchor = anchor
	for _, c in ipairs(tip.body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local o = 0
	local function nx()
		o += 1
		return o
	end
	local title = tipText(nx(), spec.title, 18, spec.color:Lerp(C(255, 255, 255), 0.2), Enum.Font.GothamBlack)
	U.textStroke(C(0, 0, 0), 1.4).Parent = title
	if spec.sub then
		tipText(nx(), spec.sub, 12, spec.color, Enum.Font.GothamBlack)
	end
	if spec.lines and #spec.lines > 0 then
		tipSep(nx())
		for _, l in ipairs(spec.lines) do
			tipLine(nx(), l[1], l[2], l[3], l[4], l[5])
		end
	end
	if spec.desc and spec.desc ~= "" then
		tipSep(nx())
		tipText(nx(), spec.desc, 13, C(190, 198, 190), Enum.Font.Gotham, true)
	end
	if spec.footer then
		tipSep(nx())
		tipText(nx(), spec.footer, 12, spec.footerColor or C(255, 220, 120), Enum.Font.GothamBlack, true)
	end
	tip.band.BackgroundColor3 = spec.color
	tip.stroke.Color = spec.color
	local wasShown = tip.holder.Visible and not tip.hiding
	tip.hiding = false
	if not wasShown then
		tip.holder.Visible = true
		tip.card.GroupTransparency = 1
		tip.pop.Scale = 0.92
		tip.stroke.Transparency = 1
	end
	-- размер карточки (AutomaticSize) известен только к следующему кадру
	local token = tip.token
	task.spawn(function()
		RunService.RenderStepped:Wait()
		if tip.token == token then
			placeTip(anchor, not wasShown)
		end
	end)
	U.tween(tip.card, 0.15, { GroupTransparency = 0 })
	U.tween(tip.stroke, 0.15, { Transparency = 0 })
	U.tween(tip.pop, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function hideTip(anchor)
	if anchor and tip.anchor ~= anchor then
		return
	end
	local token = (tip.token or 0) + 1
	tip.token = token
	-- небольшая пауза: при переходе на соседнюю ячейку подсказка не мигает, а переезжает
	task.delay(0.07, function()
		if tip.token ~= token or not tip.holder.Visible then
			return
		end
		tip.hiding = true
		tip.anchor = nil
		U.tween(tip.card, 0.12, { GroupTransparency = 1 })
		U.tween(tip.stroke, 0.12, { Transparency = 1 })
		U.tween(tip.pop, 0.12, { Scale = 0.95 })
		task.delay(0.13, function()
			if tip.token == token and tip.hiding then
				tip.holder.Visible = false
				tip.hiding = false
			end
		end)
	end)
end

local function bindTip(obj, getSpec)
	obj.MouseEnter:Connect(function()
		local spec = getSpec()
		if spec then
			tip.getSpec = getSpec
			showTip(obj, spec)
		end
	end)
	obj.MouseLeave:Connect(function()
		hideTip(obj)
	end)
end

-- ======================================================================
-- ДАННЫЕ
-- ======================================================================
local function data()
	return State.data
end

local function equipped(slot)
	local d = data()
	return d and d.gear and d.gear[slot]
end

local function isEquipped(item)
	return equipped(item.slot) == item.id
end

-- характеристики предмета + сравнение с тем, что надето в этом слоте
local function gearSpec(item, fromSlot)
	local g = gradeOf(item)
	local d = data()
	local cur = not fromSlot and equipped(item.slot)
	local curItem = cur and cur ~= item.id and Shop.ById[cur]
	local lines = {}
	local seen = {}
	for _, k in ipairs(STAT_ORDER) do
		local v = item.stats[k]
		local cv = curItem and curItem.stats[k]
		if v or cv then
			seen[k] = true
			local delta, dcol
			if curItem then
				local diff = (v or 0) - (cv or 0)
				if math.abs(diff) > 0.0001 then
					local better = (k == "cd") and diff < 0 or (k ~= "cd" and diff > 0)
					delta = (better and "▲ " or "▼ ") .. fmtDelta(k, diff)
					dcol = better and C(120, 255, 120) or C(255, 110, 100)
				else
					delta, dcol = "=", C(170, 170, 170)
				end
			end
			table.insert(lines, { STAT_LABELS[k] or k, v and fmtStat(k, v) or "—", v and C(255, 255, 255) or C(140, 140, 140), delta, dcol })
		end
	end
	local sub = (SLOT_NAME[item.slot] and SLOT_NAME[item.slot].name or item.slot):upper() .. "  •  " .. g.name:upper()
	if item.tier and item.slot ~= "backpack" then
		sub ..= ("  •  УР. %d"):format(item.tier)
	end
	local footer, fcol
	if item.stack then
		local n = d and d.consum and d.consum[item.id] or 0
		sub = "РАСХОДНИК  •  x" .. n
		footer, fcol = "ЛКМ — использовать (или клавиша в хотбаре)", C(130, 220, 255)
	elseif isEquipped(item) then
		footer = FIXED[item.slot] and "✔ НАДЕТО  •  заменить можно другим предметом" or "✔ НАДЕТО  •  ЛКМ — снять"
		fcol = C(140, 255, 120)
	else
		footer = curItem and ("ЛКМ — надеть вместо «%s»"):format(curItem.name) or "ЛКМ — надеть"
	end
	return { title = item.name, color = g.color, sub = sub, lines = lines, desc = item.desc, footer = footer, footerColor = fcol }
end

local function findSpec(it, n)
	local tier = Items.Tiers[it.tier]
	local lines = { { "🔋 Цена продажи", U.fmt(it.value), T.Battery }, { "Всего в рюкзаке", "x" .. n } }
	if n > 1 then
		table.insert(lines, { "🔋 Продать все", U.fmt(it.value * n), T.Battery })
	end
	local u = it.use
	if u then
		if u.heal then
			table.insert(lines, 1, { "❤ Лечение", u.heal >= 9999 and "полное" or ("+" .. u.heal), C(255, 140, 140) })
		end
		if u.speed then
			table.insert(lines, 1, { "» Скорость", ("+%d на %d с"):format(u.speed, u.time or 20), C(120, 230, 255) })
		end
		if u.energy then
			table.insert(lines, 1, { "⚡ Заряд роя", ("+%d%%"):format(u.energy * 100), C(120, 200, 255) })
		end
		if u.gems then
			table.insert(lines, 1, { "💎 Гемы", "+" .. u.gems, C(120, 230, 255) })
		end
	end
	return {
		title = it.name,
		color = tier.color,
		sub = "НАХОДКА  •  " .. tier.name:upper(),
		lines = lines,
		desc = it.desc,
		footer = u and "ЛКМ — выбрать, затем «Использовать» или «Продать»" or "ЛКМ — выбрать, затем «Продать». Нужна и для крафта в Магазине",
	}
end

-- ======================================================================
-- 3D-СЦЕНА: копия персонажа со всем снаряжением стоит прямо перед камерой, за окошком в окне.
-- ViewportFrame рисуется с пониженной частотой кадров, поэтому персонаж настоящий: крошечный
-- (STAGE_H стада) и в паре десятых стада от камеры, а тёмный задник сразу за ним.
-- ======================================================================
local STAGE_H = 0.2
local STAGE_PITCH = math.rad(7)
local ARM_RAISE = math.rad(80) -- правая рука с оружием поднята вперёд, как в игре
local stage = { yaw = math.rad(-18), vel = 0, idle = 0 }
local slotsUI = {}
local hole = {}

local JOINT_CLASSES = { Motor6D = true, Weld = true, ManualWeld = true, Snap = true, AccessoryWeld = true, Glue = true }

-- Поза покоя: ставим каждую деталь по суставам от HumanoidRootPart, без текущей анимации бега
local function restPose(m, root)
	local adj = {}
	local function link(a, b, rel)
		adj[a] = adj[a] or {}
		adj[b] = adj[b] or {}
		table.insert(adj[a], { b, rel })
		table.insert(adj[b], { a, rel:Inverse() })
	end
	for _, j in ipairs(m:GetDescendants()) do
		if JOINT_CLASSES[j.ClassName] and j.Part0 and j.Part1 and j.Part0:IsDescendantOf(m) and j.Part1:IsDescendantOf(m) then
			local extra = CFrame.identity
			if j.Name == "RightShoulder" and stage.armRaise then
				extra = CFrame.Angles(ARM_RAISE, 0, 0)
			end
			link(j.Part0, j.Part1, j.C0 * extra * j.C1:Inverse())
		elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 and j.Part0:IsDescendantOf(m) and j.Part1:IsDescendantOf(m) then
			link(j.Part0, j.Part1, j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame))
		elseif (j:IsA("RigidConstraint") or j:IsA("AnimationConstraint")) and j.Attachment0 and j.Attachment1 and j.Attachment0:IsDescendantOf(m) and j.Attachment1:IsDescendantOf(m) then
			-- новые суставы аватара (AnimationConstraint) и крепления аксессуаров: по их Attachment
			local extra = CFrame.identity
			if j.Name == "RightShoulder" and stage.armRaise then
				extra = CFrame.Angles(ARM_RAISE, 0, 0)
			end
			link(j.Attachment0.Parent, j.Attachment1.Parent, j.Attachment0.CFrame * extra * j.Attachment1.CFrame:Inverse())
		end
	end
	-- сцена неподвижная: суставы больше не нужны, а с ними перенос одной детали тянул бы за собой остальные
	for _, j in ipairs(m:GetDescendants()) do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("Constraint") then
			j:Destroy()
		end
	end
	local done = { [root] = true }
	local queue = { root }
	local i = 1
	while queue[i] do
		local p = queue[i]
		i += 1
		for _, e in ipairs(adj[p] or {}) do
			local q = e[1]
			if not done[q] then
				done[q] = true
				q.CFrame = p.CFrame * e[2]
				table.insert(queue, q)
			end
		end
	end
end

local function charSource()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not (hum and hrp and torso and char:FindFirstChild("Head")) then
		return nil
	end
	return char, hrp, torso
end

local function clearStage()
	if stage.model then
		stage.model:Destroy()
		stage.model = nil
	end
	stage.parts, stage.entries, stage.cfs = nil, nil, nil
end

local function buildStageBack()
	if stage.back then
		return
	end
	stage.back = new("Part", {
		Name = "ZSS_InvStage",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 0.02),
	})
	local sg = new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		LightInfluence = 0,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(420, 780),
		Parent = stage.back,
	})
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, Parent = sg }, {
		U.grad(C(22, 30, 44), C(8, 10, 16), 90),
	})
	-- лучи прожектора сверху
	stage.rays = {}
	for k = 1, 5 do
		local r = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -40),
			Size = UDim2.fromOffset(46 + k * 10, 900),
			BackgroundColor3 = C(255, 255, 255),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = sg,
		}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 1) }) }) })
		table.insert(stage.rays, { f = r, base = (k - 3) * 9, speed = 0.35 + k * 0.07, phase = k * 1.3 })
	end
	-- мягкое свечение цвета лучшего снаряжения за спиной
	stage.glow = {}
	for k = 1, 9 do
		local dd = 120 + k * 30
		table.insert(stage.glow, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(dd, dd),
			BackgroundTransparency = 0.955,
			BorderSizePixel = 0,
			ZIndex = 12 - k,
			Parent = sg,
		}, { U.round() }))
	end
	-- светлое пятно на «полу»
	for k = 1, 6 do
		table.insert(stage.glow, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromOffset(110 + k * 34, 24 + k * 9),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = sg,
		}, { U.round() }))
	end
	stage.keyAtt = new("Attachment", { Parent = stage.back })
	stage.key = new("PointLight", { Brightness = 1.4, Range = 1, Shadows = false, Color = C(255, 244, 230), Parent = stage.keyAtt })
	stage.fillAtt = new("Attachment", { Parent = stage.back })
	stage.fill = new("PointLight", { Brightness = 0.9, Range = 1, Shadows = false, Color = C(200, 215, 255), Parent = stage.fillAtt })
	stage.rimAtt = new("Attachment", { Parent = stage.back })
	stage.rim = new("PointLight", { Brightness = 1.2, Range = 1, Shadows = false, Parent = stage.rimAtt })
end

local function stageColor()
	local best
	for _, s in ipairs(SLOT_DEFS) do
		local it = equipped(s.key) and Shop.ById[equipped(s.key)]
		if it and (not best or (it.grade or 1) > (best.grade or 1)) then
			best = it
		end
	end
	return best and gradeOf(best).color or C(120, 170, 255)
end

local function rebuildStage()
	clearStage()
	local char, _, torso = charSource()
	if not char then
		return
	end
	buildStageBack()
	local d = data()
	local weaponItem = d and d.gear and Shop.ById[d.gear.weapon or ""]
	stage.armRaise = weaponItem ~= nil

	local was = char.Archivable
	char.Archivable = true
	local ok, m = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not m then
		return
	end
	for _, dsc in ipairs(m:GetDescendants()) do
		if dsc:IsA("BaseScript") or dsc:IsA("Sound") or dsc:IsA("Tool") or dsc:IsA("ForceField") or dsc:IsA("ProximityPrompt") or dsc:IsA("BillboardGui") or dsc.ClassName == "AudioEmitter" or dsc.ClassName == "AudioListener" then
			dsc:Destroy()
		end
	end
	local cTorso = m:FindFirstChild(torso.Name)
	-- броня и рюкзак лежат отдельно в Workspace и приварены к торсу — копируем и привариваем к копии
	local wf = workspace:FindFirstChild("ZSS_WornBackpacks")
	if wf then
		for _, w in ipairs(wf:GetChildren()) do
			if w.Name:sub(-#tostring(player.UserId) - 1) == "_" .. player.UserId then
				w.Archivable = true
				local cl = w:Clone()
				for _, j in ipairs(cl:GetDescendants()) do
					if j:IsA("JointInstance") and j.Part0 == torso then
						j.Part0 = cTorso
					end
				end
				cl.Parent = m
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.AutomaticScalingEnabled = false
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(0, 10, 0)
	restPose(m, root)
	-- оружие в правой руке (как Tool: хват по RightGripAttachment)
	local hand = m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm")
	if weaponItem and hand then
		local okW, wm = pcall(IB.Weapon, weaponItem)
		if okW and wm then
			local grip = hand:FindFirstChild("RightGripAttachment")
			local base = hand.CFrame * (grip and grip.CFrame or CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
			for _, j in ipairs(wm:GetDescendants()) do
				if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
					j:Destroy()
				end
			end
			for _, p in ipairs(wm:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = base * p.CFrame
				end
			end
			wm.Name = "HeldWeapon"
			wm.Parent = m
		end
	end
	-- габариты тела без крыльев и оружия: от макушки до подошв
	local top, bottom = -math.huge, math.huge
	for _, n in ipairs({ "Head", "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local p = m:FindFirstChild(n)
		if p then
			local half = p.Size.Y / 2
			top = math.max(top, p.Position.Y + half)
			bottom = math.min(bottom, p.Position.Y - half)
		end
	end
	if top - bottom < 1 then
		top, bottom = root.Position.Y + 2.6, root.Position.Y - 3
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("Light") or p:IsA("Fire") or p:IsA("Smoke") or p:IsA("Sparkles") then
			p.Enabled = false -- частицы и свет на таком масштабе превращаются в огромные пятна; свет сцены свой
		end
	end
	m.Name = "ZSS_InvCharacter"
	-- уменьшаем вручную (Model:ScaleTo у модели с Humanoid пересобирает скелет и сдвигает детали):
	-- размеры деталей и мешей, смещения от точки между ступнями
	local pivot = CFrame.new(root.Position.X, bottom, root.Position.Z)
	local s = STAGE_H / (top - bottom)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(p.CFrame)
			p.Size *= s
			p.CFrame = pivot * (rel - rel.Position + rel.Position * s)
		elseif p:IsA("SpecialMesh") then
			p.Scale *= s
			p.Offset *= s
		elseif p:IsA("Attachment") then
			p.Position *= s
		end
	end
	m.WorldPivot = pivot
	-- подставка под ногами: металлический диск и светящееся кольцо
	local col = stageColor()
	local disc = new("Part", { Name = "Pedestal", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Metal, Color = C(46, 52, 60), Size = Vector3.new(STAGE_H * 0.03, STAGE_H * 0.62, STAGE_H * 0.62), Parent = m })
	disc.CFrame = pivot * CFrame.new(0, -STAGE_H * 0.016, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local ring = new("Part", { Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = 0.15, Size = Vector3.new(STAGE_H * 0.012, STAGE_H * 0.66, STAGE_H * 0.66), Parent = m })
	ring.CFrame = pivot * CFrame.new(0, -STAGE_H * 0.024, 0) * CFrame.Angles(0, 0, math.pi / 2)
	stage.ring = ring

	local parts, entries = {}, {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			table.insert(entries, pivot:ToObjectSpace(p.CFrame))
		end
	end
	stage.model = m
	-- габариты сцены со всем снаряжением, оружием и крыльями: по ним подбирается расстояние до камеры,
	-- чтобы при любом повороте ничего не выходило за рамку окошка
	local top, low, rad = 0, 0, STAGE_H * 0.33
	for i, p in ipairs(parts) do
		local off = entries[i]
		local ext = p.Size.Magnitude / 2
		if p.Transparency < 1 then
			top = math.max(top, off.Y + ext)
			low = math.min(low, off.Y - ext)
			rad = math.max(rad, Vector2.new(off.X, off.Z).Magnitude + ext)
		end
	end
	stage.top, stage.low, stage.rad = top, low, rad
	stage.parts = parts
	stage.entries = entries
	stage.cfs = table.create(#parts)
	stage.shown = false
	for _, g in ipairs(stage.glow) do
		g.BackgroundColor3 = col
	end
	stage.rim.Color = col
	U.tween(hole.border, 0.35, { Color = col })
	for _, b in ipairs(hole.brackets) do
		U.tween(b, 0.35, { BackgroundColor3 = col })
	end
end

local rebuildToken = 0
local function queueRebuild(delay)
	rebuildToken += 1
	local token = rebuildToken
	task.delay(delay or 0.25, function()
		if token ~= rebuildToken then
			return
		end
		if win and win.Visible then
			-- вспышка прикрывает подмену модели
			if hole.flash then
				hole.flash.BackgroundTransparency = 0.55
				U.tween(hole.flash, 0.45, { BackgroundTransparency = 1 })
			end
			rebuildStage()
		else
			stage.dirty = true
		end
	end)
end

local function stageStep(dt)
	local cam = workspace.CurrentCamera
	local h = hole.frame
	local as = h and h.AbsoluteSize
	local frac, tanH, z
	local show = stage.model ~= nil and win and win.Visible and cam ~= nil and as.Y > 4 and as.X > 4
	if show then
		local vpY = math.max(cam.ViewportSize.Y, 1)
		frac = as.Y / vpY
		tanH = math.tan(math.rad(cam.FieldOfView) / 2)
		-- глубина, на которой вся сцена (высота и диаметр вращения) помещается в окошко с полями;
		-- ближний край модели крупнее из-за перспективы, поэтому запас на радиус
		local zH = (stage.top - stage.low) / (0.9 * frac * 2 * tanH)
		local zW = 2 * stage.rad / (0.9 * (as.X / vpY) * 2 * tanH)
		z = math.max(zH, zW) + stage.rad * 0.5
		z = math.max(z, 0.1 + stage.rad + 0.01)
		-- пока окно раскрывается, окошко маленькое — сцену прячем, чтобы она не торчала за краями
		local base = scaleObj:GetAttribute("BaseScale") or scaleObj.Scale
		show = as.Y >= HOLE.h * base * fitScale.Scale * 0.6
	end
	if show ~= stage.shown then
		stage.shown = show
		if stage.model then
			stage.model.Parent = show and cam or nil
		end
		if stage.back then
			stage.back.Parent = show and cam or nil
		end
	end
	if not show then
		return
	end
	local t = os.clock()
	dt = dt or 0.016
	-- вращение: тянешь мышью — крутится, отпустил — докручивается по инерции, потом сам медленно поворачивается
	if not stage.dragging then
		stage.vel *= math.exp(-dt * 3.5)
		stage.yaw += stage.vel * dt
		stage.idle += dt
		if stage.idle > 2.5 then
			local k = math.min(1, (stage.idle - 2.5) / 1.5)
			stage.yaw += dt * 0.28 * k
		end
	end
	local ap = h.AbsolutePosition
	local inset = GuiService:GetGuiInset()
	local ray = cam:ViewportPointToRay(ap.X + as.X / 2 + inset.X, ap.Y + as.Y / 2 + inset.Y)
	local camCF = cam.CFrame
	local look = camCF.LookVector
	local function at(depth)
		return camCF.Position + ray.Direction * (depth / ray.Direction:Dot(look))
	end
	local center = at(z)
	local up = camCF.UpVector
	-- сцена смотрит прямо на камеру (вдоль луча через окошко), а не параллельно экрану
	local rot = CFrame.lookAt(Vector3.zero, camCF.Position - center, up)
	local bob = math.sin(t * 1.6) * STAGE_H * 0.006
	-- центр персонажа — в центре окошка; поворот вокруг вертикальной оси через ступни
	local feet = CFrame.new(center - up * ((stage.top + stage.low) / 2) + up * bob) * rot * CFrame.Angles(-STAGE_PITCH, 0, 0) * CFrame.Angles(0, stage.yaw, 0)
	for i, off in ipairs(stage.entries) do
		stage.cfs[i] = feet * off
	end
	workspace:BulkMoveTo(stage.parts, stage.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if stage.ring then
		stage.ring.Transparency = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(t * 2.4))
	end
	-- задник сразу за персонажем
	local zb = z + stage.rad + STAGE_H * 0.08
	local hb = frac * 2 * tanH * zb * 1.1
	stage.back.Size = Vector3.new(hb * as.X / as.Y, hb, 0.02)
	stage.back.CFrame = CFrame.new(at(zb)) * rot
	-- ключевой свет спереди-сверху, контровой — сзади цветом снаряжения
	stage.keyAtt.Position = Vector3.new(-STAGE_H * 0.35, STAGE_H * 0.45, -(zb - z) - STAGE_H * 0.55)
	stage.key.Range = STAGE_H * 3
	-- мягкий заполняющий свет снизу спереди, чтобы ноги и низ брони не уходили в черноту
	stage.fillAtt.Position = Vector3.new(STAGE_H * 0.3, -STAGE_H * 0.35, -(zb - z) - STAGE_H * 0.5)
	stage.fill.Range = STAGE_H * 2.4
	stage.rimAtt.Position = Vector3.new(STAGE_H * 0.2, STAGE_H * 0.25, -STAGE_H * 0.05)
	stage.rim.Range = STAGE_H * 1.3
	for _, r in ipairs(stage.rays) do
		r.f.Rotation = r.base + math.sin(t * r.speed + r.phase) * 7
	end
end

-- ======================================================================
-- ОКНО
-- ======================================================================
local stats = {}
local buffChips = {}
local cap = {}
local tabs = { current = "gear" }
local gearCells, findCells = {}, {}
local gearFilter = "all"
local selectedFind
local act = {}
local power = {}

local function holedBackground(parent, w, h, hl, radius, color, g0, g1, z)
	local function piece(x, y, pw, ph, rounded)
		if pw <= 0 or ph <= 0 then
			return
		end
		local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(pw, ph), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 0, Parent = parent })
		if rounded then
			U.corner(radius).Parent = f
		end
		if g0 then
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(g0:Lerp(g1, y / h), g0:Lerp(g1, (y + ph) / h)), Parent = f })
		end
	end
	local bottomY = hl.y + hl.h
	piece(0, 0, w, hl.y, true)
	piece(0, hl.y - radius, w, radius, false)
	piece(0, bottomY, w, h - bottomY, true)
	piece(0, bottomY, w, radius, false)
	piece(0, hl.y - 1, hl.x, hl.h + 2, false)
	piece(hl.x + hl.w, hl.y - 1, w - hl.x - hl.w, hl.h + 2, false)
end

-- «полёт» предмета из хранилища в ячейку снаряжения
local function flyTo(fromObj, toObj, color)
	if not (fromObj and toObj and fromObj.Parent and toObj.Parent) then
		return
	end
	local gp = api.gui.AbsolutePosition
	local a = fromObj.AbsolutePosition + fromObj.AbsoluteSize / 2 - gp
	local b = toObj.AbsolutePosition + toObj.AbsoluteSize / 2 - gp
	local sz = math.max(24, fromObj.AbsoluteSize.X * 0.9)
	local orb = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(sz, sz), BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = color, ImageTransparency = 0.1, ZIndex = 250, Parent = api.gui })
	local star = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55), BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = color:Lerp(C(255, 255, 255), 0.6), ZIndex = 251, Parent = orb })
	U.tween(orb, 0.42, { Position = UDim2.fromOffset(b.X, b.Y), Size = UDim2.fromOffset(sz * 0.6, sz * 0.6) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	U.tween(star, 0.42, { Rotation = 240 })
	task.delay(0.4, function()
		U.tween(orb, 0.18, { ImageTransparency = 1, Size = UDim2.fromOffset(sz * 1.6, sz * 1.6) })
		U.tween(star, 0.18, { ImageTransparency = 1 })
		task.delay(0.2, function()
			orb:Destroy()
		end)
	end)
end

local function equipItem(item, fromObj)
	if item.stack then
		Remotes.UseItem:FireServer(item.id)
		U.play(U.Sounds.tap, 0.4, 1.2)
		return
	end
	local wasOn = isEquipped(item)
	if wasOn and FIXED[item.slot] then
		api.toast("Этот слот нельзя оставить пустым — надень другой предмет", "info")
		return
	end
	Remotes.ShopEquip:FireServer(item.id)
	local s = slotsUI[item.slot]
	if not wasOn and s then
		flyTo(fromObj, s.btn, gradeOf(item).color)
		U.play(U.Sounds.chime, 0.35, 1.15)
	else
		U.play(U.Sounds.tap, 0.4, 0.9)
	end
end

-- ===== ячейки снаряжения вокруг персонажа =====
local function buildSlots(left)
	local yStepL = (HOLE.h - SLOT * 4) / 3
	local yStepR = (HOLE.h - SLOT * 3) / 2
	for _, def in ipairs(SLOT_DEFS) do
		local x = def.side == 0 and 12 or (LEFT.w - 12 - SLOT)
		local y = HOLE.y + def.row * (SLOT + (def.side == 0 and yStepL or yStepR))
		local s = { def = def }
		s.btn = api.button({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(SLOT, SLOT), BackgroundColor3 = C(255, 255, 255), Text = "", ZIndex = 4, Parent = left }, function()
			local id = equipped(def.key)
			local it = id and Shop.ById[id]
			if it and not FIXED[def.key] then
				equipItem(it, s.btn)
			else
				-- пустая или несменяемая ячейка: показываем подходящие вещи в хранилище
				Inv.SetTab("gear")
				Inv.SetFilter(def.key)
			end
		end)
		U.corner(14).Parent = s.btn
		s.grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(40, 46, 56), C(18, 21, 26)), Parent = s.btn })
		s.stroke = U.stroke(C(70, 78, 90), 2)
		s.stroke.Parent = s.btn
		s.glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), BackgroundTransparency = 1, Image = Icons.glow, ImageTransparency = 1, ZIndex = 3, Parent = s.btn })
		s.ph = label(s.btn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(40, 40), Text = def.icon, TextSize = 30, TextTransparency = 0.55, ZIndex = 5 })
		s.vp = itemVp(s.btn, { Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -6, 1, -16), ZIndex = 5, Visible = false })
		s.cap = label(s.btn, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 12), Text = def.name:upper(), TextSize = 9, TextColor3 = C(170, 180, 190), ZIndex = 6 }, 1)
		s.pop = U.scaleOf(s.vp)
		bindTip(s.btn, function()
			local id = equipped(def.key)
			local it = id and Shop.ById[id]
			if it then
				return gearSpec(it, true)
			end
			return { title = def.name, color = C(150, 160, 175), sub = "ПУСТАЯ ЯЧЕЙКА", desc = "Здесь ничего не надето.", footer = "ЛКМ — показать подходящие вещи в рюкзаке" }
		end)
		slotsUI[def.key] = s
	end
end

local function updateSlots()
	for key, s in pairs(slotsUI) do
		local id = equipped(key)
		local it = id and Shop.ById[id]
		if s.id ~= id or not s.shownOnce then
			local had = s.shownOnce
			s.id = id
			s.shownOnce = true
			if it then
				setVp(s.vp, it)
				s.vp.Visible = true
				s.ph.TextTransparency = 1
				-- новая вещь «выпрыгивает» и вспыхивает
				s.pop.Scale = 0.55
				U.tween(s.pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				local g = gradeOf(it)
				U.tween(s.stroke, 0.3, { Color = g.color, Thickness = 2.5 })
				U.gradTo(s.grad, U.darken(g.color, 0.42), C(14, 16, 20))
				s.glow.ImageColor3 = g.color
				s.glow.ImageTransparency = 0.2
				U.tween(s.glow, 0.6, { ImageTransparency = 0.72 })
				U.tween(s.cap, 0.3, { TextColor3 = g.color:Lerp(C(255, 255, 255), 0.45) })
			else
				s.vp.Visible = false
				U.tween(s.ph, 0.3, { TextTransparency = 0.55 })
				U.tween(s.stroke, 0.3, { Color = C(70, 78, 90), Thickness = 2 })
				U.gradTo(s.grad, C(40, 46, 56), C(18, 21, 26))
				U.tween(s.glow, 0.3, { ImageTransparency = 1 })
				U.tween(s.cap, 0.3, { TextColor3 = C(170, 180, 190) })
			end
			if had and win.Visible then
				U.pulseScale(s.btn, 1.12)
			end
		end
	end
end

-- ===== характеристики =====
local STAT_ROWS = {
	{ key = "hp", icon = "❤", name = "Здоровье", color = C(255, 120, 120) },
	{ key = "def", icon = "🛡", name = "Защита", color = C(140, 190, 255) },
	{ key = "speed", icon = "»", name = "Скорость бега", color = C(110, 230, 255), buff = "speed" },
	{ key = "jump", icon = "⬆", name = "Прыжок", color = C(170, 230, 140) },
	{ key = "dmg", icon = "⚔", name = "Урон оружия", color = C(255, 150, 90), buff = "rage" },
	{ key = "radius", icon = "◎", name = "Радиус удара", color = C(255, 200, 120) },
	{ key = "cd", icon = "⏱", name = "Удар раз в", color = C(230, 220, 160) },
	{ key = "gather", icon = "⛏", name = "Добыча за удар", color = C(255, 210, 90) },
	{ key = "scrap", icon = "⚙", name = "Сбор лома", color = C(255, 170, 70), buff = "scrap" },
	{ key = "cap", icon = "🎒", name = "Вместимость", color = C(130, 200, 255) },
	{ key = "conv", icon = "♻", name = "Переработка", color = C(130, 240, 130) },
	{ key = "luck", icon = "🍀", name = "Удача находок", color = C(120, 240, 100), buff = "luck" },
}

local function multStr(m)
	return Buffs.MultText(m)
end

-- значение, текст и подробный разбор каждой характеристики
local function computeStats()
	local d = data() or {}
	local gear = d.gear or {}
	local t = Shop.Totals(gear)
	local perks = d.perks or {}
	local wpn = Shop.ById[gear.weapon or ""] or Shop.ById[Shop.DefaultWeapon]
	local tool = Shop.ById[gear.tool or ""] or Shop.ById[Shop.DefaultTool]
	local out = {}
	local hp = 100 + t.hp + (perks.hp or 0)
	out.hp = { v = hp, text = U.fmt(hp), lines = { { "База", "100" }, { "Снаряжение", "+" .. U.fmt(t.hp), C(140, 255, 120) }, { "Награды квестов", "+" .. U.fmt(perks.hp or 0), C(255, 220, 120) } } }
	out.def = { v = t.def, text = ("%d%%"):format(math.floor(t.def * 100 + 0.5)), lines = { { "Урон по тебе", ("x%.2f"):format(1 - t.def) }, { "Предел защиты", "80%" } } }
	local sm = Buffs.Mult(player, "speed")
	local spd = (16 + t.speed) * sm
	out.speed = { v = spd, text = fmtNum(math.floor(spd * 10 + 0.5) / 10), mult = sm, lines = { { "База", "16" }, { "Снаряжение", "+" .. t.speed .. " (макс. +32)", C(140, 255, 120) }, { "Бафф «Ускорение»", multStr(sm), C(110, 230, 255) } } }
	out.jump = { v = t.jump, text = "+" .. t.jump, lines = { { "Снаряжение", "+" .. t.jump, C(140, 255, 120) } } }
	local rm = Buffs.Mult(player, "rage")
	local dmg = wpn.stats.dmg * (1 + (perks.dmg or 0)) * rm
	out.dmg = { v = dmg, text = U.fmt(math.floor(dmg + 0.5)), mult = rm, lines = { { wpn.name, U.fmt(wpn.stats.dmg) }, { "Награды квестов", ("+%d%%"):format((perks.dmg or 0) * 100), C(255, 220, 120) }, { "Бафф «Ярость роя»", multStr(rm), C(255, 120, 90) }, { "Ночью", "x2", C(190, 170, 255) } } }
	out.radius = { v = wpn.stats.radius, text = fmtNum(wpn.stats.radius), lines = { { "Оружие", fmtNum(wpn.stats.radius) }, { "Инструмент", fmtNum(tool.stats.radius) } } }
	out.cd = { v = wpn.stats.cd, text = ("%.2f с"):format(wpn.stats.cd), lines = { { "Оружие", ("%.2f с"):format(wpn.stats.cd) }, { "Инструмент", ("%.2f с"):format(tool.stats.cd or 0.45) } } }
	out.gather = { v = tool.stats.gather or 0, text = U.fmt(tool.stats.gather or 0), lines = { { tool.name, "+" .. (tool.stats.gather or 0) } } }
	local scm = Buffs.Mult(player, "scrap")
	local sc = (1 + t.scrap + (perks.scrap or 0)) * scm
	out.scrap = { v = sc, text = multStr(sc), mult = scm, lines = { { "Снаряжение", fmtStat("scrap", t.scrap), C(140, 255, 120) }, { "Награды квестов", fmtStat("scrap", perks.scrap or 0), C(255, 220, 120) }, { "Бафф «Щедрый сбор»", multStr(scm), C(255, 170, 70) } } }
	out.cap = { v = d.capacity or 0, text = U.fmt(d.capacity or 0), lines = { { "Уровень рюкзака", tostring(d.bagLevel or 1) }, { "Бонус рюкзака", fmtStat("cap", t.cap), C(140, 255, 120) } } }
	out.conv = { v = t.conv + t.cspeed, text = ("+%d%%"):format(math.floor(t.conv * 100 + 0.5)), lines = { { "Батарей с переработки", fmtStat("conv", t.conv), C(140, 255, 120) }, { "Скорость переработки", fmtStat("cspeed", t.cspeed), C(140, 255, 120) } } }
	local lm = Buffs.Mult(player, "luck")
	local lk = (1 + (perks.luck or 0)) * lm
	out.luck = { v = lk, text = multStr(lk), mult = lm, lines = { { "Награды квестов", ("+%d%%"):format((perks.luck or 0) * 100), C(255, 220, 120) }, { "Бафф «Удача»", multStr(lm), C(120, 240, 100) } } }
	return out
end

local STAT_DESC = {
	hp = "Максимальный запас здоровья.",
	def = "Какую долю урона от зомби поглощает броня и шлем.",
	speed = "Скорость бега. Баффы «Ускорение» и Адреналин складываются.",
	jump = "Насколько выше ты прыгаешь благодаря ботинкам.",
	dmg = "Урон одного удара выбранным оружием.",
	radius = "Насколько далеко достаёт удар.",
	cd = "Пауза между ударами: чем меньше, тем быстрее.",
	gather = "Сколько ресурсов приносит один удар инструментом по куче.",
	scrap = "Множитель лома со всех куч: перчатки, награды и бафф.",
	cap = "Сколько лома помещается в рюкзак.",
	conv = "Бонус Переработчика от рюкзака: больше батарей и быстрее.",
	luck = "Шанс найти редкие предметы в кучах и у зомби.",
}

local function buildStats(mid)
	label(mid, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 22), Text = "ХАРАКТЕРИСТИКИ", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255) }, 1.5)
	local list = new("Frame", { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, #STAT_ROWS * 26), BackgroundTransparency = 1, Parent = mid }, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	for i, r in ipairs(STAT_ROWS) do
		local row = new("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = i % 2 == 0 and 0.965 or 0.93, AutoButtonColor = false, Text = "", Parent = list }, { U.corner(6) })
		local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = r.color, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = row }, { U.corner(6) })
		label(row, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(22, 24), Text = r.icon, TextSize = 15, TextColor3 = r.color, ZIndex = 3 })
		label(row, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -120, 1, 0), Text = r.name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C(205, 212, 205), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		local val = label(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(110, 24), Text = "", TextSize = 15, TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 }, 1.2)
		local arrow = label(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(10, 12), Text = "▲", TextSize = 9, TextColor3 = r.color, TextTransparency = 1, ZIndex = 3 })
		row.MouseEnter:Connect(function()
			U.tween(row, 0.12, { BackgroundTransparency = 0.86 })
		end)
		row.MouseLeave:Connect(function()
			U.tween(row, 0.12, { BackgroundTransparency = i % 2 == 0 and 0.965 or 0.93 })
		end)
		stats[r.key] = { row = row, val = val, flash = flash, arrow = arrow, def = r }
		bindTip(row, function()
			local s = stats[r.key].last
			if not s then
				return nil
			end
			return { title = r.icon .. "  " .. r.name, color = r.color, sub = "СЕЙЧАС: " .. s.text, lines = s.lines, desc = STAT_DESC[r.key] }
		end)
	end
	-- активные баффы
	local by = 38 + #STAT_ROWS * 26 + 8
	label(mid, { Position = UDim2.fromOffset(14, by), Size = UDim2.new(1, -28, 0, 18), Text = "АКТИВНЫЕ БАФФЫ", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 230, 150) }, 1.2)
	local row = new("Frame", { Position = UDim2.fromOffset(12, by + 22), Size = UDim2.new(1, -24, 0, MID.h - by - 34), BackgroundTransparency = 1, Parent = mid }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local cw = math.floor((MID.w - 24 - 18) / 4)
	for _, b in ipairs(Buffs.List) do
		if b.time > 0 then
			local c = new("Frame", { LayoutOrder = b.index, Size = UDim2.new(0, cw, 1, 0), BackgroundColor3 = C(255, 255, 255), Parent = row }, { U.corner(10) })
			local grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(34, 38, 44), C(18, 20, 24)), Parent = c })
			local st = U.stroke(C(60, 66, 74), 1.5)
			st.Parent = c
			local glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = b.color, ImageTransparency = 1, ZIndex = 2, Parent = c })
			local icon = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = Icons.buffs[b.id] or Icons.speed, ImageTransparency = 0.6, ZIndex = 3, Parent = c })
			local mult = label(c, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 16), Text = "x1", TextSize = 14, TextColor3 = C(150, 155, 160), ZIndex = 3 }, 1.2)
			local name = label(c, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 11), Text = b.short, TextSize = 9, TextColor3 = C(150, 155, 160), ZIndex = 3 })
			local barBg = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -12, 0, 4), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 3, Parent = c }, { U.round() })
			local bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = b.color, ZIndex = 4, Parent = barBg }, { U.round() })
			buffChips[b.id] = { frame = c, grad = grad, stroke = st, glow = glow, icon = icon, mult = mult, name = name, bar = bar, def = b }
			bindTip(c, function()
				local left = Buffs.Left(player, b.id)
				local n = Buffs.Stacks(player, b.id)
				local lines = { { "Ступени", ("%d / %d"):format(n, Buffs.MaxStacks) }, { "Множитель", multStr(1 + b.per * n), b.color }, { "За ступень", ("+%d%%"):format(b.per * 100) } }
				if left > 0 then
					table.insert(lines, { "Осталось", ("%.1f с"):format(left) })
				end
				return { title = b.name, color = b.color, sub = left > 0 and "АКТИВЕН" or "НЕ АКТИВЕН", lines = lines, desc = "Усиливает: " .. b.desc .. ". Подбирай такие сферы на полях — ступени складываются." }
			end)
		end
	end
end

local function updateStats(animate)
	local s = computeStats()
	for key, r in pairs(stats) do
		local v = s[key]
		local prev = r.last
		r.last = v
		local buffed = v.mult and v.mult > 1.0001
		if not prev or prev.text ~= v.text then
			r.val.Text = v.text
			if prev and animate then
				-- значение изменилось: строка вспыхивает, число «подпрыгивает»
				r.flash.BackgroundTransparency = 0.6
				U.tween(r.flash, 0.6, { BackgroundTransparency = 1 })
				U.pulseScale(r.val, 1.18)
			end
		end
		if r.buffed ~= buffed then
			r.buffed = buffed
			U.tween(r.val, 0.25, { TextColor3 = buffed and r.def.color:Lerp(C(255, 255, 255), 0.3) or C(255, 255, 255) })
			U.tween(r.arrow, 0.25, { TextTransparency = buffed and 0 or 1 })
		end
	end
end

local function updateBuffChips()
	local now = os.clock()
	for id, c in pairs(buffChips) do
		local b = c.def
		local left = Buffs.Left(player, id)
		local n = Buffs.Stacks(player, id)
		local on = left > 0
		if c.on ~= on then
			c.on = on
			U.tween(c.icon, 0.25, { ImageTransparency = on and 0 or 0.6 })
			U.tween(c.glow, 0.25, { ImageTransparency = on and 0.55 or 1 })
			U.tween(c.stroke, 0.25, { Color = on and b.color or C(60, 66, 74) })
			U.tween(c.mult, 0.25, { TextColor3 = on and C(255, 255, 255) or C(150, 155, 160) })
			U.tween(c.name, 0.25, { TextColor3 = on and b.color or C(150, 155, 160) })
			U.gradTo(c.grad, on and U.darken(b.color, 0.35) or C(34, 38, 44), on and C(16, 18, 22) or C(18, 20, 24))
			if on then
				U.pulseScale(c.frame, 1.1)
			end
		end
		c.mult.Text = on and multStr(1 + b.per * n) or "—"
		c.bar.Size = UDim2.fromScale(on and math.clamp(left / b.time, 0, 1) or 0, 1)
		if on then
			c.glow.Rotation = now * 40
			c.icon.Rotation = math.sin(now * 2 + b.index) * 6
		end
	end
end

-- ===== хранилище =====
local function newCell(parent, order)
	local c = {}
	c.btn = api.button({ LayoutOrder = order, BackgroundColor3 = C(255, 255, 255), Text = "", Parent = parent }, function()
		if c.onClick then
			c.onClick()
		end
	end)
	U.corner(12).Parent = c.btn
	c.grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(40, 46, 56), C(18, 21, 26)), Parent = c.btn })
	c.stroke = U.stroke(C(70, 78, 90), 2)
	c.stroke.Parent = c.btn
	c.shine = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Image = Icons.glow, ImageTransparency = 0.75, ZIndex = 2, Parent = c.btn })
	c.vp = itemVp(c.btn, { Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 56), ZIndex = 3, Visible = false })
	c.img = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Visible = false, Parent = c.btn })
	c.name = label(c.btn, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -8, 0, 24), Text = "", TextScaled = true, TextWrapped = true, Font = Enum.Font.GothamBold, ZIndex = 4 }, 1.2)
	new("UITextSizeConstraint", { MaxTextSize = 11, Parent = c.name })
	c.count = label(c.btn, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 3), Size = UDim2.fromOffset(50, 16), Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 }, 1.5)
	c.badge = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C(110, 230, 80), ZIndex = 6, Visible = false, Parent = c.btn }, { U.round(), U.stroke(C(20, 40, 10), 1.5) })
	label(c.badge, { Size = UDim2.fromScale(1, 1), Text = "✔", TextSize = 12, TextColor3 = C(20, 40, 10), ZIndex = 7 })
	c.badgeScale = U.scaleOf(c.badge)
	return c
end

local function gearList()
	local d = data()
	local list = {}
	if not d then
		return list
	end
	local slotOrder = {}
	for i, s in ipairs(Shop.Slots) do
		slotOrder[s.key] = i
	end
	for id in pairs(d.items or {}) do
		local it = Shop.ById[id]
		if it and not it.stack and (gearFilter == "all" or gearFilter == it.slot) then
			table.insert(list, it)
		end
	end
	if gearFilter == "all" or gearFilter == "consumable" then
		for id, n in pairs(d.consum or {}) do
			local it = Shop.ById[id]
			if it and n > 0 then
				table.insert(list, it)
			end
		end
	end
	table.sort(list, function(a, b)
		local ea, eb = isEquipped(a), isEquipped(b)
		if ea ~= eb then
			return ea
		end
		if (a.stack or false) ~= (b.stack or false) then
			return not a.stack
		end
		if (a.grade or 1) ~= (b.grade or 1) then
			return (a.grade or 1) > (b.grade or 1)
		end
		if a.price ~= b.price then
			return a.price > b.price
		end
		return (slotOrder[a.slot] or 0) < (slotOrder[b.slot] or 0)
	end)
	return list
end

local function countGear()
	local d = data()
	local n = 0
	for id in pairs(d and d.items or {}) do
		local it = Shop.ById[id]
		if it and not it.stack then
			n += 1
		end
	end
	for _, k in pairs(d and d.consum or {}) do
		if k > 0 then
			n += 1
		end
	end
	return n
end

local function fillGearCell(c, it, animate)
	local g = gradeOf(it)
	if c.itemId ~= it.id then
		c.itemId = it.id
		if it.stack then
			c.vp.Visible = false
			c.img.Visible = true
			c.img.Image = Icons[it.icon or it.id] or ""
		else
			c.img.Visible = false
			c.vp.Visible = true
			setVp(c.vp, it)
		end
		c.name.Text = it.name
		c.name.TextColor3 = g.color:Lerp(C(255, 255, 255), 0.55)
		c.stroke.Color = g.color
		c.shine.ImageColor3 = g.color
		c.grad.Color = ColorSequence.new(U.darken(g.color, 0.3), C(14, 16, 20))
		if animate then
			local sc = U.scaleOf(c.btn)
			sc.Scale = 0.6
			U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	c.item = it
	local d = data()
	c.count.Text = it.stack and ("x" .. (d and d.consum and d.consum[it.id] or 0)) or ""
	local on = isEquipped(it)
	if c.on ~= on then
		c.on = on
		if on then
			c.badge.Visible = true
			c.badgeScale.Scale = 0
			U.tween(c.badgeScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			U.tween(c.badgeScale, 0.15, { Scale = 0 }).Completed:Connect(function()
				if not c.on then
					c.badge.Visible = false
				end
			end)
		end
		U.tween(c.stroke, 0.2, { Thickness = on and 3.5 or 2 })
		U.tween(c.shine, 0.2, { ImageTransparency = on and 0.5 or 0.78 })
	end
	c.onClick = function()
		equipItem(it, c.btn)
	end
end

function Inv.RefreshGear(animate)
	local list = gearList()
	local key = {}
	for _, it in ipairs(list) do
		table.insert(key, it.id)
	end
	key = table.concat(key, ",")
	local changed = key ~= tabs.gearKey
	tabs.gearKey = key
	for i, it in ipairs(list) do
		local c = gearCells[i]
		if not c then
			c = newCell(tabs.gearGrid, i)
			gearCells[i] = c
			bindTip(c.btn, function()
				return c.item and gearSpec(c.item)
			end)
		end
		c.btn.Visible = true
		fillGearCell(c, it, animate and changed)
	end
	for i = #list + 1, #gearCells do
		gearCells[i].btn.Visible = false
		gearCells[i].item = nil
	end
	tabs.gearEmpty.Visible = #list == 0
	local rows = math.ceil(#list / 4)
	tabs.gearGrid.CanvasSize = UDim2.fromOffset(0, rows * (CELL.Y + 8) + 4)
end

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

local function updateAction(entry)
	if not entry then
		U.fadeVisible(act.box, false, 0.15)
		act.empty.Visible = true
		return
	end
	act.empty.Visible = false
	U.fadeVisible(act.box, true, 0.15)
	local it = entry.item
	local tier = Items.Tiers[it.tier]
	if act.shownId ~= it.id then
		act.shownId = it.id
		act.icon.ImageTransparency = 1
		U.tween(act.icon, 0.25, { ImageTransparency = 0 })
		local sc = U.scaleOf(act.icon)
		sc.Scale = 0.6
		U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	act.icon.Image = Icons.items[it.id] or ""
	act.name.Text = it.name
	act.name.TextColor3 = tier.color:Lerp(C(255, 255, 255), 0.25)
	act.sub.Text = tier.name:upper() .. "  •  x" .. entry.n .. "  •  🔋 " .. U.fmt(it.value)
	act.sub.TextColor3 = tier.color
	U.tween(act.use, 0.2, { BackgroundTransparency = it.use and 0 or 0.7, TextTransparency = it.use and 0 or 0.6 })
	act.sellAll.Text = ("ВСЕ 🔋%s"):format(U.fmt(it.value * entry.n))
	U.tween(act.stroke, 0.2, { Color = tier.color })
end

function Inv.RefreshFinds()
	local d = data()
	if not d then
		return
	end
	local list = bagList(d)
	local selEntry
	for i = 1, Items.BagSlots do
		local c = findCells[i]
		local e = list[i]
		c.entry = e
		if e then
			local tier = Items.Tiers[e.item.tier]
			if c.itemId ~= e.item.id then
				c.itemId = e.item.id
				c.img.ImageTransparency = 1
				U.tween(c.img, 0.25, { ImageTransparency = 0 })
				c.img.Image = Icons.items[e.item.id] or ""
				c.img.Visible = true
				c.name.Text = e.item.name
				c.name.TextColor3 = tier.color:Lerp(C(255, 255, 255), 0.55)
				U.tween(c.stroke, 0.18, { Color = tier.color })
				U.gradTo(c.grad, U.darken(tier.color, 0.3), C(14, 16, 20))
				c.shine.ImageColor3 = tier.color
				U.tween(c.shine, 0.2, { ImageTransparency = tier.order >= 4 and 0.45 or 0.78 })
			end
			c.count.Text = "x" .. e.n
			if e.item.id == selectedFind then
				selEntry = e
			end
		else
			if c.itemId then
				c.itemId = nil
				c.img.Visible = false
				c.name.Text = ""
				c.count.Text = ""
				U.tween(c.stroke, 0.18, { Color = C(55, 62, 70) })
				U.gradTo(c.grad, C(30, 34, 40), C(18, 20, 24))
				U.tween(c.shine, 0.2, { ImageTransparency = 1 })
			end
		end
	end
	if not selEntry then
		selEntry = list[1]
		selectedFind = selEntry and selEntry.item.id
	end
	for _, c in ipairs(findCells) do
		local sel = c.entry and c.entry.item.id == selectedFind
		if c.sel ~= sel then
			c.sel = sel
			U.tween(c.stroke, 0.18, { Thickness = sel and 3.5 or 2 })
		end
	end
	updateAction(selEntry)
	tabs.findsEmpty.Visible = #list == 0
end

local function bagAct(action)
	if not selectedFind then
		return
	end
	local ok, res = pcall(function()
		return Remotes.BagAction:InvokeServer(action, selectedFind)
	end)
	if ok and res then
		if res.ok then
			api.toast(res.msg or "Готово", "good")
			U.play(U.Sounds.coin, 0.4, 1.2)
		else
			api.toast(res.err or "Не получилось", "bad")
		end
	end
end

function Inv.SetFilter(key)
	gearFilter = key
	for k, b in pairs(tabs.filters) do
		local on = k == key
		U.tween(b.btn, 0.18, { BackgroundColor3 = on and C(90, 170, 255) or C(36, 42, 50) })
		U.tween(b.txt, 0.18, { TextTransparency = on and 0 or 0.35 })
	end
	tabs.gearGrid.CanvasPosition = Vector2.zero
	Inv.RefreshGear(true)
end

function Inv.SetTab(key)
	if tabs.current == key and tabs.init then
		return
	end
	tabs.init = true
	tabs.current = key
	local gearOn = key == "gear"
	local pw = RIGHT.w - 24
	U.tween(tabs.gearPage, 0.3, { Position = UDim2.fromOffset(gearOn and 0 or -pw - 20, 0) }, Enum.EasingStyle.Quart)
	U.tween(tabs.findsPage, 0.3, { Position = UDim2.fromOffset(gearOn and pw + 20 or 0, 0) }, Enum.EasingStyle.Quart)
	U.tween(tabs.underline, 0.3, { Position = UDim2.fromOffset(gearOn and 12 or tabs.tabW + 20, 134) }, Enum.EasingStyle.Quart)
	U.tween(tabs.underline, 0.3, { BackgroundColor3 = gearOn and C(90, 170, 255) or C(255, 190, 70) })
	U.tween(tabs.gearBtn, 0.2, { TextColor3 = gearOn and C(255, 255, 255) or T.Muted })
	U.tween(tabs.findsBtn, 0.2, { TextColor3 = gearOn and T.Muted or C(255, 255, 255) })
end

local function buildRight(right)
	-- лом и уровень рюкзака
	cap.lvl = label(right, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(150, 210, 255) }, 1.2)
	local capBg = new("Frame", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 26), BackgroundColor3 = C(10, 12, 10), Parent = right }, { U.corner(8), U.stroke(C(70, 80, 70), 1.5) })
	cap.bar = new("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = C(255, 255, 255), Parent = capBg }, { U.corner(8), U.grad(C(170, 255, 90), C(70, 160, 30), 90) })
	cap.text = label(capBg, { Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, TextColor3 = C(255, 255, 255), ZIndex = 3 }, 1.6)
	cap.up = api.button({ Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(180, 30), BackgroundColor3 = T.Accent, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C(20, 30, 10), Text = "", Parent = right }, function()
		Remotes.UpgradeBag:FireServer()
	end)
	U.corner(8).Parent = cap.up
	cap.mats = label(right, { Position = UDim2.fromOffset(198, 58), Size = UDim2.fromOffset(RIGHT.w - 210, 34), Text = "", Font = Enum.Font.GothamBold, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted })

	-- вкладки
	tabs.tabW = math.floor((RIGHT.w - 32) / 2)
	local function tabBtn(x, text)
		local b = api.button({ Position = UDim2.fromOffset(x, 100), Size = UDim2.fromOffset(tabs.tabW, 32), BackgroundColor3 = C(30, 35, 42), Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = T.Muted, Text = text, Parent = right })
		U.corner(8).Parent = b
		return b
	end
	tabs.gearBtn = tabBtn(12, "")
	tabs.findsBtn = tabBtn(tabs.tabW + 20, "")
	tabs.gearBtn.Activated:Connect(function()
		Inv.SetTab("gear")
	end)
	tabs.findsBtn.Activated:Connect(function()
		Inv.SetTab("finds")
	end)
	tabs.underline = new("Frame", { Position = UDim2.fromOffset(12, 134), Size = UDim2.fromOffset(tabs.tabW, 3), BackgroundColor3 = C(90, 170, 255), BorderSizePixel = 0, Parent = right }, { U.round() })

	local pages = new("Frame", { Position = UDim2.fromOffset(12, 142), Size = UDim2.new(1, -24, 1, -152), BackgroundTransparency = 1, ClipsDescendants = true, Parent = right })
	local pw, ph = RIGHT.w - 24, RIGHT.h - 152

	-- страница «Снаряжение»: фильтры по слотам и сетка вещей
	tabs.gearPage = new("Frame", { Size = UDim2.fromOffset(pw, ph), BackgroundTransparency = 1, Parent = pages })
	local fr = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = tabs.gearPage }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	tabs.filters = {}
	local filterDefs = { { key = "all", icon = "★", name = "Все вещи" } }
	for _, s in ipairs(Shop.Slots) do
		table.insert(filterDefs, { key = s.key, icon = s.icon, name = s.name })
	end
	local fw = math.floor((pw - 4 * (#filterDefs - 1)) / #filterDefs)
	for i, f in ipairs(filterDefs) do
		local b = api.button({ LayoutOrder = i, Size = UDim2.fromOffset(fw, 30), BackgroundColor3 = C(36, 42, 50), Text = "", Parent = fr })
		U.corner(8).Parent = b
		local txt = label(b, { Size = UDim2.fromScale(1, 1), Text = f.icon, TextSize = 16, TextTransparency = 0.35, ZIndex = 3 })
		b.Activated:Connect(function()
			Inv.SetFilter(f.key)
		end)
		bindTip(b, function()
			return { title = f.name, color = C(90, 170, 255), sub = "ФИЛЬТР", desc = "Показать в рюкзаке только эти вещи." }
		end)
		tabs.filters[f.key] = { btn = b, txt = txt }
	end
	tabs.gearGrid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C(120, 140, 160),
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = tabs.gearPage,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(CELL.X, CELL.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }),
	})
	tabs.gearEmpty = label(tabs.gearPage, { Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 80), Text = "Здесь пока пусто.\nПокупай и крафти снаряжение в Магазине — всё купленное хранится в рюкзаке навсегда.", Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextColor3 = T.Muted, Visible = false })

	-- страница «Находки»: предметы из куч лома, продажа и использование
	tabs.findsPage = new("Frame", { Position = UDim2.fromOffset(pw + 20, 0), Size = UDim2.fromOffset(pw, ph), BackgroundTransparency = 1, Parent = pages })
	local fgrid = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C(120, 140, 160),
		CanvasSize = UDim2.fromOffset(0, math.ceil(Items.BagSlots / 4) * (CELL.Y + 8) + 4),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = tabs.findsPage,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(CELL.X, CELL.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }),
	})
	for i = 1, Items.BagSlots do
		local c = newCell(fgrid, i)
		c.stroke.Color = C(55, 62, 70)
		c.grad.Color = ColorSequence.new(C(30, 34, 40), C(18, 20, 24))
		c.shine.ImageTransparency = 1
		c.img.Size = UDim2.fromOffset(50, 50)
		c.onClick = function()
			if c.entry then
				selectedFind = c.entry.item.id
				Inv.RefreshFinds()
			end
		end
		bindTip(c.btn, function()
			return c.entry and findSpec(c.entry.item, c.entry.n)
		end)
		findCells[i] = c
	end
	tabs.findsEmpty = label(tabs.findsPage, { Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 80), Text = "Рюкзак пуст.\nСобирай лом и убивай зомби — иногда в кучах попадаются редкие находки. Ночью их вдвое больше!", Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextColor3 = T.Muted, Visible = false, ZIndex = 5 })
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C(20, 24, 28), Parent = tabs.findsPage }, { U.corner(10) })
	act.stroke = U.stroke(C(70, 80, 90), 1.5)
	act.stroke.Parent = bar
	act.empty = label(bar, { Size = UDim2.fromScale(1, 1), Text = "Выбери находку", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Muted })
	act.box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = bar })
	act.icon = new("ImageLabel", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = act.box })
	act.name = label(act.box, { Position = UDim2.fromOffset(34, 2), Size = UDim2.new(1, -40, 0, 16), Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }, 1.2)
	act.sub = label(act.box, { Position = UDim2.fromOffset(34, 17), Size = UDim2.new(1, -40, 0, 12), Text = "", TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left })
	local bw = math.floor((pw - 12 - 8) / 3)
	local function actBtn(i, text, color, tcolor, action)
		local b = api.button({ Position = UDim2.fromOffset(6 + (i - 1) * (bw + 4), 32), Size = UDim2.fromOffset(bw, 24), BackgroundColor3 = color, Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = tcolor, Text = text, Parent = act.box }, function()
			bagAct(action)
		end)
		U.corner(6).Parent = b
		return b
	end
	act.use = actBtn(1, "✔ ИСПОЛЬЗОВАТЬ", C(80, 200, 255), C(10, 25, 40), "use")
	act.sell = actBtn(2, "ПРОДАТЬ 1", T.Hazard, C(40, 25, 0), "sell")
	act.sellAll = actBtn(3, "ВСЕ", C(235, 120, 40), C(40, 15, 0), "sellall")
end

local function buildCharacterPanel(left)
	holedBackground(left, LEFT.w, LEFT.h, HOLE, 14, C(255, 255, 255), C(36, 42, 50), C(22, 26, 30), 1)
	local frame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = left }, { U.corner(14) })
	U.stroke(C(60, 70, 80), 1.5).Parent = frame

	-- окошко с 3D-персонажем: рамка, уголки, искры, тень снизу, вспышка при смене снаряжения
	hole.frame = new("TextButton", { Position = UDim2.fromOffset(HOLE.x, HOLE.y), Size = UDim2.fromOffset(HOLE.w, HOLE.h), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ClipsDescendants = true, ZIndex = 3, Parent = left })
	hole.border = U.stroke(C(120, 170, 255), 2, 0.35)
	hole.border.Parent = hole.frame
	new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.22, 0), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = hole.frame }, {
		new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new(0.2, 1) }),
	})
	hole.flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6, Parent = hole.frame })
	hole.sweep = new("Frame", { Position = UDim2.fromScale(0, -0.2), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C(160, 210, 255), BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 4, Parent = hole.frame }, {
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	hole.motes = {}
	for k = 1, 10 do
		local m = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = Icons.twinkle, ImageTransparency = 1, Size = UDim2.fromOffset(10, 10), ZIndex = 5, Parent = hole.frame })
		table.insert(hole.motes, { img = m, t0 = -k * 0.45, dur = 3 + (k % 4) * 0.6, x = 0.15 + ((k * 37) % 70) / 100 })
	end
	-- уголки рамки
	hole.brackets = {}
	local L, Tk = 18, 3
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local cx, cy = c[1], c[2]
		for _, horiz in ipairs({ true, false }) do
			local b = new("Frame", {
				AnchorPoint = Vector2.new(cx, cy),
				Position = UDim2.new(0, HOLE.x + cx * HOLE.w + (cx == 0 and -2 or 2), 0, HOLE.y + cy * HOLE.h + (cy == 0 and -2 or 2)),
				Size = horiz and UDim2.fromOffset(L, Tk) or UDim2.fromOffset(Tk, L),
				BackgroundColor3 = C(120, 170, 255),
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = left,
			})
			table.insert(hole.brackets, b)
		end
	end
	hole.hint = label(hole.frame, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 14), Text = "Тяни мышью — повернуть", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C(200, 215, 230), TextTransparency = 0.2, ZIndex = 6 }, 1)
	-- вращение персонажа мышью или пальцем
	hole.frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stage.dragging = true
			stage.lastX = input.Position.X
			stage.idle = 0
			if not stage.hinted then
				stage.hinted = true
				U.tween(hole.hint, 0.4, { TextTransparency = 1 })
			end
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if stage.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dx = input.Position.X - (stage.lastX or input.Position.X)
			stage.lastX = input.Position.X
			local dYaw = dx * 0.015
			stage.yaw += dYaw
			stage.vel = stage.vel * 0.5 + dYaw * 30
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if stage.dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			stage.dragging = false
			stage.idle = 0
		end
	end)

	buildSlots(left)

	-- имя и рейтинг снаряжения
	local by = HOLE.y + HOLE.h + 10
	power.name = label(left, { Position = UDim2.fromOffset(14, by), Size = UDim2.new(1, -28, 0, 24), Text = player.DisplayName, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255) }, 1.6)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(190, 210, 230)), Parent = power.name })
	power.count = label(left, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, by + 4), Size = UDim2.fromOffset(160, 18), Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Muted })
	label(left, { Position = UDim2.fromOffset(14, by + 30), Size = UDim2.fromOffset(200, 14), Text = "РЕЙТИНГ СНАРЯЖЕНИЯ", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 220, 130) })
	power.val = label(left, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, by + 30), Size = UDim2.fromOffset(120, 14), Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C(255, 255, 255) }, 1)
	local bg = new("Frame", { Position = UDim2.fromOffset(14, by + 48), Size = UDim2.new(1, -28, 0, 12), BackgroundColor3 = C(10, 12, 14), Parent = left }, { U.round(), U.stroke(C(70, 76, 86), 1) })
	power.fill = new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = C(255, 255, 255), Parent = bg }, { U.round() })
	power.grad = new("UIGradient", { Color = ColorSequence.new(C(255, 210, 90), C(255, 120, 60)), Parent = power.fill })
	power.sheen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 2, Parent = power.fill }, {
		U.round(),
	})
	power.sheenGrad = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(-1, 0), Parent = power.sheen })
	bindTip(bg, function()
		local lines = {}
		for _, s in ipairs(SLOT_DEFS) do
			local it = equipped(s.key) and Shop.ById[equipped(s.key)]
			table.insert(lines, { s.icon .. " " .. s.name, it and gradeOf(it).name or "—", it and gradeOf(it).color or C(140, 140, 140) })
		end
		return { title = "Рейтинг снаряжения", color = C(255, 200, 90), sub = power.val.Text, lines = lines, desc = "Сумма грейдов всего надетого: от «Обычный» (1) до «Абсолют» (7) в каждой из 7 ячеек." }
	end)
end

local function updatePower()
	local sum, n = 0, 0
	for _, s in ipairs(SLOT_DEFS) do
		local id = equipped(s.key)
		local it = id and Shop.ById[id]
		if it then
			sum += it.grade or 1
			n += 1
		end
	end
	local max = #SLOT_DEFS * #Shop.Grades
	power.count.Text = ("Надето: %d / %d"):format(n, #SLOT_DEFS)
	U.countTo(power.val, sum, function(v)
		return ("%d / %d"):format(math.floor(v + 0.5), max)
	end, 0.6)
	U.tween(power.fill, 0.6, { Size = UDim2.fromScale(math.max(0.03, sum / max), 1) }, Enum.EasingStyle.Quart)
end

local function updateCap(d)
	local ratio = math.clamp(d.scrap / math.max(d.capacity, 1), 0, 1)
	U.tween(cap.bar, 0.25, { Size = UDim2.fromScale(math.max(ratio, 0.02), 1) })
	cap.text.Text = ("Лом: %s / %s"):format(U.fmt(d.scrap), U.fmt(d.capacity))
	cap.lvl.Text = ("УРОВЕНЬ РЮКЗАКА: %d / %d"):format(d.bagLevel, Config.MaxBagLevel)
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
		cap.up.Text = ("⬆ УЛУЧШИТЬ — 🔋 %s"):format(U.fmt(d.bagCost))
		U.tween(cap.up, 0.2, { BackgroundColor3 = (d.batteries >= d.bagCost and okMats) and T.Accent or C(70, 80, 70) })
		cap.mats.Text = #parts > 0 and ("🧰 " .. table.concat(parts, "  •  ")) or ""
		cap.mats.TextColor3 = okMats and C(170, 255, 140) or C(255, 170, 150)
	else
		cap.up.Text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		U.tween(cap.up, 0.2, { BackgroundColor3 = C(70, 80, 70) })
		cap.mats.Text = ""
	end
end

local lastGearKey
function Inv.Refresh(d)
	d = d or data()
	if not d or not win then
		return
	end
	local list = bagList(d)
	tabs.gearBtn.Text = ("⚔ СНАРЯЖЕНИЕ  %d"):format(countGear())
	tabs.findsBtn.Text = ("💎 НАХОДКИ  %d/%d"):format(#list, Items.BagSlots)
	updateCap(d)
	updateSlots()
	updatePower()
	updateStats(true)
	Inv.RefreshGear(false)
	Inv.RefreshFinds()
	-- вещи пересортировались: подсказка над ячейкой показывает то, что в ней теперь лежит
	local a = tip.anchor
	if a and tip.holder.Visible and not tip.hiding and tip.getSpec then
		local spec = a.Visible and tip.getSpec()
		if spec then
			showTip(a, spec)
		else
			hideTip(a)
		end
	end
	local key = {}
	for _, s in ipairs(SLOT_DEFS) do
		table.insert(key, d.gear and d.gear[s.key] or "-")
	end
	key = table.concat(key, "|")
	if key ~= lastGearKey then
		local first = lastGearKey == nil
		lastGearKey = key
		if not first then
			-- сервер переодевает персонажа — пересобираем 3D-копию, когда новые детали придут на клиент
			queueRebuild(0.45)
		end
	end
end

local function buildWindow()
	win = new("Frame", {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	})
	scaleObj = api.addScale(win)
	body = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = win })
	fitScale = new("UIScale", { Parent = body })
	-- фон окна с окошком под персонажа
	local holeWin = { x = LEFT.x + HOLE.x, y = LEFT.y + HOLE.y, w = HOLE.w, h = HOLE.h }
	holedBackground(body, W, H, holeWin, 18, C(255, 255, 255), C(30, 36, 46), C(12, 14, 18), 0)
	local frame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = body }, { U.corner(18) })
	local st = U.stroke(C(255, 255, 255), 3)
	st.Parent = frame
	new("UIGradient", { Rotation = 45, Color = ColorSequence.new(C(90, 180, 255), C(170, 110, 255)), Parent = st })

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C(255, 255, 255), Parent = body }, { U.corner(18), U.grad(C(36, 60, 90), C(20, 30, 46), 90) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.bag, Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(12, 6), Parent = header })
	local title = label(header, { Position = UDim2.fromOffset(70, 5), Size = UDim2.fromOffset(300, 32), Text = "ИНВЕНТАРЬ", TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255) }, 1.5)
	new("UIGradient", { Color = ColorSequence.new(C(200, 235, 255), C(90, 170, 255)), Rotation = 90, Parent = title })
	label(header, { Position = UDim2.fromOffset(72, 38), Size = UDim2.fromOffset(520, 16), Text = "Персонаж, снаряжение и находки. Наведи на вещь — увидишь её характеристики", Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted })
	local close = api.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = T.Danger, Font = Enum.Font.GothamBlack, Text = "X", TextSize = 20, TextColor3 = C(255, 255, 255), Parent = header }, function()
		Inv.Close()
	end)
	U.corner(10).Parent = close

	local left = new("Frame", { Position = UDim2.fromOffset(LEFT.x, LEFT.y), Size = UDim2.fromOffset(LEFT.w, LEFT.h), BackgroundTransparency = 1, Parent = body })
	buildCharacterPanel(left)
	local mid = new("Frame", { Position = UDim2.fromOffset(MID.x, MID.y), Size = UDim2.fromOffset(MID.w, MID.h), BackgroundColor3 = C(255, 255, 255), Parent = body }, { U.corner(14), U.grad(C(36, 42, 50), C(22, 26, 30), 90), U.stroke(C(60, 70, 80), 1.5) })
	buildStats(mid)
	local right = new("Frame", { Position = UDim2.fromOffset(RIGHT.x, RIGHT.y), Size = UDim2.fromOffset(RIGHT.w, RIGHT.h), BackgroundColor3 = C(255, 255, 255), Parent = body }, { U.corner(14), U.grad(C(36, 42, 50), C(22, 26, 30), 90), U.stroke(C(60, 70, 80), 1.5) })
	buildRight(right)
	Inv.SetTab("gear")
	Inv.SetFilter("all")
end

-- окно целиком помещается на экран (на телефоне оно больше остальных окон)
local function fit()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local inset = GuiService:GetGuiInset()
	local base = scaleObj:GetAttribute("Animating") and (scaleObj:GetAttribute("BaseScale") or scaleObj.Scale) or scaleObj.Scale
	local k = math.min(1, (vp.X * 0.98) / (W * base), ((vp.Y - inset.Y) * 0.95) / (H * base))
	if math.abs(fitScale.Scale - k) > 0.002 then
		fitScale.Scale = k
	end
end

local frameT = 0
local function onFrame(dt)
	if not (win and win.Visible) then
		return
	end
	fit()
	local t = os.clock()
	updateBuffChips()
	frameT += dt
	if frameT > 0.25 then
		frameT = 0
		updateStats(true)
	end
	-- искры в окошке персонажа плывут вверх
	for _, m in ipairs(hole.motes) do
		local p = (t - m.t0) / m.dur
		if p >= 1 or p < 0 then
			m.t0 = t + math.random() * 0.8
			m.x = 0.1 + math.random() * 0.8
			p = 0
		end
		m.img.Position = UDim2.fromScale(m.x + math.sin(p * 6 + m.dur) * 0.03, 0.95 - p * 0.75)
		m.img.ImageTransparency = 0.25 + 0.75 * math.abs(p * 2 - 1)
		m.img.Rotation = p * 180
		m.img.ImageColor3 = hole.border.Color:Lerp(C(255, 255, 255), 0.5)
	end
	-- медленная световая полоса сканера
	local sp = (t * 0.22) % 1.6
	hole.sweep.Position = UDim2.fromScale(0, sp - 0.2)
	power.sheenGrad.Offset = Vector2.new(((t * 0.5) % 2.4) - 1.2, 0)
end

function Inv.Open()
	if not win then
		return
	end
	if api.closeOthers then
		api.closeOthers()
	end
	Inv.Refresh()
	if stage.dirty or not stage.model then
		stage.dirty = false
		rebuildStage()
	end
	fit()
	api.openWindow(win, scaleObj)
end

function Inv.Close()
	if win then
		hideTip()
		api.closeWindow(win, scaleObj)
	end
end

function Inv.Toggle()
	if U.isOpen(win, scaleObj) then
		Inv.Close()
	else
		Inv.Open()
	end
end

function Inv.IsOpen()
	return U.isOpen(win, scaleObj)
end

function Inv.Init(a)
	api = a
	buildWindow()
	buildTip()
	State.Changed:Connect(function(d)
		if win.Visible then
			Inv.Refresh(d)
		end
	end)
	RunService.RenderStepped:Connect(onFrame)
	-- после обновления камеры, чтобы персонаж не отставал от неё ни на кадр
	RunService:BindToRenderStep("ZSS_InvStage", Enum.RenderPriority.Camera.Value + 2, stageStep)
	-- персонаж переродился или ему пересобрали снаряжение — обновляем 3D-копию
	local function watchChar(char)
		lastGearKey = nil
		queueRebuild(1)
		char.ChildAdded:Connect(function(c)
			if c.Name == "ZSS_Gear" or c:IsA("Accessory") then
				queueRebuild(0.3)
			end
		end)
	end
	player.CharacterAdded:Connect(watchChar)
	if player.Character then
		watchChar(player.Character)
	end
	task.spawn(function()
		local wf = workspace:WaitForChild("ZSS_WornBackpacks", 60)
		if wf then
			wf.ChildAdded:Connect(function(c)
				if c.Name:sub(-#tostring(player.UserId) - 1) == "_" .. player.UserId then
					queueRebuild(0.3)
				end
			end)
		end
	end)
end

return Inv
