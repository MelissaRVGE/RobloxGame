-- Меню настроек: графика, управление, звук, интерфейс. Значения сохраняются в профиль игрока.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = RS:WaitForChild("ZSS")
local Icons = require(Shared.Icons)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)
local FX = require(script.Parent.FX)
local WorldLOD = require(script.Parent.WorldLOD)
local Keybinds = require(script.Parent.Keybinds)
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local S = {}
local api
local win, scaleObj
local pages, tabs = {}, {}
local widgets = {}
local ACCENT = C(90, 200, 255)

S.Defaults = {
	preset = "high",
	shadows = true,
	effects = true,
	particles = true,
	fov = 70,
	sensitivity = 1,
	shake = true,
	master = 1,
	sfx = 1,
	ui = 1,
	uiScale = 1,
	showQuests = true,
	showDamage = true,
	toasts = true,
	keys = {}, -- переназначенные горячие клавиши (только отличные от стандартных)
}
S.Values = table.clone(S.Defaults)
local loaded = false
local saveToken = 0

-- ===== ПРИМЕНЕНИЕ =====
local function applyAll()
	local v = S.Values
	Lighting.GlobalShadows = v.shadows
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
			e.Enabled = v.effects
		end
	end
	-- дальность фонарей/частиц и тени мелкого декора: по пресету, а в «своих» настройках — по тумблерам
	local lv = v.preset == "low" and 1 or v.preset == "med" and 2 or v.preset == "high" and 3 or ((v.shadows and v.particles) and 3 or (v.particles and 2 or 1))
	WorldLOD.SetLevel(lv)
	FX.Particles = v.particles and 1 or 0.35
	FX.ShakeEnabled = v.shake
	FX.ShowDamage = v.showDamage
	U.tween(workspace.CurrentCamera, 0.25, { FieldOfView = v.fov }) -- угол обзора меняется плавно
	UIS.MouseDeltaSensitivity = v.sensitivity
	U.Volume.master = v.master
	U.Volume.sfx = v.sfx
	U.Volume.ui = v.ui
	if api and api.onApply then
		api.onApply(v)
	end
end

local function save()
	saveToken += 1
	local my = saveToken
	task.delay(1, function()
		if my == saveToken then
			Remotes.SaveSettings:FireServer(S.Values)
		end
	end)
end

local function set(key, value)
	S.Values[key] = value
	applyAll()
	save()
	for _, w in ipairs(widgets) do
		if w.key == key and w.sync then
			w.sync()
		end
	end
end

local PRESETS = {
	low = { shadows = false, effects = false, particles = false },
	med = { shadows = true, effects = false, particles = true },
	high = { shadows = true, effects = true, particles = true },
}

-- ===== ЭЛЕМЕНТЫ =====
local function row(page, order, iconText, title, desc)
	local r = new("Frame", { Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = C(26, 30, 36), LayoutOrder = order, Parent = page }, { U.corner(12), U.stroke(C(55, 62, 72), 1.2) })
	new("TextLabel", { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(30, 60), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = iconText, TextSize = 24, TextColor3 = ACCENT, Parent = r })
	new("TextLabel", { Position = UDim2.fromOffset(48, 9), Size = UDim2.new(1, -290, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(240, 244, 248), Parent = r })
	new("TextLabel", { Position = UDim2.fromOffset(48, 31), Size = UDim2.new(1, -290, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = desc or "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(150, 160, 172), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
	return r
end

local function toggle(page, order, key, iconText, title, desc)
	local r = row(page, order, iconText, title, desc)
	local track = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(64, 32), BackgroundColor3 = C(60, 66, 76), Text = "", AutoButtonColor = false, Parent = r }, { U.round() })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C(255, 255, 255), Parent = track }, { U.round(), U.grad(C(255, 255, 255), C(200, 205, 215), 90) })
	local w = { key = key }
	function w.sync()
		local on = S.Values[key]
		U.tween(track, 0.15, { BackgroundColor3 = on and C(70, 190, 90) or C(60, 66, 76) })
		U.tween(knob, 0.15, { Position = on and UDim2.new(0, 36, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) })
	end
	U.pressFx(track, { hover = 1.06, hoverSound = false })
	track.Activated:Connect(function()
		U.play(U.Sounds.tap, 0.5, S.Values[key] and 0.9 or 1.2)
		-- кнопка «пружинит» в сторону переключения
		U.pulseSize(knob, UDim2.fromOffset(32, 22), UDim2.fromOffset(24, 24), 0.06, 0.35)
		set(key, not S.Values[key])
		if key == "shadows" or key == "effects" or key == "particles" then
			S.Values.preset = "custom"
			for _, x in ipairs(widgets) do
				if x.key == "preset" then
					x.sync()
				end
			end
		end
	end)
	table.insert(widgets, w)
	return w
end

local function slider(page, order, key, iconText, title, desc, minV, maxV, step, fmt)
	local r = row(page, order, iconText, title, desc)
	local valueLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(52, 24), BackgroundColor3 = C(16, 20, 26), Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = ACCENT, Parent = r }, { U.corner(8) })
	local track = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -78, 0.5, 0), Size = UDim2.fromOffset(170, 10), BackgroundColor3 = C(16, 20, 26), Text = "", AutoButtonColor = false, Parent = r }, { U.round() })
	local fill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C(255, 255, 255), Parent = track }, { U.round(), U.grad(C(130, 230, 255), C(50, 140, 230), 0) })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = C(255, 255, 255), ZIndex = 3, Parent = track }, { U.round(), U.stroke(ACCENT, 2) })
	local w = { key = key }
	function w.sync()
		local v = S.Values[key]
		local a = math.clamp((v - minV) / (maxV - minV), 0, 1)
		U.tween(fill, 0.1, { Size = UDim2.fromScale(a, 1) })
		U.tween(knob, 0.1, { Position = UDim2.fromScale(a, 0.5) })
		valueLbl.Text = fmt and fmt(v) or tostring(v)
	end
	local dragging = false
	local function update(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = minV + (maxV - minV) * a
		v = math.floor(v / step + 0.5) * step
		if v ~= S.Values[key] then
			set(key, v)
		end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(widgets, w)
	return w
end

local function segmented(page, order, key, iconText, title, desc, options)
	local r = row(page, order, iconText, title, desc)
	local holder = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(234, 34), BackgroundColor3 = C(16, 20, 26), Parent = r }, { U.corner(10), U.pad(3), new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local btns = {}
	for i, o in ipairs(options) do
		local b = new("TextButton", { Size = UDim2.new(1 / #options, -2, 1, 0), BackgroundColor3 = C(16, 20, 26), Font = Enum.Font.GothamBlack, Text = o.label, TextSize = 13, TextColor3 = C(170, 180, 190), AutoButtonColor = false, LayoutOrder = i, Parent = holder }, { U.corner(8) })
		btns[o.value] = b
		U.pressFx(b, { hover = 1.04, hoverSound = false })
		b.Activated:Connect(function()
			U.play(U.Sounds.tap, 0.5, 1.1)
			if o.apply then
				for k, v in pairs(o.apply) do
					S.Values[k] = v
				end
			end
			set(key, o.value)
			for _, x in ipairs(widgets) do
				if x.sync then
					x.sync()
				end
			end
		end)
	end
	local w = { key = key }
	function w.sync()
		for value, b in pairs(btns) do
			local on = S.Values[key] == value
			U.tween(b, 0.15, { BackgroundColor3 = on and C(50, 150, 230) or C(16, 20, 26), TextColor3 = on and C(255, 255, 255) or C(170, 180, 190) })
		end
	end
	table.insert(widgets, w)
	return w
end

-- клавиша, которую нельзя поменять (мышь, Esc, E и т.п.)
local function keyRow(page, order, key, text)
	local r = new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C(22, 25, 30), LayoutOrder = order, Parent = page }, { U.corner(10) })
	new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(84, 28), BackgroundColor3 = C(190, 196, 204), Font = Enum.Font.GothamBlack, Text = key, TextSize = 13, TextColor3 = C(30, 34, 40), Parent = r }, { U.corner(7), U.stroke(C(110, 118, 128), 1.5) })
	new("TextLabel", { Position = UDim2.fromOffset(108, 0), Size = UDim2.new(1, -120, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(170, 178, 188), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
end

-- ===== ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ =====
local bindRows = {}
local capture -- строка, которая сейчас ждёт новую клавишу

local function stopCapture()
	local c = capture
	if not c then
		return
	end
	capture = nil
	CAS:UnbindAction("ZSS_KeyCapture")
	if c.pulse then
		c.pulse:Cancel()
		c.pulse = nil
	end
	-- игровые клавиши оживают чуть позже, чтобы это же нажатие не открыло окно
	task.delay(0.15, function()
		if not capture then
			Keybinds.Capturing = false
		end
	end)
	c.sync()
end

-- нажатие, пока строка ждёт новую клавишу; клавиша перехватывается целиком (персонаж не бежит и не прыгает)
local function onCaptureKey(_, state, input)
	local row = capture
	if not row or state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Escape then
		U.play(U.Sounds.tap, 0.4, 0.8)
		stopCapture()
		return Enum.ContextActionResult.Sink
	end
	local ok, info = Keybinds.Assign(row.action.id, kc)
	stopCapture()
	if ok then
		U.play(U.Sounds.chime, 0.4, 1.2)
		U.pulseScale(row.cap, 1.15, 0.08, 0.3)
		S.OnKeysChanged(row.action.id, info)
	else
		row.fail(("%s is taken: %s"):format(Keybinds.Name(kc), info))
	end
	return Enum.ContextActionResult.Sink
end

local function bindRow(page, order, action)
	local r = new("Frame", { Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C(26, 30, 36), LayoutOrder = order, Parent = page }, { U.corner(10) })
	local rst = U.stroke(C(55, 62, 72), 1.2)
	rst.Parent = r
	local cap = new("TextButton", { Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(84, 30), BackgroundColor3 = C(235, 238, 242), Font = Enum.Font.GothamBlack, Text = "", TextSize = 14, TextColor3 = C(20, 24, 30), AutoButtonColor = false, Parent = r }, { U.corner(7) })
	local cst = U.stroke(C(140, 150, 160), 1.5)
	cst.Parent = cap
	local lbl = new("TextLabel", { Position = UDim2.fromOffset(108, 0), Size = UDim2.new(1, -160, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = action.label, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(220, 226, 232), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
	-- «СБРОС» — вернуть стандартную клавишу этого действия (видна, только если клавиша изменена)
	local back = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(64, 28), BackgroundColor3 = C(40, 46, 56), Font = Enum.Font.GothamBlack, Text = "RESET", TextSize = 11, TextColor3 = C(200, 220, 240), AutoButtonColor = false, Visible = false, Parent = r }, { U.corner(8) })
	local row = { action = action, cap = cap, lbl = lbl }
	local errUntil = 0
	function row.sync()
		if capture == row then
			return
		end
		local kc = Keybinds.Get(action.id)
		local custom = Keybinds.Overrides[action.id] ~= nil
		cap.Text = Keybinds.Name(kc)
		U.tween(cap, 0.18, { BackgroundColor3 = C(235, 238, 242), TextColor3 = C(20, 24, 30) })
		U.tween(cst, 0.18, { Color = custom and ACCENT or C(140, 150, 160), Thickness = custom and 2 or 1.5 })
		U.tween(rst, 0.18, { Color = C(55, 62, 72) })
		if os.clock() >= errUntil then
			lbl.Text = action.label
			U.tween(lbl, 0.18, { TextColor3 = C(220, 226, 232) })
		end
		U.fadeVisible(back, custom, 0.15)
	end
	function row.fail(msg)
		errUntil = os.clock() + 2.5
		lbl.Text = msg
		lbl.TextColor3 = C(255, 120, 110)
		U.play(U.Sounds.error, 0.45, 0.8)
		local p0 = UDim2.fromOffset(12, 7)
		task.spawn(function()
			for k = 1, 4 do
				U.tween(cap, 0.04, { Position = p0 + UDim2.fromOffset(k % 2 == 0 and -6 or 6, 0) }).Completed:Wait()
			end
			U.tween(cap, 0.05, { Position = p0 })
		end)
		task.delay(2.5, function()
			if os.clock() >= errUntil then
				row.sync()
			end
		end)
	end
	U.pressFx(cap, { hover = 1.05, hoverSound = false })
	cap.Activated:Connect(function()
		if capture == row then
			stopCapture()
			return
		end
		stopCapture()
		capture = row
		Keybinds.Capturing = true
		errUntil = 0
		U.play(U.Sounds.tap, 0.5, 1.25)
		cap.Text = "…"
		lbl.Text = "Press a new key  •  Esc to cancel"
		U.tween(lbl, 0.18, { TextColor3 = ACCENT })
		U.tween(rst, 0.18, { Color = ACCENT })
		U.tween(cst, 0.18, { Color = ACCENT, Thickness = 2 })
		cap.BackgroundColor3 = C(235, 238, 242)
		-- мягкое «дыхание» колпачка, пока ждём нажатие
		row.pulse = TweenService:Create(cap, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = C(120, 205, 255) })
		row.pulse:Play()
		CAS:BindActionAtPriority("ZSS_KeyCapture", onCaptureKey, false, Enum.ContextActionPriority.High.Value + 200, Enum.UserInputType.Keyboard)
	end)
	U.pressFx(back, { hover = 1.1, hoverSound = false })
	back.Activated:Connect(function()
		local a = Keybinds.ById[action.id]
		local ok, info = Keybinds.Assign(action.id, Enum.KeyCode[a.default])
		if ok then
			U.play(U.Sounds.tap, 0.5, 0.95)
			S.OnKeysChanged(action.id, info)
		end
	end)
	table.insert(bindRows, row)
	return row
end

local function header(page, order, text)
	new("TextLabel", { Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT, LayoutOrder = order, Parent = page })
end

-- ===== ОКНО =====
local TABS = {
	{ id = "graphics", label = "Graphics", icon = "setGraphics", color = C(90, 170, 255) },
	{ id = "controls", label = "Controls", icon = "setControls", color = C(255, 170, 70) },
	{ id = "sound", label = "Sound", icon = "setSound", color = C(110, 230, 120) },
	{ id = "ui", label = "Interface", icon = "setUi", color = C(190, 130, 255) },
	{ id = "codes", label = "Promo Codes", icon = "lootCrate", color = C(255, 200, 60) },
}

local currentTab
local function selectTab(id)
	for _, t in ipairs(TABS) do
		local on = t.id == id
		local page = pages[t.id]
		if on and currentTab ~= id then
			-- новая страница мягко въезжает справа
			page.Position = UDim2.fromOffset(222 + 24, 80)
			page.Visible = true
			U.tween(page, 0.25, { Position = UDim2.fromOffset(222, 80) }, Enum.EasingStyle.Quart)
		elseif not on then
			page.Visible = false
		end
		local b = tabs[t.id]
		U.tween(b.btn, 0.15, { BackgroundColor3 = on and C(36, 44, 56) or C(22, 26, 32) })
		U.tween(b.stroke, 0.15, { Color = on and t.color or C(45, 50, 58) })
		U.fadeVisible(b.bar, on, 0.15)
		U.tween(b.label, 0.15, { TextColor3 = on and C(255, 255, 255) or C(160, 170, 180) })
	end
	currentTab = id
end

local function build()
	win = new("Frame", {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(780, 500),
		BackgroundColor3 = C(16, 19, 24),
		Visible = false,
		ZIndex = 30,
		Parent = api.gui,
	}, { U.corner(20), U.grad(C(255, 255, 255), C(190, 195, 205), 90) })
	local wst = U.stroke(C(255, 255, 255), 3)
	wst.Parent = win
	new("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(90, 200, 255)), ColorSequenceKeypoint.new(0.5, C(170, 120, 255)), ColorSequenceKeypoint.new(1, C(90, 230, 140)) }), Parent = wst })
	scaleObj = api.addScale(win)
	-- шапка
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C(24, 30, 40), Parent = win }, { U.corner(20), U.grad(C(255, 255, 255), C(150, 160, 180), 90) })
	local gear = new("ImageLabel", { Name = "Gear", BackgroundTransparency = 1, Image = Icons.gear, Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(48, 48), Parent = head })
	S.gearIcon = gear
	local title = new("TextLabel", { Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -150, 0, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "SETTINGS", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255), Parent = head }, { U.textStroke(C(0, 10, 25), 2) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(230, 245, 255), C(120, 200, 255)), Parent = title })
	new("TextLabel", { Position = UDim2.fromOffset(75, 40), Size = UDim2.new(1, -150, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Changes are saved automatically", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(150, 170, 190), Parent = head })
	local close = api.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = T.Danger, Font = Enum.Font.GothamBlack, Text = "X", TextSize = 20, TextColor3 = C(255, 255, 255), Parent = head }, function()
		S.Close()
	end)
	U.corner(12).Parent = close
	-- вкладки
	local side = new("Frame", { Position = UDim2.fromOffset(14, 80), Size = UDim2.fromOffset(196, 406), BackgroundTransparency = 1, Parent = win }, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, t in ipairs(TABS) do
		local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = C(22, 26, 32), Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = side }, { U.corner(14) })
		local st = U.stroke(C(45, 50, 58), 2)
		st.Parent = b
		local bar = new("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(5, 38), BackgroundColor3 = t.color, Visible = false, Parent = b }, { U.round() })
		new("ImageLabel", { BackgroundTransparency = 1, Image = Icons[t.icon], Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(44, 44), Parent = b })
		local lbl = new("TextLabel", { Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -74, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = t.label, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(160, 170, 180), Parent = b })
		b.Activated:Connect(function()
			U.play(U.Sounds.click, 0.4, 1.1)
			selectTab(t.id)
		end)
		U.pressFx(b, { hover = 1.03, color = t.color })
		tabs[t.id] = { btn = b, stroke = st, bar = bar, label = lbl }
		pages[t.id] = new("ScrollingFrame", {
			Position = UDim2.fromOffset(222, 80),
			Size = UDim2.new(1, -236, 1, -94),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = t.color,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = win,
		}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	end
	-- ГРАФИКА
	local g = pages.graphics
	segmented(g, 1, "preset", "⭐", "Graphics Quality", "Quick presets for weak and powerful devices", {
		{ value = "low", label = "LOW", apply = PRESETS.low },
		{ value = "med", label = "MEDIUM", apply = PRESETS.med },
		{ value = "high", label = "HIGH", apply = PRESETS.high },
	})
	toggle(g, 2, "shadows", "🌗", "Shadows", "Soft shadows from the sun and lamps")
	toggle(g, 3, "effects", "✨", "Post Effects", "Bloom and sun rays")
	toggle(g, 4, "particles", "💥", "All Particles", "Turn off if the game lags")
	slider(g, 5, "fov", "📷", "Field of View", "Camera view width", 55, 100, 1, function(v)
		return tostring(v) .. "°"
	end)
	-- УПРАВЛЕНИЕ
	local c = pages.controls
	slider(c, 1, "sensitivity", "🖱", "Mouse Sensitivity", "Camera turn speed", 0.2, 3, 0.05, function(v)
		return ("%.2f"):format(v)
	end)
	toggle(c, 2, "shake", "📳", "Camera Shake", "On explosions and boss hits")
	-- на телефоне/планшете без клавиатуры список клавиш не нужен
	if UIS.KeyboardEnabled then
		header(c, 3, "HOTKEYS")
		new("TextLabel", { Size = UDim2.new(1, -8, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Click a key, then press a new one. A key that's already taken gets swapped.", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(150, 160, 172), TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 4, Parent = c })
		for i, a in ipairs(Keybinds.Actions) do
			bindRow(c, 10 + i, a)
		end
		local resetKeys = api.button({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C(40, 48, 60), Font = Enum.Font.GothamBlack, Text = "RESTORE DEFAULT KEYS", TextSize = 14, TextColor3 = C(200, 225, 255), LayoutOrder = 60, Parent = c }, function()
			stopCapture()
			Keybinds.Reset()
			S.OnKeysChanged()
		end)
		U.corner(10).Parent = resetKeys
		header(c, 70, "FIXED KEYS")
		local fixed = {
			{ "E", "Interact (NPCs, stations, Recycler)" },
			{ "LMB", "Weapon hit / tool gathering" },
			{ "Hover", "In inventory: hover over an item + slot key 3–6" },
			{ "Drag", "Drag an item into a hotbar slot" },
			{ "RMB", "Clear a hotbar slot" },
			{ "Wheel", "Zoom the character in the inventory" },
			{ "Enter", "Skip the gacha (along with the assigned key)" },
			{ "Esc", "Close windows" },
		}
		for i, k in ipairs(fixed) do
			keyRow(c, 70 + i, k[1], k[2])
		end
	end
	-- ЗВУК
	local pct = function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end
	local sd = pages.sound
	slider(sd, 1, "master", "🔊", "Master Volume", "All game sounds", 0, 1, 0.05, pct)
	slider(sd, 2, "sfx", "💣", "Effects", "Explosions, hits, finds, gacha", 0, 1, 0.05, pct)
	slider(sd, 3, "ui", "🔘", "Interface", "Button and menu clicks", 0, 1, 0.05, pct)
	-- ИНТЕРФЕЙС
	local ui = pages.ui
	slider(ui, 1, "uiScale", "🔍", "Interface Size", "Make all windows bigger or smaller", 0.7, 1.3, 0.05, pct)
	toggle(ui, 3, "showDamage", "⚔️", "Damage Numbers", "Pop-up numbers above zombies")
	toggle(ui, 4, "toasts", "🔔", "Notifications", "Messages at the top of the screen (important ones always show)")
	-- сброс
	local reset = api.button({ Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C(70, 40, 40), Font = Enum.Font.GothamBlack, Text = "↺ RESET ALL SETTINGS", TextSize = 15, TextColor3 = C(255, 210, 200), LayoutOrder = 99, Parent = ui }, function()
		stopCapture()
		S.Values = table.clone(S.Defaults)
		Keybinds.Reset()
		S.Values.keys = Keybinds.Export()
		applyAll()
		save()
		for _, w in ipairs(widgets) do
			w.sync()
		end
	end)
	U.corner(12).Parent = reset
	-- ПРОМОКОДЫ
	local cp = pages.codes
	header(cp, 1, "ENTER PROMO CODE")
	local box = new("Frame", { Size = UDim2.new(1, -8, 0, 120), BackgroundColor3 = C(22, 26, 32), LayoutOrder = 2, Parent = cp }, { U.corner(14) })
	local bst = U.stroke(C(255, 200, 60), 2, 0.3)
	bst.Parent = box
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.lootCrate, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(52, 52), Parent = box })
	local input = new("TextBox", { Position = UDim2.fromOffset(78, 16), Size = UDim2.new(1, -96, 0, 48), BackgroundColor3 = C(12, 14, 18), Font = Enum.Font.GothamBlack, PlaceholderText = "For example: RELEASE", PlaceholderColor3 = C(100, 110, 120), Text = "", TextSize = 22, TextColor3 = C(255, 230, 150), ClearTextOnFocus = false, Parent = box }, { U.corner(10), U.stroke(C(60, 66, 76), 2) })
	local status = new("TextLabel", { Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -196, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Codes are posted on the game's social media", TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(160, 170, 180), Parent = box })
	local busy = false
	local function redeem()
		if busy then
			return
		end
		busy = true
		status.Text = "Checking…"
		status.TextColor3 = C(200, 200, 200)
		local ok, res = pcall(function()
			return Remotes.RedeemCode:InvokeServer(input.Text)
		end)
		busy = false
		if ok and res and res.ok then
			status.Text = res.msg
			status.TextColor3 = C(140, 255, 120)
			input.Text = ""
			U.play(U.Sounds.prize, 0.6, 1)
			if api.toast then
				api.toast(res.msg, "good")
			end
			-- радостная вспышка поля
			bst.Color = C(140, 255, 120)
			bst.Transparency = 0
			U.tween(bst, 0.8, { Transparency = 0.3, Color = C(255, 200, 60) })
		else
			status.Text = (ok and res and res.err) or "Network error, try again"
			status.TextColor3 = C(255, 120, 110)
			U.play(U.Sounds.error, 0.5, 0.7)
			-- поле «мотает головой»
			local p0 = input.Position
			for k = 1, 4 do
				U.tween(input, 0.04, { Position = p0 + UDim2.fromOffset(k % 2 == 0 and -8 or 8, 0) }).Completed:Wait()
			end
			input.Position = p0
		end
	end
	local go = api.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 72), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = C(255, 180, 40), Font = Enum.Font.GothamBlack, Text = "🎁 REDEEM", TextSize = 15, TextColor3 = C(40, 25, 0), Parent = box }, redeem)
	U.corner(12).Parent = go
	input.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
	selectTab("graphics")
end

function S.Toggle()
	if U.isOpen(win, scaleObj) then
		S.Close()
	else
		if api.closeOthers then
			api.closeOthers()
		end
		for _, w in ipairs(widgets) do
			w.sync()
		end
		api.openWindow(win, scaleObj)
	end
end

-- после любого переназначения: сохранить в профиль и обновить строки
function S.OnKeysChanged(id, swappedWith)
	S.Values.keys = Keybinds.Export()
	save()
	if swappedWith and api.toast then
		local a, b = Keybinds.ById[id], Keybinds.ById[swappedWith]
		api.toast(("“%s” is now on %s, “%s” on %s"):format(a.label, Keybinds.Name(Keybinds.Get(id)), b.label, Keybinds.Name(Keybinds.Get(swappedWith))), "good")
	end
end

function S.Close()
	stopCapture()
	if win then
		api.closeWindow(win, scaleObj)
	end
end

function S.Init(a)
	api = a
	build()
	local function onData(d)
		if loaded or not d then
			return
		end
		loaded = true
		-- на телефоне без сохранённых настроек начинаем со «Среднего»: без пост-эффектов, ближе дальность света
		if UIS.TouchEnabled and not UIS.KeyboardEnabled and not (d.settings and d.settings.preset) then
			S.Values.preset = "med"
			for k, v in pairs(PRESETS.med) do
				S.Values[k] = v
			end
		end
		for k, v in pairs(d.settings or {}) do
			if S.Defaults[k] ~= nil and typeof(v) == typeof(S.Defaults[k]) then
				S.Values[k] = v
			end
		end
		Keybinds.Load(S.Values.keys)
		S.Values.keys = Keybinds.Export()
		applyAll()
	end
	-- все строки клавиш следят за назначениями (в т.ч. после обмена местами)
	Keybinds.Changed:Connect(function()
		for _, r in ipairs(bindRows) do
			r.sync()
		end
	end)
	State.Changed:Connect(onData)
	if State.data then
		onData(State.data)
	else
		applyAll()
	end
	-- стандартная камера может сбросить FOV — держим выбранное
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if win.Visible and S.gearIcon then
			S.gearIcon.Rotation = (S.gearIcon.Rotation + dt * 30) % 360
		end
		acc += dt
		if acc > 1 then
			acc = 0
			local cam = workspace.CurrentCamera
			if cam and math.abs(cam.FieldOfView - S.Values.fov) > 0.5 and cam.CameraType == Enum.CameraType.Custom then
				U.tween(cam, 0.3, { FieldOfView = S.Values.fov })
			end
		end
	end)
end

return S
