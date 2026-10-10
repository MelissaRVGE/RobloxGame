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

function U.play(id, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	local cat = UI_SOUNDS[id] and U.Volume.ui or U.Volume.sfx
	s.Volume = (volume or 0.5) * U.Volume.master * cat
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 5)
	return s
end

return U
