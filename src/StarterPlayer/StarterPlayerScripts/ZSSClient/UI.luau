-- Интерфейс: HUD, инвентарь дронов, окно гачи, уведомления, баннеры полей
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Builder = require(Shared.DroneBuilder)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)
local GachaAnim = require(script.Parent.GachaAnim)
local ShopUI = require(script.Parent.ShopUI)
local DonateUI = require(script.Parent.DonateUI)
local BagUI = require(script.Parent.BagUI)
local QuestUI = require(script.Parent.QuestUI)
local WitchUI = require(script.Parent.WitchUI)
local SettingsUI = require(script.Parent.SettingsUI)
local HS = require(script.Parent.HotbarSlots)
local Keybinds = require(script.Parent.Keybinds)
local FXmod = require(script.Parent.FX)
local ItemsCfg = require(Shared:WaitForChild("ItemsConfig"))

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local UI = {}
local gui
local scales = {} -- UIScale объекты, адаптируемые под экран
local respScale = 1
local rainbowGrads = {}
local rainbowBgs = {} -- фоны мифических карточек: радуга плавно перетекает по оттенку
local secretStrokes = {}
local hud, inv, gacha, hgacha = {}, {}, {}, {}
local BANNERS -- баннеры гачи (ниже, у окна гачи)

local SORTED = {}
for _, d in ipairs(Config.Drones) do
	table.insert(SORTED, d)
end
table.sort(SORTED, function(a, b)
	local ra, rb = Config.Rarities[a.rarity].order, Config.Rarities[b.rarity].order
	if ra ~= rb then
		return ra > rb
	end
	return a.index < b.index
end)

local function addScale(obj)
	local s = new("UIScale", { Scale = respScale, Parent = obj })
	table.insert(scales, s)
	return s
end

local UIS = game:GetService("UserInputService")
local layoutMode = "pc"
local function detectMode()
	local vp = workspace.CurrentCamera.ViewportSize
	if (UIS.TouchEnabled and not UIS.KeyboardEnabled) or math.min(vp.X, vp.Y) < 520 then
		return "mobile"
	end
	return "pc"
end

local function updateScale()
	local vp = workspace.CurrentCamera.ViewportSize
	layoutMode = detectMode()
	if layoutMode == "mobile" then
		respScale = math.clamp(math.min(vp.X / 1100, vp.Y / 520), 0.5, 0.95)
	else
		respScale = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.7, 1.15)
	end
	respScale *= UI.UserScale or 1
	for _, s in ipairs(scales) do
		if not s:GetAttribute("Animating") then
			-- окна, которые не влезают в экран телефона, ужимаются под него
			s.Scale = s.Parent and U.fit(s.Parent, respScale) or respScale
			s:SetAttribute("BaseScale", s.Scale)
		end
	end
	if UI.ApplyLayout then
		UI.ApplyLayout(layoutMode)
	end
end

local function rainbowify(parent)
	local g = new("UIGradient", { Color = Config.RainbowSequence, Parent = parent })
	table.insert(rainbowGrads, g)
	return g
end

-- радужный фон карточки (цвет фона белый, градиент красит его)
local function rainbowBg(frame, rotation, val)
	frame.BackgroundColor3 = C(255, 255, 255)
	local g = new("UIGradient", { Rotation = rotation or 35, Color = Config.RainbowFlow(os.clock(), 0.75, val or 0.8), Parent = frame })
	table.insert(rainbowBgs, { g = g, val = val or 0.8 })
	return g
end

local function button(props, onClick)
	local b = new("TextButton", props)
	b.AutoButtonColor = false
	-- подсветка поверх кнопки, цвет самой кнопки можно менять в любой момент
	local hl = new("Frame", { Name = "HoverLight", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = b.ZIndex + 1, Parent = b })
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = hl })
	b.MouseEnter:Connect(function()
		U.tween(hl, 0.12, { BackgroundTransparency = 0.85 })
	end)
	b.MouseLeave:Connect(function()
		U.tween(hl, 0.12, { BackgroundTransparency = 1 })
	end)
	b.Activated:Connect(function()
		U.play(U.Sounds.click, 0.45, 1.05)
		if onClick then
			onClick()
		end
	end)
	U.pressFx(b)
	-- крестики окон мелкие на телефоне — даём им зону касания побольше
	if props.Text == "X" and onClick then
		U.hitPad(b, function()
			U.play(U.Sounds.click, 0.45, 1.05)
			onClick()
		end)
	end
	return b
end

local function openWindow(win, scaleObj)
	U.openPanel(win, scaleObj, respScale)
	U.play(U.Sounds.open, 0.35, 1.25)
end

-- плавное закрытие окна (сжимается и исчезает)
local function closeWindow(win, scaleObj)
	U.closePanel(win, scaleObj or (win and win:FindFirstChildOfClass("UIScale")))
end

-- ===== УВЕДОМЛЕНИЯ =====
local toastHolder
local toastSeq = 0
-- уведомление растворяется, затем схлопывается по высоте, и остальные плавно подтягиваются
local function dismissToast(f, t)
	if not f.Parent or f:GetAttribute("Leaving") then
		return
	end
	f:SetAttribute("Leaving", true)
	local card = f:FindFirstChildOfClass("Frame")
	if card then
		local lbl = card:FindFirstChildOfClass("TextLabel")
		local sc = card:FindFirstChildOfClass("UIScale")
		U.tween(card, t, { BackgroundTransparency = 1 })
		if lbl then
			U.tween(lbl, t, { TextTransparency = 1 })
		end
		if sc then
			U.tween(sc, t, { Scale = 0.92 })
		end
		U.tween(card:FindFirstChildOfClass("UIStroke"), t, { Transparency = 1 })
	end
	task.delay(t, function()
		if not f.Parent then
			return
		end
		U.tween(f, 0.2, { Size = UDim2.fromOffset(480, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			f:Destroy()
		end)
	end)
end

function UI.Toast(text, kind)
	text = U.touchText(text)
	if UI.ToastsEnabled == false and (kind == nil or kind == "info" or kind == "good" or kind == "speed" or kind == "night") then
		return
	end
	local color
	if kind == "bad" then
		color = T.Danger
	elseif kind == "good" then
		color = T.Accent
	elseif kind == "night" then
		color = C(150, 120, 255)
	elseif kind == "speed" then
		color = C(80, 230, 255)
	elseif kind == "boss" then
		color = C(255, 70, 40)
	elseif kind and ItemsCfg.Tiers[kind] then
		color = ItemsCfg.Tiers[kind].color
	elseif kind and Config.Rarities[kind] then
		color = Config.Rarities[kind].color
	else
		color = T.Hazard
	end
	-- появляется плавно: строка раздвигается по высоте (остальные съезжают), фон и текст проявляются
	-- f — прозрачная «строка» списка (высота 0 → 46, включая отступ), card — сама плашка
	local f = new("Frame", {
		Size = UDim2.fromOffset(480, 0),
		BackgroundTransparency = 1,
		LayoutOrder = toastSeq,
		Parent = toastHolder,
	})
	toastSeq += 1
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 1,
		Parent = f,
	}, { U.corner(10), U.stroke(color, 2, 1) })
	local lbl = new("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 17,
		TextColor3 = T.Text,
		TextTransparency = 1,
		TextWrapped = true,
		Parent = card,
	})
	local fsc = new("UIScale", { Scale = 0.85, Parent = card })
	U.tween(f, 0.28, { Size = UDim2.fromOffset(480, 46) }, Enum.EasingStyle.Quart)
	U.tween(card, 0.28, { BackgroundTransparency = 0.1 })
	U.tween(lbl, 0.28, { TextTransparency = 0 })
	U.tween(card:FindFirstChildOfClass("UIStroke"), 0.28, { Transparency = 0 })
	U.tween(fsc, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "Mythic" then
		rainbowify(card:FindFirstChildOfClass("UIStroke"))
	end
	if kind == "bad" then
		U.play(U.Sounds.tick, 0.4, 0.6)
	end
	task.delay(3.2, function()
		dismissToast(f, 0.3)
	end)
	-- больше 4 уведомлений: самое старое быстро уходит (тоже плавно)
	local live = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") and not c:GetAttribute("Leaving") then
			table.insert(live, c)
		end
	end
	if #live > 4 then
		table.sort(live, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		dismissToast(live[1], 0.18)
	end
end

-- ===== HUD (адаптивный: ПК / телефон) =====
local Icons = require(Shared:WaitForChild("Icons"))
local ShopCfg = require(Shared:WaitForChild("ShopConfig"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
UI.Energy = {}

local function iconImg(parent, key, size, pos, z)
	return new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons[key] or "",
		Size = size,
		Position = pos or UDim2.new(),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z or 3,
		Parent = parent,
	})
end

-- объёмная тыква (та же модель, что на полях) для кнопки котла; ViewportFrame статичный, качается сам кадр
local function pumpkinIcon(parent)
	local vp = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0.5, 0, 0, 30),
		Ambient = C(255, 225, 200),
		LightColor = C(255, 255, 255),
		LightDirection = Vector3.new(-0.3, -0.6, 1),
		ZIndex = 4,
		Parent = parent,
	})
	local lib = Shared:FindFirstChild("HalloweenMeshes")
	local src = lib and lib:FindFirstChild("Pumpkin")
	if not src then
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🎃", TextScaled = true, Font = Enum.Font.GothamBlack, ZIndex = 4, Parent = vp })
		return vp
	end
	local m = src:Clone()
	local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart", true)
	local size = m:IsA("Model") and select(2, m:GetBoundingBox()) or part.Size
	if m:IsA("Model") then
		m:PivotTo(CFrame.new())
	else
		m.CFrame = CFrame.new()
	end
	m.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- лицо тыквы смотрит в локальную -Z: камера спереди и чуть сверху
	local dist = size.Magnitude * 1.75
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.22, dist * 0.32, -dist), Vector3.new(0, -size.Y * 0.04, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function makeBar(parent, pos, size, c1, c2, iconKey)
	local holder = new("Frame", { Position = pos, Size = size, BackgroundTransparency = 1, Parent = parent })
	local bg = new("Frame", {
		Position = UDim2.new(0, 20, 0, 3),
		Size = UDim2.new(1, -20, 1, -6),
		BackgroundColor3 = C(10, 12, 10),
		Parent = holder,
	}, { U.corner(9), U.stroke(C(70, 80, 70), 1.5) })
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), Parent = bg }, { U.corner(9) })
	local grad = U.grad(c1, c2, 90)
	grad.Parent = fill
	new("Frame", { Size = UDim2.new(1, 0, 0.42, 0), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 2, Parent = fill }, { U.corner(9) })
	local txt = new("TextLabel", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = C(255, 255, 255),
		ZIndex = 4,
		Parent = bg,
	}, { U.textStroke(C(0, 0, 0), 1.6), new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }) })
	local ic = iconImg(holder, iconKey, UDim2.fromOffset(38, 38), UDim2.new(0, -6, 0.5, -19), 5)
	return { holder = holder, bg = bg, fill = fill, grad = grad, text = txt, icon = ic }
end

local function buildHUD()
	-- ===== панель ресурсов =====
	local panel = new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(352, 150),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, { U.corner(18), U.grad(C(255, 255, 255), C(150, 158, 150), 90) })
	local pst = U.stroke(C(255, 255, 255), 2)
	pst.Parent = panel
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(C(130, 230, 60), C(80, 200, 255)), Parent = pst })
	addScale(panel)
	hud.panel = panel
	hud.chips = {}

	-- «драгоценный» чип валюты: внутреннее свечение, блик по иконке, бегущий отблеск, мерцающие искры
	local function makeChip(x, iconKey, color, caption)
		local chip = new("CanvasGroup", {
			Position = UDim2.fromOffset(x, 8),
			Size = UDim2.fromOffset(164, 54),
			BackgroundColor3 = C(14, 18, 22),
			Parent = panel,
		}, { U.corner(16), U.grad(C(255, 255, 255), C(170, 170, 170), 90) })
		local st = U.stroke(color, 2)
		st.Parent = chip
		local stGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, color:Lerp(C(255, 255, 255), 0.8)), ColorSequenceKeypoint.new(1, color) }), Parent = st })
		-- мягкий цветной фон-свечение изнутри
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 1, Parent = chip }, { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) }) }) })
		local glow = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28, 27), Size = UDim2.fromOffset(96, 96), ZIndex = 2, Parent = chip })
		local icon = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons[iconKey], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28, 27), Size = UDim2.fromOffset(44, 44), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = chip })
		-- блик, пробегающий по форме самой иконки
		local glint = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons[iconKey], ImageColor3 = C(255, 255, 255), Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = icon })
		local glintGrad = new("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(-1, 0), Parent = glint })
		-- отблеск, проходящий по всему чипу
		local sheen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 6, Parent = chip })
		local sheenGrad = new("UIGradient", { Rotation = 20, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(-1.2, 0), Parent = sheen })
		local value = new("TextLabel", { Position = UDim2.fromOffset(56, 4), Size = UDim2.new(1, -62, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "0", TextScaled = true, TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = chip }, { U.textStroke(C(0, 0, 0), 2), new("UITextSizeConstraint", { MaxTextSize = 28 }) })
		local valueGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.45, color), ColorSequenceKeypoint.new(0.5, C(255, 255, 240)), ColorSequenceKeypoint.new(0.55, color), ColorSequenceKeypoint.new(1, color) }), Parent = value })
		new("TextLabel", { Position = UDim2.fromOffset(57, 34), Size = UDim2.new(1, -62, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = caption, TextSize = 11, TextColor3 = color:Lerp(C(255, 255, 255), 0.5), TextTransparency = 0.25, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = chip })
		-- искорки-звёздочки вокруг иконки
		local stars = {}
		for k = 1, 3 do
			local img = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = color:Lerp(C(255, 255, 255), 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 7, Parent = chip })
			stars[k] = { img = img, sc = U.scaleOf(img), start = -10, dur = 1 }
			stars[k].sc.Scale = 0
		end
		local c = { chip = chip, glow = glow, glowScale = U.scaleOf(glow), glintGrad = glintGrad, sheenGrad = sheenGrad, stGrad = stGrad, valueGrad = valueGrad, stars = stars, phase = #hud.chips * 1.7, icon = icon }
		table.insert(hud.chips, c)
		return value, c
	end
	hud.bat, hud.batChip = makeChip(8, "battery", C(170, 255, 80), "BATTERIES")
	hud.gems, hud.gemChip = makeChip(180, "gem", C(100, 215, 255), "GEMS")
	hud.scrapBar = makeBar(panel, UDim2.fromOffset(16, 68), UDim2.new(1, -28, 0, 32), C(170, 255, 90), C(70, 160, 30), "bag")
	-- Хэллоуин: тыквы — валюта события (справа от панели, под шестерёнкой настроек)
	if Config.HalloweenOn() then
		local pill = new("Frame", {
			Name = "Pumpkins",
			Position = UDim2.new(1, 8, 0, 58),
			Size = UDim2.fromOffset(164, 30),
			BackgroundColor3 = C(34, 16, 8),
			BackgroundTransparency = 0.08,
			Parent = panel,
		}, { U.corner(12), U.stroke(C(255, 140, 30), 2), U.grad(C(255, 255, 255), C(170, 140, 120), 90) })
		new("TextLabel", { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(26, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "🎃", TextSize = 20, Parent = pill })
		hud.pumpkins = new("TextLabel", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "0", TextSize = 18, TextColor3 = C(255, 175, 60), TextXAlignment = Enum.TextXAlignment.Left, Parent = pill }, { U.textStroke(C(0, 0, 0), 1.6) })
		new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(70, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "PUMPKINS", TextSize = 10, TextColor3 = C(255, 210, 150), TextTransparency = 0.25, TextXAlignment = Enum.TextXAlignment.Right, Parent = pill })
	end
	-- ресурсы по видам: 5 равных ячеек в ряд (не налезают друг на друга)
	local resRow = new("Frame", { Position = UDim2.fromOffset(8, 106), Size = UDim2.new(1, -16, 0, 36), BackgroundTransparency = 1, Parent = panel }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	hud.res = {}
	for i, r in ipairs(Config.Resources) do
		local cell = new("Frame", { Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = C(14, 18, 22), BackgroundTransparency = 0.15, LayoutOrder = i, Parent = resRow }, { U.corner(10) })
		local st = U.stroke(r.color, 1.5, 0.4)
		st.Parent = cell
		local ic = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.res and Icons.res[r.id] or "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(28, 28), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = cell })
		local val = new("TextLabel", { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -33, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "0", TextScaled = true, TextColor3 = r.color:Lerp(C(255, 255, 255), 0.35), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = cell }, { U.textStroke(C(0, 0, 0), 1.4), new("UITextSizeConstraint", { MaxTextSize = 15 }), new("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0) }) })
		hud.res[r.id] = { cell = cell, stroke = st, icon = ic, val = val, last = 0, def = r }
	end
	-- кнопка настроек (шестерёнка справа от панели)
	local setBtn = button({
		Position = UDim2.new(1, 8, 0, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = C(24, 30, 38),
		BackgroundTransparency = 0.05,
		Text = "",
		Parent = panel,
	}, function()
		SettingsUI.Toggle()
	end)
	U.corner(14).Parent = setBtn
	local sbs = U.stroke(C(255, 255, 255), 2)
	sbs.Parent = setBtn
	new("UIGradient", { Rotation = 45, Color = ColorSequence.new(C(90, 200, 255), C(170, 120, 255)), Parent = sbs })
	local gearImg = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.gear, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(36, 36), ZIndex = 3, Parent = setBtn })
	hud.setHot = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C(255, 255, 255), Font = Enum.Font.GothamBlack, Text = "P", TextSize = 10, TextColor3 = C(20, 20, 20), ZIndex = 5, Parent = setBtn }, { U.corner(5) })
	setBtn.MouseEnter:Connect(function()
		U.tween(gearImg, 0.4, { Rotation = gearImg.Rotation + 90 }, Enum.EasingStyle.Back)
	end)
	hud.setBtn = setBtn
	U.hitPad(setBtn, function()
		U.play(U.Sounds.click, 0.45, 1.05)
		SettingsUI.Toggle()
	end, 0.35)
	hud.fill, hud.fillGrad, hud.scrap = hud.scrapBar.fill, hud.scrapBar.grad, hud.scrapBar.text
	-- предупреждение о разряженных дронах (появляется только при необходимости)
	hud.chargeBtn = button({
		Position = UDim2.new(0, 0, 1, 8),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = C(255, 170, 30),
		Font = Enum.Font.GothamBlack,
		Text = "⚡ CHARGE DRONES",
		TextSize = 15,
		TextColor3 = C(30, 20, 0),
		Visible = false,
		ZIndex = 6,
		Parent = panel,
	}, function()
		Remotes.Teleport:FireServer("station")
		UI.Toast("⚡ Charging stations are by the south wall of the base: claim a free one and press E at the console", "info")
	end)
	U.corner(8).Parent = hud.chargeBtn
	hud.chargeBtn:GetPropertyChangedSignal("Visible"):Connect(function()
		UI.FitRail(true)
	end)
	hud.displayBat = 0

	-- ===== вкладки слева (иконки) =====
	local rail = new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(88, 470),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	hud.railScale = addScale(rail)
	hud.rail = rail
	hud.railList = rail:FindFirstChildOfClass("UIListLayout")
	-- на ПК вкладки идут сеткой 3×2 прямо под панелью валюты
	hud.railGrid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(80, 79),
		CellPadding = UDim2.fromOffset(12, 8),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 3,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local items = {
		{ key = "drones", icon = "drones", label = "Drones", color = C(130, 230, 60), hot = "Y" },
		{ key = "gacha", icon = "gacha", label = "Gacha", color = C(190, 90, 255), hot = "G" },
		{ key = "shop", icon = "shop", label = "Shop", color = C(255, 190, 80), hot = "N" },
		{ key = "map", icon = "teleport", label = "Map", color = C(255, 90, 80), hot = "M" },
		{ key = "bag", icon = "bag", label = "Inventory", color = C(80, 170, 255), hot = "B" },
		{ key = "convert", icon = "converter", label = "Recycling", color = C(120, 240, 110), hot = "R" },
		{ key = "quests", icon = "quest", label = "Quests", color = C(255, 200, 80), hot = "Q" },
		{ key = "donate", icon = "donate", label = "Donate", color = C(255, 90, 170), hot = "H" },
	}
	-- Хэллоуин: кнопка-телепорт к «Тыквенному котлу» (пока событие идёт; выключили событие — кнопки нет)
	if Config.HalloweenOn() then
		table.insert(items, { key = "halloween", pumpkin = true, label = "Cauldron", color = C(255, 140, 30), hot = "J" })
	end
	hud.buttons = {}
	hud.railFx = {}
	local BW, BH, EDGE = 80, 74, 5
	for i, it in ipairs(items) do
		-- объёмная кнопка: цветной «торец» снизу, стеклянная лицевая часть, свечение за иконкой
		local holder = new("Frame", { Name = it.key, Size = UDim2.fromOffset(BW, BH + EDGE), BackgroundTransparency = 1, LayoutOrder = i, Parent = rail })
		new("Frame", { Name = "Shadow", Position = UDim2.fromOffset(2, EDGE + 3), Size = UDim2.fromOffset(BW, BH), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.6, Parent = holder }, { U.corner(18) })
		local edgeF = new("Frame", { Name = "Edge", Position = UDim2.fromOffset(0, EDGE), Size = UDim2.fromOffset(BW, BH), BackgroundColor3 = it.color:Lerp(C(0, 0, 0), 0.5), Parent = holder }, { U.corner(18) })
		local b = button({
			Size = UDim2.fromOffset(BW, BH),
			BackgroundColor3 = C(255, 255, 255),
			Text = "",
			ClipsDescendants = true,
			ZIndex = 2,
			Parent = holder,
		}, function()
			UI.OnMenu(it.key)
		end)
		U.corner(18).Parent = b
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(46, 52, 64), C(14, 16, 22)), Parent = b })
		-- переливающаяся рамка
		local st = U.stroke(C(255, 255, 255), 2.5)
		st.Parent = b
		local stGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, it.color), ColorSequenceKeypoint.new(0.5, it.color:Lerp(C(255, 255, 255), 0.75)), ColorSequenceKeypoint.new(1, it.color) }), Parent = st })
		-- цветная подсветка снизу и стеклянный блик сверху
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = it.color, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 2, Parent = b }, { U.corner(18), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.6), NumberSequenceKeypoint.new(1, 0) }) }) })
		new("Frame", { Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.42, 0), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 3, Parent = b }, { U.corner(14), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) }) })
		local glow = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Icons.glow,
			ImageColor3 = it.color,
			ImageTransparency = 0.45,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.fromOffset(78, 78),
			ZIndex = 3,
			Parent = b,
		})
		local ic = it.pumpkin and pumpkinIcon(b) or iconImg(b, it.icon, UDim2.fromOffset(46, 46), UDim2.new(0.5, 0, 0, 30), 4)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		local icScale = U.scaleOf(ic)
		local glowScale = U.scaleOf(glow)
		-- блик, пробегающий по кнопке
		local sheen = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.6, 0, 0.5, 0), Size = UDim2.new(0, 16, 2, 0), Rotation = 22, BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 6, Parent = b })
		-- подпись-плашка
		local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 17), BackgroundColor3 = it.color:Lerp(C(0, 0, 0), 0.62), BackgroundTransparency = 0.1, ZIndex = 4, Parent = b }, { U.corner(8) })
		local lbl = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = it.label,
			TextScaled = true,
			TextColor3 = it.color:Lerp(C(255, 255, 255), 0.55),
			ZIndex = 5,
			Parent = pill,
		}, { U.textStroke(C(0, 0, 0), 1.4), new("UITextSizeConstraint", { MaxTextSize = 12 }), new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }) })
		table.insert(hud.railFx, { b = b, ic = ic, glow = glow, stGrad = stGrad, sheen = sheen, ph = i * 0.9, nextSheen = os.clock() + 1 + i * 0.7, hover = false })
		local fx = hud.railFx[#hud.railFx]
		local sub = new("TextLabel", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(46, 16),
			BackgroundColor3 = C(0, 0, 0),
			BackgroundTransparency = 0.35,
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextSize = 10,
			TextColor3 = C(255, 255, 255),
			Visible = false,
			ZIndex = 5,
			Parent = b,
		}, { U.corner(5) })
		local hot
		if it.hot then
			hot = new("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = C(255, 255, 255),
				Font = Enum.Font.GothamBlack,
				Text = it.hot,
				TextSize = 11,
				TextColor3 = C(20, 20, 20),
				ZIndex = 5,
				Parent = b,
			}, { U.corner(5) })
		end
		-- наведение: кнопка приподнимается над торцом, иконка увеличивается, свечение ярче
		b.MouseEnter:Connect(function()
			fx.hover = true
			U.tween(b, 0.15, { Position = UDim2.fromOffset(0, -2) }, Enum.EasingStyle.Back)
			U.tween(icScale, 0.2, { Scale = 52 / 46 }, Enum.EasingStyle.Back)
			U.tween(glow, 0.2, { ImageTransparency = 0.15 })
			U.tween(glowScale, 0.2, { Scale = 92 / 78 })
		end)
		b.MouseLeave:Connect(function()
			fx.hover = false
			U.tween(b, 0.15, { Position = UDim2.fromOffset(0, 0) })
			U.tween(icScale, 0.2, { Scale = 1 })
			U.tween(glow, 0.2, { ImageTransparency = 0.45 })
			U.tween(glowScale, 0.2, { Scale = 1 })
		end)
		-- нажатие: кнопка вдавливается в торец, иконка подпрыгивает, расходятся кольцо и искры
		b.Activated:Connect(function()
			U.tween(b, 0.06, { Position = UDim2.fromOffset(0, EDGE - 1) }).Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					U.tween(b, 0.28, { Position = UDim2.fromOffset(0, fx.hover and -2 or 0) }, Enum.EasingStyle.Back)
				end
			end)
			fx.jump = os.clock()
			fx.nextSheen = 0
			U.tween(glow, 0.07, { ImageTransparency = 0 })
			U.tween(glowScale, 0.07, { Scale = 40 / 78 }).Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					U.tween(glowScale, 0.45, { Scale = fx.hover and 92 / 78 or 1 })
					U.tween(glow, 0.45, { ImageTransparency = fx.hover and 0.15 or 0.45 })
				end
			end)
			local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, ZIndex = 6, Parent = b }, { U.round() })
			local rs = U.stroke(it.color:Lerp(C(255, 255, 255), 0.3), 4)
			rs.Parent = ring
			U.tween(ring, 0.45, { Size = UDim2.fromOffset(104, 104) })
			U.tween(rs, 0.45, { Transparency = 1, Thickness = 1 })
			for k = 1, 8 do
				local a = k / 8 * math.pi * 2 + math.random() * 0.4
				local sp = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = it.color:Lerp(C(255, 255, 255), 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(16, 16), ZIndex = 7, Parent = b })
				local d = math.random(34, 50)
				U.tween(sp, 0.5, { Position = UDim2.new(0.5, math.cos(a) * d, 0, 30 + math.sin(a) * d), Size = UDim2.fromOffset(4, 4), ImageTransparency = 1, Rotation = math.random(-180, 180) }, Enum.EasingStyle.Quart)
				task.delay(0.55, function()
					sp:Destroy()
				end)
			end
			task.delay(0.5, function()
				ring:Destroy()
			end)
		end)
		hud.buttons[it.key] = { b = b, label = lbl, sub = sub, hot = hot, icon = ic, holder = holder }
	end
	-- живые кнопки: иконки плавают, рамка переливается, иногда пробегает блик
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, f in ipairs(hud.railFx) do
			-- Покачивание иконки — только поворотом. Интерфейс рисуется по целым пикселям, и медленный
			-- сдвиг на 1–2 пикселя выглядит как подёргивание; поворот же отрисовывается без ступенек.
			f.tilt = (f.tilt or 0) + ((f.hover and -6 or 0) - (f.tilt or 0)) * math.min(1, dt * 12)
			local rot = math.sin(t * 1.6 + f.ph) * 5 + f.tilt
			local y = 0
			if f.jump then
				local k = (t - f.jump) / 0.5
				if k < 1 then
					y = -math.sin(k * math.pi) * 9 * (1 - k * 0.5)
					rot += math.sin(k * math.pi * 2) * 14 * (1 - k)
				else
					f.jump = nil
				end
			end
			f.ic.Rotation = rot
			f.ic.Position = UDim2.new(0.5, 0, 0, 30 + y)
			f.stGrad.Rotation = (t * 60 + f.ph * 40) % 360
			if t >= f.nextSheen then
				f.nextSheen = t + 4 + math.random() * 3
				f.sheen.Position = UDim2.new(-0.6, 0, 0.5, 0)
				U.tween(f.sheen, 0.55, { Position = UDim2.new(1.6, 0, 0.5, 0) })
			end
		end
	end)

	-- ===== здоровье =====
	local hpHolder = new("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -94),
		Size = UDim2.fromOffset(330, 26),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	hud.hpScale = addScale(hpHolder)
	hud.hpHolder = hpHolder
	hud.hpBar = makeBar(hpHolder, UDim2.new(), UDim2.fromScale(1, 1), C(255, 110, 110), C(190, 20, 30), "health")
	-- сердце: свечение за иконкой, сердцебиение (чаще при низком HP), вспышка и дрожь при уроне
	do
		local ic = hud.hpBar.icon
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.new(0, 13, 0.5, 0)
		ic.Size = UDim2.fromOffset(32, 32)
		local glow = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = C(255, 60, 70), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = ic.Position, Size = UDim2.fromOffset(60, 60), ZIndex = 4, Parent = hud.hpBar.holder })
		local ring = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.health, ImageColor3 = C(255, 255, 255), ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = ic.Position, Size = UDim2.fromOffset(32, 32), ZIndex = 4, Parent = hud.hpBar.holder })
		hud.heart = { icon = ic, glow = glow, ring = ring, hit = 0, phase = 0, iconScale = U.scaleOf(ic), glowScale = U.scaleOf(glow), ringScale = U.scaleOf(ring) }
		RunService.RenderStepped:Connect(function(dt)
			local h = hud.heart
			local low = hud.hpLow
			h.phase += dt * (low and 2.6 or 1.15)
			local ph = h.phase % 1
			-- двойной удар «тук-тук»
			local beat = math.max(0, 1 - math.abs(ph - 0.08) / 0.08) + 0.6 * math.max(0, 1 - math.abs(ph - 0.28) / 0.08)
			local s = 32 * (1 + beat * (low and 0.22 or 0.12)) + h.hit * 8
			-- размер через UIScale: дробный масштаб, удары сердца без пиксельной «лесенки»
			h.iconScale.Scale = s / 32
			h.glowScale.Scale = (56 + beat * 18 + h.hit * 16) / 60
			h.glow.ImageTransparency = 0.55 - beat * 0.3 - h.hit * 0.3
			-- кольцо-импульс расходится от сердца на каждом ударе
			local rp = math.clamp(ph / 0.45, 0, 1)
			h.ringScale.Scale = (32 + rp * 26) / 32
			h.ring.ImageTransparency = 0.55 + rp * 0.45
			h.ring.ImageColor3 = low and C(255, 120, 60) or C(255, 170, 180)
			if h.hit > 0 then
				-- плавное затухающее покачивание вместо случайной дрожи
				h.icon.Rotation = math.sin(os.clock() * 38) * 13 * h.hit
				h.icon.ImageColor3 = C(255, 255, 255):Lerp(C(255, 120, 120), h.hit)
				h.hit = math.max(0, h.hit - dt * 3)
			else
				h.icon.Rotation = 0
				h.icon.ImageColor3 = C(255, 255, 255)
			end
		end)
	end

	-- ===== хотбар: оружие, инструмент, дальше свободные ячейки под любой предмет =====
	local NSLOT = ShopCfg.HotbarWeapons + HS.Free
	local hb = new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(NSLOT * 68 + (NSLOT - 1) * 8 + 10, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }) })
	hud.hbScale = addScale(hb)
	hud.hotbar = hb
	hud.slots = {}
	for i = 1, NSLOT do
		local slot = new("TextButton", {
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = C(22, 26, 22),
			BackgroundTransparency = 0.1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			Parent = hb,
		}, { U.corner(14), U.grad(C(255, 255, 255), C(140, 140, 140), 90) })
		local st = U.stroke(C(80, 90, 80), 2)
		st.Parent = slot
		local vp = new("ViewportFrame", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundTransparency = 1,
			Ambient = C(170, 170, 170),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			Visible = false,
			Parent = slot,
		})
		local img = iconImg(slot, "medkit", UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8), 3)
		img.Visible = false
		hud.slotKeys = hud.slotKeys or {}
		table.insert(hud.slotKeys, { i = i, lbl = new("TextLabel", {
			Position = UDim2.fromOffset(5, 3),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(i),
			TextSize = 14,
			TextColor3 = C(255, 255, 255),
			ZIndex = 5,
			Parent = slot,
		}, { U.textStroke(C(0, 0, 0), 1.5) }) })
		local count = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -2),
			Size = UDim2.fromOffset(40, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C(255, 255, 255),
			ZIndex = 5,
			Parent = slot,
		}, { U.textStroke(C(0, 0, 0), 1.5) })
		-- значок типа ячейки: ⚔ оружие / ⛏ инструмент
		local kind
		if i <= ShopCfg.HotbarWeapons then
			local isTool = ShopCfg.HotbarOrder and ShopCfg.HotbarOrder[i] == "tool"
			kind = new("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = isTool and C(255, 190, 60) or C(255, 90, 80),
				Font = Enum.Font.GothamBlack,
				Text = isTool and "⛏" or "⚔",
				TextSize = 12,
				TextColor3 = C(20, 20, 20),
				ZIndex = 6,
				Parent = slot,
			}, { U.corner(10) })
		end
		local entry = { slot = slot, stroke = st, vp = vp, img = img, count = count, index = i, kind = kind }
		slot.Activated:Connect(function()
			if HS.JustDropped() then
				return
			end
			UI.UseSlot(i)
		end)
		if i > ShopCfg.HotbarWeapons then
			-- свободная ячейка: «+» когда пусто, подпись с названием при наведении, перетаскивание
			local fi = i - ShopCfg.HotbarWeapons
			entry.free = fi
			entry.plus = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromOffset(30, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = "+",
				TextSize = 30,
				TextColor3 = C(150, 170, 150),
				TextTransparency = 0.55,
				ZIndex = 4,
				Parent = slot,
			})
			entry.imgScale = U.scaleOf(img)
			entry.hoverScale = U.scaleOf(slot)
			entry.pill = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -6),
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = C(16, 20, 16),
				BackgroundTransparency = 0.1,
				Font = Enum.Font.GothamBold,
				Text = "",
				TextSize = 13,
				TextColor3 = C(255, 255, 255),
				Visible = false,
				ZIndex = 8,
				Parent = slot,
			}, { U.corner(8), U.stroke(C(90, 110, 90), 1.5), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
			slot.MouseEnter:Connect(function()
				entry.mouseOn = true
				local vis = HS.Visual(HS.Key(fi))
				entry.pill.Text = vis and vis.name or "Empty. Drag an item here from the inventory (B)"
				U.fadeVisible(entry.pill, true, 0.15)
			end)
			slot.MouseLeave:Connect(function()
				entry.mouseOn = false
				U.fadeVisible(entry.pill, false, 0.15)
			end)
			-- ПКМ очищает ячейку
			slot.MouseButton2Click:Connect(function()
				if HS.Key(fi) ~= "" then
					HS.Assign(fi, "")
					U.play(U.Sounds.tap, 0.4, 0.8)
				end
			end)
			HS.AttachSource(slot, function()
				local k = HS.Key(fi)
				return k ~= "" and k or nil
			end, function()
				return fi
			end)
			HS.AddTarget(slot, fi, function(on)
				entry.hoverOn = on
				UI.StyleFreeSlot(entry)
			end, function(on)
				entry.dragOn = on
				UI.StyleFreeSlot(entry)
			end, function()
				return not (BagUI.IsOpen() or ShopUI.IsOpen and ShopUI.IsOpen())
			end)
		end
		hud.slots[i] = entry
	end

	-- ===== уведомления =====
	toastHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(480, 230),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	addScale(toastHolder)

	-- ===== баннер зоны =====
	hud.banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(700, 100),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	hud.bannerScale = addScale(hud.banner)
	hud.bannerTitle = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 52,
		TextColor3 = C(255, 255, 255),
		Parent = hud.banner,
	}, { U.textStroke(C(0, 0, 0), 4) })
	hud.bannerSub = new("TextLabel", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = T.Accent,
		Parent = hud.banner,
	}, { U.textStroke(C(0, 0, 0), 2) })
end

local EDGE_PAD = 4
-- вкладки слева всегда начинаются под панелью ресурсов и ужимаются, если не влезают по высоте
function UI.FitRail(animate)
	if not hud.rail or layoutMode == "mobile" then
		return
	end
	local ps = respScale
	local top = hud.panel.Position.Y.Offset + 150 * ps + 12
	if hud.chargeBtn and hud.chargeBtn.Visible and not hud.chargeBtn:GetAttribute("FadingOut") then
		top += 40 * ps
	end
	local rows = math.ceil(#hud.railFx / 3)
	local need = rows * 79 + (rows - 1) * 8
	local avail = (gui and gui.AbsoluteSize.Y or 700) - top - 12
	-- ширина сетки равна ширине панели валюты (352), кнопки по центру
	hud.rail.Size = UDim2.fromOffset(352, need)
	local pos = UDim2.fromOffset(hud.panel.Position.X.Offset, top)
	local sc = math.clamp(avail / need, 0.45, ps)
	if animate then
		-- появилась/исчезла кнопка «Зарядить» — вкладки плавно съезжают
		U.tween(hud.rail, 0.3, { Position = pos }, Enum.EasingStyle.Quart)
		U.tween(hud.railScale, 0.3, { Scale = sc }, Enum.EasingStyle.Quart)
	else
		hud.rail.Position = pos
		hud.railScale.Scale = sc
	end
end

-- Верхняя полоса Roblox (TopbarInset): справа от её кнопок свободное место, на телефоне туда встают вкладки.
-- Возвращает рамку этой области или nil, если полосы нет / она слишком узкая.
function UI.LayoutTopArea()
	local tb = GuiService.TopbarInset
	local area = UI.TopArea
	if not area or tb.Height < 30 then
		return nil
	end
	-- правый край не заходит под вырез/скругление экрана
	local right = tb.Max.X
	local probe = UI.SafeProbe
	if probe and probe.AbsoluteSize.X > 50 then
		right = math.min(right, probe.AbsolutePosition.X + probe.AbsoluteSize.X)
	end
	local left = tb.Min.X + 6
	right -= 6
	if right - left < 220 then
		return nil
	end
	area.Position = UDim2.fromOffset(left, tb.Min.Y + 2)
	area.Size = UDim2.fromOffset(right - left, tb.Height - 4)
	return area
end

-- раскладка под устройство
function UI.ApplyLayout(mode)
	if not hud.rail then
		return
	end
	local mobile = mode == "mobile"
	hud.panel.Size = UDim2.fromOffset(352, 150)
	hud.panel.Position = mobile and UDim2.fromOffset(6, 4) or UDim2.fromOffset(12, 10)
	local list = hud.railList
	list.Parent = mobile and hud.rail or nil
	hud.railGrid.Parent = (not mobile) and hud.rail or nil
	if mobile then
		-- телефон: вкладки строкой справа в верхней полосе Roblox (рядом с её кнопками),
		-- чтобы не занимать и без того низкий экран; снизу джойстик и прыжок
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.Padding = UDim.new(0, 8)
		hud.rail.Size = UDim2.fromOffset(#hud.railFx * 88, 86)
		local area = UI.TopArea and UI.LayoutTopArea()
		if area then
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			hud.rail.Parent = area
			hud.rail.AnchorPoint = Vector2.new(1, 0.5)
			hud.rail.Position = UDim2.new(1, 0, 0.5, 0)
			local a = area.AbsoluteSize
			hud.railScale.Scale = math.min((a.Y - 2) / 82, a.X / (#hud.railFx * 88), 0.75)
		else
			list.VerticalAlignment = Enum.VerticalAlignment.Top
			hud.rail.Parent = gui
			hud.rail.AnchorPoint = Vector2.new(1, 0)
			hud.rail.Position = UDim2.new(1, -6, 0, 4)
			hud.railScale.Scale = respScale * 0.85
		end
	else
		hud.rail.Parent = gui
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		hud.rail.AnchorPoint = Vector2.new(0, 0)
		UI.FitRail()
	end
	-- вкладки ушли в верхнюю полосу — верх экрана свободен, часы и полоса босса стоят как на ПК
	BagUI.ApplyLayout(mobile and hud.rail.Parent == gui)
	QuestUI.ApplyLayout(mobile)
	if toastHolder then
		toastHolder.Position = mobile and UDim2.new(0.5, 0, 0, 96) or UDim2.new(0.5, 0, 0, 132)
	end
	for _, b in pairs(hud.buttons) do
		b.label.Visible = true
		if b.hot then
			b.hot.Visible = not mobile
		end
	end
	-- на телефоне клавиш нет: прячем подсказку-клавишу у шестерёнки
	if hud.setHot then
		hud.setHot.Visible = not mobile
	end
	-- на телефоне хотбар выше (над кнопками экрана), ячейки крупнее
	hud.hotbar.Position = mobile and UDim2.new(0.5, 0, 1, -8) or UDim2.new(0.5, 0, 1, -14)
	hud.hpHolder.Position = mobile and UDim2.new(0.5, 0, 1, -90) or UDim2.new(0.5, 0, 1, -94)
	hud.hpHolder.Size = UDim2.fromOffset(mobile and 290 or 330, 26)
	if mobile then
		hud.hbScale.Scale = math.max(respScale, 0.72)
		hud.hpScale.Scale = math.max(respScale, 0.7)
	end
end

local function energyStats()
	local total, sum, tired, docked = 0, 0, 0, 0
	for _, e in pairs(UI.Energy) do
		total += 1
		sum += e.e
		if e.e <= 0 then
			tired += 1
		end
		if e.s == 1 then
			docked += 1
		end
	end
	return total, total > 0 and sum / total or 100, tired, docked
end

function UI.UpdateEnergyHUD()
	if not hud.chargeBtn then
		return
	end
	local total, avg, tired, docked = energyStats()
	local was = hud.energyLow
	hud.energyLow = tired > 0 and docked == 0
	if hud.energyLow ~= was then
		U.fadeVisible(hud.chargeBtn, hud.energyLow, 0.25)
		if not hud.energyLow then
			UI.FitRail(true) -- кнопка уходит — вкладки поднимаются одновременно с её исчезновением
		end
	end
	if hud.energyLow then
		hud.chargeBtn.Text = ("⚡ Drones out of charge: %d  •  CHARGE"):format(tired)
	end
end

local function updateHUD(d)
	if hud.gems then
		U.countTo(hud.gems, d.gems or 0)
	end
	if hud.pumpkins then
		U.countTo(hud.pumpkins, d.pumpkins or 0)
	end
	local ratio = math.clamp(d.scrap / math.max(d.capacity, 1), 0, 1)
	U.tween(hud.fill, 0.25, { Size = UDim2.fromScale(math.max(ratio, 0.02), 1) })
	local full = d.scrap >= d.capacity
	hud.full = full
	if full then
		U.countTo(hud.scrap, d.scrap, function()
			return "BACKPACK FULL! Go to the Recycler"
		end)
		U.gradTo(hud.fillGrad, C(255, 190, 60), C(220, 90, 20))
	else
		local cap = d.capacity
		U.countTo(hud.scrap, d.scrap, function(v)
			return ("Backpack: %s / %s"):format(U.fmt(v), U.fmt(cap))
		end, 0.25)
		U.gradTo(hud.fillGrad, C(170, 255, 90), C(70, 160, 30))
	end
	-- ячейки ресурсов: пульс иконки при пополнении
	for id, e in pairs(hud.res or {}) do
		local n = d.res and d.res[id] or 0
		U.countTo(e.val, n)
		local has = n > 0
		U.tween(e.icon, 0.3, { ImageTransparency = has and 0 or 0.65 })
		U.tween(e.val, 0.3, { TextTransparency = has and 0 or 0.5 })
		U.tween(e.stroke, 0.3, { Transparency = has and 0.1 or 0.6 })
		if n > e.last then
			U.pulseScale(e.icon, 36 / 28)
		end
		e.last = n
	end
	local bag = hud.buttons.bag
	local kinds = 0
	for _, n in pairs(d.bag or {}) do
		if n > 0 then
			kinds += 1
		end
	end
	U.fadeVisible(bag.sub, kinds > 0)
	bag.sub.Text = ("%d/%d"):format(kinds, ItemsCfg.BagSlots)
	-- задания: сколько можно сдать прямо сейчас
	local qb = hud.buttons.quests
	local ready = QuestUI.ReadyCount()
	if ready > 0 then
		qb.sub.Text = "✔ " .. ready
		qb.sub.BackgroundColor3 = C(60, 170, 40)
	end
	U.fadeVisible(qb.sub, ready > 0)
	local dr = hud.buttons.drones
	dr.sub.Visible = true
	dr.sub.Text = ("%d/%d"):format(d.equippedTotal, d.maxSlots)
	if UI.RefreshHotbar then
		UI.RefreshHotbar()
	end
end

-- ===== ЗДОРОВЬЕ ИГРОКА =====
local function watchHealth(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local lastHp = hum.Health
	local function upd()
		local r = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		if hud.heart then
			if hum.Health < lastHp - 0.5 then
				hud.heart.hit = 1
			elseif hum.Health > lastHp + 0.5 then
				-- лечение: зелёная вспышка свечения
				local glow = hud.heart.glow
				U.tween(glow, 0.15, { ImageColor3 = C(120, 255, 140) }).Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed then
						U.tween(glow, 0.5, { ImageColor3 = C(255, 60, 70) })
					end
				end)
			end
		end
		lastHp = hum.Health
		U.tween(hud.hpBar.fill, 0.2, { Size = UDim2.fromScale(math.max(r, 0.02), 1) })
		local maxHp = hum.MaxHealth
		U.countTo(hud.hpBar.text, math.max(0, math.ceil(hum.Health)), function(v)
			return ("Health: %d / %d"):format(math.ceil(v), maxHp)
		end, 0.25)
		if r < 0.3 then
			U.gradTo(hud.hpBar.grad, C(255, 200, 80), C(220, 40, 20))
		else
			U.gradTo(hud.hpBar.grad, C(255, 110, 110), C(190, 20, 30))
		end
		hud.hpLow = r < 0.3
	end
	hum.HealthChanged:Connect(upd)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(upd)
	upd()
end

-- ===== ХОТБАР =====
local function heldTool()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Tool")
end

local function weaponTools()
	local list = {}
	for _, c in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if c then
			for _, t in ipairs(c:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("HotbarSlot") then
					list[t:GetAttribute("HotbarSlot")] = t
				end
			end
		end
	end
	return list
end

-- рамка свободной ячейки: цвет предмета, подсветка во время перетаскивания и под указателем
function UI.StyleFreeSlot(e)
	local color, thick, bg = e.baseColor or C(70, 80, 70), 2, C(22, 26, 22)
	if e.hoverOn then
		color, thick, bg = T.Accent, 4, C(40, 70, 30)
	elseif e.dragOn then
		color, thick, bg = C(150, 220, 120), 3, C(30, 40, 28)
	end
	U.tween(e.stroke, 0.18, { Color = color, Thickness = thick })
	U.tween(e.slot, 0.18, { BackgroundColor3 = bg })
	U.tween(e.hoverScale, 0.2, { Scale = e.hoverOn and 1.12 or 1 }, Enum.EasingStyle.Back)
	U.tween(e.plus, 0.2, { TextTransparency = e.shown and 1 or (e.dragOn and 0.15 or 0.55) })
end

function UI.RefreshHotbar()
	if not hud.slots then
		return
	end
	local tools = weaponTools()
	local held = heldTool()
	local d = State.data
	local hbList = HS.List()
	for i, e in ipairs(hud.slots) do
		if i <= ShopCfg.HotbarWeapons then
			local t = tools[i]
			local id = t and t:GetAttribute("ZSSWeapon")
			if id ~= e.id then
				e.id = id
				for _, c in ipairs(e.vp:GetChildren()) do
					if c:IsA("Model") then
						c:Destroy()
					end
				end
				if id and ShopCfg.ById[id] then
					local m = ItemBuilder.Weapon(ShopCfg.ById[id])
					local cam = Builder.SetupViewport(e.vp, m, math.rad(50), math.rad(5), 0.72)
					cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(-45)) -- оружие по диагонали ячейки
					e.vp.Ambient = C(220, 220, 220)
				end
			end
			e.vp.Visible = id ~= nil
			e.img.Visible = false
			e.count.Text = ""
			e.tool = t
			local selected = t ~= nil and t == held
			U.tween(e.stroke, 0.18, { Color = selected and T.Accent or (id and ShopCfg.Grades[ShopCfg.ById[id].grade].color or C(70, 80, 70)), Thickness = selected and 4 or 2 })
			U.tween(e.slot, 0.18, { BackgroundColor3 = selected and C(40, 70, 30) or C(22, 26, 22) })
		else
			local key = hbList[e.free] or ""
			local vis = HS.Visual(key)
			e.vp.Visible = false
			e.img.Visible = true
			if key ~= e.id then
				local first = e.id == nil
				e.id = key
				if vis then
					-- новый предмет в ячейке: иконка «впрыгивает»
					e.img.Image = vis.image
					if not first then
						e.img.ImageTransparency = 1
						e.imgScale.Scale = 0.4
						U.tween(e.imgScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
						U.pulseScale(e.slot, 1.08)
					end
				end
				if e.mouseOn then
					e.pill.Text = vis and vis.name or "Empty. Drag an item here from the inventory (B)"
				end
			end
			local n = vis and HS.Count(key) or 0
			e.shown = vis ~= nil
			-- закончился — иконка остаётся полупрозрачной, чтобы было видно, что тут лежало
			e.count.Text = vis and ("x" .. n) or ""
			e.count.TextColor3 = n > 0 and C(255, 255, 255) or C(255, 120, 110)
			U.tween(e.img, 0.2, { ImageTransparency = vis and (n > 0 and 0 or 0.6) or 1 })
			e.baseColor = vis and (n > 0 and vis.color or vis.color:Lerp(C(70, 80, 70), 0.65)) or C(70, 80, 70)
			UI.StyleFreeSlot(e)
		end
	end
end

function UI.UseSlot(i)
	local e = hud.slots[i]
	if not e then
		return
	end
	U.tween(e.slot, 0.08, { Size = UDim2.fromOffset(62, 62) }).Completed:Connect(function()
		U.tween(e.slot, 0.15, { Size = UDim2.fromOffset(68, 68) }, Enum.EasingStyle.Back)
	end)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if i <= ShopCfg.HotbarWeapons then
		if e.tool then
			if heldTool() == e.tool then
				hum:UnequipTools()
			else
				hum:EquipTool(e.tool)
			end
			U.play(U.Sounds.tick, 0.4, 1.1)
		end
	elseif HS.Use(e.free) then
		U.play(U.Sounds.pop, 0.5, 1.2)
	end
	task.delay(0.1, UI.RefreshHotbar)
end

local function hookHotbarContainers()
	local function watch(c)
		if not c then
			return
		end
		c.ChildAdded:Connect(function()
			task.defer(UI.RefreshHotbar)
		end)
		c.ChildRemoved:Connect(function()
			task.defer(UI.RefreshHotbar)
		end)
	end
	watch(player:WaitForChild("Backpack"))
	if player.Character then
		watch(player.Character)
		task.spawn(watchHealth, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		watch(char)
		watch(player:WaitForChild("Backpack"))
		task.spawn(watchHealth, char)
		task.delay(1, UI.RefreshHotbar)
	end)
end

-- ===== КАРТА (быстрое перемещение) =====
local mapWin = {}
local function buildMap()
	local win = new("Frame", {
		Name = "Map",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(620, 560),
		BackgroundColor3 = T.Bg,
		Visible = false,
		Parent = gui,
	}, { U.corner(18), U.stroke(C(255, 90, 80), 3), U.grad(C(255, 255, 255), C(160, 165, 160), 90) })
	mapWin.win = win
	mapWin.scale = addScale(win)
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = T.Panel, Parent = win }, { U.corner(18) })
	iconImg(header, "teleport", UDim2.fromOffset(42, 42), UDim2.fromOffset(14, 9))
	new("TextLabel", {
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "MAP • FAST TRAVEL",
		TextSize = 22,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	}, { U.textStroke(C(0, 0, 0), 2) })
	local close = button({
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
		closeWindow(win)
	end)
	U.corner(10).Parent = close
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 72),
		Size = UDim2.new(1, -28, 1, -86),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C(255, 90, 80),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		Parent = win,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local fieldsById = {}
	for _, f in ipairs(Config.Fields) do
		fieldsById[f.id] = f
	end
	local entries = {
		{ id = "base", name = "Survivor Base", desc = "Scrap Recycler", icon = "base" },
		{ id = "station", name = "Charging Station", desc = "Cells for charging drones (at the base)", icon = "energy" },
		{ id = "gacha", name = "Drone Lab", desc = "Gacha: new drones", icon = "gacha" },
		{ id = "shop", name = "Shop", desc = "Weapons, tools, gear", icon = "shop" },
	}
	if Config.HalloweenOn() then
		table.insert(entries, { id = "halloween", name = "🎃 Pumpkin Cauldron", desc = "Halloween drone gacha", icon = "gacha" })
	end
	for _, loc in ipairs(Config.Locations) do
		if loc.field then
			local f = fieldsById[loc.id]
			table.insert(entries, { id = f.id, name = f.name, field = f, icon = f.boss and "boss" or "scrap" })
		end
	end
	mapWin.rows = {}
	for i, e in ipairs(entries) do
		local row = new("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = T.Panel, LayoutOrder = i, Parent = list }, { U.corner(12), U.stroke(C(70, 80, 70), 1.5) })
		iconImg(row, e.icon, UDim2.fromOffset(46, 46), UDim2.fromOffset(10, 9))
		new("TextLabel", {
			Position = UDim2.fromOffset(66, 8),
			Size = UDim2.new(1, -230, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = e.name,
			TextSize = 19,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, { U.textStroke(C(0, 0, 0), 1.5) })
		local desc = new("TextLabel", {
			Position = UDim2.fromOffset(66, 33),
			Size = UDim2.new(1, -230, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = e.desc or "",
			TextSize = 13,
			RichText = true,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local go = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 42),
			BackgroundColor3 = C(200, 60, 50),
			Font = Enum.Font.GothamBlack,
			Text = "GO",
			TextSize = 16,
			TextColor3 = C(255, 255, 255),
			Parent = row,
		}, function()
			-- закрытая локация: не телепортируем, объясняем почему (сервер тоже проверяет)
			local f = e.field
			local have = State.data and State.data.equippedTotal or 0
			if f and have < (f.req or 0) then
				UI.Toast(("🔒 “%s” unlocks when your swarm has %d drones (now %d)"):format(f.name, f.req, have), "bad")
				return
			end
			Remotes.Teleport:FireServer(e.id)
			closeWindow(win)
		end)
		U.corner(10).Parent = go
		mapWin.rows[i] = { e = e, desc = desc, go = go }
	end
end

function UI.UpdateMap()
	local d = State.data
	for _, r in ipairs(mapWin.rows or {}) do
		local f = r.e.field
		if f then
			local ok = d and d.equippedTotal >= f.req
			local h = f.tier and ("tier " .. (f.tier + 1)) or "plains"
			r.desc.Text = ok and ('<font color="#8CFF5A">✔ Unlocked</font>  •  scrap x%s  •  %s'):format(tostring(f.mult), h)
				or ('<font color="#FF6A5A">🔒 Needs %d drones</font>  •  scrap x%s  •  %s'):format(f.req, tostring(f.mult), h)
			r.go.BackgroundColor3 = ok and C(200, 60, 50) or C(80, 80, 80)
		end
	end
end

function UI.ToggleMap()
	if U.isOpen(mapWin.win, mapWin.scale) then
		closeWindow(mapWin.win, mapWin.scale)
	else
		closeWindow(inv.win, inv.scale)
		closeWindow(gacha.win, gacha.scale)
		ShopUI.Close()
		DonateUI.Close()
		QuestUI.CloseBook()
		UI.UpdateMap()
		openWindow(mapWin.win, mapWin.scale)
	end
end

-- ===== 3D-ВИТРИНЫ =====
-- Фон окна с прямоугольным «окошком»: четыре полосы вокруг окошка, внешние углы скруглены.
-- Сквозь окошко виден мир, и витрина показывает настоящего 3D-дрона в полном разрешении.
local function holedBackground(parent, W, H, hole, radius, color, g0, g1)
	local function piece(x, y, w, h, rounded)
		local f = new("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = parent,
		})
		if rounded then
			U.corner(radius).Parent = f
		end
		if g0 then
			-- общий вертикальный градиент окна, разрезанный по полосам
			local c0 = g0:Lerp(g1, y / H)
			local c1 = g0:Lerp(g1, (y + h) / H)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c0, c1), Parent = f })
		end
	end
	local bottomY = hole.y + hole.h
	piece(0, 0, W, hole.y, true)
	piece(0, hole.y - radius, W, radius, false) -- снизу у верхней полосы углы прямые
	piece(0, bottomY, W, H - bottomY, true)
	piece(0, bottomY, W, radius, false)
	-- боковые полосы на пиксель заходят на соседние, чтобы при масштабе окна не было щелей
	piece(0, hole.y - 1, hole.x, hole.h + 2, false)
	piece(hole.x + hole.w, hole.y - 1, W - hole.x - hole.w, hole.h + 2, false)
end

-- 3D-витрина (гача и окно дронов). Дрон в ViewportFrame рисовался с пониженной частотой кадров и в низком
-- разрешении, поэтому он стоит в мире прямо перед камерой, точно за окошком в окне интерфейса.
-- Каждый кадр после обновления камеры дрон и тёмный задник под ним ставятся на луч камеры через центр
-- окошка, на такую глубину, чтобы дрон занимал окошко. Винты и орбитальные шары крутятся, как в мире.
-- Дрон крошечный и стоит в паре десятых стада от камеры, а задник сразу за ним: так между камерой и задником
-- не помещается ни стена, ни колонна, и декорации мира не просвечивают в окошко.
local STAGE_SIZE = 0.1 -- диаметр дрона на сцене, стадов
local STAGE_PITCH = math.rad(12)

-- fill: какую долю высоты окошка занимает дрон по диагонали габаритов
local function newStage(name, bg, brightness, fill)
	return { name = name, bg = bg, brightness = brightness or 0.35, fill = fill or 1 / 1.15 }
end

local function stageBack(st)
	if st.back then
		return
	end
	st.back = new("Part", {
		Name = st.name,
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
		CanvasSize = Vector2.new(720, 380),
		Parent = st.back,
	})
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = st.bg, BorderSizePixel = 0, Parent = sg })
	-- мягкое приглушённое свечение цвета редкости: стопка почти прозрачных кругов
	st.glow = {}
	for k = 1, 10 do
		local d = 120 + k * 26
		table.insert(st.glow, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(d, d),
			BackgroundTransparency = 0.965,
			BorderSizePixel = 0,
			ZIndex = 12 - k,
			Parent = sg,
		}, { U.round() }))
	end
	st.lightAtt = new("Attachment", { Parent = st.back })
	st.light = new("PointLight", { Brightness = st.brightness, Range = 4, Shadows = false, Parent = st.lightAtt })
end

-- mode: "full" — дрон в своих цветах; "hidden" — чёрный силуэт нераскрытого секретного дрона;
-- "silhouette" — тёмный силуэт ещё не выбитого дрона с контуром цвета редкости
local function stageSetModel(st, def, mode, r)
	if st.model then
		st.model:Destroy()
		st.model = nil
	end
	stageBack(st)
	for _, g in ipairs(st.glow) do
		g.BackgroundColor3 = r.color:Lerp(C(0, 0, 0), 0.3)
	end
	local dark = mode ~= "full"
	local m = Builder.Build(def, 1)
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	m:ScaleTo(STAGE_SIZE / math.max(size.Magnitude, 0.01))
	local box = m:GetBoundingBox()
	local center = CFrame.new(box.Position)
	local core = m.PrimaryPart and m.PrimaryPart.CFrame or m:GetPivot()
	local parts, entries, tints = {}, {}, {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
			p.CanQuery = false
			p.CanTouch = false
			p.CanCollide = false
			if dark then
				p.Color = C(0, 0, 0)
				p.Material = Enum.Material.SmoothPlastic
			end
			if p:GetAttribute("Tint") and not dark then
				table.insert(tints, p)
			end
			table.insert(parts, p)
			table.insert(entries, { offset = core:ToObjectSpace(p.CFrame), spin = p:GetAttribute("Spin"), axis = p:GetAttribute("SpinAxis"), orbit = p:GetAttribute("Orbit") })
		elseif dark and (p:IsA("Light") or p:IsA("ParticleEmitter") or p:IsA("Beam") or p:IsA("Trail")) then
			p.Enabled = false
		end
	end
	st.outline = nil
	if dark then
		-- силуэт чёрный, даже если у деталей есть текстуры; у не выбитого дрона светится контур цвета редкости
		local outlined = mode == "silhouette"
		local hl = new("Highlight", {
			Adornee = m,
			FillColor = C(0, 0, 0),
			FillTransparency = 0,
			OutlineColor = r.rainbow and C(255, 255, 255) or r.color,
			OutlineTransparency = outlined and 0.15 or 1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Parent = m,
		})
		if outlined and r.rainbow then
			st.outline = hl
		end
	end
	st.model = m
	st.parts = parts
	st.entries = entries
	st.cfs = table.create(#parts)
	-- радужные и секретные дроны переливаются, как в мире
	st.tints = tints
	st.rainbow = m:GetAttribute("Rainbow") == true
	st.secret = m:GetAttribute("Secret") == true
	st.coreRel = center:ToObjectSpace(core)
	if st.shown and st.back.Parent then
		m.Parent = st.back.Parent
	end
end

local function stageStep(st, hole, visible)
	local cam = workspace.CurrentCamera
	local as = hole and hole.AbsoluteSize
	local frac, tanH, z
	local show = st.model ~= nil and visible and cam ~= nil and as ~= nil and as.Y > 4 and as.X > 4
	if show then
		frac = as.Y / math.max(cam.ViewportSize.Y, 1)
		tanH = math.tan(math.rad(cam.FieldOfView) / 2)
		-- глубина, на которой дрон (по диагонали габаритов) занимает почти всю высоту окошка. Пока окно только раскрывается и окошко
		-- маленькое, дрон пришлось бы ставить далеко и он торчал бы за края окна — тогда он скрыт.
		z = STAGE_SIZE / (frac * 2 * tanH * st.fill)
		show = z <= STAGE_SIZE * 10
		-- передний край дрона не должен заходить за плоскость отсечения камеры (0.1 стада)
		z = math.max(z, 0.1 + STAGE_SIZE * 0.7)
	end
	if show ~= st.shown then
		st.shown = show
		if st.model then
			st.model.Parent = show and cam or nil
		end
		if st.back then
			st.back.Parent = show and cam or nil
		end
	end
	if not show then
		return
	end
	local t = os.clock()
	local ap = hole.AbsolutePosition
	local inset = GuiService:GetGuiInset()
	local ray = cam:ViewportPointToRay(ap.X + as.X / 2 + inset.X, ap.Y + as.Y / 2 + inset.Y)
	local camCF = cam.CFrame
	local look = camCF.LookVector
	-- от самой камеры: начало луча лежит на плоскости отсечения, а не в камере
	local function at(depth)
		return camCF.Position + ray.Direction * (depth / ray.Direction:Dot(look))
	end
	local rot = camCF.Rotation * CFrame.Angles(0, math.pi, 0)
	-- дрон смотрит вдоль луча на камеру: в окошке сбоку экрана он виден прямо, без перспективного перекоса
	local pos = at(z)
	local face = CFrame.lookAt(pos, pos - ray.Direction, camCF.UpVector).Rotation
	-- дрон повёрнут к камере «лицом» и чуть сверху, медленно вращается и мягко парит
	local bob = math.sin(t * 1.4) * STAGE_SIZE * 0.035
	local body = CFrame.new(pos + camCF.UpVector * bob) * face * CFrame.Angles(-STAGE_PITCH, 0, 0) * CFrame.Angles(0, t * 0.7, 0)
	local core = body * st.coreRel
	for i, e in ipairs(st.entries) do
		local cf
		if e.orbit then
			cf = core * CFrame.Angles(0, t * e.orbit, 0) * e.offset
		else
			cf = core * e.offset
			if e.spin then
				local a = t * e.spin
				cf = cf * (e.axis == "X" and CFrame.Angles(a, 0, 0) or CFrame.Angles(0, a, 0))
			end
		end
		st.cfs[i] = cf
	end
	workspace:BulkMoveTo(st.parts, st.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if st.rainbow then
		for k, p in ipairs(st.tints) do
			p.Color = Config.Rainbow(t, k * 0.06)
		end
	elseif st.secret then
		local pulse = 0.55 + 0.45 * math.abs(math.sin(t * 3))
		for _, p in ipairs(st.tints) do
			p.Color = Color3.new(pulse, 0.05 * pulse, 0.06 * pulse)
		end
	end
	if st.outline then
		st.outline.OutlineColor = Config.Rainbow(t)
	end
	-- свечение за дроном мягко «дышит»
	local breathe = 0.965 - 0.012 * (0.5 + 0.5 * math.sin(t * 1.6))
	for _, g in ipairs(st.glow) do
		g.BackgroundTransparency = breathe
	end
	-- задник: сразу за дроном, с небольшим запасом закрывает окошко, но не вылезает за край окна
	local zb = z + STAGE_SIZE * 0.75
	local h = frac * 2 * tanH * zb * 1.08
	st.back.Size = Vector3.new(h * as.X / as.Y, h, 0.02)
	st.back.CFrame = CFrame.new(at(zb)) * rot
	st.lightAtt.Position = Vector3.new(0, h * 0.25, -(zb - z) - STAGE_SIZE * 0.8)
	st.light.Range = STAGE_SIZE * 4
end


-- ===== ИНВЕНТАРЬ (клавиша Y) =====
local function rarityStroke(parent, rarity, thickness)
	local r = Config.Rarities[rarity]
	local st = U.stroke(r.color, thickness or 2.5)
	st.Parent = parent
	if r.rainbow then
		st.Color = C(255, 255, 255)
		rainbowify(st)
	elseif rarity == "Secret" then
		table.insert(secretStrokes, st)
	end
	return st
end

local function setModelVp(vp, def, yaw, pitch)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local m = Builder.Build(def, 1)
	Builder.SetupViewport(vp, m, yaw or math.rad(25), pitch or math.rad(16), 1.0)
	return m
end

local function ownedOf(id)
	local d = State.data
	if not d then
		return 0, 0
	end
	return d.owned[id] or 0, d.equippedCount[id] or 0
end

local function smallButton(parent, props, onClick)
	local b = button(props, onClick)
	U.corner(8).Parent = b
	b.Parent = parent
	return b
end

inv.filter = "All"
inv.onlyOwned = false

-- карточки появляются волной с пружинкой (смена фильтра, вкладки)
local function popCards(list)
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, card in ipairs(list) do
		local sc = card:FindFirstChild("CardPop") or new("UIScale", { Name = "CardPop", Parent = card })
		sc.Scale = 0.6
		task.delay(math.min(i, 16) * 0.018, function()
			U.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

local function applyFilter(animate)
	local shown = {}
	for id, c in pairs(inv.cards) do
		local owned = ownedOf(id)
		local okR = inv.filter == "All" or c.def.rarity == inv.filter
		local okO = not inv.onlyOwned or owned > 0
		c.card.Visible = okR and okO
		if c.card.Visible then
			table.insert(shown, c.card)
		end
	end
	if animate then
		popCards(shown)
	end
	for key, b in pairs(inv.filterButtons) do
		local on = (key == inv.filter)
		U.tween(b, 0.15, { BackgroundTransparency = on and 0 or 0.65 })
		U.tween(b:FindFirstChildOfClass("UIStroke"), 0.15, { Thickness = on and 2.5 or 1 })
	end
	inv.ownedToggle.Text = (inv.onlyOwned and "☑" or "☐") .. " Owned only"
	U.tween(inv.ownedToggle, 0.15, { TextColor3 = inv.onlyOwned and T.Accent or T.Muted })
end

-- окошко превью в координатах окна: панель деталей (x = 960 - 14 - 272, y = 70) плюс отступ 10
local INV_DETAIL = { x = 674, y = 70, w = 272, h = 516 }
local INV_HOLE = { x = INV_DETAIL.x + 10, y = INV_DETAIL.y + 10, w = INV_DETAIL.w - 20, h = 170 }
local INV_STAGE_BG = C(14, 20, 16)

local function buildInventory()
	local win = new("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(960, 600),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { U.corner(18), U.stroke(T.Accent, 3) })
	-- в фоне окна «окошко» под превью дрона в панели деталей: сквозь него виден 3D-дрон (см. stageStep)
	holedBackground(win, 960, 600, INV_HOLE, 18, T.Bg, C(255, 255, 255), C(170, 180, 170))
	inv.scale = addScale(win)
	inv.win = win

	-- шапка
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = T.Panel, Parent = win }, { U.corner(18) })
	new("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = header })
	new("TextLabel", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(0, 330, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🤖 DRONE INVENTORY",
		TextSize = 24,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	}, { U.textStroke(C(0, 0, 0), 2) })
	hud.dronesHot = new("TextLabel", {
		Position = UDim2.fromOffset(300, 18),
		Size = UDim2.fromOffset(34, 24),
		BackgroundColor3 = C(50, 60, 50),
		Font = Enum.Font.GothamBlack,
		Text = "Y",
		TextSize = 16,
		TextColor3 = T.Accent,
		Parent = header,
	}, { U.corner(6), U.stroke(T.Accent, 1.5) })
	local auto = smallButton(header, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -258, 0.5, 0),
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = T.AccentDark,
		Font = Enum.Font.GothamBlack,
		Text = "⚡ EQUIP BEST",
		TextSize = 15,
		TextColor3 = C(255, 255, 255),
	}, function()
		Remotes.AutoEquip:FireServer()
	end)
	U.stroke(T.Accent, 2).Parent = auto
	local clear = smallButton(header, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, 0),
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = C(110, 40, 35),
		Font = Enum.Font.GothamBlack,
		Text = "REMOVE ALL",
		TextSize = 15,
		TextColor3 = C(255, 255, 255),
	}, function()
		Remotes.UnequipAll:FireServer()
	end)
	U.stroke(T.Danger, 2).Parent = clear
	local close = smallButton(header, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = T.Danger,
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 22,
		TextColor3 = C(255, 255, 255),
	}, function()
		closeWindow(win)
	end)

	-- ===== СЛОТЫ РОЯ =====
	inv.slotsTitle = new("TextLabel", {
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.fromOffset(640, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "SWARM 0 / 25  •  click a drone in a slot to remove it",
		TextSize = 14,
		TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = win,
	})
	local slotsFrame = new("Frame", {
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.fromOffset(640, 100),
		BackgroundColor3 = C(10, 12, 10),
		Parent = win,
	}, {
		U.corner(12),
		U.stroke(C(60, 70, 60), 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }),
		new("UIGridLayout", { CellSize = UDim2.fromOffset(44, 44), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	inv.slots = {}
	for i = 1, Config.MaxSlots do
		local slot = new("TextButton", {
			BackgroundColor3 = C(28, 32, 28),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			Parent = slotsFrame,
		}, { U.corner(8) })
		local st = U.stroke(C(60, 66, 60), 1.5)
		st.Parent = slot
		local plus = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "+",
			TextSize = 20,
			TextColor3 = C(70, 80, 70),
			Parent = slot,
		})
		local vp = new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = C(150, 150, 150),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			Visible = false,
			Parent = slot,
		})
		local x = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C(150, 20, 20),
			BackgroundTransparency = 0.35,
			Font = Enum.Font.GothamBlack,
			Text = "✖",
			TextSize = 20,
			TextColor3 = C(255, 255, 255),
			Visible = false,
			ZIndex = 3,
			Parent = slot,
		}, { U.corner(8) })
		local ebg = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, -8, 0, 5),
			BackgroundColor3 = C(0, 0, 0),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 4,
			Parent = slot,
		}, { U.corner(3) })
		local efill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(90, 230, 255), BorderSizePixel = 0, ZIndex = 5, Parent = ebg }, { U.corner(3) })
		local bolt = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -1, 0, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "⚡",
			TextSize = 13,
			TextColor3 = C(255, 220, 60),
			Visible = false,
			ZIndex = 5,
			Parent = slot,
		}, { U.textStroke(C(0, 0, 0), 1) })
		local entry = { slot = slot, vp = vp, plus = plus, x = x, stroke = st, uid = nil, id = nil, ebg = ebg, efill = efill, bolt = bolt }
		slot.MouseEnter:Connect(function()
			x.Visible = entry.uid ~= nil
		end)
		slot.MouseLeave:Connect(function()
			x.Visible = false
		end)
		slot.Activated:Connect(function()
			if entry.uid then
				U.play(U.Sounds.tick, 0.4, 0.9)
				Remotes.Unequip:FireServer(entry.uid)
				x.Visible = false
			end
		end)
		inv.slots[i] = entry
	end

	-- ===== ФИЛЬТРЫ =====
	local filters = new("Frame", {
		Position = UDim2.fromOffset(14, 196),
		Size = UDim2.fromOffset(640, 30),
		BackgroundTransparency = 1,
		Parent = win,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	inv.filterButtons = {}
	local fdefs = { { "All", "ALL", T.Accent } }
	for i = #Config.RarityOrder, 1, -1 do
		local key = Config.RarityOrder[i]
		table.insert(fdefs, { key, Config.Rarities[key].label, Config.Rarities[key].color })
	end
	for i, f in ipairs(fdefs) do
		local fb = smallButton(filters, {
			Size = UDim2.fromOffset(f[1] == "All" and 50 or (f[1] == "Legendary" and 92 or 76), 28),
			BackgroundColor3 = U.darken(f[3], 0.45),
			Font = Enum.Font.FredokaOne,
			Text = f[2],
			TextSize = 13,
			TextColor3 = f[1] == "Mythic" and C(255, 255, 255) or f[3]:Lerp(C(255, 255, 255), 0.3),
			LayoutOrder = i,
		}, function()
			inv.filter = f[1]
			applyFilter(true)
		end)
		U.stroke(f[3], 1).Parent = fb
		if f[1] == "Mythic" then
			rainbowify(fb)
		end
		inv.filterButtons[f[1]] = fb
	end
	inv.ownedToggle = button({
		Size = UDim2.fromOffset(110, 28),
		BackgroundTransparency = 1,
		BackgroundColor3 = C(0, 0, 0),
		Font = Enum.Font.GothamBold,
		Text = "☐ Owned only",
		TextSize = 13,
		TextColor3 = T.Muted,
		LayoutOrder = 99,
		Parent = filters,
	}, function()
		inv.onlyOwned = not inv.onlyOwned
		applyFilter(true)
	end)

	-- ===== СЕТКА ДРОНОВ =====
	local grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 232),
		Size = UDim2.new(0, 640, 1, -246),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		Parent = win,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 158), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	inv.cards = {}
	for i, def in ipairs(SORTED) do
		local r = Config.Rarities[def.rarity]
		local card = button({
			BackgroundColor3 = U.darken(r.color, 0.22),
			Text = "",
			LayoutOrder = i,
			Parent = grid,
		}, function()
			UI.SelectDrone(def.id)
		end)
		U.corner(12).Parent = card
		local stroke = rarityStroke(card, def.rarity, 2.5)
		if r.rainbow then
			rainbowBg(card, 35, 0.72)
		else
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(90, 90, 90)), Parent = card })
		end
		local vp = new("ViewportFrame", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 80),
			BackgroundTransparency = 1,
			Ambient = C(150, 150, 150),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			Parent = card,
		})
		setModelVp(vp, def)
		local name = new("TextLabel", {
			Position = UDim2.new(0, 4, 0, 84),
			Size = UDim2.new(1, -8, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = def.name,
			TextScaled = true,
			TextColor3 = C(255, 255, 255),
			Parent = card,
		}, { U.textStroke(C(0, 0, 0), 1.5), new("UITextSizeConstraint", { MaxTextSize = 15 }) })
		local rl = new("TextLabel", {
			Position = UDim2.new(0, 4, 0, 102),
			Size = UDim2.new(1, -8, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = r.label,
			TextSize = 13,
			TextColor3 = r.rainbow and C(255, 255, 255) or r.color,
			Parent = card,
		}, { U.textStroke(C(0, 0, 0), 1.5) })
		local count = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = C(0, 0, 0),
			BackgroundTransparency = 0.35,
			Font = Enum.Font.GothamBlack,
			Text = "x0",
			TextSize = 14,
			TextColor3 = C(255, 255, 255),
			Parent = card,
		}, { U.corner(6) })
		local eq = new("TextLabel", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = T.AccentDark,
			Font = Enum.Font.GothamBlack,
			Text = "⚡0",
			TextSize = 13,
			TextColor3 = C(255, 255, 255),
			Visible = false,
			Parent = card,
		}, { U.corner(6) })
		-- быстрые кнопки на карточке
		local plus = smallButton(card, {
			Position = UDim2.new(0, 5, 1, -33),
			Size = UDim2.new(0.5, -7, 0, 28),
			BackgroundColor3 = T.AccentDark,
			Font = Enum.Font.GothamBlack,
			Text = "+ SWARM",
			TextSize = 13,
			TextColor3 = C(255, 255, 255),
		}, function()
			Remotes.Equip:FireServer(def.id, 1)
		end)
		local minus = smallButton(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 1, -33),
			Size = UDim2.new(0.5, -7, 0, 28),
			BackgroundColor3 = C(110, 40, 35),
			Font = Enum.Font.GothamBlack,
			Text = "− REMOVE",
			TextSize = 13,
			TextColor3 = C(255, 255, 255),
		}, function()
			Remotes.Equip:FireServer(def.id, -1)
		end)
		inv.cards[def.id] = { card = card, vp = vp, name = name, count = count, eq = eq, stroke = stroke, def = def, plus = plus, minus = minus }
	end

	-- ===== ПАНЕЛЬ ДЕТАЛЕЙ =====
	local detail = new("Frame", {
		Position = UDim2.fromOffset(INV_DETAIL.x, INV_DETAIL.y),
		Size = UDim2.fromOffset(INV_DETAIL.w, INV_DETAIL.h),
		BackgroundTransparency = 1,
		Parent = win,
	}, { U.corner(14) })
	holedBackground(detail, INV_DETAIL.w, INV_DETAIL.h, { x = 10, y = 10, w = INV_HOLE.w, h = INV_HOLE.h }, 14, T.Panel)
	inv.detailStroke = U.stroke(T.AccentDark, 2)
	inv.detailStroke.Parent = detail
	-- превью: настоящий крошечный 3D-дрон перед камерой, видный сквозь окошко (ViewportFrame рисовался рывками)
	inv.dhole = new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(INV_HOLE.w, INV_HOLE.h),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 2,
		Parent = detail,
	})
	inv.dholeStroke = U.stroke(T.AccentDark, 2, 0.35)
	inv.dholeStroke.Parent = inv.dhole
	-- шторка для плавной смены дрона в превью
	inv.dcover = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INV_STAGE_BG,
		BorderSizePixel = 0,
		Parent = inv.dhole,
	})
	inv.dname = new("TextLabel", {
		Position = UDim2.fromOffset(12, 186),
		Size = UDim2.new(1, -24, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = C(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	}, { U.textStroke(C(0, 0, 0), 2) })
	inv.drarity = new("TextLabel", {
		Position = UDim2.fromOffset(12, 216),
		Size = UDim2.fromOffset(160, 22),
		BackgroundColor3 = C(0, 0, 0),
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		Parent = detail,
	}, { U.corner(6) })
	inv.ddesc = new("TextLabel", {
		Position = UDim2.fromOffset(12, 244),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})
	inv.dstats = new("TextLabel", {
		Position = UDim2.fromOffset(12, 282),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	local abBox = new("Frame", {
		Position = UDim2.fromOffset(10, 306),
		Size = UDim2.new(1, -20, 0, 84),
		BackgroundColor3 = C(18, 22, 18),
		Parent = detail,
	}, { U.corner(10), U.stroke(T.Hazard, 1.5, 0.3), U.pad(8) })
	inv.dability = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		RichText = true,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = abBox,
	})
	inv.dcount = new("TextLabel", {
		Position = UDim2.new(0, 12, 1, -82),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	inv.plus = smallButton(detail, {
		Position = UDim2.new(0, 10, 1, -54),
		Size = UDim2.new(0.5, -15, 0, 44),
		BackgroundColor3 = T.AccentDark,
		Font = Enum.Font.GothamBlack,
		Text = "+ TO SWARM",
		TextSize = 17,
		TextColor3 = C(255, 255, 255),
	}, function()
		if inv.selected then
			Remotes.Equip:FireServer(inv.selected, 1)
		end
	end)
	inv.minus = smallButton(detail, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 1, -54),
		Size = UDim2.new(0.5, -15, 0, 44),
		BackgroundColor3 = C(110, 40, 35),
		Font = Enum.Font.GothamBlack,
		Text = "− REMOVE",
		TextSize = 17,
		TextColor3 = C(255, 255, 255),
	}, function()
		if inv.selected then
			Remotes.Equip:FireServer(inv.selected, -1)
		end
	end)
	applyFilter()
end

function UI.SelectDrone(id)
	inv.selected = id
	local def = Config.DroneById[id]
	local r = Config.Rarities[def.rarity]
	local owned, eq = ownedOf(id)
	local hidden = owned == 0 and def.rarity == "Secret"
	-- выбитый дрон крутится в своих цветах, ещё не выбитый — тёмным силуэтом с контуром цвета редкости
	local mode = hidden and "hidden" or (owned > 0 and "full" or "silhouette")
	local key = id .. "/" .. mode
	if inv.dmodelKey ~= key then
		inv.dmodelKey = key
		-- шторка плавно закрывает старого дрона, под ней ставится новый и шторка уходит
		local token = {}
		inv.dtoken = token
		task.spawn(function()
			if inv.stage.model and inv.win.Visible then
				U.tween(inv.dcover, 0.15, { BackgroundTransparency = 0 })
				task.wait(0.15)
				if inv.dtoken ~= token then
					return
				end
			end
			stageSetModel(inv.stage, def, mode, r)
			inv.dcover.BackgroundTransparency = 0
			U.tween(inv.dcover, 0.35, { BackgroundTransparency = 1 })
		end)
	end
	U.tween(inv.dholeStroke, 0.2, { Color = r.color })
	inv.dname.Text = hidden and "???" or def.name
	inv.drarity.Text = r.label .. " • " .. Config.ChanceText(def.rarity)
	inv.drarity.TextColor3 = r.rainbow and Config.Rainbow(os.clock()) or r.color
	inv.drarityRainbow = r.rainbow
	U.tween(inv.detailStroke, 0.2, { Color = r.color })
	if hidden then
		inv.ddesc.Text = "Secret drone. Pull it to find out more..."
		inv.dstats.Text = "⚙ ?   ⚔ ?   » ?"
		inv.dability.Text = "<b>★ ???</b>"
	else
		inv.ddesc.Text = def.desc
		local base = Config.RarityStats[def.rarity]
		local m = def.mods or {}
		inv.dstats.Text = ("⚙ Gather: %d    ⚔ Damage: %d    » Speed: %d"):format(
			math.floor(base.gather * (m.gather or 1) + 0.5),
			math.floor(base.damage * (m.damage or 1) + 0.5),
			base.speed
		)
		local ab = def.ability
		local cd = ab.passive and "passive" or ("cooldown %ds"):format(ab.cd)
		inv.dability.Text = ('<font color="#FFB020"><b>★ %s</b></font> <font color="#8A9488">(%s)</font>\n%s'):format(ab.name, cd, ab.desc)
	end
	inv.dcount.Text = ("In collection: %d   •   In swarm: %d"):format(owned, eq)
	local d = State.data
	local canPlus = d and owned > eq and d.equippedTotal < d.maxSlots
	U.tween(inv.plus, 0.15, { BackgroundTransparency = canPlus and 0 or 0.6 })
	U.tween(inv.minus, 0.15, { BackgroundTransparency = eq > 0 and 0 or 0.6 })
	for cid, c in pairs(inv.cards) do
		U.tween(c.stroke, 0.15, { Thickness = cid == id and 5 or 2.5 })
	end
end

local function updateSlots(d)
	local list = d.equippedList or {}
	for i, s in ipairs(inv.slots) do
		local e = list[i]
		local newUid = e and e.uid or nil
		if s.uid ~= newUid or s.id ~= (e and e.id) then
			s.uid = newUid
			s.id = e and e.id or nil
			for _, c in ipairs(s.vp:GetChildren()) do
				if c:IsA("Model") then
					c:Destroy()
				end
			end
			if e then
				local def = Config.DroneById[e.id]
				local r = Config.Rarities[def.rarity]
				setModelVp(s.vp, def, math.rad(25), math.rad(16))
				s.vp.Visible = true
				s.plus.Visible = false
				-- дрон «влетает» в слот: проявление модели и смена цвета ячейки
				s.vp.ImageTransparency = 1
				U.tween(s.vp, 0.3, { ImageTransparency = 0 })
				U.tween(s.slot, 0.25, { BackgroundColor3 = U.darken(r.color, 0.3) })
				U.tween(s.stroke, 0.25, { Color = r.rainbow and Config.Rainbow(os.clock()) or r.color, Thickness = 2 })
			else
				s.vp.Visible = false
				s.plus.Visible = true
				U.tween(s.slot, 0.25, { BackgroundColor3 = C(28, 32, 28) })
				U.tween(s.stroke, 0.25, { Color = C(60, 66, 60), Thickness = 1.5 })
			end
		end
		-- слоты сверх купленных гнёзд — закрыты
		if not e then
			local locked = i > (d.maxSlots or 3)
			s.plus.Text = locked and "🔒" or "+"
			s.plus.TextSize = locked and 16 or 20
			U.tween(s.slot, 0.2, { BackgroundTransparency = locked and 0.45 or 0 })
		end
	end
	inv.slotsTitle.Text = ("SWARM %d / %d  •  click a drone in a slot to remove it"):format(d.equippedTotal, d.maxSlots)
	if UI.UpdateSlotEnergy then
		UI.UpdateSlotEnergy()
	end
end

-- заряд каждого дрона в слотах роя
function UI.UpdateSlotEnergy()
	if not inv.slots then
		return
	end
	for _, s in ipairs(inv.slots) do
		local e = s.uid and UI.Energy[s.uid]
		s.ebg.Visible = e ~= nil
		s.bolt.Visible = e ~= nil and e.s == 1
		if e then
			local r = math.clamp(e.e / 100, 0, 1)
			U.tween(s.efill, 0.3, { Size = UDim2.fromScale(math.max(r, 0.04), 1), BackgroundColor3 = r > 0.5 and C(90, 230, 255) or (r > 0.2 and C(255, 200, 60) or C(255, 70, 60)) })
			U.tween(s.vp, 0.3, { ImageTransparency = r <= 0 and 0.5 or 0 })
		end
	end
end

local function updateInventory(d)
	updateSlots(d)
	for id, c in pairs(inv.cards) do
		local owned = d.owned[id] or 0
		local eq = d.equippedCount[id] or 0
		c.count.Text = "x" .. owned
		c.count.Visible = owned > 0
		c.eq.Text = "⚡" .. eq
		c.eq.Visible = eq > 0
		c.vp.ImageColor3 = owned > 0 and C(255, 255, 255) or C(0, 0, 0)
		c.vp.ImageTransparency = owned > 0 and 0 or 0.25
		c.name.Text = (owned > 0 or c.def.rarity ~= "Secret") and c.def.name or "???"
		c.name.TextTransparency = owned > 0 and 0 or 0.4
		c.plus.Visible = owned > eq and d.equippedTotal < d.maxSlots
		c.minus.Visible = eq > 0
	end
	applyFilter()
	if inv.selected then
		UI.SelectDrone(inv.selected)
	end
end

function UI.ToggleInventory()
	if U.isOpen(inv.win, inv.scale) then
		closeWindow(inv.win, inv.scale)
	else
		closeWindow(gacha.win, gacha.scale)
		ShopUI.Close()
		DonateUI.Close()
		QuestUI.CloseBook()
		openWindow(inv.win, inv.scale)
		if not inv.selected then
			local pick = SORTED[#SORTED].id
			for _, d in ipairs(SORTED) do
				if State.data and (State.data.owned[d.id] or 0) > 0 then
					pick = d.id
					break
				end
			end
			UI.SelectDrone(pick)
		end
	end
end

inv.stage = newStage("ZSS_InvStage", INV_STAGE_BG, 0.5, 1.1)
RunService:BindToRenderStep("ZSS_InvStage", Enum.RenderPriority.Camera.Value + 1, function()
	stageStep(inv.stage, inv.dhole, inv.win and inv.win.Visible)
end)

-- ===== ГАЧА =====
gacha.stage = newStage("ZSS_GachaStage", C(24, 16, 36))
hgacha.stage = newStage("ZSS_HGachaStage", C(34, 16, 12), 0.45)
-- после обновления камеры, чтобы дрон не отставал от неё ни на кадр
RunService:BindToRenderStep("ZSS_GachaStage", Enum.RenderPriority.Camera.Value + 1, function()
	stageStep(gacha.stage, gacha.showHole, gacha.win and gacha.win.Visible)
	stageStep(hgacha.stage, hgacha.showHole, hgacha.win and hgacha.win.Visible)
end)

-- баннеры гачи: обычная «Лаборатория дронов» и хэллоуинский «Тыквенный котёл»
local function poolOf(event)
	local list = {}
	for _, d in ipairs(SORTED) do
		if d.event == event then
			table.insert(list, d)
		end
	end
	return list
end
BANNERS = {
	main = {
		id = "main",
		state = gacha,
		name = "Gacha",
		title = "DRONE GACHA",
		place = "DRONE LAB",
		pool = poolOf(nil),
		bg = C(14, 10, 22),
		bgGrad = C(140, 130, 160),
		panel = C(24, 16, 36),
		dark = C(12, 8, 18),
		accent = T.Gacha,
		titleC1 = C(180, 255, 90),
		titleC2 = C(190, 90, 255),
		titleStroke = C(20, 0, 30),
		chance = Config.ChanceText,
		pity = Config.Pity,
		hint = "💎 Gems: NPC quests at the base • defeating the Colossus • rare finds",
		hintBg = C(20, 40, 60),
		hintStroke = C(120, 220, 255),
		cur = "💎",
		cost1 = Config.PullCost,
		cost10 = Config.Pull10Cost,
		b1 = { C(140, 230, 70), C(50, 130, 30) },
		b10 = { C(200, 110, 255), C(100, 30, 170) },
		balance = function(d)
			return d.gems or 0, "🔋 " .. U.fmt(d.batteries)
		end,
		pulls = function(d)
			return d.totalPulls or 0
		end,
		pityOf = function(d)
			return d.pity or {}
		end,
		invoke = function(count)
			return Remotes.Pull:InvokeServer(count)
		end,
		inZone = function()
			return UI.InGachaZone()
		end,
	},
}
if Config.HalloweenOn() then
	local HG = Config.Halloween.gacha
	BANNERS.halloween = {
		id = "halloween",
		state = hgacha,
		name = "HGacha",
		title = "PUMPKIN CAULDRON",
		place = "HALLOWEEN GACHA",
		pool = poolOf("halloween"),
		bg = C(20, 10, 8),
		bgGrad = C(170, 110, 70),
		panel = C(38, 18, 12),
		dark = C(16, 8, 6),
		accent = C(255, 140, 30),
		border = C(255, 140, 30),
		titleC1 = C(255, 200, 60),
		titleC2 = C(190, 70, 255),
		titleStroke = C(30, 6, 0),
		chance = Config.HalloweenChanceText,
		pity = HG.pity,
		hint = "🎃 Pumpkins: glowing pumpkins on the fields • ghost zombies at night • Pumpkin Colossus • Witch's quests",
		hintBg = C(60, 30, 10),
		hintStroke = C(255, 160, 60),
		cur = "🎃",
		cost1 = HG.pullCost,
		cost10 = HG.pull10Cost,
		b1 = { C(255, 170, 50), C(190, 70, 10) },
		b10 = { C(190, 90, 255), C(80, 20, 140) },
		theme = "halloween",
		zone = "HalloweenZone",
		balance = function(d)
			return d.pumpkins or 0, "💎 " .. U.fmt(d.gems or 0)
		end,
		pulls = function(d)
			return d.hpulls or 0
		end,
		pityOf = function(d)
			return d.hpity or {}
		end,
		invoke = function(count)
			return Remotes.Halloween:InvokeServer("pull", count)
		end,
		inZone = function()
			return UI.InHalloweenZone()
		end,
	}
end

-- окно гачи для баннера B (обычная «Лаборатория дронов» или хэллоуинский «Тыквенный котёл»); g — его состояние
local function buildGacha(g, B)
	-- витрина — «окно» в фоне: сквозь него виден настоящий 3D-дрон (см. stageStep)
	local HOLE = { x = 36, y = 100, w = 360, h = 190 }
	local win = new("Frame", {
		Name = B.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(900, 560),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { U.corner(20) })
	holedBackground(win, 900, 560, HOLE, 20, B.bg, C(255, 255, 255), B.bgGrad)
	g.win = win
	g.scale = addScale(win)
	local st = U.stroke(B.border or C(255, 255, 255), 3.5)
	st.Parent = win
	if not B.border then
		rainbowify(st)
	end

	-- левая панель: баннер
	local left = new("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(0, 400, 1, -32),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	}, { U.corner(16), U.stroke(B.accent, 2, 0.3) })
	holedBackground(left, 400, 528, { x = HOLE.x - 16, y = HOLE.y - 16, w = HOLE.w, h = HOLE.h }, 16, B.panel)
	local title = new("TextLabel", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		Text = B.title,
		TextSize = 52,
		TextColor3 = C(255, 255, 255),
		Parent = left,
	}, { U.textStroke(B.titleStroke, 3) })
	U.grad(B.titleC1, B.titleC2, 90).Parent = title
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = ("%s • %d DRONES IN THE POOL"):format(B.place, #B.pool),
		TextSize = 13,
		TextColor3 = T.Muted,
		Parent = left,
	})
	g.showHole = new("Frame", {
		Position = UDim2.fromOffset(HOLE.x - 16, HOLE.y - 16),
		Size = UDim2.fromOffset(HOLE.w, HOLE.h),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = left,
	})
	g.showStroke = U.stroke(B.accent, 2, 0.4)
	g.showStroke.Parent = g.showHole
	-- шторка для плавной смены дронов на витрине
	g.showCover = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = B.panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = g.showHole,
	})
	g.showName = new("TextLabel", {
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = C(255, 255, 255),
		Parent = left,
	}, { U.textStroke(C(0, 0, 0), 2) })
	-- шансы
	local rates = new("Frame", {
		Position = UDim2.fromOffset(16, 300),
		Size = UDim2.new(1, -32, 0, 196),
		BackgroundColor3 = B.dark,
		Parent = left,
	}, { U.corner(12), U.pad(10), new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "DROP CHANCES",
		TextSize = 13,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = rates,
	})
	for i = #Config.RarityOrder, 1, -1 do
		local key = Config.RarityOrder[i]
		local r = Config.Rarities[key]
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = r.color,
			BackgroundTransparency = 0.85,
			LayoutOrder = 10 - i,
			Parent = rates,
		}, { U.corner(6) })
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = r.rainbow and C(255, 255, 255) or r.color,
			Parent = row,
		}, { U.round() })
		local lbl = new("TextLabel", {
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = r.label,
			TextSize = 15,
			TextColor3 = r.rainbow and C(255, 255, 255) or r.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, { U.textStroke(C(0, 0, 0), 1) })
		new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0.35, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = B.chance(key),
			TextSize = 15,
			TextColor3 = C(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		if r.rainbow then
			rainbowify(lbl)
			rainbowify(dot)
		end
	end

	-- правая панель
	local right = new("Frame", {
		Position = UDim2.fromOffset(432, 16),
		Size = UDim2.new(1, -448, 1, -32),
		BackgroundTransparency = 1,
		Parent = win,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = T.Danger,
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 22,
		TextColor3 = C(255, 255, 255),
		Parent = right,
	}, function()
		closeWindow(win)
	end)
	U.corner(12).Parent = close
	g.balance = new("TextLabel", {
		Size = UDim2.new(1, -56, 0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🔋 0",
		TextSize = 30,
		TextColor3 = T.Battery,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = right,
	}, { U.textStroke(C(0, 0, 0), 2) })

	-- гарант
	local pity = new("Frame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundColor3 = B.panel,
		Parent = right,
	}, { U.corner(14), U.stroke(B.accent, 2, 0.4), U.pad(12) })
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🛡 PITY",
		TextSize = 15,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pity,
	})
	g.total = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Total pulls: 0",
		TextSize = 13,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = pity,
	})
	g.pityBars = {}
	local rules = { "Legendary", "Mythic", "Secret" }
	for i, key in ipairs(rules) do
		local r = Config.Rarities[key]
		local pulls
		for _, rule in ipairs(B.pity) do
			if rule.rarity == key then
				pulls = rule.pulls
			end
		end
		local y = 26 + (i - 1) * 42
		local lbl = new("TextLabel", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = r.label,
			TextSize = 14,
			TextColor3 = r.rainbow and C(255, 255, 255) or r.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = pity,
		}, { U.textStroke(C(0, 0, 0), 1) })
		if r.rainbow then
			rainbowify(lbl)
		end
		local val = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y),
			Size = UDim2.new(0.7, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "",
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = pity,
		})
		local bg = new("Frame", {
			Position = UDim2.fromOffset(0, y + 19),
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundColor3 = C(8, 6, 12),
			Parent = pity,
		}, { U.corner(7) })
		local fill = new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = r.rainbow and C(255, 255, 255) or r.color,
			Parent = bg,
		}, { U.corner(7) })
		if r.rainbow then
			rainbowify(fill)
		end
		g.pityBars[key] = { val = val, fill = fill, pulls = pulls }
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "The counter resets when this rarity or higher drops",
		TextSize = 11,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pity,
	})

	-- пул дронов
	local pool = new("Frame", {
		Position = UDim2.fromOffset(0, 240),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = B.panel,
		Parent = right,
	}, {
		U.corner(14),
		U.pad(8),
		new("UIGridLayout", { CellSize = UDim2.fromOffset(40, 40), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for i, def in ipairs(B.pool) do
		local cell = button({
			BackgroundColor3 = U.darken(Config.Rarities[def.rarity].color, 0.25),
			Text = "",
			LayoutOrder = i,
			Parent = pool,
		}, function()
			g.showDef(def)
		end)
		U.corner(8).Parent = cell
		rarityStroke(cell, def.rarity, 1.5)
		if Config.Rarities[def.rarity].rainbow then
			rainbowBg(cell, 35, 0.75)
		end
		local vp = new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = C(150, 150, 150),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			Parent = cell,
		})
		setModelVp(vp, def)
		if def.rarity == "Secret" then
			vp.ImageColor3 = C(0, 0, 0)
			new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "?", Font = Enum.Font.FredokaOne, TextSize = 26, TextColor3 = C(255, 40, 40), Parent = cell })
		end
	end

	-- гемы не покупаются за батареи: подсказка, где их взять
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 394),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = B.hintBg,
		BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBold,
		Text = B.hint,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = C(200, 235, 255),
		Parent = right,
	}, { U.corner(8), U.stroke(B.hintStroke, 1.2, 0.4) })

	-- кнопки круток
	local function pullButton(x, count, cost, c1, c2)
		local b = button({
			Position = UDim2.new(x, x > 0 and 6 or 0, 1, -100),
			Size = UDim2.new(0.5, -6, 0, 70),
			BackgroundColor3 = C(255, 255, 255),
			Text = "",
			ClipsDescendants = true,
			Parent = right,
		}, function()
			UI.Pull(count, B.id)
		end)
		U.corner(14).Parent = b
		U.grad(c1, c2, 90).Parent = b
		U.stroke(C(255, 255, 255), 2.5, 0.2).Parent = b
		new("TextLabel", {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "PULL ×" .. count,
			TextSize = 24,
			TextColor3 = C(255, 255, 255),
			Parent = b,
		}, { U.textStroke(C(0, 0, 0), 2) })
		new("TextLabel", {
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = B.cur .. " " .. U.fmt(cost),
			TextSize = 17,
			TextColor3 = C(255, 255, 255),
			Parent = b,
		}, { U.textStroke(C(0, 0, 0), 1.5) })
		local shine = new("Frame", {
			Position = UDim2.new(-0.4, 0, -0.5, 0),
			Size = UDim2.new(0, 30, 2, 0),
			BackgroundColor3 = C(255, 255, 255),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Rotation = 20,
			ZIndex = 3,
			Parent = b,
		})
		task.spawn(function()
			while b.Parent do
				shine.Position = UDim2.new(-0.4, 0, -0.5, 0)
				U.tween(shine, 0.7, { Position = UDim2.new(1.2, 0, -0.5, 0) })
				task.wait(2.4 + math.random())
			end
		end)
		return b
	end
	g.b1 = pullButton(0, 1, B.cost1, B.b1[1], B.b1[2])
	g.b10 = pullButton(0.5, 10, B.cost10, B.b10[1], B.b10[2])

	g.fast = false
	local fastBtn = button({
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		BackgroundColor3 = C(0, 0, 0),
		Font = Enum.Font.GothamBold,
		Text = "☐ Fast animation",
		TextSize = 14,
		TextColor3 = T.Muted,
		Parent = right,
	})
	fastBtn.Activated:Connect(function()
		g.fast = not g.fast
		fastBtn.Text = (g.fast and "☑" or "☐") .. " Fast animation"
		fastBtn.TextColor3 = g.fast and T.Accent or T.Muted
	end)

	-- витрина
	g.showDef = function(def)
		-- витрина сменяется плавно: шторка закрывает старого дрона, под ней ставится новый и шторка уходит
		g.showUntil = os.clock() + 6
		local token = {}
		g.showToken = token
		if g.stage.model and g.win.Visible then
			U.tween(g.showCover, 0.2, { BackgroundTransparency = 0 })
			U.tween(g.showName, 0.2, { TextTransparency = 1 })
			task.wait(0.2)
			if g.showToken ~= token then
				return
			end
		end
		local r = Config.Rarities[def.rarity]
		local hidden = def.rarity == "Secret" and not (State.data and (State.data.owned[def.id] or 0) > 0)
		stageSetModel(g.stage, def, hidden and "hidden" or "full", r)
		g.showName.Text = (hidden and "???" or def.name) .. "  •  " .. r.label
		g.showName.TextColor3 = r.color
		g.showRainbow = r.rainbow
		U.tween(g.showStroke, 0.3, { Color = r.color })
		g.showCover.BackgroundTransparency = 0
		g.showName.TextTransparency = 1
		U.tween(g.showCover, 0.35, { BackgroundTransparency = 1 })
		U.tween(g.showName, 0.3, { TextTransparency = 0 })
	end
	g.showIndex = 0
end

local function updateGacha(g, B, d)
	if not g.win then
		return
	end
	local cur, other = B.balance(d)
	U.countTo(g.balance, cur, function(v)
		return B.cur .. " " .. U.fmt(v) .. "    " .. other
	end)
	g.total.Text = "Total pulls: " .. U.fmt(B.pulls(d))
	local pity = B.pityOf(d)
	for key, bar in pairs(g.pityBars) do
		local v = pity[key] or 0
		bar.val.Text = ("%d / %d  •  %d left"):format(v, bar.pulls, bar.pulls - v)
		U.tween(bar.fill, 0.3, { Size = UDim2.fromScale(math.clamp(v / bar.pulls, 0, 1), 1) })
	end
	U.tween(g.b1, 0.2, { BackgroundTransparency = cur >= B.cost1 and 0 or 0.5 })
	U.tween(g.b10, 0.2, { BackgroundTransparency = cur >= B.cost10 and 0 or 0.5 })
end

local pulling = false
function UI.Pull(count, banner)
	if pulling or GachaAnim.IsPlaying() then
		return
	end
	local B = BANNERS[banner or "main"]
	pulling = true
	local ok, res = pcall(B.invoke, count)
	pulling = false
	if not ok or type(res) ~= "table" then
		UI.Toast("Server connection error", "bad")
		return
	end
	if not res.ok then
		UI.Toast(res.err or "Didn't work", "bad")
		return
	end
	local g = B.state
	closeWindow(g.win, g.scale)
	closeWindow(inv.win, inv.scale)
	-- HUD прячет сама анимация гачи (под мягким затемнением)
	GachaAnim.Play(res.results, { fast = g.fast, zone = B.zone, theme = B.theme }, function()
		gui.Enabled = true
		if B.inZone() then
			openWindow(g.win, g.scale)
		end
	end)
end

function UI.InGachaZone()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and (hrp.Position - Config.GachaZone.center).Magnitude <= Config.GachaZone.radius + 8
end

function UI.OpenGacha(banner)
	if GachaAnim.IsPlaying() then
		return
	end
	closeWindow(inv.win, inv.scale)
	QuestUI.CloseBook()
	for key, B in pairs(BANNERS) do
		if key ~= (banner or "main") and B.state.win then
			closeWindow(B.state.win, B.state.scale)
		end
	end
	local g = BANNERS[banner or "main"].state
	openWindow(g.win, g.scale)
end

function UI.InHalloweenZone()
	if not Config.HalloweenOn() then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local z = Config.Halloween.zone
	return hrp ~= nil and (hrp.Position - z.center).Magnitude <= z.radius + 10
end

function UI.OnMenu(key)
	if key ~= "quests" then
		QuestUI.CloseBook()
	end
	if key == "drones" then
		UI.ToggleInventory()
	elseif key == "gacha" then
		if UI.InGachaZone() then
			UI.OpenGacha()
		else
			Remotes.Teleport:FireServer("gacha")
			UI.Toast("🎰 Drone Lab! Walk up to the Drone Capsule and press E", "Epic")
		end
	elseif key == "shop" then
		if ShopUI.InZone() then
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			ShopUI.Open()
		else
			Remotes.Teleport:FireServer("shop")
			UI.Toast("🛒 Shop! Walk up to the counter and press E", "Legendary")
		end
	elseif key == "map" then
		UI.ToggleMap()
	elseif key == "base" then
		Remotes.Teleport:FireServer("base")
	elseif key == "bag" then
		BagUI.Toggle()
	elseif key == "convert" then
		UI.GoConverter()
	elseif key == "donate" then
		DonateUI.Toggle()
	elseif key == "quests" then
		QuestUI.ToggleBook()
	elseif key == "halloween" and Config.HalloweenOn() then
		if UI.InHalloweenZone() then
			UI.Toast("🎃 Walk up to the cauldron and press E", "Legendary")
		else
			Remotes.Teleport:FireServer("halloween")
			UI.Toast("🎃 Pumpkin Cauldron! Walk up to it and press E", "Legendary")
		end
	end
end

-- телепорт на площадку Переработчика: звук «вжух», зелёная вспышка на экране
local lastConvTp = 0
function UI.GoConverter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pad = Config.Converter.pad
	if hrp and Vector3.new(hrp.Position.X - pad.X, 0, hrp.Position.Z - pad.Z).Magnitude <= Config.Converter.radius then
		UI.Toast("♻ You're already on the pad. Press E at the Recycler", "info")
		return
	end
	if os.clock() - lastConvTp < 2 then
		return
	end
	lastConvTp = os.clock()
	U.play(U.Sounds.whooshRise, 0.5, 1.15)
	task.delay(0.12, function()
		U.play(U.Sounds.chime, 0.4, 1.2)
	end)
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(140, 255, 120), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 50, Parent = gui })
	U.tween(flash, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.55, function()
		flash:Destroy()
	end)
	Remotes.Teleport:FireServer("converter")
	UI.Toast("♻ Recycler! Press E to turn resources into batteries", "good")
end

-- ===== БАННЕР ЗОНЫ =====
local currentZone = nil
local function showBanner(title, sub, color)
	sub = U.touchText(sub)
	hud.banner.Visible = true
	local s1 = hud.bannerTitle:FindFirstChildOfClass("UIStroke")
	local s2 = hud.bannerSub:FindFirstChildOfClass("UIStroke")
	local token = {}
	hud.bannerToken = token
	-- если прошлый баннер ещё виден — сначала плавно гасим его, потом показываем новый
	local delay = 0
	if hud.bannerTitle.TextTransparency < 0.95 then
		delay = 0.15
		U.tween(hud.bannerTitle, delay, { TextTransparency = 1 })
		U.tween(hud.bannerSub, delay, { TextTransparency = 1 })
		U.tween(s1, delay, { Transparency = 1 })
		U.tween(s2, delay, { Transparency = 1 })
	end
	task.delay(delay, function()
		if hud.bannerToken ~= token then
			return
		end
		hud.bannerTitle.Text = title
		hud.bannerSub.Text = sub
		hud.bannerSub.TextColor3 = color
		-- лёгкий «наезд»: баннер чуть увеличивается из 85% с пружинкой
		local sc = hud.bannerScale
		sc:SetAttribute("Animating", true)
		sc.Scale = respScale * 0.85
		U.tween(sc, 0.45, { Scale = respScale }, Enum.EasingStyle.Back)
		task.delay(0.46, function()
			if hud.bannerToken == token then
				sc:SetAttribute("Animating", nil)
			end
		end)
		U.tween(hud.bannerTitle, 0.4, { TextTransparency = 0 })
		U.tween(hud.bannerSub, 0.4, { TextTransparency = 0 })
		U.tween(s1, 0.4, { Transparency = 0 })
		U.tween(s2, 0.4, { Transparency = 0 })
	end)
	task.delay(2.6 + delay, function()
		if hud.bannerToken ~= token then
			return
		end
		U.tween(hud.bannerTitle, 0.5, { TextTransparency = 1 })
		U.tween(hud.bannerSub, 0.5, { TextTransparency = 1 })
		U.tween(s1, 0.5, { Transparency = 1 })
		U.tween(s2, 0.5, { Transparency = 1 })
	end)
end

local function zoneTick()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local pos = hrp.Position
	local zone = nil
	for _, f in ipairs(Config.Fields) do
		local c = f.center
		if math.abs(pos.X - c.X) <= f.size / 2 + 1 and math.abs(pos.Z - c.Z) <= f.size / 2 + 1 then
			zone = f
		end
	end
	local inGacha = UI.InGachaZone()
	local inGrove = UI.InHalloweenZone()
	local key = zone and zone.id or (inGacha and "gacha" or nil) or (inGrove and "halloween" or nil)
	if key ~= currentZone then
		currentZone = key
		if zone then
			local d = State.data
			local ok = not d or d.equippedTotal >= zone.req
			if zone.boss then
				showBanner("☠ " .. zone.name, ok and ("Boss with %s HP • defeat it for gems and rare finds"):format(U.fmt(zone.zombies.hp)) or ("Needs %d drones in your swarm!"):format(zone.req), ok and C(255, 120, 80) or T.Danger)
			else
			showBanner("☣ " .. zone.name, ok and ("Scrap x%s  •  Zombies: %s"):format(tostring(zone.mult), zone.zombies.name) or ("Needs %d drones in your swarm!"):format(zone.req), ok and T.Accent or T.Danger)
			end
		elseif inGacha then
			showBanner("🎰 DRONE LAB", "Walk up to the capsule and press E", T.Gacha)
		elseif inGrove then
			showBanner("🎃 PUMPKIN CAULDRON", "Walk up to the cauldron and press E", C(255, 150, 40))
		end
	end
	if U.isOpen(gacha.win, gacha.scale) and not inGacha and not GachaAnim.IsPlaying() then
		closeWindow(gacha.win, gacha.scale)
	end
	if hgacha.win and U.isOpen(hgacha.win, hgacha.scale) and not inGrove and not GachaAnim.IsPlaying() then
		closeWindow(hgacha.win, hgacha.scale)
	end
end

-- ===== INIT =====
function UI.Init()
	local pg = player:WaitForChild("PlayerGui")
	gui = new("ScreenGui", {
		Name = "ZSS_HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = pg,
	})
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- учитывает и верхнюю панель Roblox, и вырез экрана
	-- отдельный слой для вкладок в верхней полосе Roblox (телефоны) и «щуп» безопасной зоны экрана
	local topGui = new("ScreenGui", {
		Name = "ZSS_TopBar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = pg,
	})
	UI.TopArea = new("Frame", { Name = "TopArea", BackgroundTransparency = 1, Parent = topGui })
	local probeGui = new("ScreenGui", {
		Name = "ZSS_SafeProbe",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		Parent = pg,
	})
	UI.SafeProbe = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = probeGui })
	updateScale()
	buildHUD()
	buildInventory()
	for _, B in pairs(BANNERS) do
		buildGacha(B.state, B)
	end
	buildMap()
	BagUI.Init({
		gui = gui,
		addScale = addScale,
		openWindow = openWindow,
		closeWindow = closeWindow,
		button = button,
		toast = UI.Toast,
		closeOthers = function()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			DonateUI.Close()
		end,
	})
	SettingsUI.Init({
		gui = gui,
		addScale = addScale,
		openWindow = openWindow,
		closeWindow = closeWindow,
		button = button,
		toast = UI.Toast,
		closeOthers = function()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			DonateUI.Close()
			BagUI.Close()
			QuestUI.Close()
		end,
		onApply = function(v)
			UI.ToastsEnabled = v.toasts
			if math.abs((UI.UserScale or 1) - v.uiScale) > 0.001 then
				UI.UserScale = v.uiScale
				updateScale()
			end
		end,
	})
	WitchUI.Init({
		gui = gui,
		addScale = addScale,
		openWindow = openWindow,
		closeWindow = closeWindow,
		button = button,
		toast = UI.Toast,
		closeOthers = function()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			if hgacha.win then
				closeWindow(hgacha.win, hgacha.scale)
			end
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			DonateUI.Close()
			BagUI.Close()
			QuestUI.Close()
		end,
	})
	QuestUI.Init({
		gui = gui,
		addScale = addScale,
		openWindow = openWindow,
		closeWindow = closeWindow,
		button = button,
		toast = UI.Toast,
		closeOthers = function()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			DonateUI.Close()
			BagUI.Close()
		end,
	})
	FXmod.OnItemDrop = function(it)
		if it.consum then
			UI.Toast("🧪 Consumable: " .. it.name .. " (" .. ItemsCfg.Tiers[it.tier].name .. ")", it.tier)
			return
		end
		UI.Toast("🎒 To backpack: " .. it.name .. " (" .. ItemsCfg.Tiers[it.tier].name .. ")", it.tier)
	end
	FXmod.OnLootSpawn = function(it)
		UI.Toast((it.c and "🧪 Consumable dropped: " or "📦 Find dropped: ") .. it.name .. ". Go pick it up!", it.tier)
	end
	FXmod.OnBossReward = BagUI.ShowBossReward
	hookHotbarContainers()
	updateScale()
	UIS.LastInputTypeChanged:Connect(updateScale)
	-- свой хотбар и своя полоса здоровья вместо стандартных
	task.spawn(function()
		local SG = game:GetService("StarterGui")
		for _ = 1, 20 do
			local ok = pcall(function()
				SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				SG:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			end)
			if ok then
				break
			end
			task.wait(0.5)
		end
	end)
	Remotes.Energy.OnClientEvent:Connect(function(t)
		UI.Energy = t
		UI.UpdateEnergyHUD()
		if UI.UpdateSlotEnergy then
			UI.UpdateSlotEnergy()
		end
	end)
	State.Changed:Connect(function()
		if mapWin.win and mapWin.win.Visible then
			UI.UpdateMap()
		end
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	-- размеры ScreenGui и верхней полосы обновляются на кадр позже камеры — пересчитываем ещё раз
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updateScale)

	local function onData(d)
		updateHUD(d)
		updateInventory(d)
		for _, B in pairs(BANNERS) do
			updateGacha(B.state, B, d)
		end
	end
	State.Changed:Connect(onData)
	if State.data then
		onData(State.data)
	end

	Remotes.Notify.OnClientEvent:Connect(UI.Toast)
	ShopUI.Init(UI.Toast)
	DonateUI.Init({
		gui = gui,
		addScale = addScale,
		openWindow = openWindow,
		closeWindow = closeWindow,
		button = button,
		toast = UI.Toast,
		closeOthers = function()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			BagUI.Close()
			QuestUI.Close()
			SettingsUI.Close()
		end,
	})
	HS.toast = UI.Toast

	-- горячие клавиши: назначения в Keybinds (меняются в настройках), Esc всегда закрывает окна
	local KEY_ACTIONS = {
		drones = function()
			UI.ToggleInventory()
		end,
		gacha = function()
			UI.OnMenu("gacha")
		end,
		shop = function()
			UI.OnMenu("shop")
		end,
		bag = function()
			QuestUI.CloseBook()
			BagUI.Toggle()
		end,
		map = function()
			UI.ToggleMap()
		end,
		convert = function()
			UI.GoConverter()
		end,
		settings = function()
			SettingsUI.Toggle()
		end,
		donate = function()
			QuestUI.CloseBook()
			DonateUI.Toggle()
		end,
		quests = function()
			QuestUI.ToggleBook()
		end,
		halloween = function()
			UI.OnMenu("halloween")
		end,
	}
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed or GachaAnim.IsPlaying() or Keybinds.Capturing then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			SettingsUI.Close()
			BagUI.Close()
			QuestUI.Close()
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			closeWindow(mapWin.win, mapWin.scale)
			ShopUI.Close()
			DonateUI.Close()
			return
		end
		local id = Keybinds.Action(input.KeyCode)
		local a = id and Keybinds.ById[id]
		if a and a.slot then
			local n = a.slot
			-- в инвентаре навёл на предмет и нажал клавишу ячейки 3–6 — предмет ложится в эту ячейку
			local hk = BagUI.IsOpen() and HS.HoverKey()
			if hk and n >= HS.First then
				HS.Assign(n - HS.First + 1, hk)
				U.play(U.Sounds.chime, 0.35, 1.2)
				local vis = HS.Visual(hk)
				UI.Toast(("“%s” → slot %d"):format(vis and vis.name or "?", n), "good")
			else
				UI.UseSlot(n)
			end
		elseif id and KEY_ACTIONS[id] then
			KEY_ACTIONS[id]()
		end
	end)

	-- значки клавиш на кнопках следуют за назначениями из настроек
	local function syncKeyBadges()
		local function badge(lbl, id, minW)
			if lbl then
				local s = Keybinds.Short(Keybinds.Get(id))
				lbl.Text = s
				lbl.Size = UDim2.fromOffset(math.max(minW, utf8.len(s) * 7 + 6), lbl.Size.Y.Offset)
			end
		end
		for key, b in pairs(hud.buttons) do
			badge(b.hot, key, 18)
		end
		badge(hud.setHot, "settings", 16)
		badge(hud.dronesHot, "drones", 34)
		for _, e in ipairs(hud.slotKeys or {}) do
			e.lbl.Text = Keybinds.Short(Keybinds.Get("slot" .. e.i))
		end
	end
	Keybinds.Changed:Connect(syncKeyBadges)
	syncKeyBadges()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "GachaPrompt" then
			ShopUI.Close()
			DonateUI.Close()
			UI.OpenGacha()
		elseif prompt.Name == "HalloweenGachaPrompt" and BANNERS.halloween then
			ShopUI.Close()
			DonateUI.Close()
			UI.OpenGacha("halloween")
		elseif prompt.Name == "ShopPrompt" then
			closeWindow(inv.win, inv.scale)
			closeWindow(gacha.win, gacha.scale)
			-- прилавки магазина открывают свою категорию (атрибут ShopTab)
			ShopUI.Open(prompt:GetAttribute("ShopTab"))
		end
	end)

	-- витрина в окне гачи (топ-дроны своего баннера по очереди)
	for _, B in pairs(BANNERS) do
		local list = {}
		for _, d in ipairs(B.pool) do
			if Config.Rarities[d.rarity].order >= 4 then
				table.insert(list, d)
			end
		end
		B.featured = list
		B.state.showDef(list[1])
	end

	-- пока открыто окно, подсказки «E»/«коснись» у пультов не висят поверх него (на телефоне их значок закрывал витрину)
	local WINDOWS = { "Inventory", "Gacha", "HGacha", "WitchShop", "Map", "Backpack", "Settings", "QuestDialog", "QuestBook", "CellShop", "Donate" }
	local shopGui = player.PlayerGui:FindFirstChild("ZSS_Shop")
	local promptsHidden = false
	task.spawn(function()
		while true do
			task.wait(0.2)
			local open = GachaAnim.IsPlaying()
			for _, n in ipairs(WINDOWS) do
				local w = gui:FindFirstChild(n)
				if w and w.Visible then
					open = true
					break
				end
			end
			shopGui = shopGui or player.PlayerGui:FindFirstChild("ZSS_Shop")
			if not open and shopGui then
				local w = shopGui:FindFirstChildWhichIsA("Frame")
				open = w ~= nil and w.Visible
			end
			if open ~= promptsHidden then
				promptsHidden = open
				pcall(function()
					ProximityPromptService.MaxPromptsVisible = open and 0 or 16
				end)
			end
		end
	end)

	local lastZone = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, g in ipairs(rainbowGrads) do
			g.Rotation = (t * 90) % 360
		end
		for _, b in ipairs(rainbowBgs) do
			if b.g.Parent and b.g.Parent.Visible ~= false then
				b.g.Color = Config.RainbowFlow(t, 0.75, b.val)
			end
		end
		local pulse = 0.55 + 0.45 * math.abs(math.sin(t * 3))
		for _, s in ipairs(secretStrokes) do
			s.Color = Color3.new(pulse, 0.08, 0.1)
		end
		-- плавный счётчик батарей
		local d = State.data
		if d then
			local target = d.batteries
			if hud.displayBat ~= target then
				local diff = target - hud.displayBat
				if math.abs(diff) < 1 then
					hud.displayBat = target
				else
					hud.displayBat += diff * math.min(1, dt * 8)
				end
				hud.bat.Text = U.fmt(math.floor(hud.displayBat + 0.5))
			end
		end
		-- блеск драгоценностей: свечение, блик по иконке, отблеск чипа, мерцание искр
		if hud.chips then
			for _, c in ipairs(hud.chips) do
				local ph = t + c.phase
				local k = 0.5 + 0.5 * math.sin(ph * 2.2)
				c.glow.ImageTransparency = 0.15 + 0.4 * (1 - k)
				c.glowScale.Scale = (84 + 26 * k) / 96
				c.glow.Rotation = (ph * 20) % 360
				c.icon.Rotation = math.sin(ph * 1.3) * 4
				-- блик проходит по иконке раз в ~2.6 с
				local g = (ph % 2.6) / 2.6
				c.glintGrad.Offset = Vector2.new(-1.1 + g * 3.2, 0)
				c.sheenGrad.Offset = Vector2.new(-1.3 + ((ph * 0.32) % 1) * 3.2, 0)
				c.stGrad.Rotation = (ph * 60) % 360
				c.valueGrad.Offset = Vector2.new(((ph * 0.45) % 2.4) - 1.2, 0)
				for _, st in ipairs(c.stars) do
					local a = (t - st.start) / st.dur
					if a >= 1 then
						if math.random() < 0.04 then
							st.start = t
							st.dur = 0.5 + math.random() * 0.5
							st.img.Position = UDim2.fromOffset(math.random(8, 50), math.random(6, 48))
							st.size = math.random(10, 18)
						else
							st.sc.Scale = 0
						end
					else
						local sz = (st.size or 12) * math.sin(a * math.pi)
						st.sc.Scale = sz / 18
						st.img.Rotation = a * 90
					end
				end
			end
		end
		-- мигание «рюкзак полон» затухает плавно, а не обрывается
		local scrapT = hud.full and 0.25 * (0.5 + 0.5 * math.sin(t * 6)) or 0
		hud.scrap.TextTransparency += (scrapT - hud.scrap.TextTransparency) * math.min(1, dt * 12)
		if hud.energyLow then
			hud.chargeBtn.BackgroundColor3 = Color3.new(1, 0.55 + 0.15 * math.sin(t * 6), 0.12)
		end
		local hp = hud.hpBar.bg:FindFirstChildOfClass("UIStroke")
		hp.Color = hp.Color:Lerp(hud.hpLow and Color3.new(1, 0.25 + 0.25 * math.sin(t * 8), 0.2) or C(70, 80, 70), math.min(1, dt * 12))
		-- вращение моделей в окнах
		if inv.win.Visible then
			if inv.drarityRainbow then
				inv.drarity.TextColor3 = Config.Rainbow(t)
			end
		end
		for _, B in pairs(BANNERS) do
			local g = B.state
			if g.win.Visible and g.stage.model then
				if g.showRainbow then
					g.showName.TextColor3 = Config.Rainbow(t)
				end
				if t > g.showUntil then
					g.showIndex = g.showIndex % #B.featured + 1
					task.spawn(g.showDef, B.featured[g.showIndex])
				end
			end
		end
		if t - lastZone > 0.3 then
			lastZone = t
			zoneTick()
		end
	end)
end

return UI