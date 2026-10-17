-- Анимация выбивания дронов (кинематографично, прямо у машины «Дрон-кузня»):
-- 1) камера плавно улетает к машине и облетает её, кольца раскручиваются, тесла-пилоны бьют молниями,
-- 2) из короны в стеклянную камеру опускается капсула, машина переливается цветами редкости,
-- 3) вспышка: лепестки капсулы раскрываются, столб света в небо, дрон всплывает к камере,
-- 4) карточка дрона с лучами и звёздами; для x10 — сетка переворачивающихся карт.
-- Если машины нет (например, игрок далеко), играется старая 2D-сцена с кейсом.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Builder = require(Shared.DroneBuilder)
local U = require(script.Parent.U)
local WorldFX = require(script.Parent.WorldFX)
local Icons = require(Shared.Icons)
local Lighting = game:GetService("Lighting")
local new = U.new
local C = Color3.fromRGB

local player = Players.LocalPlayer
local GA = {}
local playing = false
local ctx

function GA.IsPlaying()
	return playing
end

local function rinfo(rarity)
	return Config.Rarities[rarity]
end

-- ===== ТАЙМИНГ =====
local function speedK()
	return ctx.fast and 0.45 or 1
end

local function waitT(t)
	if ctx.skip then
		return
	end
	local t0 = os.clock()
	t *= speedK()
	while os.clock() - t0 < t do
		if ctx.skip then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function animate(dur, fn, style, dir)
	local c = ctx
	style = style or Enum.EasingStyle.Quad
	dir = dir or Enum.EasingDirection.Out
	dur = math.max(dur * speedK(), 1e-3)
	local t0 = os.clock()
	while true do
		local a = c.skip and 1 or math.clamp((os.clock() - t0) / dur, 0, 1)
		fn(TweenService:GetValue(a, style, dir), a)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function animateAsync(...)
	task.spawn(animate, ...)
end

local function waitClick(ignoreSkip)
	ctx.clicked = false
	while not ctx.clicked do
		if ctx.skip and not ignoreSkip then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function shake(amount)
	ctx.shakeAmp = math.max(ctx.shakeAmp, amount)
end

local function sfx(id, vol, pitch)
	if ctx.skip then
		return
	end
	local snd = U.play(id, vol, pitch)
	if snd then
		table.insert(ctx.sounds, snd)
	end
end

-- глушит всё, что гача уже запустила (пропуск или конец анимации)
local function stopSfx(fade)
	for _, snd in ipairs(ctx.sounds) do
		U.stopSound(snd, fade)
	end
	table.clear(ctx.sounds)
end

-- ===== ПОСТРОЕНИЕ ЭЛЕМЕНТОВ =====
local function makeRays(parent)
	local holder = new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	local rays = {}
	local N = 12
	for i = 1, N do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(i % 2 == 0 and 40 or 95, 2600),
			BackgroundColor3 = C(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = i * (180 / N),
			ZIndex = 1,
			Parent = holder,
		}, {
			new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.38, 0.85),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(0.62, 0.85),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		rays[i] = { f = ray, base = i * (180 / N) }
	end
	local obj = { holder = holder, rays = rays, alpha = 1, speed = 12 }
	function obj.setColor(c, rainbowOffset)
		for i, r in ipairs(rays) do
			r.f.BackgroundColor3 = rainbowOffset and Config.Rainbow(os.clock(), i * 0.08) or c
		end
	end
	function obj.fadeTo(target, dur)
		local from = obj.alpha
		animateAsync(dur, function(e)
			obj.alpha = from + (target - from) * e
			for _, r in ipairs(rays) do
				r.f.BackgroundTransparency = obj.alpha
			end
		end)
	end
	function obj.update(t)
		for i, r in ipairs(rays) do
			r.f.Rotation = r.base + t * obj.speed * (i % 2 == 0 and 1 or 0.7)
		end
	end
	return obj
end

local function makeCircle(parent, color, size, transparency, z, pos)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	}, { U.round() })
end

-- кольцевая ударная волна
local function pulseRing(color, from, to, dur, pos)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(from, from),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = ctx.fxLayer,
	}, { U.round() })
	local st = new("UIStroke", { Color = color, Thickness = 8, Transparency = 0, Parent = f })
	animateAsync(dur or 0.6, function(e)
		local s = from + (to - from) * e
		f.Size = UDim2.fromOffset(s, s)
		st.Transparency = e
		st.Thickness = 8 * (1 - e) + 1
	end)
	task.delay((dur or 0.6) + 0.1, function()
		f:Destroy()
	end)
end

-- 2D-частицы (обновляются в главном цикле)
local function uiBurst(color, count, origin, rainbow, power)
	local vp = workspace.CurrentCamera.ViewportSize
	origin = origin or Vector2.new(vp.X * 0.5, vp.Y * 0.45)
	for _ = 1, count do
		local sz = math.random(6, 16)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(sz, sz * (math.random() < 0.5 and 1 or 2.2)),
			BackgroundColor3 = rainbow and Color3.fromHSV(math.random(), 0.8, 1) or color,
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 8,
			Parent = ctx.fxLayer,
		})
		if math.random() < 0.4 then
			U.round().Parent = f
		end
		local ang = math.random() * math.pi * 2
		local spd = math.random(250, 900) * (power or 1)
		table.insert(ctx.particles, {
			f = f,
			x = origin.X,
			y = origin.Y,
			vx = math.cos(ang) * spd,
			vy = math.sin(ang) * spd - 250,
			life = math.random(80, 140) / 100,
			age = 0,
			rot = math.random(-500, 500),
		})
	end
end

local function flash(color, dur, from)
	ctx.flash.BackgroundColor3 = color
	ctx.flash.BackgroundTransparency = from or 0
	animateAsync(dur, function(e)
		ctx.flash.BackgroundTransparency = (from or 0) + (1 - (from or 0)) * e
	end)
end

-- ===== АНИМЕ-ЭФФЕКТЫ (2D поверх сцены) =====
-- радиальные «линии скорости», как в аниме: мерцают и стягиваются к центру
local function speedLines(color)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = ctx.fxLayer })
	local lines = {}
	for i = 1, 46 do
		local l = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = color or C(255, 255, 255), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 7, Parent = holder }, {
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0) }) }),
		})
		lines[i] = { f = l, a = (i / 46) * math.pi * 2 + math.random() * 0.1, ph = math.random() * 10 }
	end
	local obj = { k = 0, color = color }
	local conn = RunService.RenderStepped:Connect(function()
		local vp = workspace.CurrentCamera.ViewportSize
		local cx, cy = vp.X / 2, vp.Y * 0.45
		local R = math.max(vp.X, vp.Y) * 0.75
		local t = os.clock()
		for _, ln in ipairs(lines) do
			local on = math.sin(t * 23 + ln.ph * 7) > 0.15 - obj.k * 0.6
			local inner = R * (0.55 - obj.k * 0.25 + 0.08 * math.sin(t * 11 + ln.ph))
			local len = R - inner
			local ang = ln.a
			ln.f.Position = UDim2.fromOffset(cx + math.cos(ang) * inner, cy + math.sin(ang) * inner)
			ln.f.Size = UDim2.fromOffset(2 + obj.k * 4 + (ln.ph % 1) * 3, len)
			ln.f.Rotation = math.deg(ang) - 90
			ln.f.BackgroundTransparency = on and (1 - obj.k * 0.75) or 1
			if obj.color then
				ln.f.BackgroundColor3 = obj.color
			end
		end
	end)
	function obj.set(k, col)
		obj.k = math.clamp(k, 0, 1)
		if col then
			obj.color = col
		end
	end
	function obj.stop()
		conn:Disconnect()
		holder:Destroy()
	end
	table.insert(ctx.cleanupUI, obj.stop)
	return obj
end

-- «кадр удара»: на мгновение экран чёрный с белыми лучами, потом инверсия и вспышка цвета
local function impactFrame(color)
	if ctx.skip then
		return
	end
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BorderSizePixel = 0, ZIndex = 19, Parent = ctx.gui })
	local vp = workspace.CurrentCamera.ViewportSize
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2 + math.random() * 0.2
		new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(vp.X / 2, vp.Y * 0.45), Size = UDim2.fromOffset(math.random(6, 22), math.max(vp.X, vp.Y)), Rotation = math.deg(a), BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, ZIndex = 19, Parent = f }, {
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) }) }),
		})
	end
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	f.BackgroundColor3 = C(255, 255, 255)
	for _, c in ipairs(f:GetChildren()) do
		c.BackgroundColor3 = color or C(0, 0, 0)
	end
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	f:Destroy()
	flash(color or C(255, 255, 255), 0.6, 0)
end

-- бронированный кейс с дроном (3D внутри ViewportFrame)
local function buildCrate(vp)
	local m = Instance.new("Model")
	local function p(size, cf, color, mat, name, shape)
		local x = Instance.new("Part")
		x.Anchored = true
		x.Size = size
		x.CFrame = cf
		x.Color = color
		x.Material = mat or Enum.Material.SmoothPlastic
		x.Name = name or "P"
		if shape then
			x.Shape = shape
		end
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		x.Parent = m
		return x
	end
	local metal = C(62, 66, 72)
	local seamCol = C(130, 230, 60)
	p(Vector3.new(4, 2.6, 3), CFrame.new(0, -0.2, 0), metal, Enum.Material.DiamondPlate, "Body")
	p(Vector3.new(4.3, 0.6, 3.3), CFrame.new(0, 1.35, 0), C(82, 88, 96), Enum.Material.Metal, "Lid")
	p(Vector3.new(2.2, 0.35, 1.6), CFrame.new(0, 1.8, 0), C(50, 54, 60), Enum.Material.Metal, "Handle")
	p(Vector3.new(4.3, 0.4, 3.3), CFrame.new(0, -1.55, 0), C(36, 38, 42), Enum.Material.Metal, "Base")
	for i = 0, 7 do
		p(Vector3.new(0.5, 0.42, 0.05), CFrame.new(-1.75 + i * 0.5, -1.05, -1.53), i % 2 == 0 and C(255, 190, 20) or C(20, 20, 20), Enum.Material.SmoothPlastic, "Stripe")
	end
	local seams = {}
	local function seam(size, cf)
		table.insert(seams, p(size, cf, seamCol, Enum.Material.Neon, "Seam"))
	end
	seam(Vector3.new(4.05, 0.14, 0.06), CFrame.new(0, 1.0, -1.53))
	seam(Vector3.new(4.05, 0.14, 0.06), CFrame.new(0, 1.0, 1.53))
	seam(Vector3.new(0.06, 0.14, 3.05), CFrame.new(-2.03, 1.0, 0))
	seam(Vector3.new(0.06, 0.14, 3.05), CFrame.new(2.03, 1.0, 0))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			seam(Vector3.new(0.12, 2.4, 0.12), CFrame.new(sx * 2.0, -0.2, sz * 1.5))
		end
	end
	p(Vector3.new(0.12, 1.5, 1.5), CFrame.new(0, 0.05, -1.54) * CFrame.Angles(0, math.rad(90), 0), C(30, 30, 34), Enum.Material.Metal, "LockRing", Enum.PartType.Cylinder)
	seam(Vector3.new(0.14, 1.1, 1.1), CFrame.new(0, 0.05, -1.58) * CFrame.Angles(0, math.rad(90), 0))
	seams[#seams].Shape = Enum.PartType.Cylinder
	p(Vector3.new(0.16, 0.5, 0.5), CFrame.new(0, 0.05, -1.62) * CFrame.Angles(0, math.rad(90), 0), C(20, 20, 20), Enum.Material.Metal, "Keyhole", Enum.PartType.Cylinder)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			p(Vector3.new(0.22, 0.22, 0.22), CFrame.new(sx * 1.75, -0.2 + sy * 0.95, -1.55), C(140, 140, 150), Enum.Material.Metal, "Bolt", Enum.PartType.Ball)
		end
	end
	m.Parent = vp
	return m, seams
end

-- ===== СТАДИЯ 1: КЕЙС =====
local function crateSequence(maxOrder, topResult)
	local vp = new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 440),
		BackgroundTransparency = 1,
		Ambient = C(110, 110, 120),
		LightColor = C(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		ZIndex = 4,
		Parent = ctx.shake,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.CFrame = CFrame.lookAt(Vector3.new(3.6, 3.4, -9.5), Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	local crate, seams = buildCrate(vp)
	local glow = makeCircle(ctx.shake, C(130, 230, 60), 260, 1, 3, UDim2.fromScale(0.5, 0.45))

	local wob = { amp = 0, y = 14, yaw = math.rad(-12), rainbow = false, seamColor = C(130, 230, 60) }
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local a = math.rad(wob.amp)
		crate:PivotTo(CFrame.new(0, wob.y, 0) * CFrame.Angles(math.sin(t * 41) * a, wob.yaw + math.sin(t * 37) * a, math.sin(t * 53) * a))
		if wob.rainbow then
			for i, s in ipairs(seams) do
				s.Color = Config.Rainbow(t, i * 0.07)
			end
			glow.BackgroundColor3 = Config.Rainbow(t)
		end
	end)
	local function setSeam(c)
		wob.seamColor = c
		for _, s in ipairs(seams) do
			s.Color = c
		end
		glow.BackgroundColor3 = c
	end

	-- падение
	sfx(U.Sounds.whoosh, 0.6, 0.7)
	animate(0.65, function(e)
		wob.y = 14 * (1 - e)
	end, Enum.EasingStyle.Bounce)
	sfx(U.Sounds.thud, 0.9, 0.6)
	shake(12)
	uiBurst(C(120, 110, 90), 14, nil, false, 0.5)
	waitT(0.3)

	-- прокачка редкостей
	for k = 1, maxOrder do
		local key = Config.RarityOrder[k]
		local r = rinfo(key)
		if key == "Secret" then
			-- затемнение и «сердцебиение»
			wob.rainbow = false
			wob.amp = 0
			setSeam(C(0, 0, 0))
			glow.BackgroundTransparency = 1
			animate(0.45, function(e)
				ctx.dim.BackgroundTransparency = 1 - e * 0.85
			end)
			waitT(0.6)
			for beat = 1, 3 do
				setSeam(C(255, 20, 25))
				glow.BackgroundTransparency = 0.5
				ctx.dim.BackgroundColor3 = C(60, 0, 0)
				pulseRing(C(255, 20, 25), 200, 900, 0.5)
				sfx(U.Sounds.boom, 0.35 + beat * 0.15, 0.4)
				shake(10 + beat * 5)
				waitT(0.12)
				setSeam(C(70, 0, 0))
				glow.BackgroundTransparency = 0.85
				ctx.dim.BackgroundColor3 = C(0, 0, 0)
				waitT(0.42 - beat * 0.08)
			end
			ctx.glitch = true
			setSeam(C(255, 20, 25))
			glow.BackgroundTransparency = 0.4
			animateAsync(0.4, function(e)
				ctx.dim.BackgroundTransparency = 0.15 + e * 0.5
			end)
			wob.amp = 16
			ctx.shakeBase = 4
			waitT(0.9)
		else
			setSeam(r.color)
			wob.rainbow = r.rainbow == true
			glow.BackgroundTransparency = 0.75 - k * 0.07
			pulseRing(r.color, 180, 700 + k * 60, 0.55)
			sfx(U.Sounds.tick, 0.8, 0.7 + k * 0.18)
			ctx.bgTint = r.color
			wob.amp = 2 + k * 2.4
			shake(3 + k * 2.5)
			if k >= 2 then
				uiBurst(r.color, 6 + k * 3, nil, r.rainbow, 0.45)
			end
			waitT(k == 1 and 0.55 or 0.5 + k * 0.04)
		end
	end

	-- финальное напряжение
	wob.amp += 5
	animate(0.35, function(e)
		glow.Size = UDim2.fromOffset(260 + e * 140, 260 + e * 140)
	end)

	local topKey = Config.RarityOrder[maxOrder]
	local topCol = rinfo(topKey).color

	-- ===== КРЫШКА ОТКРЫВАЕТСЯ: столб света и дрон поднимается из кейса =====
	conn:Disconnect()
	local pivot = CFrame.new(0, 0, 0) * CFrame.Angles(0, wob.yaw, 0)
	crate:PivotTo(pivot)
	local hinge = pivot * CFrame.new(0, 1.35, 1.65)
	local lidParts = {}
	for _, part in ipairs(crate:GetChildren()) do
		if part:IsA("BasePart") and (part.Name == "Lid" or part.Name == "Handle" or (part.Name == "Seam" and part.Position.Y > 0.9 and part.Size.Y < 0.5)) then
			table.insert(lidParts, { p = part, rel = hinge:Inverse() * part.CFrame })
		end
	end
	-- замок щёлкает
	sfx(U.Sounds.tick, 1, 0.5)
	shake(6)
	waitT(0.15)
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.Material = Enum.Material.Neon
	beam.Color = topCol
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 0.25
	beam.Size = Vector3.new(0.1, 2.2, 2.2)
	beam.CFrame = pivot * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = vp
	local beam2 = beam:Clone()
	beam2.Transparency = 0.7
	beam2.Size = Vector3.new(0.1, 3.4, 3.4)
	beam2.Parent = vp
	local drone
	local ddef = topResult and Config.DroneById[topResult.id]
	if ddef then
		drone = Builder.Build(ddef, 0.75)
		drone:PivotTo(pivot * CFrame.new(0, -0.4, 0))
		drone.Parent = vp
	end
	sfx(U.Sounds.whoosh, 0.8, 0.5)
	pulseRing(topCol, 120, 900, 0.7)
	ctx.rays.setColor(topCol)
	ctx.rays.fadeTo(0.35, 0.5)
	animate(0.6, function(e)
		for _, lp in ipairs(lidParts) do
			lp.p.CFrame = hinge * CFrame.Angles(e * 1.95, 0, 0) * lp.rel
		end
		local h = 0.1 + e * 26
		beam.Size = Vector3.new(h, 2.2, 2.2)
		beam.CFrame = pivot * CFrame.new(0, 1 + h / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		beam2.Size = Vector3.new(h, 3.4, 3.4)
		beam2.CFrame = beam.CFrame
		cam.CFrame = CFrame.lookAt(Vector3.new(3.6, 3.4 + e * 1.6, -9.5 - e * 2), Vector3.new(0, e * 2.2, 0))
		glow.BackgroundTransparency = 0.6 - e * 0.25
	end, Enum.EasingStyle.Back)
	shake(10 + maxOrder * 2)
	uiBurst(topCol, 20 + maxOrder * 8, nil, topKey == "Mythic", 0.7)
	-- дрон всплывает и вращается в столбе света
	if drone then
		local t0 = os.clock()
		animate(1.0, function(e)
			local t = os.clock() - t0
			drone:PivotTo(pivot * CFrame.new(0, -0.4 + e * 3.6, 0) * CFrame.Angles(0, t * 6 * (1.2 - e), 0))
			beam.Transparency = 0.25 + math.sin(t * 30) * 0.08
		end, Enum.EasingStyle.Quart)
		sfx(U.Sounds.pop, 0.8, 0.7)
		waitT(0.25)
	end

	-- ВЗРЫВ
	if drone then
		drone:Destroy()
	end
	beam:Destroy()
	beam2:Destroy()
	flash(topKey == "Secret" and C(255, 40, 40) or C(255, 255, 255), 0.7)
	sfx(U.Sounds.boom, 0.9, maxOrder >= 5 and 0.7 or 1)
	shake(18 + maxOrder * 3)
	uiBurst(topCol, 40 + maxOrder * 14, nil, topKey == "Mythic", 1)
	glow:Destroy()
	local pieces = {}
	for _, part in ipairs(crate:GetChildren()) do
		if part:IsA("BasePart") then
			local dir = part.Position - crate:GetPivot().Position
			if dir.Magnitude < 0.1 then
				dir = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)
			end
			dir = (dir.Unit + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)).Unit
			table.insert(pieces, {
				p = part,
				cf = part.CFrame,
				v = dir * math.random(9, 18) + Vector3.new(0, 5, 0),
				w = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			})
		end
	end
	animateAsync(0.8, function(_, a)
		local t = a * 0.8
		for _, pc in ipairs(pieces) do
			local pos = pc.cf.Position + pc.v * t + Vector3.new(0, -14 * t * t, 0)
			pc.p.CFrame = CFrame.new(pos) * (pc.cf - pc.cf.Position) * CFrame.Angles(pc.w.X * t, pc.w.Y * t, pc.w.Z * t)
			pc.p.Transparency = a
		end
	end, Enum.EasingStyle.Linear)
	task.delay(1, function()
		vp:Destroy()
	end)
	ctx.shakeBase = 0
end

-- ===== СТАДИЯ 1 (новая): ДРОН-КУЗНЯ В 3D =====
local function lp(parent, props)
	local x = Instance.new(props.Class or "Part")
	props.Class = nil
	x.Anchored = true
	x.CanCollide = false
	x.CanQuery = false
	x.CanTouch = false
	x.CastShadow = false
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		x[k] = v
	end
	x.Parent = parent
	return x
end

-- капсула-«бутон»: светящееся ядро в корпусе из 6 металлических лепестков
local function buildPod(parent)
	local pod = { petals = {}, seams = {} }
	pod.core = lp(parent, { Name = "PodCore", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), Material = Enum.Material.Neon, Color = C(130, 230, 60) })
	pod.light = Instance.new("PointLight")
	pod.light.Range = 16
	pod.light.Brightness = 3
	pod.light.Parent = pod.core
	pod.base = lp(parent, { Name = "PodBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.6, 2.6), Material = Enum.Material.Metal, Color = C(60, 64, 76), Reflectance = 0.2 })
	pod.ring = lp(parent, { Name = "PodRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 2.8, 2.8), Material = Enum.Material.Neon, Color = C(130, 230, 60) })
	for i = 1, 6 do
		local petal = lp(parent, { Name = "Petal", Size = Vector3.new(1.25, 3.2, 0.22), Material = Enum.Material.Metal, Color = C(70, 76, 90), Reflectance = 0.25 })
		local seam = lp(parent, { Name = "PetalSeam", Size = Vector3.new(0.14, 2.9, 0.24), Material = Enum.Material.Neon, Color = C(130, 230, 60) })
		pod.petals[i] = { p = petal, s = seam, a = (i - 1) / 6 * math.pi * 2 }
		table.insert(pod.seams, seam)
	end
	pod.open = 0
	function pod.place(cf)
		pod.cf = cf
		pod.core.CFrame = cf * CFrame.new(0, 0.2, 0)
		pod.base.CFrame = cf * CFrame.new(0, -1.55, 0) * CFrame.Angles(0, 0, math.rad(90))
		pod.ring.CFrame = cf * CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(90))
		for _, pe in ipairs(pod.petals) do
			-- шарнир внизу лепестка; закрыт — наклонён внутрь, открыт — откинут наружу
			local tilt = math.rad(-17) + pod.open * math.rad(105)
			local hinge = cf * CFrame.Angles(0, pe.a, 0) * CFrame.new(0, -1.3, -1.05) * CFrame.Angles(tilt, 0, 0)
			pe.p.CFrame = hinge * CFrame.new(0, 1.6, 0)
			pe.s.CFrame = hinge * CFrame.new(0, 1.6, 0.05)
		end
	end
	function pod.setColor(c)
		pod.core.Color = c
		pod.light.Color = c
		pod.ring.Color = c
		for _, s in ipairs(pod.seams) do
			s.Color = c
		end
	end
	return pod
end

-- зигзаг-молния между двумя точками
local function zap(parent, a, b, color, width)
	local n = 7
	local prev = a
	local dir = b - a
	local side = dir:Cross(Vector3.new(0, 1, 0))
	if side.Magnitude < 0.01 then
		side = Vector3.new(1, 0, 0)
	end
	side = side.Unit
	local up = dir:Cross(side).Unit
	for i = 1, n do
		local t = i / n
		local p = a + dir * t
		if i < n then
			p += side * (math.random() - 0.5) * 2.2 + up * (math.random() - 0.5) * 2.2
		end
		local seg = lp(parent, { Name = "Zap", Size = Vector3.new(width or 0.18, width or 0.18, (p - prev).Magnitude), CFrame = CFrame.lookAt((prev + p) / 2, p), Material = Enum.Material.Neon, Color = color })
		task.delay(0.07 + math.random() * 0.05, function()
			seg:Destroy()
		end)
		prev = p
	end
end

local function forgeSequence(maxOrder, topResult)
	local map = workspace:FindFirstChild("Map")
	local zone = map and map:FindFirstChild("GachaZone")
	local cap = zone and zone:FindFirstChild("Capsule")
	local anchor = cap and cap:FindFirstChild("HoloAnchor")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not anchor or not hrp or (hrp.Position - anchor.Position).Magnitude > 80 then
		return false
	end
	local C0 = anchor.Position
	local cam = workspace.CurrentCamera
	local saved = { type = cam.CameraType, cf = cam.CFrame, fov = cam.FieldOfView }
	local fx = Instance.new("Folder")
	fx.Name = "ZSS_ForgeFX"
	fx.Parent = workspace

	-- всё светящееся на машине перекрашивается в цвет редкости (только у этого игрока)
	local glowParts = {}
	for _, p in ipairs(cap:GetDescendants()) do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.Name ~= "Button" and p.Name ~= "SpireTip" then
			table.insert(glowParts, { p = p, c = p.Color, tr = p.Transparency })
		end
	end
	local glass = cap:FindFirstChild("Glass", true)
	local glassSave = glass and { c = glass.Color, t = glass.Transparency }
	local teslas = {}
	for _, p in ipairs(cap:GetDescendants()) do
		if p.Name == "Tesla" then
			table.insert(teslas, p)
		end
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZSS_ForgeCC"
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloomSave = bloom and bloom.Intensity

	local function paint(c, k)
		for _, g in ipairs(glowParts) do
			if g.p.Parent then
				g.p.Color = g.c:Lerp(c, k or 1)
			end
		end
		if glass then
			glass.Color = glassSave.c:Lerp(c, (k or 1) * 0.6)
		end
	end

	-- камера: плавный вылет из текущего вида и медленный облёт
	local off = saved.cf.Position - C0
	local camS = { ang = math.atan2(off.Z, off.X), r = 34, h = 11, look = C0.Y + 1.5, fov = 52, blend = 0, orbit = 0.18, shake = 0 }
	cam.CameraType = Enum.CameraType.Scriptable
	local drive = RunService.RenderStepped:Connect(function(dt)
		camS.ang += dt * camS.orbit
		local pos = C0 + Vector3.new(math.cos(camS.ang) * camS.r, camS.h, math.sin(camS.ang) * camS.r)
		local target = CFrame.lookAt(pos, Vector3.new(C0.X, camS.look, C0.Z))
		if camS.shake > 0.02 then
			target *= CFrame.new((math.random() - 0.5) * camS.shake, (math.random() - 0.5) * camS.shake, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * camS.shake * 0.02)
			camS.shake *= math.exp(-dt * 6)
		end
		local k = camS.blend
		cam.CFrame = saved.cf:Lerp(target, k)
		cam.FieldOfView = saved.fov + (camS.fov - saved.fov) * k
	end)
	local function kick(a)
		camS.shake = math.max(camS.shake, a)
	end

	local arcsOn, arcColor = false, C(120, 230, 255)
	local pod, drone, pillar
	local cleaned = false
	ctx.cleanup = function(instant)
		if cleaned then
			return
		end
		cleaned = true
		arcsOn = false
		WorldFX.SpinBoost = 1
		WorldFX.ShowcaseHidden = false
		for _, g in ipairs(glowParts) do
			if g.p.Parent then
				g.p.Color = g.c
				g.p.Transparency = g.tr
			end
		end
		if glass then
			glass.Color = glassSave.c
			glass.Transparency = glassSave.t
		end
		if bloom then
			bloom.Intensity = bloomSave
		end
		cc:Destroy()
		fx:Destroy()
		drive:Disconnect()
		if instant then
			cam.CFrame = saved.cf
		else
			-- плавно вернуть камеру за спину игрока
			local from, f0 = cam.CFrame, cam.FieldOfView
			local t0 = os.clock()
			while true do
				local a = math.clamp((os.clock() - t0) / 0.55, 0, 1)
				local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				cam.CFrame = from:Lerp(saved.cf, e)
				cam.FieldOfView = f0 + (saved.fov - f0) * e
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end
		cam.FieldOfView = saved.fov
		cam.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
	end

	-- фоновые молнии от пилонов к камере с капсулой
	task.spawn(function()
		while not cleaned do
			if arcsOn and #teslas > 0 and not ctx.skip then
				local t = teslas[math.random(1, #teslas)]
				if t.Parent then
					local ang = math.random() * math.pi * 2
					local tgt = C0 + Vector3.new(math.cos(ang) * 4.6, (math.random() - 0.3) * 4, math.sin(ang) * 4.6)
					zap(fx, t.Position, tgt, arcColor, 0.16 + math.random() * 0.1)
				end
			end
			task.wait(0.05)
		end
	end)

	-- ударная волна по полу
	local function floorWave(c, maxR, dur)
		local ring = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 4, 4), CFrame = CFrame.new(C0.X, 0.7, C0.Z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = c, Transparency = 0.2 })
		animateAsync(dur or 0.7, function(e)
			local r = 4 + (maxR - 4) * e
			ring.Size = Vector3.new(0.15, r * 2, r * 2)
			ring.Transparency = 0.2 + 0.8 * e
		end)
		task.delay((dur or 0.7) + 0.1, function()
			ring:Destroy()
		end)
	end

	-- частицы в камере
	local emitPart = lp(fx, { Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(C0), Transparency = 1 })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.LightEmission = 1
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1.4)
	pe.Speed = NumberRange.new(6, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Drag = 3
	pe.Parent = emitPart
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.LightEmission = 1
	swirl.Rate = 0
	swirl.Lifetime = NumberRange.new(0.8, 1.2)
	swirl.Speed = NumberRange.new(1, 2)
	swirl.Acceleration = Vector3.new(0, 6, 0)
	swirl.SpreadAngle = Vector2.new(60, 60)
	swirl.Size = NumberSequence.new(0.5, 0)
	swirl.Parent = emitPart

	-- 1) вылет камеры
	WorldFX.ShowcaseHidden = true
	sfx(U.Sounds.whoosh, 0.6, 0.6)
	animate(1.0, function(e)
		camS.blend = e
	end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- 2) раскрутка машины
	arcsOn = true
	sfx(U.Sounds.whoosh, 0.8, 0.9)
	animateAsync(0.9, function(e)
		WorldFX.SpinBoost = 1 + e * 5
	end)
	swirl.Rate = 25

	-- 3) капсула опускается из короны
	pod = buildPod(fx)
	local podTop, podRest = C0.Y + 5.2, C0.Y - 2.6
	local spinA = 0
	local beam = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.2, 2.2), Material = Enum.Material.Neon, Color = C(160, 240, 255), Transparency = 0.45 })
	animate(0.9, function(e)
		spinA += 0.08
		local y = podTop + (podRest - podTop) * e
		pod.place(CFrame.new(C0.X, y, C0.Z) * CFrame.Angles(0, spinA, 0))
		local h = podTop + 1.5 - y
		beam.Size = Vector3.new(h, 2.2, 2.2)
		beam.CFrame = CFrame.new(C0.X, y + h / 2, C0.Z) * CFrame.Angles(0, 0, math.rad(90))
		camS.r = 34 - e * 4
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	beam:Destroy()
	sfx(U.Sounds.thud, 0.9, 0.7)
	kick(1.2)
	floorWave(C(160, 240, 255), 22, 0.6)

	-- 4) перебор редкостей (под нарастающий райзер и аниме-линии скорости)
	local lines = speedLines(C(255, 255, 255))
	if maxOrder >= 3 then
		sfx(maxOrder >= 5 and U.Sounds.bigRiser or U.Sounds.riser, 0.45, 1)
	end
	local podSpin = RunService.RenderStepped:Connect(function(dt)
		spinA += dt * (1.5 + WorldFX.SpinBoost * 0.6)
		if pod.core.Parent then
			pod.place(CFrame.new(C0.X, podRest + math.sin(os.clock() * 3) * 0.12, C0.Z) * CFrame.Angles(0, spinA, 0))
		end
	end)
	for k = 1, maxOrder do
		local key = Config.RarityOrder[k]
		local r = rinfo(key)
		if key == "Secret" then
			-- свет гаснет, три удара «сердца»
			arcsOn = false
			animate(0.5, function(e)
				cc.Brightness = -0.45 * e
				cc.Saturation = -0.6 * e
				paint(C(15, 0, 0), e)
				WorldFX.SpinBoost = 6 * (1 - e) + 0.3
			end)
			pod.setColor(C(40, 0, 0))
			swirl.Rate = 0
			waitT(0.5)
			for beat = 1, 3 do
				pod.setColor(C(255, 20, 30))
				paint(C(255, 20, 30), 1)
				cc.TintColor = C(255, 170, 170)
				floorWave(C(255, 20, 30), 18 + beat * 6, 0.45)
				sfx(U.Sounds.boom, 0.35 + beat * 0.15, 0.4)
				kick(0.8 + beat * 0.5)
				waitT(0.12)
				pod.setColor(C(60, 0, 0))
				paint(C(40, 0, 0), 1)
				cc.TintColor = C(255, 255, 255)
				waitT(0.42 - beat * 0.08)
			end
			ctx.glitch = true
			arcColor = C(255, 30, 40)
			arcsOn = true
			pod.setColor(C(255, 20, 30))
			paint(C(255, 20, 30), 1)
			animateAsync(0.4, function(e)
				cc.Brightness = -0.45 + e * 0.35
				WorldFX.SpinBoost = 0.3 + e * 12
			end)
			kick(2.5)
			waitT(0.8)
		else
			local col = r.color
			arcColor = col:Lerp(C(255, 255, 255), 0.35)
			pe.Color = ColorSequence.new(col)
			swirl.Color = ColorSequence.new(col)
			pod.setColor(col)
			animateAsync(0.25, function(e)
				paint(col, e)
			end)
			if r.rainbow then
				ctx.forgeRainbow = { paint = paint, pod = pod }
			end
			floorWave(col, 16 + k * 3, 0.55)
			pe:Emit(8 + k * 6)
			sfx(U.Sounds.glock, 0.55, 0.8 + k * 0.12)
			lines.set(0.12 + k * 0.13, col:Lerp(C(255, 255, 255), 0.5))
			-- «толчок» поля зрения на каждой ступени
			local f0 = camS.fov
			animateAsync(0.35, function(e)
				camS.fov = f0 + math.sin(e * math.pi) * -6
			end)
			WorldFX.SpinBoost = 4 + k * 2.2
			swirl.Rate = 20 + k * 12
			kick(0.4 + k * 0.35)
			animateAsync(0.5, function(e)
				camS.r = (30 - (k - 1) * 1.3) - e * 1.3
				camS.h = 11 - k * 0.6
			end, Enum.EasingStyle.Sine)
			camS.orbit = 0.18 + k * 0.08
			waitT(k == 1 and 0.6 or 0.5 + k * 0.05)
		end
	end

	-- финальное напряжение
	local topKey = Config.RarityOrder[maxOrder]
	local topCol = rinfo(topKey).color
	lines.set(1, topKey == "Secret" and C(255, 60, 60) or topCol:Lerp(C(255, 255, 255), 0.4))
	sfx(U.Sounds.whooshRise, 0.9, 1)
	animate(0.45, function(e)
		WorldFX.SpinBoost += 0.4
		camS.shake = math.max(camS.shake, e * 1.5)
		if bloom then
			bloom.Intensity = bloomSave + e * 1.2
		end
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- ===== ОСОБЫЕ СЦЕНЫ ПЕРЕД ВСПЫШКОЙ =====
	local special = {}
	if topKey == "Legendary" then
		-- «Золотой суд»: долли-зум, золотые молнии с неба, вращающиеся лучи и золотой дождь
		local GOLD = C(255, 200, 40)
		local f0, r0 = camS.fov, camS.r
		sfx(U.Sounds.charge, 0.7, 1)
		animate(0.8, function(e)
			-- камера отъезжает, а поле зрения сужается — фон «едет»
			camS.r = r0 + e * 12
			camS.fov = f0 - e * 22
			camS.orbit = 0.05
			cc.TintColor = C(255, 255, 255):Lerp(C(255, 225, 160), e)
		end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		-- вращающиеся золотые лучи вокруг машины
		local rays = {}
		for i = 1, 10 do
			rays[i] = lp(fx, { Size = Vector3.new(0.35, 0.35, 34), Material = Enum.Material.Neon, Color = GOLD, Transparency = 0.35 })
		end
		local rayA = 0
		local rayConn = RunService.RenderStepped:Connect(function(dt)
			rayA += dt * 1.8
			for i, r in ipairs(rays) do
				local a = rayA + i / #rays * math.pi * 2
				r.CFrame = CFrame.new(C0) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(25 + (i % 2) * 20), 0, 0) * CFrame.new(0, 0, -17)
			end
		end)
		-- золотой дождь из неба
		local sky = lp(fx, { Size = Vector3.new(36, 1, 36), CFrame = CFrame.new(C0.X, C0.Y + 28, C0.Z), Transparency = 1 })
		local coins = Instance.new("ParticleEmitter")
		coins.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		coins.Shape = Enum.ParticleEmitterShape.Box
		coins.EmissionDirection = Enum.NormalId.Bottom
		coins.Color = ColorSequence.new(C(255, 240, 150), C(255, 170, 30))
		coins.LightEmission = 1
		coins.Rate = 120
		coins.Lifetime = NumberRange.new(1.6, 2.4)
		coins.Speed = NumberRange.new(10, 16)
		coins.Size = NumberSequence.new(0.7, 0.2)
		coins.RotSpeed = NumberRange.new(-200, 200)
		coins.Parent = sky
		-- три золотые молнии с неба в корону машины + кольца, поднимающиеся вверх
		for i = 1, 3 do
			local from = C0 + Vector3.new((math.random() - 0.5) * 14, 60, (math.random() - 0.5) * 14)
			zap(fx, from, C0 + Vector3.new(0, 9, 0), GOLD, 0.8)
			zap(fx, from, C0 + Vector3.new(0, 9, 0), C(255, 255, 230), 0.3)
			flash(C(255, 220, 120), 0.3, 0.5)
			sfx(U.Sounds.hit, 0.6, 0.9 + i * 0.1)
			kick(1.5 + i * 0.5)
			local ring = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6, 6), CFrame = CFrame.new(C0.X, 1, C0.Z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = GOLD, Transparency = 0.2 })
			animateAsync(1, function(e)
				local s = 6 + e * 20
				ring.Size = Vector3.new(0.2, s, s)
				ring.CFrame = CFrame.new(C0.X, 1 + e * 18, C0.Z) * CFrame.Angles(0, 0, math.rad(90))
				ring.Transparency = 0.2 + 0.8 * e
			end, Enum.EasingStyle.Quad)
			pe.Color = ColorSequence.new(GOLD)
			pe:Emit(25)
			waitT(0.32)
		end
		lines.set(1, GOLD)
		-- резкий наезд обратно
		animate(0.25, function(e)
			camS.r = r0 + 12 - e * 14
			camS.fov = f0 - 22 + e * 28
		end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		table.insert(special, function()
			rayConn:Disconnect()
			coins.Rate = 40
			animateAsync(0.6, function(e)
				for _, r in ipairs(rays) do
					r.Transparency = 0.35 + 0.65 * e
					r.Size = Vector3.new(0.35 + e * 2, 0.35 + e * 2, 34)
				end
				camS.fov = f0 + 6 * (1 - e)
			end)
		end)
	elseif topKey == "Mythic" then
		-- «Радужное восхождение»: спираль камеры вверх, 6 радужных столбов, призматические осколки
		sfx(U.Sounds.whoosh, 1, 0.5)
		local shards = {}
		for i = 1, 28 do
			local s = lp(fx, { Class = "WedgePart", Size = Vector3.new(0.25, 1.1, 0.7), Material = Enum.Material.Neon, Color = Color3.fromHSV(i / 28, 0.8, 1), Transparency = 0.1 })
			shards[i] = { p = s, a = i / 28 * math.pi * 2, r = 7 + (i % 3) * 1.6, y = C0.Y - 3 + (i % 7) * 0.9, sp = 1.4 + (i % 4) * 0.35 }
		end
		local shardConn = RunService.RenderStepped:Connect(function(dt)
			for _, s in ipairs(shards) do
				s.a += dt * s.sp
				s.y += dt * 1.6
				if s.y > C0.Y + 9 then
					s.y -= 12
				end
				s.p.CFrame = CFrame.new(C0.X + math.cos(s.a) * s.r, s.y, C0.Z + math.sin(s.a) * s.r) * CFrame.Angles(s.a * 2, s.a, s.a * 3)
				s.p.Color = Config.Rainbow(os.clock(), s.a * 0.05)
			end
		end)
		table.insert(special, function()
			-- осколки разлетаются наружу и тают
			shardConn:Disconnect()
			local starts = {}
			for i, s in ipairs(shards) do
				starts[i] = s.p.CFrame
			end
			animateAsync(0.7, function(e)
				for i, s in ipairs(shards) do
					local out = Vector3.new(math.cos(s.a), 0.3, math.sin(s.a)) * e * 14
					s.p.CFrame = starts[i] + out
					s.p.Transparency = 0.1 + 0.9 * e
				end
			end, Enum.EasingStyle.Quad)
		end)
		local ang0 = camS.ang
		animateAsync(2.4, function(e)
			camS.h = 11 + e * 9
			camS.r = 27 - e * 3
			camS.look = C0.Y + 1.5 + e * 2
			cc.Saturation = e * 0.45
			cc.TintColor = Config.Rainbow(os.clock()):Lerp(C(255, 255, 255), 0.75)
		end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		camS.orbit = 0.9
		local _ = ang0
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local col = Color3.fromHSV((i - 1) / 6, 0.85, 1)
			local base = Vector3.new(C0.X + math.cos(a) * 15, 0.5, C0.Z + math.sin(a) * 15)
			local col1 = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.2, 2.2), Material = Enum.Material.Neon, Color = col, Transparency = 0.15 })
			local col2 = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 4.4, 4.4), Material = Enum.Material.ForceField, Color = col, Transparency = 0.3 })
			animateAsync(0.5, function(e)
				local h = e * 70
				col1.Size = Vector3.new(h, 2.2, 2.2)
				col1.CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				col2.Size = Vector3.new(h, 4.4, 4.4)
				col2.CFrame = col1.CFrame
			end, Enum.EasingStyle.Quart)
			floorWave(col, 10, 0.5)
			sfx(U.Sounds.tick, 0.9, 0.9 + i * 0.15)
			kick(0.8)
			pe.Color = ColorSequence.new(col)
			pe:Emit(14)
			waitT(0.32)
			table.insert(special, function()
				animateAsync(0.8, function(e)
					col1.Transparency = 0.15 + 0.85 * e
					col2.Transparency = 0.3 + 0.7 * e
				end)
			end)
		end
		for k = 1, 7 do
			floorWave(Color3.fromHSV(k / 7, 0.8, 1), 14 + k * 4, 0.6)
			waitT(0.06)
		end
		waitT(0.3)
	elseif topKey == "Secret" then
		-- «Разлом измерений»: тьма, молнии с неба, чёрная дыра и трещины в полу
		animate(0.5, function(e)
			cc.Brightness = -0.1 - e * 0.45
			cc.Saturation = -0.3 - e * 0.4
			cc.TintColor = C(255, 255, 255):Lerp(C(255, 150, 150), e)
			camS.h = 11 - e * 4
			camS.r = 27 - e * 5
			camS.orbit = 0.08
		end)
		-- молнии с неба
		for i = 1, 5 do
			local from = C0 + Vector3.new((math.random() - 0.5) * 30, 70, (math.random() - 0.5) * 30)
			local to = i % 2 == 0 and (C0 + Vector3.new(0, 7, 0)) or Vector3.new(C0.X + (math.random() - 0.5) * 24, 0.6, C0.Z + (math.random() - 0.5) * 24)
			for _ = 1, 2 do
				zap(fx, from, to, C(255, 40, 50), 0.7)
				zap(fx, from, to, C(255, 230, 230), 0.25)
			end
			flash(C(255, 60, 60), 0.25, 0.55)
			sfx(U.Sounds.boom, 0.7, 0.45 + i * 0.05)
			kick(2 + i * 0.4)
			floorWave(C(255, 20, 30), 12, 0.4)
			waitT(0.22 + (5 - i) * 0.05)
		end
		-- трещины по полу
		local cracks = {}
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2 + math.random() * 0.3
			local prev = Vector3.new(C0.X + math.cos(a) * 12.6, 0.56, C0.Z + math.sin(a) * 12.6)
			local segs = {}
			for s = 1, 5 do
				a += (math.random() - 0.5) * 0.35
				local r = 12.6 + s * 3.4
				local p = Vector3.new(C0.X + math.cos(a) * r, 0.56, C0.Z + math.sin(a) * r)
				table.insert(segs, { a = prev, b = p })
				prev = p
			end
			table.insert(cracks, segs)
		end
		local crackParts = {}
		animateAsync(0.9, function(e)
			local n = math.floor(e * 5 + 0.5)
			for ci, segs in ipairs(cracks) do
				crackParts[ci] = crackParts[ci] or {}
				for s = 1, n do
					if not crackParts[ci][s] then
						local sg = segs[s]
						crackParts[ci][s] = lp(fx, { Size = Vector3.new(0.35 - s * 0.04, 0.08, (sg.b - sg.a).Magnitude + 0.2), CFrame = CFrame.lookAt((sg.a + sg.b) / 2, sg.b), Material = Enum.Material.Neon, Color = C(255, 30, 40) })
					end
				end
			end
		end, Enum.EasingStyle.Linear)
		sfx(U.Sounds.thud, 1, 0.4)
		-- чёрная дыра в камере
		local hole = lp(fx, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.new(C0), Material = Enum.Material.SmoothPlastic, Color = C(0, 0, 0) })
		local rim = lp(fx, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = CFrame.new(C0), Material = Enum.Material.ForceField, Color = C(255, 20, 40), Transparency = 0.1 })
		local disk = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(C0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = C(255, 40, 60), Transparency = 0.3 })
		local holeConn = RunService.RenderStepped:Connect(function()
			disk.CFrame = CFrame.new(C0) * CFrame.Angles(math.sin(os.clock() * 2) * 0.25, os.clock() * 4, math.rad(90))
		end)
		pe.Color = ColorSequence.new(C(255, 30, 40), C(20, 0, 0))
		animate(1.1, function(e)
			local s = 0.5 + e * 9
			hole.Size = Vector3.one * s
			rim.Size = Vector3.one * (s * 1.18)
			disk.Size = Vector3.new(0.1, s * 2.2, s * 2.2)
			camS.shake = math.max(camS.shake, 0.6 + e * 1.4)
			if glass then
				glass.Transparency = glassSave.t + (1 - glassSave.t) * e
			end
		end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		pe:Emit(60)
		-- схлопывание
		sfx(U.Sounds.whoosh, 1, 0.3)
		animate(0.35, function(e)
			local s = 9.5 * (1 - e) + 0.2
			hole.Size = Vector3.one * s
			rim.Size = Vector3.one * (s * 1.18)
			disk.Size = Vector3.new(0.1, s * 2.6, s * 2.6)
			cc.Brightness = -0.55 - e * 0.3
		end, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		holeConn:Disconnect()
		hole:Destroy()
		rim:Destroy()
		disk:Destroy()
		cc.Brightness = 0.25
		table.insert(special, function()
			animateAsync(1.2, function(e)
				cc.Brightness = 0.25 - e * 0.25
				cc.Saturation = -0.7 + e * 0.5
				for _, segs in ipairs(crackParts) do
					for _, p in ipairs(segs) do
						p.Transparency = e
					end
				end
			end)
		end)
	end

	-- 5) ВСПЫШКА: капсула раскрывается, столб света, дрон всплывает
	for _, f in ipairs(special) do
		f()
	end
	arcsOn = false
	lines.stop()
	sfx(U.Sounds.hit, 0.9, maxOrder >= 5 and 0.85 or 1)
	sfx(U.Sounds.deepBoom, 0.7, 1)
	if maxOrder >= 3 then
		impactFrame(topKey == "Secret" and C(255, 40, 40) or topCol)
	else
		flash(C(255, 255, 255), 0.8)
	end
	kick(3 + maxOrder * 0.6)
	floorWave(topCol, 40, 0.9)
	floorWave(C(255, 255, 255), 28, 0.6)
	pe:Emit(70 + maxOrder * 25)
	if glass then
		animateAsync(0.5, function(e)
			glass.Transparency = glassSave.t + (1 - glassSave.t) * e * 0.85
		end)
	end
	pillar = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 3.2, 3.2), CFrame = CFrame.new(C0.X, C0.Y + 38, C0.Z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = topCol, Transparency = 0.15 })
	local pillarOuter = lp(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 6, 6), CFrame = pillar.CFrame, Material = Enum.Material.Neon, Color = topCol, Transparency = 0.7 })
	animateAsync(1.4, function(e)
		pillar.Transparency = 0.15 + 0.85 * e
		pillarOuter.Transparency = 0.7 + 0.3 * e
		local w = 3.2 * (1 - e * 0.7)
		pillar.Size = Vector3.new(80, w, w)
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	animateAsync(0.55, function(e)
		pod.open = e
	end, Enum.EasingStyle.Back)
	local ddef = topResult and Config.DroneById[topResult.id]
	if ddef then
		drone = Builder.Build(ddef, 1.5)
		drone.Parent = fx
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 0.8
		hl.FillColor = topCol
		hl.OutlineColor = topCol
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = drone
		local t0 = os.clock()
		sfx(U.Sounds.reveal, 0.8, 1)
		if maxOrder >= 4 then
			sfx(U.Sounds.sparkle, 0.5, 1)
		end
		animate(1.1, function(e)
			local t = os.clock() - t0
			drone:PivotTo(CFrame.new(C0.X, podRest + 0.4 + e * 3.4, C0.Z) * CFrame.Angles(0, t * 7 * (1.25 - e) + camS.ang, 0))
			camS.r = 25 - e * 8
			camS.h = 8 - e * 2
			camS.look = C0.Y + 1.5 + e * 0.6
			camS.fov = 52 - e * 6
			camS.orbit = 0.5 * (1 - e) + 0.12
			WorldFX.SpinBoost = math.max(1, WorldFX.SpinBoost * 0.97)
		end, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		-- послесловие для особых редкостей
		local extraHold = 0
		if topKey == "Legendary" then
			extraHold = 0.9
			sfx(U.Sounds.fanfare, 0.6, 1)
			-- золотая корона-кольцо вокруг дрона и искры
			local crown = Instance.new("Model")
			crown.Parent = fx
			for i = 0, 15 do
				local a = i / 16 * math.pi * 2
				lp(crown, { Class = "WedgePart", Size = Vector3.new(0.25, i % 2 == 0 and 0.9 or 0.5, 0.5), CFrame = CFrame.new(math.cos(a) * 3, 0, math.sin(a) * 3) * CFrame.Angles(0, -a + math.pi / 2, 0), Material = Enum.Material.Neon, Color = C(255, 205, 60) })
			end
			crown.WorldPivot = CFrame.new()
			local cConn = RunService.RenderStepped:Connect(function()
				if drone.Parent then
					crown:PivotTo(CFrame.new(drone:GetPivot().Position + Vector3.new(0, 1.6 + math.sin(os.clock() * 3) * 0.2, 0)) * CFrame.Angles(0, os.clock() * 1.6, 0))
				end
			end)
			task.delay(4, function()
				cConn:Disconnect()
			end)
		elseif topKey == "Mythic" then
			extraHold = 1.1
			-- радужный звёздный дождь и нимб над дроном
			local sky = lp(fx, { Size = Vector3.new(40, 1, 40), CFrame = CFrame.new(C0.X, C0.Y + 26, C0.Z), Transparency = 1 })
			local rain = Instance.new("ParticleEmitter")
			rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			rain.Shape = Enum.ParticleEmitterShape.Box
			rain.EmissionDirection = Enum.NormalId.Bottom
			rain.Color = Config.RainbowSequence
			rain.LightEmission = 1
			rain.Rate = 160
			rain.Lifetime = NumberRange.new(2, 3)
			rain.Speed = NumberRange.new(8, 14)
			rain.Size = NumberSequence.new(0.6, 0.1)
			rain.RotSpeed = NumberRange.new(-180, 180)
			rain.Parent = sky
			local halo = Instance.new("Model")
			halo.Parent = fx
			for i = 0, 23 do
				local a = i / 24 * math.pi * 2
				lp(halo, { Size = Vector3.new(0.6, 0.18, 0.18), CFrame = CFrame.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0), Material = Enum.Material.Neon, Color = Color3.fromHSV(i / 24, 0.8, 1) })
			end
			halo.WorldPivot = CFrame.new()
			local hc = RunService.RenderStepped:Connect(function()
				if drone.Parent then
					halo:PivotTo(CFrame.new(drone:GetPivot().Position + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0.25, os.clock() * 3, 0))
				end
			end)
			task.delay(4, function()
				hc:Disconnect()
			end)
			sfx(U.Sounds.pop, 0.9, 1.6)
		elseif topKey == "Secret" then
			extraHold = 1.2
			-- красные осколки на орбите дрона и тлеющие искры
			local ring = {}
			for i = 1, 14 do
				local s = lp(fx, { Class = "WedgePart", Size = Vector3.new(0.3, 1.4, 0.9), Material = Enum.Material.Slate, Color = C(25, 10, 12) })
				local e = lp(fx, { Size = Vector3.new(0.32, 1.42, 0.08), Material = Enum.Material.Neon, Color = C(255, 20, 40) })
				ring[i] = { s = s, e = e, a = i / 14 * math.pi * 2, y = (i % 3 - 1) * 0.8 }
			end
			local emb = lp(fx, { Size = Vector3.new(30, 1, 30), CFrame = CFrame.new(C0.X, 1, C0.Z), Transparency = 1 })
			local em = Instance.new("ParticleEmitter")
			em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			em.Shape = Enum.ParticleEmitterShape.Box
			em.EmissionDirection = Enum.NormalId.Top
			em.Color = ColorSequence.new(C(255, 40, 40), C(80, 0, 0))
			em.LightEmission = 1
			em.Rate = 90
			em.Lifetime = NumberRange.new(1.5, 2.5)
			em.Speed = NumberRange.new(2, 5)
			em.Size = NumberSequence.new(0.35, 0)
			em.Parent = emb
			local rc = RunService.RenderStepped:Connect(function()
				local t = os.clock()
				if not drone.Parent then
					return
				end
				local c = drone:GetPivot().Position
				for _, r in ipairs(ring) do
					local a = r.a + t * 1.6
					local cf = CFrame.new(c + Vector3.new(math.cos(a) * 4.2, r.y + math.sin(t * 3 + r.a) * 0.3, math.sin(a) * 4.2)) * CFrame.Angles(t + r.a, a, 0)
					r.s.CFrame = cf
					r.e.CFrame = cf * CFrame.new(0, 0, 0.46)
				end
			end)
			task.delay(4, function()
				rc:Disconnect()
			end)
			sfx(U.Sounds.boom, 0.6, 0.35)
		end
		-- коротко любуемся дроном
		local hold = os.clock()
		local holdConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if drone.Parent then
				drone:PivotTo(CFrame.new(C0.X, podRest + 3.8 + math.sin(t * 2) * 0.15, C0.Z) * CFrame.Angles(0, t * 1.2, 0))
			end
		end)
		waitT(0.7 + extraHold)
		holdConn:Disconnect()
		local _ = hold
	else
		waitT(0.8)
	end
	podSpin:Disconnect()
	ctx.forgeRainbow = nil
	if bloom then
		bloom.Intensity = bloomSave
	end
	ctx.shakeBase = 0
	return true
end

-- баннер-«удар» перед карточкой для MYTHIC / SECRET
-- «кат-ин» как в аниме-гачах: диагональная полоса врывается с края экрана, в ней чёрный силуэт дрона,
-- огромная надпись редкости и линии скорости; затем силуэт «наливается» цветом и полоса улетает
local function cutIn(r)
	if ctx.skip or not r then
		return
	end
	local rar = rinfo(r.rarity)
	local col = rar.color
	local order = rar.order
	local secret = r.rarity == "Secret"
	local def = Config.DroneById[r.id]
	local vpSize = workspace.CurrentCamera.ViewportSize
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 16, Parent = ctx.gui })
	local dimF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 16, Parent = holder })
	local bandH = math.clamp(vpSize.Y * 0.34, 170, 280)
	local band = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(-1, 0, 0.47, 0),
		Size = UDim2.new(1.7, 0, 0, bandH),
		Rotation = -9,
		BackgroundTransparency = 1,
		ZIndex = 17,
		Parent = holder,
	})
	-- фон полосы отдельным слоем, чтобы градиент не перекрашивал текст и линии
	local bandBg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, ZIndex = 17, Parent = band })
	local grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col:Lerp(C(255, 255, 255), 0.25)), ColorSequenceKeypoint.new(0.5, col), ColorSequenceKeypoint.new(1, col:Lerp(C(0, 0, 0), 0.6)) }), Parent = bandBg })
	if secret then
		grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(60, 0, 8)), ColorSequenceKeypoint.new(0.5, C(150, 10, 25)), ColorSequenceKeypoint.new(1, C(20, 0, 4)) })
	elseif rar.rainbow then
		grad.Color = Config.RainbowSequence
		grad.Rotation = 0
	end
	-- каёмки полосы
	for _, y in ipairs({ 0, 1 }) do
		new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = secret and C(255, 40, 50) or C(255, 255, 255), BorderSizePixel = 0, ZIndex = 21, Parent = band })
	end
	-- бегущие диагональные полосы и горизонтальные линии скорости
	local stripes = {}
	for i = 1, 14 do
		stripes[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / 14, 0.5), Size = UDim2.new(0, 26, 1, 0), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 18, Parent = band })
	end
	local lines = {}
	for i = 1, 18 do
		lines[i] = { f = new("Frame", { Position = UDim2.fromScale(math.random(), math.random() * 0.9 + 0.05), Size = UDim2.new(math.random(10, 35) / 100, 0, 0, math.random(2, 5)), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 19, Parent = band }), sp = math.random(18, 40) / 10 }
	end
	-- силуэт дрона (ViewportFrame с чёрным тоном)
	local vp = new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.42, 0, 0.5, 0),
		Size = UDim2.fromOffset(bandH * 1.35, bandH * 1.35),
		BackgroundTransparency = 1,
		ImageColor3 = C(0, 0, 0),
		Ambient = C(170, 170, 170),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 20,
		Parent = band,
	})
	local model
	if def then
		model = Builder.Build(def, 1)
		Builder.SetupViewport(vp, model, 0, math.rad(14), 1.0)
	end
	local baseCf = model and model:GetPivot()
	-- гигантская надпись редкости и подпись
	local big = new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1.2, 0, 0.44, 0),
		Size = UDim2.new(0, 900, 0, bandH * 0.42),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = rar.label:upper() .. "!",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C(255, 255, 255),
		ZIndex = 21,
		Parent = band,
	}, { U.textStroke(secret and C(0, 0, 0) or col:Lerp(C(0, 0, 0), 0.65), 6) })
	local sub = new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1.2, 0, 0.72, 0),
		Size = UDim2.new(0, 520, 0, bandH * 0.16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = secret and "☠ ОНО ВЫРВАЛОСЬ НАРУЖУ ☠" or ("★"):rep(order) .. "  НОВЫЙ ДРОН!",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = secret and C(255, 90, 100) or C(255, 250, 225),
		ZIndex = 21,
		Parent = band,
	}, { U.textStroke(C(0, 0, 0), 3) })
	local alive = true
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt)
		if not alive then
			return
		end
		local t = os.clock() - t0
		for i, s in ipairs(stripes) do
			s.Position = UDim2.fromScale(((i / 14) + t * 0.55) % 1.1 - 0.05, 0.5)
		end
		for _, l in ipairs(lines) do
			local x = l.f.Position.X.Scale - dt * l.sp
			if x < -0.4 then
				x = 1.05
			end
			l.f.Position = UDim2.fromScale(x, l.f.Position.Y.Scale)
		end
		if model and baseCf then
			model:PivotTo(baseCf * CFrame.Angles(0, t * 1.8, 0))
		end
		if rar.rainbow then
			grad.Offset = Vector2.new(math.sin(t * 2) * 0.3, 0)
		end
	end)
	table.insert(ctx.cleanupUI, function()
		alive = false
		conn:Disconnect()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	-- 1) влёт полосы
	sfx(U.Sounds.whoosh, 0.9, 0.85)
	animateAsync(0.2, function(e)
		dimF.BackgroundTransparency = 1 - e * 0.55
	end)
	animate(0.26, function(e)
		band.Position = UDim2.new(-1 + e * 1.5, 0, 0.47, 0)
	end, Enum.EasingStyle.Back)
	sfx(U.Sounds.hit, 0.8, 1.1)
	shake(10)
	animateAsync(0.32, function(e)
		big.Position = UDim2.new(1.2 - e * 0.62, 0, 0.44, 0)
	end, Enum.EasingStyle.Back)
	waitT(0.12)
	animateAsync(0.32, function(e)
		sub.Position = UDim2.new(1.2 - e * 0.62, 0, 0.72, 0)
	end, Enum.EasingStyle.Quart)
	waitT(0.55)
	-- 2) силуэт наливается цветом (у секретного — остаётся тёмным с алым отсветом)
	sfx(U.Sounds.sparkle, 0.6, 1.1)
	flash(C(255, 255, 255), 0.35, 0.35)
	animate(0.3, function(e)
		vp.ImageColor3 = secret and C(0, 0, 0):Lerp(C(255, 60, 70), e * 0.45) or C(0, 0, 0):Lerp(C(255, 255, 255), e)
		vp.Size = UDim2.fromOffset(bandH * (1.35 + 0.12 * math.sin(e * math.pi)), bandH * (1.35 + 0.12 * math.sin(e * math.pi)))
	end)
	waitT(0.5 + (order >= 5 and 0.25 or 0))
	-- 3) полоса улетает вправо
	sfx(U.Sounds.whooshRise, 0.6, 1.2)
	animateAsync(0.22, function(e)
		dimF.BackgroundTransparency = 0.45 + e * 0.55
	end)
	animate(0.24, function(e)
		band.Position = UDim2.new(0.5 + e * 1.6, 0, 0.47, 0)
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	alive = false
	conn:Disconnect()
	holder:Destroy()
end

local function bannerSlam(rarity)
	local secret = rarity == "Secret"
	local legend = rarity == "Legendary"
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12, Parent = ctx.shake })
	local band = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1.4, 0, 0, 0),
		Rotation = -4,
		BackgroundColor3 = secret and C(20, 0, 0) or C(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = holder,
	})
	local grad, goldGrad
	if secret then
		new("UIStroke", { Color = C(255, 20, 40), Thickness = 4, Parent = band })
	elseif legend then
		band.BackgroundColor3 = C(255, 255, 255)
		goldGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(150, 90, 10)), ColorSequenceKeypoint.new(0.45, C(255, 200, 50)), ColorSequenceKeypoint.new(0.5, C(255, 250, 210)), ColorSequenceKeypoint.new(0.55, C(255, 200, 50)), ColorSequenceKeypoint.new(1, C(150, 90, 10)) }), Parent = band })
		new("UIStroke", { Color = C(255, 240, 180), Thickness = 3, Parent = band })
	else
		grad = new("UIGradient", { Color = Config.RainbowSequence, Parent = band })
	end
	local txt = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(1000, 120),
		Rotation = -4,
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = secret and "☠ СЕКРЕТНЫЙ ДРОН ☠" or (legend and "★ ЛЕГЕНДАРНЫЙ ДРОН ★" or "✦ МИФИЧЕСКИЙ ДРОН ✦"),
		TextSize = 220,
		TextTransparency = 1,
		TextColor3 = secret and C(255, 40, 50) or (legend and C(255, 250, 225) or C(255, 255, 255)),
		ZIndex = 13,
		Parent = holder,
	}, { U.textStroke(secret and C(0, 0, 0) or (legend and C(90, 45, 0) or C(40, 10, 60)), 6) })
	-- свои звуки баннера: не повторяют фанфару и удар из 3D-сцены
	sfx(U.Sounds.thud, 0.9, secret and 0.6 or 0.9)
	if legend then
		sfx(U.Sounds.prize, 0.6, 1)
	elseif secret then
		sfx(U.Sounds.boom, 0.6, 0.5)
	else
		sfx(U.Sounds.bling, 0.6, 1)
	end
	shake(secret and 22 or 14)
	flash(secret and C(255, 30, 30) or (legend and C(255, 220, 120) or C(255, 255, 255)), 0.5, 0.3)
	uiBurst(secret and C(255, 30, 40) or (legend and C(255, 200, 50) or C(255, 255, 255)), 70, nil, not secret and not legend, 1.3)
	animate(0.35, function(e)
		txt.TextSize = 220 - 150 * e
		txt.TextTransparency = 1 - e
		band.Size = UDim2.new(1.4, 0, 0, 130 * e)
		band.BackgroundTransparency = (secret or legend) and 0.15 or (0.55 - e * 0.15)
	end, Enum.EasingStyle.Back)
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if goldGrad then
			goldGrad.Offset = Vector2.new((t * 1.2) % 2 - 1, 0)
		elseif grad then
			grad.Offset = Vector2.new((t * 0.8) % 2 - 1, 0)
			txt.TextColor3 = Config.Rainbow(os.clock()):Lerp(C(255, 255, 255), 0.35)
		else
			local on = math.random() < 0.3
			txt.Position = UDim2.new(0.5, on and math.random(-14, 14) or 0, 0.45, on and math.random(-5, 5) or 0)
			txt.TextColor3 = on and C(0, 255, 255) or C(255, 40, 50)
		end
	end)
	waitT(1.15)
	animate(0.3, function(e)
		txt.TextTransparency = e
		band.Size = UDim2.new(1.4, 0, 0, 130 * (1 - e))
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	conn:Disconnect()
	holder:Destroy()
end

-- ===== СТАДИЯ 2: РЕВИЛ ДРОНА =====
-- живой фон вокруг дрона: магический круг с рунами, светящийся постамент с волнами,
-- всплывающие искры, лучи прожекторов, конфетти (легендарный+) или тлеющие угли (секретный)
local function kp(t, v)
	return NumberSequenceKeypoint.new(t, v)
end

local function revealAmbient(layer, col, rar, order, secret, opts)
	opts = opts or {}
	local amb = { stars = nil }
	local rainbow = rar.rainbow
	local center = opts.center or UDim2.fromScale(0.5, 0.42)
	local function tint(t, k)
		return rainbow and Config.Rainbow(t, k or 0) or col
	end

	-- магический круг
	local circle, inner, hex
	local paintList = {}
	if not opts.noCircle and order >= 2 then
		circle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 3, Parent = layer })
		for i, k in ipairs({ 1, 0.86, 0.6 }) do
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k, k), BackgroundTransparency = 1, ZIndex = 3, Parent = circle }, { U.round() })
			table.insert(paintList, new("UIStroke", { Color = col, Thickness = i == 1 and 3 or 2, Transparency = 0.25 + i * 0.12, Parent = f }))
		end
		inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.93, 0.93), BackgroundTransparency = 1, ZIndex = 3, Parent = circle })
		local N = 24
		for i = 1, N do
			local a = i / N * math.pi * 2
			local big = i % 3 == 0
			table.insert(paintList, new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5), Size = UDim2.fromOffset(big and 13 or 6, big and 13 or 6), Rotation = math.deg(a) + 45, BackgroundColor3 = col, BackgroundTransparency = big and 0.05 or 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = inner }))
		end
		-- шестиконечная звезда внутри круга
		hex = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1, ZIndex = 3, Parent = circle })
		for i = 0, 5 do
			local a1 = i / 6 * math.pi * 2 - math.pi / 2
			local a2 = (i + 2) / 6 * math.pi * 2 - math.pi / 2
			local p1 = Vector2.new(math.cos(a1), math.sin(a1)) * 0.5
			local p2 = Vector2.new(math.cos(a2), math.sin(a2)) * 0.5
			local mid = (p1 + p2) / 2
			table.insert(paintList, new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + mid.X, 0.5 + mid.Y), Size = UDim2.new((p2 - p1).Magnitude, 0, 0, 2), Rotation = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X)), BackgroundColor3 = col, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3, Parent = hex }))
		end
		local target = 470 + order * 22
		animateAsync(0.6, function(e)
			circle.Size = UDim2.fromOffset(target * e, target * e)
		end, Enum.EasingStyle.Back)
	end

	-- постамент под дроном
	local ped
	if not opts.noPedestal then
		ped = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center + UDim2.fromOffset(0, 128), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = col, ImageTransparency = 0.1, ZIndex = 3, Parent = layer })
		animateAsync(0.45, function(e)
			ped.Size = UDim2.fromOffset(420 * e, 90 * e)
		end, Enum.EasingStyle.Back)
	end
	local function ring(w0, h0, w1, h1, dur, thick, color)
		if not ped or not layer.Parent then
			return
		end
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = ped.Position, Size = UDim2.fromOffset(w0, h0), BackgroundTransparency = 1, ZIndex = 3, Parent = layer }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local st = new("UIStroke", { Color = color or col, Thickness = thick, Parent = f })
		animateAsync(dur, function(e)
			f.Size = UDim2.fromOffset(w0 + (w1 - w0) * e, h0 + (h1 - h0) * e)
			st.Transparency = e
		end, Enum.EasingStyle.Quart)
		task.delay(dur + 0.05, function()
			f:Destroy()
		end)
	end
	-- удар при приземлении дрона
	function amb.landRing()
		ring(200, 40, 700, 130, 0.7, 6, C(255, 255, 255))
		ring(240, 48, 560, 104, 0.9, 4)
		if ped then
			local ap = ped.AbsolutePosition + ped.AbsoluteSize / 2
			uiBurst(col, 14 + order * 3, Vector2.new(ap.X, ap.Y), rainbow, 0.45)
			ped.ImageTransparency = 0
			animateAsync(0.6, function(e)
				ped.ImageTransparency = e * 0.25
			end)
		end
	end

	-- диагональные лучи прожекторов (редкие дроны)
	local beams = {}
	if order >= 3 and not opts.noBeams then
		for i, sx in ipairs({ -1, 1 }) do
			beams[i] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5 + sx * 0.2, 0, 0.15, 0),
				Size = UDim2.new(0, 170, 1.3, 0),
				Rotation = sx * -24,
				BackgroundColor3 = col:Lerp(C(255, 255, 255), 0.55),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = layer,
			}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(0.45, 0.55), kp(0.7, 0.85), kp(1, 1) }) }) })
		end
	end

	-- частицы
	local sparks, confetti = {}, {}
	local nextSpark, nextConf, nextRing = 0, 0, os.clock() + 0.8
	local sparkRate = 3 + order * 2.5
	local confRate = secret and 22 or (order >= 4 and 16 or 0)
	local GOLD = { C(255, 215, 60), C(255, 250, 220), C(255, 160, 40), C(255, 235, 140) }
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt)
		if not layer.Parent then
			return
		end
		local t = os.clock()
		-- круг вращается, звезда навстречу
		if circle then
			circle.Rotation = (t - t0) * 9
			inner.Rotation = -(t - t0) * 24
			hex.Rotation = -(t - t0) * 14
			if rainbow then
				for k, o in ipairs(paintList) do
					local c2 = Config.Rainbow(t, k * 0.03)
					if o:IsA("UIStroke") then
						o.Color = c2
					else
						o.BackgroundColor3 = c2
					end
				end
			end
		end
		if ped then
			if rainbow then
				ped.ImageColor3 = Config.Rainbow(t)
			end
			if t >= nextRing then
				nextRing = t + math.max(0.55, 1.2 - order * 0.1)
				ring(260, 50, 470, 90, 1.1, 3, tint(t))
			end
		end
		for i, b in ipairs(beams) do
			b.BackgroundTransparency = 0.55 + 0.25 * math.sin(t * 1.6 + i * 2)
			if rainbow then
				b.BackgroundColor3 = Config.Rainbow(t, i * 0.3):Lerp(C(255, 255, 255), 0.4)
			end
		end
		-- звёзды редкости переливаются бегущей волной
		if amb.stars then
			for i, s in ipairs(amb.stars) do
				if s.Parent then
					local w = math.max(0, math.sin(t * 3 - i * 0.7)) ^ 4
					s.TextColor3 = tint(t, i * 0.15):Lerp(C(255, 255, 255), w * 0.8)
					s.Rotation = math.sin(t * 2 + i) * 8
				end
			end
		end
		-- всплывающие искры
		if t >= nextSpark then
			nextSpark = t + 1 / sparkRate
			local a = math.random() * math.pi * 2
			local r = math.random(130, 280)
			local sz = math.random(10, 26)
			local f = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = (rainbow and Color3.fromHSV(math.random(), 0.7, 1) or col):Lerp(C(255, 255, 255), 0.35), ImageTransparency = 1, Size = UDim2.fromOffset(sz, sz), ZIndex = 5, Parent = layer })
			table.insert(sparks, { f = f, x = math.cos(a) * r, y = math.sin(a) * r * 0.8, vy = -math.random(40, 95), life = math.random(12, 20) / 10, age = 0, rot = math.random(-120, 120), sz = sz })
		end
		for i = #sparks, 1, -1 do
			local s = sparks[i]
			s.age += dt
			if s.age >= s.life then
				s.f:Destroy()
				table.remove(sparks, i)
			else
				s.y += s.vy * dt
				local a = math.sin(math.pi * s.age / s.life)
				s.f.Position = center + UDim2.fromOffset(s.x, s.y)
				s.f.ImageTransparency = 1 - a * 0.95
				s.f.Size = UDim2.fromOffset(s.sz * (0.5 + 0.5 * a), s.sz * (0.5 + 0.5 * a))
				s.f.Rotation += s.rot * dt
			end
		end
		-- конфетти сверху / угли снизу для секретного
		if confRate > 0 and t >= nextConf then
			nextConf = t + 1 / confRate
			if secret then
				local sz = math.random(4, 9)
				local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = math.random() < 0.6 and C(255, 40, 40) or C(255, 140, 40), BorderSizePixel = 0, ZIndex = 5, Parent = layer }, { U.round() })
				table.insert(confetti, { f = f, x = math.random(), y = 1.05, vy = -math.random(15, 32) / 100, ph = math.random() * 6, ember = true, age = 0 })
			else
				local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 14), BackgroundColor3 = rainbow and Color3.fromHSV(math.random(), 0.75, 1) or GOLD[math.random(#GOLD)], BorderSizePixel = 0, ZIndex = 5, Parent = layer })
				table.insert(confetti, { f = f, x = math.random(), y = -0.05, vy = math.random(20, 36) / 100, ph = math.random() * 6, spin = math.random(-300, 300), age = 0 })
			end
		end
		for i = #confetti, 1, -1 do
			local c = confetti[i]
			c.age += dt
			c.y += c.vy * dt
			if c.y > 1.1 or c.y < -0.1 then
				c.f:Destroy()
				table.remove(confetti, i)
			else
				local sway = math.sin(t * 2.2 + c.ph) * 0.015
				c.f.Position = UDim2.fromScale(c.x + sway, c.y)
				if c.ember then
					c.f.BackgroundTransparency = 0.2 + 0.6 * (1 - c.y)
				else
					c.f.Rotation += c.spin * dt
					c.f.Size = UDim2.fromOffset(1 + 8 * math.abs(math.cos(t * 6 + c.ph)), 14)
				end
			end
		end
	end)
	function amb.stop()
		conn:Disconnect()
	end
	table.insert(ctx.cleanupUI, amb.stop)
	ctx.revealStops = ctx.revealStops or {}
	table.insert(ctx.revealStops, amb.stop)
	for _, b in ipairs(beams) do
		animateAsync(0.6, function(e)
			b.BackgroundTransparency = 1 - e * 0.45
		end)
	end
	return amb
end

local function clearReveal()
	for _, f in ipairs(ctx.revealStops or {}) do
		pcall(f)
	end
	ctx.revealStops = {}
	if ctx.revealLayer then
		ctx.revealLayer:Destroy()
		ctx.revealLayer = nil
	end
	ctx.spin = nil
	ctx.rainbowMode = false
	ctx.glitch = false
	ctx.glitchLabels = nil
	ctx.sparkle = nil
	ctx.shakeBase = 0
end

local function reveal(r, final)
	clearReveal()
	local def = Config.DroneById[r.id]
	local rar = rinfo(r.rarity)
	local order = rar.order
	local col = rar.color
	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = ctx.shake })
	ctx.revealLayer = layer
	ctx.bgTint = col

	-- свечение
	local glows = {}
	for i, cfg in ipairs({ { 620, 0.92 }, { 470, 0.86 }, { 340, 0.78 }, { 230, 0.68 } }) do
		local g = makeCircle(layer, col, 0, 1, 2)
		glows[i] = { f = g, size = cfg[1], tr = cfg[2] }
		animateAsync(0.5 + i * 0.05, function(e)
			g.Size = UDim2.fromOffset(cfg[1] * e, cfg[1] * e)
			g.BackgroundTransparency = 1 - (1 - cfg[2]) * e
		end, Enum.EasingStyle.Back)
	end
	ctx.glows = glows
	local amb = revealAmbient(layer, col, rar, order, r.rarity == "Secret")

	-- лучи
	ctx.rays.setColor(col)
	ctx.rays.speed = 10 + order * 4
	ctx.rays.fadeTo(order >= 3 and 0.1 or 0.45, 0.5)

	-- дрон
	local vp = new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Ambient = C(150, 150, 150),
		LightColor = C(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 4,
		Parent = layer,
	})
	local model = Builder.Build(def, 1)
	Builder.SetupViewport(vp, model, 0, math.rad(14), 1.05)
	ctx.spin = { model = model, base = model:GetPivot(), rainbow = rar.rainbow, secret = r.rarity == "Secret" }

	-- тексты
	local rarityLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.715),
		Size = UDim2.fromOffset(900, 90),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = rar.label,
		TextSize = 76,
		TextColor3 = C(255, 255, 255),
		TextTransparency = 1,
		ZIndex = 7,
		Parent = layer,
	}, { U.textStroke(U.darken(col, 0.25), 5) })
	local rgrad = new("UIGradient", {
		Color = rar.rainbow and Config.RainbowSequence or ColorSequence.new(C(255, 255, 255), col),
		Rotation = 90,
		Parent = rarityLbl,
	})
	ctx.rarityGrad = rgrad

	-- лента под именем дрона
	local ribbon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.795),
		Size = UDim2.fromOffset(0, 54),
		BackgroundColor3 = C(255, 255, 255),
		ZIndex = 6,
		Parent = layer,
	}, { U.corner(14) })
	local ribGrad = new("UIGradient", { Color = rar.rainbow and Config.RainbowSequence or ColorSequence.new({ ColorSequenceKeypoint.new(0, U.darken(col, 0.75)), ColorSequenceKeypoint.new(0.5, U.darken(col, 0.4)), ColorSequenceKeypoint.new(1, U.darken(col, 0.75)) }), Parent = ribbon })
	if rar.rainbow then
		table.insert(ctx.rainbowGrads, ribGrad)
	end
	U.stroke(col:Lerp(C(255, 255, 255), 0.45), 2.5).Parent = ribbon
	for _, sx in ipairs({ -1, 1 }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(sx < 0 and 0 or 1, 0, 0.5, 0), Size = UDim2.fromOffset(20, 20), Rotation = 45, BackgroundColor3 = col:Lerp(C(255, 255, 255), 0.3), BorderSizePixel = 0, ZIndex = 7, Parent = ribbon }, { U.stroke(C(255, 255, 255), 2) })
	end
	local ribShine = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0, ZIndex = 6, Parent = ribbon }, { U.corner(14) })
	local ribShineGrad = new("UIGradient", { Rotation = 20, Transparency = NumberSequence.new({ kp(0, 1), kp(0.42, 1), kp(0.5, 0.55), kp(0.58, 1), kp(1, 1) }), Offset = Vector2.new(-1, 0), Parent = ribShine })
	-- плашка под описанием способности
	local abilPill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.835, -4),
		Size = UDim2.fromOffset(700, 62),
		BackgroundColor3 = C(10, 12, 16),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = layer,
	}, { U.corner(14) })
	local abilStroke = U.stroke(col, 2, 1)
	abilStroke.Parent = abilPill

	local nameLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.795),
		Size = UDim2.fromOffset(900, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = def.name,
		TextSize = 42,
		TextColor3 = C(255, 255, 255),
		MaxVisibleGraphemes = 0,
		ZIndex = 7,
		Parent = layer,
	}, { U.textStroke(C(0, 0, 0), 3) })

	local abilityLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.835),
		Size = UDim2.fromOffset(680, 54),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = ("★ %s — %s"):format(def.ability.name, def.ability.desc),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = C(215, 222, 210),
		TextTransparency = 1,
		ZIndex = 7,
		Parent = layer,
	}, { U.textStroke(C(0, 0, 0), 1.5, 1) })

	-- звёзды редкости
	local starRow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.655),
		Size = UDim2.fromOffset(400, 40),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = layer,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	local stars = {}
	for i = 1, order do
		stars[i] = new("TextLabel", {
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			Text = "★",
			Font = Enum.Font.GothamBlack,
			TextSize = 0,
			TextColor3 = rar.rainbow and Config.Rainbow(0, i * 0.15) or col,
			LayoutOrder = i,
			ZIndex = 7,
			Parent = starRow,
		}, { U.textStroke(C(0, 0, 0), 2) })
	end

	-- анимация появления
	-- в 2D-карточке не повторяем «ревил» из 3D-сцены
	sfx(order >= 3 and U.Sounds.star or U.Sounds.chime, 0.6, 0.95 + order * 0.03)
	-- блик, пробегающий по надписи редкости
	task.delay(0.45, function()
		if not rarityLbl.Parent then
			return
		end
		local sh = new("UIGradient", { Rotation = 20, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0) }), Offset = Vector2.new(-1, 0) })
		if not rarityLbl:FindFirstChildOfClass("UIGradient") or not rar.rainbow then
			local ov = rarityLbl:Clone()
			for _, c in ipairs(ov:GetChildren()) do
				c:Destroy()
			end
			ov.TextColor3 = C(255, 255, 255)
			ov.TextTransparency = 0
			ov.ZIndex = rarityLbl.ZIndex + 1
			ov.Parent = rarityLbl.Parent
			sh.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) })
			sh.Parent = ov
			animateAsync(0.7, function(e)
				sh.Offset = Vector2.new(-1 + e * 2, 0)
				ov.TextSize = rarityLbl.TextSize
			end)
			task.delay(0.75, function()
				ov:Destroy()
			end)
		end
	end)
	-- дрон падает сверху на постамент: приземление со сплющиванием, волной и пылью
	vp.Size = UDim2.fromOffset(460, 460)
	vp.Position = UDim2.new(0.5, 0, -0.4, 0)
	task.spawn(function()
		animate(0.32, function(e)
			vp.Position = UDim2.new(0.5, 0, -0.4 + 0.82 * e, 0)
		end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if not layer.Parent then
			return
		end
		sfx(U.Sounds.thud, 0.7, 1.15)
		shake(6 + order * 2)
		amb.landRing()
		animate(0.55, function(e)
			local sq = (1 - e) ^ 2 * math.cos(e * math.pi * 3)
			vp.Size = UDim2.fromOffset(460 * (1 + 0.16 * sq), 460 * (1 - 0.16 * sq))
			vp.Position = UDim2.new(0.5, 0, 0.42, 34 * sq)
		end)
		vp.Size = UDim2.fromOffset(460, 460)
		vp.Position = UDim2.fromScale(0.5, 0.42)
	end)
	animateAsync(0.4, function(e)
		rarityLbl.TextSize = 150 - 74 * e
		rarityLbl.TextTransparency = 1 - e
	end)
	shake(4 + order * 3)
	if order >= 4 then
		uiBurst(col, 30 + order * 6, nil, rar.rainbow, 0.8)
	end
	if rar.rainbow then
		ctx.rainbowMode = true
	end
	if r.rarity == "Secret" then
		ctx.glitch = true
		ctx.shakeBase = 1.5
		local g1 = rarityLbl:Clone()
		g1.TextColor3 = C(0, 255, 255)
		g1.ZIndex = 6
		g1:FindFirstChildOfClass("UIGradient"):Destroy()
		g1.Parent = layer
		local g2 = rarityLbl:Clone()
		g2.TextColor3 = C(255, 0, 60)
		g2.ZIndex = 6
		g2:FindFirstChildOfClass("UIGradient"):Destroy()
		g2.Parent = layer
		ctx.glitchLabels = { main = rarityLbl, g1 = g1, g2 = g2 }
		sfx(U.Sounds.boom, 0.7, 0.5)
	end
	if order == 4 then
		ctx.sparkle = col
	end
	waitT(0.35)

	for i, s in ipairs(stars) do
		sfx(U.Sounds.tick, 0.6, 1 + i * 0.12)
		animateAsync(0.25, function(e)
			s.TextSize = 34 * e
		end, Enum.EasingStyle.Back)
		-- маленький взрыв искр у каждой звезды
		task.delay(0.12, function()
			if s.Parent and not ctx.skip then
				local ap = s.AbsolutePosition + s.AbsoluteSize / 2
				uiBurst(col, 6, Vector2.new(ap.X, ap.Y), rar.rainbow, 0.22)
			end
		end)
		waitT(0.09)
	end
	amb.stars = stars

	-- лента раскрывается, по ней пробегает блик
	sfx(U.Sounds.whoosh, 0.35, 1.6)
	animateAsync(0.35, function(e)
		ribbon.Size = UDim2.fromOffset(580 * e, 54)
	end, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		if ribShine.Parent then
			animateAsync(0.7, function(e)
				ribShineGrad.Offset = Vector2.new(-1 + 2 * e, 0)
			end)
		end
	end)

	local len = utf8.len(def.name) or #def.name
	for i = 1, len do
		nameLbl.MaxVisibleGraphemes = i
		waitT(0.035)
	end
	nameLbl.MaxVisibleGraphemes = -1
	animateAsync(0.4, function(e)
		abilityLbl.TextTransparency = 1 - e
		abilityLbl:FindFirstChildOfClass("UIStroke").Transparency = 1 - e * 0.6
		abilPill.BackgroundTransparency = 1 - e * 0.55
		abilStroke.Transparency = 1 - e * 0.6
	end)

	-- бейджи
	local badgeY = 0.2
	local function badge(text, color)
		local b = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 210, badgeY, 0),
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = color,
			Text = text,
			Font = Enum.Font.FredokaOne,
			TextSize = 0,
			TextColor3 = C(20, 20, 20),
			Rotation = -12,
			ZIndex = 9,
			Parent = layer,
		}, { U.corner(10), U.stroke(C(255, 255, 255), 3) })
		badgeY += 0.075
		sfx(U.Sounds.pop, 0.6, 1.4)
		animateAsync(0.35, function(e)
			b.TextSize = 28 * e
			b.Size = UDim2.fromOffset(150 * e, 44 * e)
		end, Enum.EasingStyle.Back)
	end
	if r.new then
		badge("NEW!", C(160, 255, 70))
	end
	if r.pity then
		badge("ГАРАНТ!", C(255, 200, 40))
	end

	-- подсказка
	local hint = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(500, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = (final and "Нажми, чтобы забрать" or "Нажми, чтобы продолжить") .. (UIS.KeyboardEnabled and "  •  Пробел" or ""),
		TextSize = 18,
		TextColor3 = C(200, 200, 200),
		ZIndex = 9,
		Parent = layer,
	})
	ctx.hint = hint
	if final then
		ctx.skipBtn.Visible = false
	end
	waitClick(final)
	ctx.hint = nil
end

-- ===== СТАДИЯ 3: ИТОГИ x10 =====
local function summary(results)
	clearReveal()
	local best = 1
	for _, r in ipairs(results) do
		best = math.max(best, rinfo(r.rarity).order)
	end
	local bestKey = Config.RarityOrder[best]
	ctx.rays.setColor(rinfo(bestKey).color)
	ctx.rays.fadeTo(0.6, 0.4)
	ctx.bgTint = rinfo(bestKey).color

	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = ctx.shake })
	ctx.revealLayer = layer
	local bestRar = rinfo(bestKey)
	-- фон: искры и конфетти по лучшей редкости
	revealAmbient(layer, bestRar.color, bestRar, best, bestKey == "Secret", { noCircle = true, noPedestal = true, noBeams = true, center = UDim2.fromScale(0.5, 0.5) })
	-- заголовок на ленте
	local head = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromOffset(0, 62), BackgroundColor3 = C(255, 255, 255), ZIndex = 6, Parent = layer }, { U.corner(16) })
	local hg = new("UIGradient", { Color = bestRar.rainbow and Config.RainbowSequence or ColorSequence.new({ ColorSequenceKeypoint.new(0, U.darken(bestRar.color, 0.75)), ColorSequenceKeypoint.new(0.5, U.darken(bestRar.color, 0.35)), ColorSequenceKeypoint.new(1, U.darken(bestRar.color, 0.75)) }), Parent = head })
	if bestRar.rainbow then
		table.insert(ctx.rainbowGrads, hg)
	end
	U.stroke(bestRar.color:Lerp(C(255, 255, 255), 0.45), 3).Parent = head
	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "★ РЕЗУЛЬТАТ ×10 ★",
		TextSize = 36,
		TextColor3 = C(255, 255, 255),
		ZIndex = 7,
		Parent = head,
	}, { U.textStroke(C(0, 0, 0), 3) })
	animateAsync(0.4, function(e)
		head.Size = UDim2.fromOffset(560 * e, 62)
	end, Enum.EasingStyle.Back)

	local CW, CH, GAP = 150, 205, 16
	local grid = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW * 5 + GAP * 4, CH * 2 + GAP),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = layer,
	})

	local cards = {}
	for i, r in ipairs(results) do
		local def = Config.DroneById[r.id]
		local rar = rinfo(r.rarity)
		local col = rar.color
		local cx = (i - 1) % 5
		local cy = math.floor((i - 1) / 5)
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx * (CW + GAP) + CW / 2, cy * (CH + GAP) + CH / 2),
			Size = UDim2.fromOffset(CW, CH),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = grid,
		})
		local card = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C(24, 26, 24),
			ZIndex = 3,
			Parent = holder,
		}, { U.corner(14) })
		local stroke = U.stroke(U.darken(col, 0.7), 3)
		stroke.Parent = card
		-- рубашка
		local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = card })
		for s = 0, 5 do
			new("Frame", {
				Position = UDim2.new(0, -20 + s * 34, 1, -22),
				Size = UDim2.fromOffset(16, 22),
				BackgroundColor3 = C(255, 190, 20),
				BorderSizePixel = 0,
				Rotation = 30,
				ZIndex = 4,
				Parent = back,
			})
		end
		new("TextLabel", {
			Size = UDim2.fromScale(1, 0.85),
			BackgroundTransparency = 1,
			Text = "?",
			Font = Enum.Font.FredokaOne,
			TextSize = 80,
			TextColor3 = col,
			ZIndex = 5,
			Parent = back,
		}, { U.textStroke(C(0, 0, 0), 3) })
		-- лицевая сторона
		local front = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 4, Parent = card })
		new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = col,
			BackgroundTransparency = 0.55,
			ZIndex = 4,
			Parent = front,
		}, {
			U.corner(14),
			new("UIGradient", {
				Rotation = 90,
				Color = rar.rainbow and Config.RainbowSequence or ColorSequence.new(col, C(10, 10, 10)),
				Transparency = NumberSequence.new(0, 0.6),
			}),
		})
		local vp = new("ViewportFrame", {
			Position = UDim2.fromOffset(5, 6),
			Size = UDim2.new(1, -10, 0, 128),
			BackgroundTransparency = 1,
			Ambient = C(150, 150, 150),
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			ZIndex = 5,
			Parent = front,
		})
		Builder.SetupViewport(vp, Builder.Build(def, 1), math.rad(25), math.rad(16), 1.0)
		new("TextLabel", {
			Position = UDim2.new(0, 4, 1, -66),
			Size = UDim2.new(1, -8, 0, 26),
			BackgroundTransparency = 1,
			Text = def.name,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = C(255, 255, 255),
			ZIndex = 6,
			Parent = front,
		}, { U.textStroke(C(0, 0, 0), 2), new("UITextSizeConstraint", { MaxTextSize = 18 }) })
		local rl = new("TextLabel", {
			Position = UDim2.new(0, 4, 1, -38),
			Size = UDim2.new(1, -8, 0, 24),
			BackgroundTransparency = 1,
			Text = rar.label,
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
			TextColor3 = rar.rainbow and C(255, 255, 255) or col,
			ZIndex = 6,
			Parent = front,
		}, { U.textStroke(C(0, 0, 0), 2) })
		if rar.rainbow then
			local g = new("UIGradient", { Color = Config.RainbowSequence, Parent = rl })
			table.insert(ctx.rainbowGrads, g)
		end
		if r.new then
			new("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 6, 0, -8),
				Size = UDim2.fromOffset(58, 24),
				BackgroundColor3 = C(160, 255, 70),
				Text = "NEW!",
				Font = Enum.Font.FredokaOne,
				TextSize = 16,
				TextColor3 = C(20, 20, 20),
				Rotation = 10,
				ZIndex = 8,
				Parent = front,
			}, { U.corner(6) })
		end
		-- свечение за картой (появляется после переворота у эпика и выше)
		local glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.7), BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = col, ImageTransparency = 1, ZIndex = 2, Parent = holder })
		cards[i] = { holder = holder, card = card, back = back, front = front, stroke = stroke, rar = rar, col = col, glow = glow, i = i }
	end

	-- покадрово: карты покачиваются, свечение пульсирует и вращается
	local sumConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, c in ipairs(cards) do
			if c.flipped then
				c.card.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2 + c.i * 0.7) * 3)
				if c.rar.order >= 3 then
					c.glow.ImageTransparency = 0.35 - 0.2 * math.sin(t * 3 + c.i)
					c.glow.Rotation = t * 25
					if c.rar.rainbow then
						c.glow.ImageColor3 = Config.Rainbow(t, c.i * 0.1)
					end
				end
			end
		end
	end)
	table.insert(ctx.cleanupUI, function()
		sumConn:Disconnect()
	end)
	ctx.revealStops = ctx.revealStops or {}
	table.insert(ctx.revealStops, function()
		sumConn:Disconnect()
	end)

	-- раздача: карты вылетают из колоды снизу и разлетаются по местам
	local gw, gh = CW * 5 + GAP * 4, CH * 2 + GAP
	for _, c in ipairs(cards) do
		c.target = c.holder.Position
		c.holder.Position = UDim2.fromOffset(gw / 2, gh + 260)
		c.holder.Rotation = math.random(-35, 35)
		c.holder.Size = UDim2.fromOffset(CW * 0.4, CH * 0.4)
	end
	for _, c in ipairs(cards) do
		local from, rot0 = c.holder.Position, c.holder.Rotation
		sfx(U.Sounds.tick, 0.35, 1.2 + c.i * 0.05)
		animateAsync(0.34, function(e)
			c.holder.Position = from:Lerp(c.target, e)
			c.holder.Rotation = rot0 * (1 - e)
			c.holder.Size = UDim2.fromOffset(CW * (0.4 + 0.6 * e), CH * (0.4 + 0.6 * e))
		end, Enum.EasingStyle.Back)
		waitT(0.055)
	end
	waitT(0.3)
	for _, c in ipairs(cards) do
		c.holder.Position = c.target
		c.holder.Rotation = 0
		c.holder.Size = UDim2.fromOffset(CW, CH)
	end

	-- переворот карт
	local function flip(c)
		animate(0.12, function(e)
			c.card.Size = UDim2.fromScale(1 - e, 1)
		end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		c.back.Visible = false
		c.front.Visible = true
		c.stroke.Color = c.col
		c.stroke.Thickness = c.rar.order >= 4 and 5 or 3
		if c.rar.rainbow then
			local g = new("UIGradient", { Color = Config.RainbowSequence, Parent = c.stroke })
			table.insert(ctx.rainbowGrads, g)
			c.stroke.Color = C(255, 255, 255)
		end
		sfx(U.Sounds.tick, 0.5, 0.8 + c.rar.order * 0.15)
		animate(0.22, function(e)
			c.card.Size = UDim2.fromScale(e, 1)
		end, Enum.EasingStyle.Back)
		c.flipped = true
		-- блик пробегает по карте
		local sh = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), ZIndex = 7, Parent = c.card }, { U.corner(14) })
		local sg = new("UIGradient", { Rotation = 25, Transparency = NumberSequence.new({ kp(0, 1), kp(0.4, 1), kp(0.5, 0.3), kp(0.6, 1), kp(1, 1) }), Offset = Vector2.new(-1, 0), Parent = sh })
		animateAsync(0.6, function(e)
			sg.Offset = Vector2.new(-1 + 2 * e, 0)
		end)
		task.delay(0.65, function()
			sh:Destroy()
		end)
		if c.rar.order >= 4 then
			local ap = c.holder.AbsolutePosition + c.holder.AbsoluteSize / 2
			uiBurst(c.col, 24, Vector2.new(ap.X, ap.Y + ctx.insetY), c.rar.rainbow, 0.5)
			shake(6 + c.rar.order)
			sfx(U.Sounds.pop, 0.7, 1.2)
			animateAsync(0.5, function(e)
				local s = 1 + math.sin(e * math.pi) * 0.12
				c.holder.Size = UDim2.fromOffset(CW * s, CH * s)
			end)
		end
	end
	waitT(0.15)
	for _, c in ipairs(cards) do
		task.spawn(flip, c)
		waitT(0.16)
	end
	waitT(0.4)

	-- сводка по редкостям
	local counts = {}
	for _, r in ipairs(results) do
		counts[r.rarity] = (counts[r.rarity] or 0) + 1
	end
	local tally = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 238), Size = UDim2.fromOffset(900, 34), BackgroundTransparency = 1, ZIndex = 7, Parent = layer }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _, key in ipairs(Config.RarityOrder) do
		local n = counts[key]
		if n then
			local rr = rinfo(key)
			local chip = new("TextLabel", { Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = U.darken(rr.color, 0.6), Text = "   " .. rr.label .. " ×" .. n .. "   ", Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = rr.color:Lerp(C(255, 255, 255), 0.4), LayoutOrder = rr.order, ZIndex = 7, Parent = tally }, { U.corner(16), U.stroke(rr.color, 2), U.textStroke(C(0, 0, 0), 1.5) })
			local s = new("UIScale", { Scale = 0, Parent = chip })
			sfx(U.Sounds.pop, 0.35, 1.3 + rr.order * 0.08)
			animateAsync(0.3, function(e)
				s.Scale = e
			end, Enum.EasingStyle.Back)
			waitT(0.07)
		end
	end

	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromOffset(240, 58),
		BackgroundColor3 = C(130, 230, 60),
		Text = "ЗАБРАТЬ",
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextColor3 = C(20, 30, 15),
		AutoButtonColor = true,
		ZIndex = 10,
		Parent = layer,
	}, { U.corner(14), U.stroke(C(255, 255, 255), 3), U.grad(C(255, 255, 255), C(170, 200, 150), 90) })
	local bs = new("UIScale", { Scale = 0, Parent = btn })
	animateAsync(0.35, function(e)
		bs.Scale = e
	end, Enum.EasingStyle.Back)
	local pulse = RunService.RenderStepped:Connect(function()
		if bs.Scale > 0.95 then
			bs.Scale = 1 + 0.04 * math.sin(os.clock() * 5)
		end
	end)
	table.insert(ctx.cleanupUI, function()
		pulse:Disconnect()
	end)
	btn.Activated:Connect(function()
		ctx.clicked = true
	end)
	ctx.skipBtn.Visible = false
	waitClick(true)
	pulse:Disconnect()
end

-- ===== ГЛАВНЫЙ ЦИКЛ =====
local function run(results, opts)
	local pg = player:WaitForChild("PlayerGui")
	ctx = {
		fast = opts.fast,
		skip = false,
		clicked = false,
		particles = {},
		shakeAmp = 0,
		shakeBase = 0,
		rainbowGrads = {},
		bgTint = C(130, 230, 60),
		cleanupUI = {},
		sounds = {},
	}
	local vpSize = workspace.CurrentCamera.ViewportSize
	ctx.uiScale = math.clamp(math.min(vpSize.X / 1100, vpSize.Y / 720), 0.5, 1.2)
	ctx.insetY = 0

	local gui = new("ScreenGui", {
		Name = "ZSS_GachaAnim",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	ctx.gui = gui
	local bg = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(6, 8, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
	local bgGrad = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C(255, 255, 255), C(255, 255, 255)),
		Parent = bg,
	})
	ctx.bg = bg
	local scaled = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	ctx.shake = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = scaled })
	ctx.rays = makeRays(ctx.shake)
	ctx.fxLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = gui })
	ctx.dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = ctx.shake })
	ctx.flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })
	local glitchBars = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 15, Parent = gui })

	-- клик для продолжения
	local catcher = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 9,
		Parent = gui,
	})
	catcher.Activated:Connect(function()
		ctx.clicked = true
	end)
	-- на клавиатуре у кнопки есть подсказка-клавиша «ПРОБЕЛ»
	local keyHint = UIS.KeyboardEnabled
	ctx.skipBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(keyHint and 250 or 170, 44),
		BackgroundColor3 = C(30, 34, 30),
		BackgroundTransparency = 0.2,
		Text = keyHint and "" or "ПРОПУСТИТЬ ⏭",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = C(230, 230, 230),
		ZIndex = 30,
		Parent = gui,
	}, { U.corner(10), U.stroke(C(130, 230, 60), 2) })
	if keyHint then
		new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C(230, 230, 230), TextXAlignment = Enum.TextXAlignment.Left, Text = "ПРОПУСТИТЬ ⏭", ZIndex = 31, Parent = ctx.skipBtn })
		-- клавиша-«колпачок»: светлая крышка над тёмным торцом
		local cap = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, -1), Size = UDim2.fromOffset(86, 26), BackgroundColor3 = C(120, 130, 120), ZIndex = 31, Parent = ctx.skipBtn }, { U.corner(6) })
		new("TextLabel", { Size = UDim2.new(1, 0, 1, -3), BackgroundColor3 = C(235, 240, 230), Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C(30, 34, 30), Text = "ПРОБЕЛ", ZIndex = 32, Parent = cap }, { U.corner(6) })
	end
	local function doSkip()
		if ctx.skip then
			return
		end
		ctx.skip = true
		ctx.skipAt = os.clock()
		ctx.skipBtn.Visible = false
		stopSfx(0.12)
	end
	ctx.skipBtn.Activated:Connect(doSkip)
	-- Пробел / Enter (A на геймпаде): пока видна кнопка — пропуск анимации, дальше — «продолжить/забрать».
	-- Клавиша перехватывается целиком, чтобы персонаж не прыгал под анимацией.
	ContextActionService:BindActionAtPriority("ZSS_GachaSkip", function(_, state)
		if state == Enum.UserInputState.Begin then
			if ctx.skipBtn.Visible and not ctx.skip then
				doSkip()
			elseif os.clock() - (ctx.skipAt or 0) > 0.35 then
				-- небольшая пауза после пропуска, чтобы двойное нажатие не закрыло итог раньше, чем его увидят
				ctx.clicked = true
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA)
	table.insert(ctx.cleanupUI, function()
		ContextActionService:UnbindAction("ZSS_GachaSkip")
	end)

	-- общий покадровый апдейт
	local c = ctx
	local loop = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- тряска
		local amp = math.max(c.shakeAmp, c.shakeBase)
		if amp > 0.2 then
			-- плавная тряска (шум Перлина), без рваных скачков
			local nt = t * 22
			c.shake.Position = UDim2.fromOffset(math.noise(nt, 0.3) * amp * 1.6, math.noise(0.7, nt) * amp * 1.6)
		else
			c.shake.Position = UDim2.fromOffset(0, 0)
		end
		c.shakeAmp *= math.exp(-dt * 7)
		-- лучи
		c.rays.update(t)
		if c.rainbowMode then
			c.rays.setColor(nil, true)
			if c.glows then
				for i, g in ipairs(c.glows) do
					g.f.BackgroundColor3 = Config.Rainbow(t, i * 0.1)
				end
			end
			if c.rarityGrad then
				c.rarityGrad.Rotation = (t * 120) % 360
			end
		end
		for _, g in ipairs(c.rainbowGrads) do
			g.Rotation = (t * 120) % 360
		end
		-- радужная машина для MYTHIC
		if c.forgeRainbow then
			local rc = Config.Rainbow(t)
			c.forgeRainbow.paint(rc, 1)
			c.forgeRainbow.pod.setColor(rc)
		end
		-- фон с оттенком редкости
		local tint = c.rainbowMode and Config.Rainbow(t) or c.bgTint
		bgGrad.Color = ColorSequence.new(U.darken(tint, 0.35):Lerp(C(6, 8, 6), 0.3), C(4, 5, 4))
		-- пульсация свечения
		if c.glows then
			for i, g in ipairs(c.glows) do
				if g.f.Parent then
					local s = g.size * (1 + math.sin(t * 2.5 + i) * 0.04)
					if g.f.Size.X.Offset >= g.size * 0.9 then
						g.f.Size = UDim2.fromOffset(s, s)
					end
				end
			end
		end
		-- вращение дрона
		if c.spin and c.spin.model.Parent then
			local m = c.spin.model
			m:PivotTo(c.spin.base * CFrame.new(0, math.sin(t * 1.8) * 0.15, 0) * CFrame.Angles(0, t * 0.9, 0))
			if c.spin.rainbow or c.spin.secret then
				local k = 0
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") and p:GetAttribute("Tint") then
						k += 1
						if c.spin.rainbow then
							p.Color = Config.Rainbow(t, k * 0.06)
						else
							local pulse = 0.55 + 0.45 * math.abs(math.sin(t * 4))
							p.Color = Color3.new(pulse, 0.05, 0.06)
						end
					end
				end
			end
		end
		-- золотые искры для LEGENDARY
		if c.sparkle and math.random() < 0.25 then
			local vp = workspace.CurrentCamera.ViewportSize
			local ang = math.random() * math.pi * 2
			local rr = math.random(120, 260) * c.uiScale
			uiBurst(c.sparkle, 1, Vector2.new(vp.X * 0.5 + math.cos(ang) * rr, vp.Y * 0.42 + math.sin(ang) * rr), false, 0.15)
		end
		-- глитч для SECRET
		if c.glitch then
			if math.random() < 0.3 then
				local vp = workspace.CurrentCamera.ViewportSize
				local bar = new("Frame", {
					Position = UDim2.fromOffset(math.random(-200, 200), math.random(0, vp.Y)),
					Size = UDim2.new(1, 0, 0, math.random(2, 14)),
					BackgroundColor3 = math.random() < 0.5 and C(255, 0, 40) or C(0, 255, 255),
					BackgroundTransparency = math.random(30, 80) / 100,
					BorderSizePixel = 0,
					ZIndex = 15,
					Parent = glitchBars,
				})
				task.delay(math.random(4, 12) / 100, function()
					bar:Destroy()
				end)
			end
			local gl = c.glitchLabels
			if gl and gl.main.Parent then
				local on = math.random() < 0.35
				local base = gl.main.Position
				gl.g1.Position = base + UDim2.fromOffset(on and math.random(-12, 12) or -3, on and math.random(-4, 4) or 0)
				gl.g2.Position = base + UDim2.fromOffset(on and math.random(-12, 12) or 3, on and math.random(-4, 4) or 0)
				gl.g1.TextTransparency = gl.main.TextTransparency + 0.3
				gl.g2.TextTransparency = gl.main.TextTransparency + 0.3
				gl.g1.TextSize = gl.main.TextSize
				gl.g2.TextSize = gl.main.TextSize
			end
		end
		-- частицы
		for i = #c.particles, 1, -1 do
			local p = c.particles[i]
			p.age += dt
			if p.age >= p.life then
				p.f:Destroy()
				table.remove(c.particles, i)
			else
				p.vy += 900 * dt
				p.vx *= math.exp(-dt * 1.5)
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.f.Position = UDim2.fromOffset(p.x, p.y)
				p.f.Rotation += p.rot * dt
				p.f.BackgroundTransparency = (p.age / p.life) ^ 2
			end
		end
		-- мигающая подсказка
		if c.hint and c.hint.Parent then
			c.hint.TextTransparency = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 4))
		end
	end)

	-- масштаб под экран (телефоны)
	new("UIScale", { Scale = 1, Parent = scaled })
	local sc = ctx.uiScale
	if sc < 1 then
		ctx.shake.Size = UDim2.fromScale(1 / sc, 1 / sc)
		scaled:FindFirstChildOfClass("UIScale").Scale = sc
	end

	-- появление фона: полупрозрачный, сквозь него виден размытый мир
	local Lighting = game:GetService("Lighting")
	local blur = Instance.new("BlurEffect")
	blur.Name = "ZSS_GachaBlur"
	blur.Size = 0
	blur.Parent = Lighting
	ctx.blur = blur
	local hud = pg:FindFirstChild("ZSS_HUD")
	if hud then
		-- HUD прячется под короткое затемнение, а не исчезает рывком
		local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 60, Parent = gui })
		local fastK = ctx.fast and 0.6 or 1
		TweenService:Create(cover, TweenInfo.new(0.16 * fastK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.25 }):Play()
		task.wait(0.16 * fastK)
		hud.Enabled = false
		ctx.hud = hud
		local tw = TweenService:Create(cover, TweenInfo.new(0.3 * fastK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		tw.Completed:Connect(function()
			cover:Destroy()
		end)
		tw:Play()
	end

	local maxOrder = 1
	local top
	for _, r in ipairs(results) do
		local o = rinfo(r.rarity).order
		if o >= maxOrder then
			maxOrder = o
			top = r
		end
	end

	-- главная сцена — у машины в 3D; если игрок далеко — старый кейс в 2D
	ctx.skipBtn.Visible = true
	local forged = forgeSequence(maxOrder, top)
	if forged then
		animate(0.45, function(e)
			bg.BackgroundTransparency = 1 - e * 0.45
			blur.Size = e * 14
		end, Enum.EasingStyle.Sine)
	else
		animate(0.35, function(e)
			bg.BackgroundTransparency = 1 - e * 0.5
			blur.Size = e * 22
		end)
		crateSequence(maxOrder, top)
	end
	ctx.glitch = false
	ctx.dim.BackgroundTransparency = 1
	local topKeyAll = Config.RarityOrder[maxOrder]
	-- аниме-кат-ин для эпика и выше
	if maxOrder >= 3 and not ctx.skip and top then
		cutIn(top)
	end
	if (topKeyAll == "Legendary" or topKeyAll == "Mythic" or topKeyAll == "Secret") and not ctx.skip then
		bannerSlam(topKeyAll)
	end

	if #results == 1 then
		reveal(results[1], true)
	else
		local special = {}
		for _, r in ipairs(results) do
			if rinfo(r.rarity).order >= 3 then
				table.insert(special, r)
			end
		end
		table.sort(special, function(a, b)
			return rinfo(a.rarity).order < rinfo(b.rarity).order
		end)
		for _, r in ipairs(special) do
			if ctx.skip then
				break
			end
			reveal(r, false)
		end
		summary(results)
	end

	-- затухание
	ctx.skip = false
	stopSfx(0.3)
	-- уход в затемнение, под ним убираем сцену и возвращаем HUD, затем мир плавно проявляется
	local fadeGui = new("ScreenGui", { Name = "ZSS_GachaFade", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 101, Parent = pg })
	local fadeOut = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = fadeGui })
	ctx.fadeGui = fadeGui
	local blur0 = blur.Size
	animate(0.25, function(e)
		fadeOut.BackgroundTransparency = 1 - e * 0.85
	end)
	loop:Disconnect()
	for _, f in ipairs(ctx.cleanupUI) do
		pcall(f)
	end
	gui:Destroy()
	if ctx.hud then
		ctx.hud.Enabled = true
	end
	-- камера возвращается за спину игрока, пока затемнение рассеивается
	local camDone = not ctx.cleanup
	if ctx.cleanup then
		task.spawn(function()
			pcall(ctx.cleanup, false)
			camDone = true
		end)
	end
	animate(0.45, function(e)
		fadeOut.BackgroundTransparency = 0.15 + 0.85 * e
		blur.Size = blur0 * (1 - e)
	end, Enum.EasingStyle.Sine)
	blur:Destroy()
	fadeGui:Destroy()
	while not camDone do
		RunService.RenderStepped:Wait()
	end
end

function GA.Play(results, opts, onDone)
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		local ok, err = pcall(run, results, opts or {})
		if not ok then
			warn("[ZSS] Ошибка анимации гачи:", err)
			if ctx and ctx.cleanupUI then
				for _, f in ipairs(ctx.cleanupUI) do
					pcall(f)
				end
			end
			if ctx and ctx.cleanup then
				pcall(ctx.cleanup, true)
			end
			local pg = player:FindFirstChild("PlayerGui")
			local g = pg and pg:FindFirstChild("ZSS_GachaAnim")
			if g then
				g:Destroy()
			end
			local fg = pg and pg:FindFirstChild("ZSS_GachaFade")
			if fg then
				fg:Destroy()
			end
			local b = game:GetService("Lighting"):FindFirstChild("ZSS_GachaBlur")
			if b then
				b:Destroy()
			end
			local hud = pg and pg:FindFirstChild("ZSS_HUD")
			if hud then
				hud.Enabled = true
			end
		end
		playing = false
		if onDone then
			onDone()
		end
	end)
end

return GA
