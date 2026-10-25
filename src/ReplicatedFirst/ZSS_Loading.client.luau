-- Zombie Swarm Simulator — экран загрузки.
-- Лежит в ReplicatedFirst, поэтому запускается раньше всего остального: убирает стандартную загрузку Roblox
-- и закрывает мир, пока карта подгружается частями (StreamingEnabled), грузятся картинки и приходят данные игрока.
-- Прогресс складывается из четырёх этапов, полоса только растёт и плавно догоняет цель; в конце всё плавно гаснет.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- картинки фона (обложка игры 1024x576); пустая строка = только процедурный фон
local ART = {
	normal = "rbxassetid://122545549564828",
	halloween = "rbxassetid://107246362184089",
}
local ICON_DRONE = "rbxassetid://86616950601909" -- Icons.drones
local ICON_RAYS = "rbxassetid://132056028348411" -- Icons.dn.rays
local TITLE_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local MIN_TIME = 2.5 -- не мелькать, даже если всё уже в кеше
local MAX_TIME = 45 -- что бы ни случилось, дальше игрок не ждёт
local SKIP_AFTER = 12

local C = Color3.fromRGB
local theme = {
	accent = C(120, 255, 90),
	accent2 = C(40, 200, 70),
	ember = { C(140, 255, 100), C(90, 220, 255), C(255, 230, 120) },
	bg = C(8, 14, 12),
	rays = C(90, 255, 120),
}
local HALLOWEEN_THEME = {
	accent = C(255, 170, 50),
	accent2 = C(235, 95, 20),
	ember = { C(255, 160, 50), C(255, 110, 30), C(190, 120, 255) },
	bg = C(16, 8, 22),
	rays = C(255, 140, 40),
}

local TIPS = {
	"Claim a Charging Station to launch your drone swarm.",
	"Bring Scrap to the Recycler to turn it into Batteries.",
	"A bigger swarm unlocks new fields and tougher zombies.",
	"Zombies drop twice as many items at night.",
	"Buff orbs on fields stack all the way up to x10.",
	"Spend Gems on drone pulls. Secret drones are out there!",
	"NPCs give quests that reward Gems and crafting Finds.",
	"Press Q to open your quest book.",
}
local HALLOWEEN_TIPS = {
	"Collect pumpkins on the fields for cauldron pulls.",
	"Beat the Pumpkin Colossus for a big pile of pumpkins.",
}

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, ch in ipairs(children or {}) do
		ch.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

-- ===== ПОСТРОЕНИЕ =====
local gui = new("ScreenGui", {
	Name = "ZSS_Loading",
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = pg,
})

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = theme.bg,
	BorderSizePixel = 0,
	Active = true, -- клики не проходят в мир под экраном
	Parent = gui,
})

-- процедурный фон: медленно вращающиеся лучи (виден, пока грузится картинка)
local rays = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(1.9, 1.9),
	SizeConstraint = Enum.SizeConstraint.RelativeXX,
	BackgroundTransparency = 1,
	Image = ICON_RAYS,
	ImageColor3 = theme.rays,
	ImageTransparency = 0.82,
	Parent = root,
})

-- обложка игры: появляется, когда загрузится, и медленно «наезжает» камерой
local art = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1.14, 1.14),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	ImageTransparency = 1,
	Parent = root,
})

-- затемнение сверху и снизу, чтобы текст читался на любой картинке
local shade = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C(0, 0, 0),
	BorderSizePixel = 0,
	Parent = root,
}, {
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.55, 0.8),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 0.08),
		}),
	}),
})

-- искры, поднимающиеся снизу
local emberLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = root })

-- заголовок
local titleBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromScale(0.86, 0.3),
	BackgroundTransparency = 1,
	Parent = root,
})
local titleScale = new("UIScale", { Scale = 0.7, Parent = titleBox })
local titleStroke = new("UIStroke", { Thickness = 4, Color = C(10, 20, 10), Transparency = 1 })
local title = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 0.62),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	Text = "ZOMBIE SWARM",
	TextScaled = true,
	TextColor3 = C(255, 255, 255),
	TextTransparency = 1,
	Parent = titleBox,
}, {
	titleStroke,
	new("UITextSizeConstraint", { MaxTextSize = 120 }),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.accent:Lerp(C(255, 255, 255), 0.45)),
			ColorSequenceKeypoint.new(0.55, theme.accent),
			ColorSequenceKeypoint.new(1, theme.accent2),
		}),
	}),
})
local subStroke = new("UIStroke", { Thickness = 3, Color = C(10, 10, 10), Transparency = 1 })
local subtitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromScale(0.6, 0.3),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	Text = "SIMULATOR",
	TextScaled = true,
	TextColor3 = C(255, 255, 255),
	TextTransparency = 1,
	Parent = titleBox,
}, { subStroke, new("UITextSizeConstraint", { MaxTextSize = 60 }) })

-- плашка события (показывается только на Хэллоуин)
local badge = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.36, 0),
	Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C(235, 95, 20),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	Text = "HALLOWEEN UPDATE!",
	TextSize = 20,
	TextColor3 = C(255, 255, 255),
	TextTransparency = 1,
	Visible = false,
	Parent = root,
}, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 3) }),
	new("UIStroke", { Thickness = 2, Color = C(60, 20, 0), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})

-- нижняя панель: статус, полоса, проценты, совет
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.new(0.56, 0, 0, 104),
	BackgroundTransparency = 1,
	Parent = root,
}, { new("UISizeConstraint", { MinSize = Vector2.new(280, 104), MaxSize = Vector2.new(640, 104) }) })

local drone = new("ImageLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(0, 14),
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	Image = ICON_DRONE,
	ImageTransparency = 1,
	Parent = panel,
})
local statusStroke = new("UIStroke", { Thickness = 2, Color = C(0, 0, 0), Transparency = 1 })
local status = new("TextLabel", {
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(1, -110, 0, 28),
	BackgroundTransparency = 1,
	FontFace = BODY_FONT,
	Text = "Connecting...",
	TextSize = 18,
	TextColor3 = C(255, 255, 255),
	TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = panel,
}, { statusStroke })
local pctStroke = new("UIStroke", { Thickness = 2, Color = C(0, 0, 0), Transparency = 1 })
local pct = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(70, 28),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	Text = "0%",
	TextSize = 24,
	TextColor3 = theme.accent,
	TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = panel,
}, { pctStroke })

local barStroke = new("UIStroke", { Thickness = 2, Color = C(0, 0, 0), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local bar = new("Frame", {
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundColor3 = C(14, 18, 16),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = panel,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), barStroke })
local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C(255, 255, 255),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = bar,
}, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.accent:Lerp(C(255, 255, 255), 0.35)),
			ColorSequenceKeypoint.new(0.5, theme.accent),
			ColorSequenceKeypoint.new(1, theme.accent2),
		}),
	}),
})
-- блик, бегущий по заполненной части
local sheen = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C(255, 255, 255),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = fill,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local sheenGrad = new("UIGradient", {
	Rotation = 20,
	Offset = Vector2.new(-1, 0),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = sheen,
})

local tipStroke = new("UIStroke", { Thickness = 1.5, Color = C(0, 0, 0), Transparency = 1 })
local tip = new("TextLabel", {
	Position = UDim2.fromOffset(0, 64),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
	Text = "",
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = C(225, 235, 225),
	TextTransparency = 1,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = panel,
}, { tipStroke })

local skipStroke = new("UIStroke", { Thickness = 2, Color = C(255, 255, 255), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local skip = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -34),
	Size = UDim2.fromOffset(96, 38),
	BackgroundColor3 = C(0, 0, 0),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	FontFace = TITLE_FONT,
	Text = "SKIP",
	TextSize = 20,
	TextColor3 = C(255, 255, 255),
	TextTransparency = 1,
	Visible = false,
	Parent = root,
}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), skipStroke })

-- ===== ПОДГОНКА ПОД ЭКРАН =====
local function fit()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local small = vp.Y < 500 or vp.X < 700
	titleStroke.Thickness = math.clamp(vp.Y / 150, 2, 7)
	subStroke.Thickness = math.clamp(vp.Y / 220, 1.5, 5)
	titleBox.Size = small and UDim2.fromScale(0.92, 0.34) or UDim2.fromScale(0.86, 0.3)
	panel.Size = UDim2.new(small and 0.8 or 0.56, 0, 0, 104)
	panel.Position = UDim2.new(0.5, 0, 1, small and -14 or -34)
	badge.Position = UDim2.new(0.5, 0, titleBox.Position.Y.Scale + titleBox.Size.Y.Scale * 0.5, 6)
	skip.Position = UDim2.new(1, small and -12 or -24, 1, small and -14 or -34)
	skip.Size = small and UDim2.fromOffset(78, 32) or UDim2.fromOffset(96, 38)
end
fit()
local camConn
local function hookCamera()
	if camConn then
		camConn:Disconnect()
	end
	local cam = workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		fit()
	end
end
hookCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

-- ===== ПОЯВЛЕНИЕ =====
local alive = true
local tipsList = table.clone(TIPS)

tween(titleScale, 0.9, { Scale = 1 }, Enum.EasingStyle.Back)
tween(title, 0.6, { TextTransparency = 0 })
tween(titleStroke, 0.6, { Transparency = 0 })
task.delay(0.25, function()
	tween(subtitle, 0.6, { TextTransparency = 0 })
	tween(subStroke, 0.6, { Transparency = 0 })
end)
task.delay(0.35, function()
	for _, inst in ipairs({ status, pct, tip }) do
		tween(inst, 0.5, { TextTransparency = 0 })
	end
	for _, s in ipairs({ statusStroke, pctStroke }) do
		tween(s, 0.5, { Transparency = 0.2 })
	end
	tween(tipStroke, 0.5, { Transparency = 0.5 })
	tween(drone, 0.5, { ImageTransparency = 0 })
	tween(bar, 0.5, { BackgroundTransparency = 0.25 })
	tween(barStroke, 0.5, { Transparency = 0.1 })
	tween(fill, 0.5, { BackgroundTransparency = 0 })
	tween(sheen, 0.5, { BackgroundTransparency = 0 })
end)

-- лучи вращаются, дрон покачивается — всё на одном RenderStepped, без рывков
local t0 = os.clock()
local stepConn = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	rays.Rotation = t * 6
	drone.Rotation = 8 * math.sin(t * 2.2)
	drone.Position = UDim2.fromOffset(0, 14 + 2.5 * math.sin(t * 3.1))
	sheenGrad.Offset = Vector2.new(((t * 0.55) % 1.6) * 2 - 1.3, 0)
end)

-- искры: каждая поднимается снизу вверх, покачиваясь, и гаснет; потом стартует заново
local function ember()
	local rnd = Random.new()
	local size = rnd:NextInteger(3, 7)
	local e = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = theme.ember[rnd:NextInteger(1, #theme.ember)],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = emberLayer,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	task.spawn(function()
		task.wait(rnd:NextNumber(0, 4))
		while alive do
			local x = rnd:NextNumber(0.02, 0.98)
			local dur = rnd:NextNumber(5, 9)
			e.BackgroundColor3 = theme.ember[rnd:NextInteger(1, #theme.ember)]
			e.Position = UDim2.fromScale(x, 1.03)
			e.BackgroundTransparency = 1
			tween(e, dur, { Position = UDim2.fromScale(x + rnd:NextNumber(-0.08, 0.08), rnd:NextNumber(0.25, 0.6)) }, Enum.EasingStyle.Sine)
			tween(e, dur * 0.3, { BackgroundTransparency = rnd:NextNumber(0.1, 0.4) }, Enum.EasingStyle.Sine)
			task.wait(dur * 0.55)
			if not alive then
				break
			end
			tween(e, dur * 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			task.wait(dur * 0.45 + rnd:NextNumber(0, 1.2))
		end
	end)
end
for _ = 1, 28 do
	ember()
end

-- советы сменяются с плавным затуханием
task.spawn(function()
	local i = math.random(1, #tipsList)
	tip.Text = "TIP: " .. tipsList[i]
	while alive do
		task.wait(4.5)
		if not alive then
			break
		end
		tween(tip, 0.35, { TextTransparency = 1 })
		tween(tipStroke, 0.35, { Transparency = 1 })
		task.wait(0.4)
		if not alive then
			break
		end
		i = i % #tipsList + 1
		tip.Text = "TIP: " .. tipsList[i]
		tween(tip, 0.45, { TextTransparency = 0 })
		tween(tipStroke, 0.45, { Transparency = 0.5 })
	end
end)

local statusText = status.Text
local function setStatus(text)
	if text == statusText then
		return
	end
	statusText = text
	tween(status, 0.15, { TextTransparency = 1 })
	task.delay(0.16, function()
		if statusText == text and alive then
			status.Text = text
			tween(status, 0.25, { TextTransparency = 0 })
		end
	end)
end

-- ===== ТЕМА И КАРТИНКА (ждём конфиг недолго, иначе обычная тема) =====
local function applyArt(id)
	if not id or id == "" or id == "rbxassetid://0" then
		return
	end
	art.Image = id
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ art })
		end)
		if alive then
			tween(art, 1.2, { ImageTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tween(art, 30, { Size = UDim2.fromScale(1.02, 1.02) }, Enum.EasingStyle.Sine)
		end
	end)
end

task.spawn(function()
	local halloween = false
	local zss = game:GetService("ReplicatedStorage"):WaitForChild("ZSS", 3)
	local cfgModule = zss and zss:WaitForChild("Config", 2)
	if cfgModule then
		local ok, cfg = pcall(require, cfgModule)
		halloween = ok and type(cfg) == "table" and cfg.Halloween and cfg.Halloween.enabled == true or false
	end
	if halloween and alive then
		for k, v in pairs(HALLOWEEN_THEME) do
			theme[k] = v
		end
		for _, t in ipairs(HALLOWEEN_TIPS) do
			table.insert(tipsList, math.random(1, #tipsList + 1), t)
		end
		-- плавно перекрашиваем то, что уже на экране
		tween(root, 0.8, { BackgroundColor3 = theme.bg })
		tween(rays, 0.8, { ImageColor3 = theme.rays })
		tween(pct, 0.8, { TextColor3 = theme.accent })
		local tg = title:FindFirstChildOfClass("UIGradient")
		tg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.accent:Lerp(C(255, 255, 255), 0.45)),
			ColorSequenceKeypoint.new(0.55, theme.accent),
			ColorSequenceKeypoint.new(1, theme.accent2),
		})
		fill:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.accent:Lerp(C(255, 255, 255), 0.35)),
			ColorSequenceKeypoint.new(0.5, theme.accent),
			ColorSequenceKeypoint.new(1, theme.accent2),
		})
		badge.Visible = true
		tween(badge, 0.6, { BackgroundTransparency = 0, TextTransparency = 0 })
		tween(badge:FindFirstChildOfClass("UIStroke"), 0.6, { Transparency = 0 })
	end
	applyArt(halloween and ART.halloween or ART.normal)
end)

-- ===== ПРОГРЕСС =====
-- этапы и их вес в полосе
local stage = { game = 0, assets = 0, world = 0, data = 0 }
local WEIGHT = { game = 0.15, assets = 0.2, world = 0.4, data = 0.25 }
local skipped = false

skip.MouseButton1Click:Connect(function()
	skipped = true
end)
skip.MouseEnter:Connect(function()
	tween(skip, 0.15, { BackgroundTransparency = 0.2 })
end)
skip.MouseLeave:Connect(function()
	tween(skip, 0.15, { BackgroundTransparency = 0.45 })
end)

-- 1) загрузка самой игры
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	stage.game = 1
end)

-- 2) очередь загрузки картинок, мешей и звуков
task.spawn(function()
	local peak = 1
	while alive and stage.assets < 1 do
		local q = ContentProvider.RequestQueueSize
		peak = math.max(peak, q)
		local f = 1 - q / peak
		if stage.game == 1 and q == 0 then
			f = 1
		end
		stage.assets = math.max(stage.assets, f)
		task.wait(0.1)
	end
end)

-- 3) карта вокруг игрока: персонаж появился, а новые детали карты перестали приходить
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	local count = 0
	local lastAdd = os.clock()
	if map then
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") then
				count += 1
			end
		end
		map.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				count += 1
				lastAdd = os.clock()
			end
		end)
	end
	while alive and stage.world < 1 do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local quiet = os.clock() - lastAdd
		-- пока детали идут, растём по количеству (асимптотически к 85%), затишье добирает остальное
		local f = 0.85 * (1 - math.exp(-count / 2500))
		if hrp and count > 50 then
			f = math.max(f, 0.85 + 0.15 * math.clamp(quiet / 1.2, 0, 1))
		end
		stage.world = math.max(stage.world, f)
		if hrp and (count > 50 and quiet >= 1.2 or not map) then
			stage.world = 1
		end
		task.wait(0.1)
	end
end)

-- 4) данные игрока и интерфейс: HUD собран, профиль пришёл, иконки HUD загружены
task.spawn(function()
	local hud = pg:WaitForChild("ZSS_HUD", MAX_TIME)
	stage.data = math.max(stage.data, 0.3)
	local t = os.clock()
	while alive and not player:GetAttribute("ZSS_DataReady") and os.clock() - t < 20 do
		task.wait(0.1)
	end
	stage.data = math.max(stage.data, 0.6)
	if hud and alive then
		local done = false
		task.delay(6, function()
			done = true
		end)
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ hud })
			end)
			done = true
		end)
		while alive and not done do
			task.wait(0.1)
		end
	end
	stage.data = 1
end)

local function target()
	local s = 0
	for k, w in pairs(WEIGHT) do
		s += w * math.clamp(stage[k], 0, 1)
	end
	return s
end

local function statusFor()
	if stage.game < 1 then
		return "Connecting to the server..."
	elseif stage.world < 0.85 then
		return "Loading the map..."
	elseif stage.assets < 1 then
		return "Loading textures and models..."
	elseif stage.world < 1 then
		return "Waking up the zombies..."
	elseif stage.data < 1 then
		return "Charging your drones..."
	end
	return "Ready!"
end

local shown = 0
local start = os.clock()
local skipShown = false
while true do
	local dt = task.wait()
	local goal = target()
	-- полоса догоняет цель плавно и никогда не идёт назад
	shown = math.min(1, shown + (goal - shown) * math.min(1, dt * 3.5))
	shown = math.max(shown, math.min(goal, shown + dt * 0.02))
	fill.Size = UDim2.fromScale(shown, 1)
	pct.Text = math.floor(shown * 100 + 0.001) .. "%"
	setStatus(statusFor())
	local elapsed = os.clock() - start
	if not skipShown and elapsed > SKIP_AFTER then
		skipShown = true
		skip.Visible = true
		tween(skip, 0.4, { BackgroundTransparency = 0.45, TextTransparency = 0 })
		tween(skipStroke, 0.4, { Transparency = 0.4 })
	end
	if (goal >= 0.999 and shown >= 0.985 and elapsed >= MIN_TIME) or skipped or elapsed > MAX_TIME then
		break
	end
end

-- ===== ЗАВЕРШЕНИЕ =====
setStatus("Ready!")
tween(fill, 0.3, { Size = UDim2.fromScale(1, 1) })
pct.Text = "100%"
task.wait(0.45)
player:SetAttribute("ZSS_LoadingDone", true)

-- всё содержимое гаснет, заголовок чуть приближается, затем уходит сам фон
tween(titleScale, 0.9, { Scale = 1.08 }, Enum.EasingStyle.Sine)
local FADE = 0.55
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		tween(d, FADE, { TextTransparency = 1, BackgroundTransparency = 1 })
	elseif d:IsA("ImageLabel") and d ~= art then
		tween(d, FADE, { ImageTransparency = 1 })
	elseif d:IsA("UIStroke") then
		tween(d, FADE, { Transparency = 1 })
	elseif d:IsA("Frame") and d ~= shade and d.BackgroundTransparency < 1 then
		tween(d, FADE, { BackgroundTransparency = 1 })
	end
end
task.wait(FADE * 0.6)
alive = false
tween(art, 0.9, { ImageTransparency = 1, Size = UDim2.fromScale(1.12, 1.12) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
tween(shade, 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
tween(root, 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
stepConn:Disconnect()
if camConn then
	camConn:Disconnect()
end
gui:Destroy()
