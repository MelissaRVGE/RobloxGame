-- UI-утилиты, тема, звуки
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local U = {}
local C = Color3.fromRGB

U.Theme = {
	Bg = C(16, 20, 16),
	Panel = C(28, 34, 28),
	Panel2 = C(38, 46, 38),
	Accent = C(130, 230, 60),
	AccentDark = C(60, 120, 30),
	Hazard = C(255, 170, 30),
	Danger = C(235, 60, 50),
	Text = C(236, 242, 230),
	Muted = C(150, 162, 145),
	Battery = C(190, 255, 90),
	Gacha = C(190, 90, 255),
}

function U.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function U.corner(r)
	if typeof(r) == "UDim" then
		return U.new("UICorner", { CornerRadius = r })
	end
	return U.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function U.round()
	return U.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function U.stroke(color, thickness, transparency)
	return U.new("UIStroke", {
		Color = color or C(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function U.textStroke(color, thickness, transparency)
	return U.new("UIStroke", {
		Color = color or C(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function U.grad(c0, c1, rotation)
	return U.new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rotation or 90 })
end

function U.pad(px)
	return U.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function U.darken(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

function U.fmt(n)
	n = math.floor(n or 0)
	local abs = math.abs(n)
	if abs < 10000 then
		local s = tostring(n)
		local formatted = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
		return (formatted:gsub("^%s+", ""))
	end
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if abs >= u[1] then
			local v = n / u[1]
			local s = v >= 100 and tostring(math.floor(v)) or string.format("%.1f", math.floor(v * 10) / 10)
			s = s:gsub("%.0$", "")
			return s .. u[2]
		end
	end
	return tostring(n)
end

function U.tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ===== Плавность: все изменения интерфейса идут через твины, без резких скачков =====
local weakK = { __mode = "k" }

-- ===== Телефоны: окна всегда влезают в экран, мелкие кнопки получают большую зону касания =====
local UIS = game:GetService("UserInputService")

-- сенсорный экран без клавиатуры (телефон/планшет)
function U.isTouch()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

-- "press E" hints turn into "press the button" on phones (they have no keyboard)
function U.touchText(s)
	if typeof(s) ~= "string" or not UIS.TouchEnabled or UIS.KeyboardEnabled then
		return s
	end
	s = s:gsub("([Pp])ress E", "%1ress the button")
	return s
end

-- Наибольший масштаб окна (не больше target), при котором оно целиком помещается на своём ScreenGui
-- с учётом якоря и позиции. Окна, которые слишком велики для экрана телефона, ужимаются, а не обрезаются.
local FIT_MARGIN = 6
function U.fit(win, target)
	local root = win and win:FindFirstAncestorOfClass("ScreenGui")
	if not root or win.Parent ~= root then
		return target
	end
	local ps = root.AbsoluteSize
	if ps.X < 50 or ps.Y < 50 then
		return target
	end
	local w = win.Size.X.Scale * ps.X + win.Size.X.Offset
	local h = win.Size.Y.Scale * ps.Y + win.Size.Y.Offset
	local s = target
	local function axis(size, pos, ap, total)
		if size <= 1 then
			return
		end
		if ap > 0 then
			s = math.min(s, (pos - FIT_MARGIN) / (ap * size))
		end
		if ap < 1 then
			s = math.min(s, (total - FIT_MARGIN - pos) / ((1 - ap) * size))
		end
	end
	axis(w, win.Position.X.Scale * ps.X + win.Position.X.Offset, win.AnchorPoint.X, ps.X)
	axis(h, win.Position.Y.Scale * ps.Y + win.Position.Y.Offset, win.AnchorPoint.Y, ps.Y)
	return math.max(s, 0.2)
end

-- Невидимая зона касания вокруг маленькой кнопки (крестик окна): палец попадает, даже если кнопка мелкая.
function U.hitPad(b, onClick, grow)
	-- только на сенсорных экранах: мышью точно попадают и так, а наведение на кнопку должно работать
	if not b or not UIS.TouchEnabled or b:FindFirstChild("HitPad") then
		return
	end
	grow = grow or 0.8
	local pad = U.new("TextButton", {
		Name = "HitPad",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1 + grow, 1 + grow),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = b.ZIndex + 5,
		Parent = b,
	})
	pad.Activated:Connect(function()
		local sc = b:FindFirstChild("PressScale")
		if sc then
			U.tween(sc, 0.07, { Scale = 0.88 }).Completed:Connect(function()
				U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Elastic)
			end)
		end
		onClick()
	end)
	return pad
end

-- Плавное открытие окна: из точки с пружинкой. Если окно как раз закрывается, разворачивает анимацию обратно.
function U.openPanel(win, sc, target)
	local token = (sc:GetAttribute("AnimToken") or 0) + 1
	sc:SetAttribute("AnimToken", token)
	sc:SetAttribute("Animating", true)
	sc:SetAttribute("Closing", nil)
	target = U.fit(win, target)
	sc:SetAttribute("BaseScale", target)
	if not win.Visible then
		sc.Scale = target * 0.05
	end
	win.Visible = true
	U.tween(sc, 0.32, { Scale = target }, Enum.EasingStyle.Back)
	task.delay(0.33, function()
		if sc:GetAttribute("AnimToken") == token then
			sc:SetAttribute("Animating", nil)
		end
	end)
end

-- Плавное закрытие окна: сжимается в точку и только потом скрывается.
function U.closePanel(win, sc)
	if not win or not win.Visible then
		return
	end
	if not sc then
		win.Visible = false
		return
	end
	if sc:GetAttribute("Closing") then
		return
	end
	local token = (sc:GetAttribute("AnimToken") or 0) + 1
	sc:SetAttribute("AnimToken", token)
	sc:SetAttribute("Animating", true)
	sc:SetAttribute("Closing", true)
	local base = sc:GetAttribute("BaseScale") or sc.Scale
	U.tween(sc, 0.2, { Scale = base * 0.05 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.2, function()
		if sc:GetAttribute("AnimToken") ~= token then
			return -- окно успели открыть снова
		end
		win.Visible = false
		sc.Scale = base
		sc:SetAttribute("Animating", nil)
		sc:SetAttribute("Closing", nil)
	end)
end

-- окно открыто и не в процессе закрытия
function U.isOpen(win, sc)
	if not win or not win.Visible then
		return false
	end
	sc = sc or win:FindFirstChildOfClass("UIScale")
	return not (sc and sc:GetAttribute("Closing"))
end

-- Счётчик: число в тексте плавно «докручивается» до нового значения.
local counters = setmetatable({}, weakK)
function U.countTo(label, target, render, t)
	render = render or U.fmt
	local c = counters[label]
	if not c then
		c = { v = Instance.new("NumberValue"), target = target, render = render }
		c.v.Value = target
		c.v.Changed:Connect(function(x)
			label.Text = c.render(x)
		end)
		counters[label] = c
		label.Text = render(target)
		return
	end
	c.render = render
	if c.target == target then
		label.Text = render(c.v.Value)
		return
	end
	c.target = target
	if c.tw then
		c.tw:Cancel()
	end
	c.tw = TweenService:Create(c.v, TweenInfo.new(t or 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = target })
	c.tw:Play()
end

-- Плавная смена цветов UIGradient (двухцветный градиент).
local gradTweens = setmetatable({}, weakK)
function U.gradTo(grad, c0, c1, t)
	local prev = gradTweens[grad]
	if prev and prev.c0 == c0 and prev.c1 == c1 then
		return
	end
	local kp = grad.Color.Keypoints
	local s0, s1 = kp[1].Value, kp[#kp].Value
	if prev then
		prev.tw:Cancel()
		prev.v:Destroy()
		gradTweens[grad] = nil
	end
	if s0 == c0 and s1 == c1 then
		return
	end
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		grad.Color = ColorSequence.new(s0:Lerp(c0, a), s1:Lerp(c1, a))
	end)
	local tw = TweenService:Create(v, TweenInfo.new(t or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	gradTweens[grad] = { tw = tw, v = v, c0 = c0, c1 = c1 }
	tw.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and gradTweens[grad] and gradTweens[grad].tw == tw then
			gradTweens[grad] = nil
			v:Destroy()
		end
	end)
	tw:Play()
end

-- Короткий «пульс» размера: плавно вверх и пружинисто назад (без мгновенного скачка).
function U.pulseSize(inst, big, normal, tUp, tDown)
	U.tween(inst, tUp or 0.08, { Size = big }).Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			U.tween(inst, tDown or 0.3, { Size = normal }, Enum.EasingStyle.Back)
		end
	end)
end

-- Масштаб без «лесенки»: у Size и Position смещение в пикселях целое, поэтому покадровые
-- анимации размера идут через UIScale (дробный масштаб рисуется плавно).
function U.scaleOf(inst)
	local sc = inst:FindFirstChild("AnimScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "AnimScale"
		sc.Parent = inst
	end
	return sc
end

-- «Пульс» через масштаб: плавно вверх и пружинисто назад
function U.pulseScale(inst, peak, tUp, tDown)
	local sc = U.scaleOf(inst)
	U.tween(sc, tUp or 0.08, { Scale = peak }).Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			U.tween(sc, tDown or 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

-- Плавное появление/скрытие элемента вместе со всем содержимым (текст, картинки, рамки).
-- Исходная прозрачность запоминается при первом вызове, к ней элемент и возвращается.
local fadeBase = setmetatable({}, weakK)
local function captureFade(inst)
	local list = {}
	local function add(o)
		local b = {}
		if o:IsA("GuiObject") then
			b.BackgroundTransparency = o.BackgroundTransparency
		end
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			b.TextTransparency = o.TextTransparency
		elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
			b.ImageTransparency = o.ImageTransparency
		elseif o:IsA("UIStroke") then
			b.Transparency = o.Transparency
		end
		if next(b) then
			table.insert(list, { o, b })
		end
	end
	add(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		add(d)
	end
	return list
end

local function fadeTo(inst, k, t)
	local list = fadeBase[inst]
	if not list then
		list = captureFade(inst)
		fadeBase[inst] = list
	end
	for _, e in ipairs(list) do
		local o, base = e[1], e[2]
		if o.Parent then
			local props = {}
			for prop, b in pairs(base) do
				props[prop] = b + (1 - b) * k
			end
			if t then
				U.tween(o, t, props)
			else
				for prop, v in pairs(props) do
					o[prop] = v
				end
			end
		end
	end
end

function U.fadeVisible(inst, on, t)
	t = t or 0.2
	local token = (inst:GetAttribute("FadeToken") or 0) + 1
	inst:SetAttribute("FadeToken", token)
	if on then
		if not inst.Visible then
			fadeTo(inst, 1) -- старт из полной прозрачности
			inst.Visible = true
		elseif not inst:GetAttribute("FadingOut") then
			return -- уже показан
		end
		inst:SetAttribute("FadingOut", nil)
		fadeTo(inst, 0, t)
	elseif inst.Visible and not inst:GetAttribute("FadingOut") then
		inst:SetAttribute("FadingOut", true)
		fadeTo(inst, 1, t)
		task.delay(t, function()
			if inst:GetAttribute("FadeToken") == token then
				inst.Visible = false
				inst:SetAttribute("FadingOut", nil)
				fadeTo(inst, 0) -- вернуть исходную прозрачность, чтобы прямой показ тоже работал
			end
		end)
	end
end

-- Звуки (библиотека Roblox: APM Music, Pro Sound Effects и открытые UI-звуки)
U.Sounds = {
	-- интерфейс
	tick = "rbxassetid://82676714368656", -- короткий мягкий «тик»
	hover = "rbxassetid://92708987611847", -- наведение на кнопку
	click = "rbxassetid://17582213219", -- нажатие
	tap = "rbxassetid://3623733749", -- маленький тап (переключатели)
	open = "rbxassetid://9126228631", -- открытие окна (лёгкий свиш)
	pop = "rbxassetid://17582213219",
	coin = "rbxassetid://3416831713", -- покупка / награда
	chime = "rbxassetid://79130903404606", -- кристальный звон
	bling = "rbxassetid://4612374036",
	error = "rbxassetid://3623733749",
	-- мир и гача
	whoosh = "rbxassetid://9126229267",
	whooshRise = "rbxassetid://9125807267",
	thud = "rbxassetid://1837830314",
	boom = "rbxassetid://1837830640",
	deepBoom = "rbxassetid://1837830221",
	hit = "rbxassetid://1848298868", -- аниме-удар
	riser = "rbxassetid://9040281024", -- нарастание напряжения
	bigRiser = "rbxassetid://9048836344",
	charge = "rbxassetid://86487440907995", -- заряд энергии
	reveal = "rbxassetid://77566342592571", -- волшебный ревил
	sparkle = "rbxassetid://1847063040", -- фейские искры
	star = "rbxassetid://139330213484352",
	fanfare = "rbxassetid://73774648241042",
	prize = "rbxassetid://119620526223720",
	glock = "rbxassetid://72644163309528",
}

-- громкость из меню настроек
U.Volume = { master = 1, sfx = 1, ui = 1 }
local UI_SOUNDS = {}
for _, k in ipairs({ "tick", "hover", "click", "tap", "open", "error" }) do
	UI_SOUNDS[U.Sounds[k]] = true
end

-- чтобы первое нажатие не было тихим (звук ещё не загружен)
task.spawn(function()
	local list = {}
	for _, id in pairs(U.Sounds) do
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(list, s)
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

-- Анимация нажатия для любой кнопки: «прожим» (сжатие и пружинистый возврат),
-- волна от места клика, лёгкое увеличение при наведении. Повторный вызов безопасен.
function U.pressFx(b, opts)
	if not b or not b:IsA("GuiButton") or b:GetAttribute("ZSS_PressFx") then
		return
	end
	b:SetAttribute("ZSS_PressFx", true)
	opts = opts or {}
	local sc = b:FindFirstChild("PressScale") or U.new("UIScale", { Name = "PressScale", Scale = 1, Parent = b })
	local hovered = false
	b.MouseEnter:Connect(function()
		hovered = true
		U.tween(sc, 0.15, { Scale = opts.hover or 1.05 }, Enum.EasingStyle.Back)
		if opts.hoverSound ~= false then
			U.play(U.Sounds.hover, 0.18, 1.1)
		end
	end)
	b.MouseLeave:Connect(function()
		hovered = false
		U.tween(sc, 0.15, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		U.tween(sc, 0.07, { Scale = 0.9 })
	end)
	b.Activated:Connect(function(input)
		U.tween(sc, 0.07, { Scale = 0.88 }).Completed:Connect(function()
			U.tween(sc, 0.35, { Scale = hovered and (opts.hover or 1.05) or 1 }, Enum.EasingStyle.Elastic)
		end)
		-- волна
		if b.AbsoluteSize.X > 8 then
			local pos = input and input.Position and Vector2.new(input.Position.X, input.Position.Y) - b.AbsolutePosition or b.AbsoluteSize / 2
			if pos.X < 0 or pos.Y < 0 or pos.X > b.AbsoluteSize.X or pos.Y > b.AbsoluteSize.Y then
				pos = b.AbsoluteSize / 2
			end
			local holder = b:FindFirstChild("RippleClip")
			if not holder then
				holder = U.new("CanvasGroup", { Name = "RippleClip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = b.ZIndex + 3, Parent = b })
				local corner = b:FindFirstChildOfClass("UICorner")
				if corner then
					corner:Clone().Parent = holder
				end
			end
			local r = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y) * 2.2
			local dot = U.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = opts.color or Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = b.ZIndex + 3, Parent = holder }, { U.round() })
			U.tween(dot, 0.45, { Size = UDim2.fromOffset(r, r), BackgroundTransparency = 1 })
			Debris:AddItem(dot, 0.5)
		end
	end)
end

-- Один и тот же звук не накладывается сам на себя: не чаще раза в SFX_GAP секунд
-- и не больше SFX_MAX копий одновременно. Звук удаляется, как только доиграл,
-- а слишком длинный плавно глушится через SFX_LIFE секунд.
local SFX_GAP, SFX_MAX, SFX_LIFE = 0.045, 4, 12
local lastPlay, alive = {}, {}

-- плавно заглушить и удалить звук
function U.stopSound(s, fade)
	if not s or not s.Parent then
		return
	end
	fade = fade or 0.15
	if fade <= 0 then
		s:Destroy()
		return
	end
	TweenService:Create(s, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
	Debris:AddItem(s, fade + 0.05)
end

function U.play(id, volume, pitch)
	local cat = UI_SOUNDS[id] and U.Volume.ui or U.Volume.sfx
	local vol = (volume or 0.5) * U.Volume.master * cat
	if vol <= 0.001 then
		return nil
	end
	local now = os.clock()
	if now - (lastPlay[id] or 0) < SFX_GAP or (alive[id] or 0) >= SFX_MAX then
		return nil
	end
	lastPlay[id] = now
	alive[id] = (alive[id] or 0) + 1
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s.Destroying:Once(function()
		alive[id] = math.max(0, (alive[id] or 1) - 1)
	end)
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(SFX_LIFE, U.stopSound, s, 0.4)
	s:Play()
	return s
end

return U
