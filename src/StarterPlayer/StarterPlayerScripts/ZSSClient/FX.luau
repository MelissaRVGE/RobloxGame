-- Визуальные эффекты в мире: способности, лазеры, всплывающие цифры
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)

local player = Players.LocalPlayer
local FX = {}
local Renderer
local folder
local C = Color3.fromRGB
local Neon = Enum.Material.Neon

local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"

local function part(o)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = o.mat or Neon
	p.Color = o.color or C(255, 255, 255)
	p.Transparency = o.tr or 0
	if o.shape then
		p.Shape = o.shape
	end
	p.Size = o.size or Vector3.one
	p.CFrame = o.cf or CFrame.new()
	p.Parent = folder
	Debris:AddItem(p, o.life or 3)
	return p
end

local function tw(inst, t, props, style, dir)
	local x = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function dronePos(owner, key)
	return Renderer and Renderer.GetPos(owner, key)
end

local function ownerRoot(owner)
	local plr = Players:GetPlayerByUserId(owner)
	local char = plr and plr.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

-- настройки игрока (меняются из меню настроек)
FX.Particles = 1 -- множитель количества частиц
FX.ShakeEnabled = true
FX.ShowDamage = true

-- вспышка частиц в точке
function FX.Burst(pos, color, count, size, speed, texture)
	count = math.max(1, math.floor((count or 20) * FX.Particles + 0.5))
	local p = part({ size = Vector3.one * 0.2, cf = CFrame.new(pos), tr = 1, life = 3 })
	local a = Instance.new("Attachment")
	a.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK_TEX
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color or C(255, 255, 255))
	e.Size = NumberSequence.new(size or 0.6, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new((speed or 12) * 0.4, speed or 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rate = 0
	e.Drag = 3
	e.Transparency = NumberSequence.new(0, 1)
	e.Parent = a
	e:Emit(count or 20)
end

function FX.Beam(a, b, color, width, duration)
	local dist = (b - a).Magnitude
	if dist < 0.05 then
		return
	end
	width = width or 0.25
	local p = part({ size = Vector3.new(width, width, dist), cf = CFrame.lookAt((a + b) / 2, b), color = color, life = (duration or 0.25) + 0.1 })
	tw(p, duration or 0.25, { Size = Vector3.new(0, 0, dist), Transparency = 1 })
	return p
end

function FX.Lightning(a, b, color)
	local segs = 6
	local prev = a
	for i = 1, segs do
		local t = i / segs
		local pt = a:Lerp(b, t)
		if i < segs then
			pt += Vector3.new(math.random(-10, 10) / 10, math.random(-10, 10) / 10, math.random(-10, 10) / 10)
		end
		FX.Beam(prev, pt, color, 0.22, 0.3)
		prev = pt
	end
	FX.Burst(b, color, 10, 0.5, 10)
end

function FX.Laser(a, b, color)
	FX.Beam(a, b, color, 0.14, 0.14)
	local f = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.8, cf = CFrame.new(b), color = color, tr = 0.2, life = 0.3 })
	tw(f, 0.2, { Size = Vector3.one * 0.1, Transparency = 1 })
end

function FX.Ring(pos, radius, color, duration, implode)
	duration = duration or 0.6
	local ground = Vector3.new(pos.X, pos.Y - 2.6, pos.Z)
	local disc = part({
		shape = Enum.PartType.Cylinder,
		size = implode and Vector3.new(0.3, radius * 2, radius * 2) or Vector3.new(0.3, 1, 1),
		cf = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		tr = 0.35,
		life = duration + 0.2,
	})
	tw(disc, duration, { Size = implode and Vector3.new(0.3, 1, 1) or Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
	local sph = part({
		shape = Enum.PartType.Ball,
		size = implode and Vector3.one * radius * 2 or Vector3.one,
		cf = CFrame.new(ground),
		color = color,
		mat = Enum.Material.ForceField,
		tr = 0,
		life = duration + 0.2,
	})
	tw(sph, duration, { Size = implode and Vector3.one or Vector3.one * radius * 2, Transparency = 1 })
end

function FX.Popup(pos, text, color, big, icon)
	local p = part({ size = Vector3.one * 0.1, cf = CFrame.new(pos), tr = 1, life = 1.4 })
	local bb = U.new("BillboardGui", {
		Size = UDim2.fromOffset(160, 40),
		StudsOffset = Vector3.new(0, 1, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		Parent = p,
	})
	local lbl = U.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Position = icon and UDim2.fromOffset(14, 0) or UDim2.new(),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = big and 30 or 22,
		TextColor3 = color,
		Parent = bb,
	}, { U.textStroke(C(0, 0, 0), 2) })
	local ic
	if icon then
		ic = U.new("ImageLabel", { BackgroundTransparency = 1, Image = icon, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -8 - #text * 3, 0.5, 0), Size = UDim2.fromOffset(26, 26), Parent = bb })
		task.delay(0.6, function()
			tw(ic, 0.6, { ImageTransparency = 1 })
		end)
	end
	local st = lbl:FindFirstChildOfClass("UIStroke")
	-- цифра «выпрыгивает» с пружинкой, а не появляется сразу полного размера
	local ts = lbl.TextSize
	lbl.TextSize = math.floor(ts * 0.4)
	tw(lbl, 0.22, { TextSize = ts }, Enum.EasingStyle.Back)
	tw(bb, 1.2, { StudsOffset = Vector3.new(math.random(-10, 10) / 10, 4, 0) })
	task.delay(0.6, function()
		tw(lbl, 0.6, { TextTransparency = 1 })
		if st then
			tw(st, 0.6, { Transparency = 1 })
		end
	end)
end

function FX.Text3D(pos, text, color)
	local p = part({ size = Vector3.one * 0.1, cf = CFrame.new(pos), tr = 1, life = 2 })
	local bb = U.new("BillboardGui", {
		Size = UDim2.fromOffset(260, 34),
		StudsOffset = Vector3.new(0, 2, 0),
		AlwaysOnTop = true,
		MaxDistance = 120,
		Parent = p,
	})
	local lbl = U.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = color,
		Parent = bb,
	}, { U.textStroke(C(0, 0, 0), 2) })
	lbl.TextTransparency = 1
	tw(lbl, 0.25, { TextTransparency = 0 })
	tw(bb, 1.8, { StudsOffset = Vector3.new(0, 5, 0) })
	task.delay(1.1, function()
		tw(lbl, 0.7, { TextTransparency = 1 })
		local st = lbl:FindFirstChildOfClass("UIStroke")
		if st then
			tw(st, 0.7, { Transparency = 1 })
		end
	end)
end

-- тряска камеры
local shakeAmp = 0
function FX.Shake(amount)
	if not FX.ShakeEnabled then
		return
	end
	shakeAmp = math.max(shakeAmp, amount)
end

function FX.Scoop(pos)
	-- удар без звука: только облачко пыли
	FX.Burst(pos + Vector3.new(0, 1, 0), C(200, 160, 110), 8, 0.5, 8, SMOKE_TEX)
end

-- ===== ОБРАБОТЧИКИ СЕРВЕРНЫХ ЭФФЕКТОВ =====
local H = {}

H.ability = function(d)
	local pos = dronePos(d.owner, d.key)
	if pos then
		local col = Config.RarityColor(d.rarity)
		FX.Text3D(pos, "⚡ " .. d.name, col)
		FX.Burst(pos, col, 12, 0.5, 6)
	end
end

H.beams = function(d)
	local from = dronePos(d.owner, d.key)
	if not from then
		return
	end
	for _, t in ipairs(d.targets) do
		FX.Beam(from, t, d.color, 0.18, 0.45)
		FX.Burst(t, d.color, 8, 0.4, 6)
	end
end

H.zap = function(d)
	local from = dronePos(d.owner, d.key)
	if from then
		FX.Lightning(from, d.to, d.color)
	end
end

H.shot = function(d)
	local from = dronePos(d.owner, d.key)
	if from then
		FX.Laser(from, d.to + Vector3.new(math.random(-5, 5) / 10, 0.5, math.random(-5, 5) / 10), d.color)
	end
end

H.ring = function(d)
	FX.Ring(d.pos, d.radius, d.color, 0.6)
	if d.style == "fire" then
		FX.Burst(d.pos, ColorSequence.new(C(255, 200, 60), C(255, 40, 10)), 40, 2.5, 30, FIRE_TEX)
	elseif d.style == "frost" then
		FX.Burst(d.pos, C(200, 240, 255), 40, 0.8, 25)
	elseif d.style == "gold" then
		FX.Burst(d.pos, C(255, 220, 80), 40, 0.8, 20)
	else
		FX.Burst(d.pos, d.color, 25, 0.6, 22)
	end
end

H.heal = function(d)
	local hrp = ownerRoot(d.owner)
	if hrp then
		FX.Burst(hrp.Position, C(90, 255, 120), 25, 0.7, 6)
		local from = dronePos(d.owner, d.key)
		if from then
			FX.Beam(from, hrp.Position, C(90, 255, 120), 0.3, 0.5)
		end
		if d.owner == player.UserId then
			FX.Popup(hrp.Position + Vector3.new(0, 3, 0), "❤ +25", C(90, 255, 120))
		end
	end
end

H.magnet = function(d)
	FX.Ring(d.pos, d.radius, C(80, 140, 255), 0.5, true)
	local hrp = ownerRoot(d.owner)
	if hrp then
		for _, t in ipairs(d.targets) do
			FX.Beam(t, hrp.Position, C(120, 170, 255), 0.12, 0.35)
		end
	end
end

H.chain = function(d)
	local from = dronePos(d.owner, d.key)
	if not from then
		return
	end
	local prev = from
	for _, p in ipairs(d.points) do
		FX.Lightning(prev, p, C(120, 230, 255))
		prev = p
	end
end

H.recycle = function(d)
	local pos = dronePos(d.owner, d.key)
	if pos then
		FX.Burst(pos, C(90, 255, 140), 20, 0.6, 8)
		FX.Ring(pos + Vector3.new(0, 2.6, 0), 4, C(90, 255, 140), 0.4)
	end
end

H.cloud = function(d)
	local p = part({ size = Vector3.one * 0.2, cf = CFrame.new(d.pos), tr = 1, life = d.duration + 3 })
	local a = Instance.new("Attachment")
	a.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEX
	e.Color = ColorSequence.new(d.color, C(60, 140, 30))
	e.Size = NumberSequence.new(4, 8)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Rate = 25
	e.LightEmission = 0.5
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Parent = a
	task.delay(d.duration, function()
		e.Enabled = false
	end)
	FX.Ring(d.pos, d.radius, d.color, 0.8)
end

H.phase = function(d)
	local from = dronePos(d.owner, d.key)
	local col = C(200, 140, 255)
	for i, t in ipairs(d.targets) do
		task.delay(i * 0.06, function()
			FX.Burst(t, col, 14, 0.6, 8)
			local pillar = part({ size = Vector3.new(0.6, 8, 0.6), cf = CFrame.new(t + Vector3.new(0, 4, 0)), color = col, tr = 0.2, life = 0.6 })
			tw(pillar, 0.5, { Size = Vector3.new(0, 8, 0), Transparency = 1 })
		end)
	end
	if from then
		FX.Burst(from, col, 20, 0.6, 10)
	end
end

H.aura = function(d)
	local hrp, char = ownerRoot(d.owner)
	if not char then
		return
	end
	local hl = Instance.new("Highlight")
	-- аура плавно разгорается и так же плавно гаснет
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	tw(hl, 0.3, { FillTransparency = 0.75, OutlineTransparency = 0 })
	hl.FillColor = d.color or C(255, 255, 255)
	hl.OutlineColor = d.color or C(255, 255, 255)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > d.duration or not hl.Parent then
			conn:Disconnect()
			if hl.Parent then
				tw(hl, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
				task.delay(0.36, function()
					hl:Destroy()
				end)
			end
			return
		end
		if d.rainbow then
			local c = Config.Rainbow(os.clock())
			hl.FillColor = c
			hl.OutlineColor = c
		end
	end)
	if hrp then
		FX.Burst(hrp.Position, d.rainbow and Config.RainbowSequence or d.color, 40, 0.8, 14)
	end
end

H.orbital = function(d)
	local pos, r, col = d.pos, d.radius, d.color
	-- метка прицела
	local mark = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, r * 2, r * 2), cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color = C(255, 60, 30), tr = 0.6, life = 1.3 })
	tw(mark, 1.1, { Transparency = 0.2 })
	local beam = part({ size = Vector3.new(0.4, 400, 0.4), cf = CFrame.new(pos + Vector3.new(0, 200, 0)), color = col, tr = 0.3, life = 2 })
	tw(beam, 1.1, { Size = Vector3.new(2, 400, 2) })
	task.delay(1.1, function()
		beam:Destroy()
		local big = part({ size = Vector3.new(r * 0.8, 400, r * 0.8), cf = CFrame.new(pos + Vector3.new(0, 200, 0)), color = C(255, 240, 180), tr = 0, life = 1 })
		tw(big, 0.6, { Size = Vector3.new(0, 400, 0), Transparency = 1 })
		local sph = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2, cf = CFrame.new(pos), color = col, tr = 0, life = 1.2 })
		tw(sph, 0.7, { Size = Vector3.one * r * 2, Transparency = 1 })
		FX.Ring(pos + Vector3.new(0, 2.6, 0), r * 1.3, col, 0.8)
		FX.Burst(pos, ColorSequence.new(C(255, 230, 120), C(255, 80, 20)), 60, 3, 40, FIRE_TEX)
		U.play(U.Sounds.boom, 0.6, 1)
		local hrp = ownerRoot(player.UserId)
		if hrp and (hrp.Position - pos).Magnitude < 80 then
			FX.Shake(0.8)
		end
	end)
end

H.summon = function(d)
	local pos = dronePos(d.owner, d.key)
	if pos then
		FX.Burst(pos, C(255, 200, 60), 40, 0.6, 14)
		FX.Ring(pos + Vector3.new(0, 2.6, 0), 6, C(255, 200, 60), 0.5)
	end
end

H.reap = function(d)
	local from = dronePos(d.owner, d.key)
	for i, p in ipairs(d.points) do
		local col = Config.Rainbow(os.clock(), i * 0.12)
		if from then
			FX.Beam(from, p, col, 0.3, 0.6)
		end
		FX.Burst(p, Config.RainbowSequence, 30, 1, 10)
		local soul = part({ shape = Enum.PartType.Ball, size = Vector3.one * 1.5, cf = CFrame.new(p), color = col, tr = 0.2, life = 1.6 })
		tw(soul, 1.4, { CFrame = CFrame.new(p + Vector3.new(0, 14, 0)), Size = Vector3.one * 0.2, Transparency = 1 })
	end
end

H.doomsday = function(d)
	local pos, r = d.pos, d.radius
	local ground = Vector3.new(pos.X, pos.Y - 2.6, pos.Z)
	-- предупреждающие красные кольца
	for i = 0, 2 do
		task.delay(i * 0.5, function()
			FX.Ring(pos, r, C(255, 20, 20), 0.5, true)
			U.play(U.Sounds.tick, 0.6, 0.5)
		end)
	end
	task.delay(1.6, function()
		local core = part({ shape = Enum.PartType.Ball, size = Vector3.one * 4, cf = CFrame.new(ground), color = C(255, 230, 200), tr = 0, life = 3 })
		tw(core, 0.5, { Size = Vector3.one * r * 2 })
		task.delay(0.5, function()
			tw(core, 1.2, { Transparency = 1, Color = C(255, 30, 20) })
		end)
		local shell = part({ shape = Enum.PartType.Ball, size = Vector3.one * 4, cf = CFrame.new(ground), color = C(255, 30, 20), mat = Enum.Material.ForceField, life = 3 })
		tw(shell, 1.4, { Size = Vector3.one * r * 3, Transparency = 1 })
		local stem = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(30, 6, 6), cf = CFrame.new(ground + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = C(255, 90, 30), tr = 0.2, life = 3 })
		tw(stem, 2, { Size = Vector3.new(30, 12, 12), Transparency = 1 })
		local cap = part({ shape = Enum.PartType.Ball, size = Vector3.new(10, 6, 10), cf = CFrame.new(ground + Vector3.new(0, 30, 0)), color = C(255, 60, 20), tr = 0.1, life = 3 })
		tw(cap, 2, { Size = Vector3.new(36, 18, 36), CFrame = CFrame.new(ground + Vector3.new(0, 40, 0)), Transparency = 1 })
		FX.Ring(pos, r * 1.4, C(255, 40, 20), 1.2)
		FX.Burst(ground, ColorSequence.new(C(255, 220, 120), C(200, 0, 0)), 120, 5, 60, FIRE_TEX)
		U.play(U.Sounds.boom, 1, 0.6)
		U.play(U.Sounds.boom, 0.8, 0.45)
		local hrp = ownerRoot(player.UserId)
		if hrp and (hrp.Position - pos).Magnitude < 150 then
			FX.Shake(2)
		end
	end)
end

H.zdeath = function(d)
	FX.Burst(d.pos, d.glow and C(140, 255, 60) or C(120, 20, 20), 20, 0.9, 10, SMOKE_TEX)
	FX.Burst(d.pos, d.glow and C(160, 255, 90) or C(90, 140, 60), 14, 0.5, 14)
end

H.hit = function(d)
	FX.Burst(d.pos, C(200, 20, 20), 10, 0.5, 8)
	local hrp = ownerRoot(player.UserId)
	if hrp and (hrp.Position - d.pos).Magnitude < 3 then
		FX.Shake(0.35)
	end
end

H.convert = function(d)
	FX.Burst(d.pos + Vector3.new(0, 3, 0), C(140, 255, 80), 50, 0.8, 18)
	FX.Ring(d.pos + Vector3.new(0, 2.6, 0), 8, C(140, 255, 80), 0.6)
	if d.owner == player.UserId then
		U.play(U.Sounds.pop, 0.6, 1.3)
	end
end

-- эффекты ударов оружием
H.weapon = function(d)
	local pos, r = d.pos, d.radius
	if d.fx == "fire" then
		FX.Burst(pos, ColorSequence.new(C(255, 220, 100), C(255, 60, 10)), 25, 1.6, 12, FIRE_TEX)
	elseif d.fx == "shock" then
		FX.Ring(pos, r, C(255, 200, 120), 0.45)
		FX.Burst(pos - Vector3.new(0, 2, 0), C(150, 130, 100), 20, 1.2, 14, SMOKE_TEX)
		if d.owner == player.UserId then
			FX.Shake(0.4)
		end
	elseif d.fx == "sparks" then
		FX.Burst(pos, C(255, 220, 120), 18, 0.35, 18)
	elseif d.fx == "zap" then
		local hrp = ownerRoot(d.owner)
		if hrp then
			for _ = 1, 3 do
				local a = math.random() * math.pi * 2
				FX.Lightning(hrp.Position, pos + Vector3.new(math.cos(a) * r * 0.6, -1.5, math.sin(a) * r * 0.6), C(120, 230, 255))
			end
		end
	elseif d.fx == "plasma" then
		FX.Ring(pos, r, C(200, 110, 255), 0.4)
		FX.Burst(pos, ColorSequence.new(C(230, 150, 255), C(80, 200, 255)), 30, 0.8, 20)
	end
end

H.grenade = function(d)
	local g = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.9, cf = CFrame.new(d.from), color = C(80, 110, 50), mat = Enum.Material.SmoothPlastic, life = 1 })
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.65, 0, 1)
		local p = d.from:Lerp(d.pos, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0)
		g.CFrame = CFrame.new(p) * CFrame.Angles(a * 8, a * 5, 0)
		if a >= 1 then
			conn:Disconnect()
			g:Destroy()
			local sph = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2, cf = CFrame.new(d.pos), color = C(255, 180, 60), tr = 0, life = 1 })
			tw(sph, 0.5, { Size = Vector3.one * d.radius * 2, Transparency = 1 })
			FX.Ring(d.pos + Vector3.new(0, 2.6, 0), d.radius, C(255, 140, 40), 0.6)
			FX.Burst(d.pos, ColorSequence.new(C(255, 230, 120), C(255, 60, 10)), 50, 2.5, 30, FIRE_TEX)
			FX.Burst(d.pos, C(70, 60, 50), 20, 3, 12, SMOKE_TEX)
			U.play(U.Sounds.boom, 0.8, 1.1)
			local hrp = ownerRoot(player.UserId)
			if hrp and (hrp.Position - d.pos).Magnitude < 40 then
				FX.Shake(0.7)
			end
		end
	end)
end

-- зомби выбирается из-под земли: комья земли и кольцо
H.zspawn = function(d)
	local p = d.pos - Vector3.new(0, 2.5, 0)
	FX.Burst(p, C(120, 95, 65), 18, 0.8, 10, SMOKE_TEX)
	FX.Burst(p, C(140, 210, 90), 8, 0.4, 7)
	FX.Ring(p + Vector3.new(0, 0.3, 0), 4, C(150, 120, 80), 0.5)
end

H.purchase = function(d)
	local hrp = ownerRoot(d.owner)
	if hrp then
		FX.Burst(hrp.Position, ColorSequence.new(C(255, 230, 120), C(255, 160, 30)), 40, 0.8, 14)
		FX.Ring(hrp.Position, 6, C(255, 200, 60), 0.5)
	end
end

-- чужой игрок ударил оружием — проиграть его анимацию
H.swing = function(d)
	local _, char = ownerRoot(d.owner)
	if char and FX.PlayerAnim then
		FX.PlayerAnim.Play(char, d.w)
	end
end

-- находка: иконка вылетает из кучи лома и летит к игроку
H.itemdrop = function(d)
	local Items = require(Shared.ItemsConfig)
	local Icons = require(Shared.Icons)
	local it = d.c and { id = d.id, tier = d.tier, name = d.name, consum = true } or Items.ById[d.id]
	if not it then
		return
	end
	local tier = Items.Tiers[it.tier]
	local anchor = part({ size = Vector3.one * 0.2, cf = CFrame.new(d.pos), tr = 1, life = 2 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(70, 70)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Size = UDim2.fromScale(1.6, 1.6)
	glow.Position = UDim2.fromScale(-0.3, -0.3)
	glow.Image = "rbxasset://textures/particles/sparkles_main.dds"
	glow.ImageColor3 = tier.color
	glow.Parent = bb
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = (d.c and Icons[it.id] or Icons.items[it.id]) or ""
	img.Parent = bb
	FX.Burst(d.pos, tier.color, 24, 0.7, 12)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - t0) / 1.2
		local hrp = ownerRoot(player.UserId)
		if a >= 1 or not anchor.Parent or not hrp then
			conn:Disconnect()
			if anchor.Parent then
				anchor:Destroy()
			end
			return
		end
		local up = d.pos + Vector3.new(0, 5, 0)
		local p
		if a < 0.45 then
			p = d.pos:Lerp(up, math.sin(a / 0.45 * math.pi / 2))
		else
			p = up:Lerp(hrp.Position + Vector3.new(0, 1, 0), ((a - 0.45) / 0.55) ^ 2)
		end
		anchor.CFrame = CFrame.new(p)
		glow.Rotation = a * 360
	end)
	U.play(U.Sounds.pop, 0.7, 1.5)
	if FX.OnItemDrop then
		FX.OnItemDrop(it)
	end
end

H.pickup = function(d)
	local col = d.color or C(80, 230, 255)
	FX.Burst(d.pos, col:Lerp(C(255, 255, 255), 0.3), 35, 0.8, 16)
	FX.Ring(d.pos, 5, col, 0.4)
	if d.owner == player.UserId then
		U.play(U.Sounds.pop, 0.7, 1.8)
	end
end

-- выпала находка: столб света цвета редкости и вспышка
H.lootspawn = function(d)
	local Items = require(Shared.ItemsConfig)
	local it = d.c and { id = d.id, tier = d.tier, name = d.name, c = true } or Items.ById[d.id]
	if not it then
		return
	end
	local col = Items.Tiers[it.tier].color
	local beam = part({ size = Vector3.new(0.5, 26, 0.5), cf = CFrame.new(d.pos + Vector3.new(0, 13, 0)), color = col, tr = 0.35, life = 1.6 })
	tw(beam, 1.5, { Size = Vector3.new(0, 26, 0), Transparency = 1 })
	FX.Burst(d.pos, col, 26, 0.7, 12)
	FX.Ring(d.pos - Vector3.new(0, 1.2, 0), 4, col, 0.45)
	U.play(U.Sounds.pop, 0.6, 1.2)
	if FX.OnLootSpawn then
		FX.OnLootSpawn(it)
	end
end

-- ударная волна босса
H.bossslam = function(d)
	FX.Ring(d.pos + Vector3.new(0, 2.6, 0), d.radius, C(255, 90, 40), 0.55)
	FX.Ring(d.pos + Vector3.new(0, 2.6, 0), d.radius * 0.6, C(255, 200, 120), 0.35)
	FX.Burst(d.pos, C(110, 90, 70), 40, 3.5, 22, SMOKE_TEX)
	FX.Burst(d.pos, ColorSequence.new(C(255, 220, 140), C(255, 80, 20)), 30, 1.2, 30)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = part({ mat = Enum.Material.Slate, color = C(80, 72, 66), size = Vector3.new(1.4, 1.2, 1.6), cf = CFrame.new(d.pos + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4)) * CFrame.Angles(math.random(), math.random(), 0), life = 1.2 })
		tw(r, 0.9, { CFrame = r.CFrame + Vector3.new(math.cos(a) * 10, 4, math.sin(a) * 10), Transparency = 1 })
	end
	U.play(U.Sounds.boom, 1, 0.7)
	local hrp = ownerRoot(player.UserId)
	if hrp and (hrp.Position - d.pos).Magnitude < 70 then
		FX.Shake(1.1)
	end
end

H.bossdeath = function(d)
	for k = 0, 4 do
		task.delay(k * 0.35, function()
			local off = Vector3.new(math.random(-8, 8), math.random(0, 10), math.random(-8, 8))
			FX.Burst(d.pos + off, ColorSequence.new(C(255, 230, 120), C(255, 60, 10)), 60, 3, 30, FIRE_TEX)
			FX.Burst(d.pos + off, C(60, 50, 45), 30, 5, 14, SMOKE_TEX)
			U.play(U.Sounds.boom, 1, 0.8 + k * 0.1)
		end)
	end
	FX.Ring(d.pos, 45, C(255, 200, 60), 1.2)
	FX.Shake(1.5)
end

H.bossreward = function(d)
	if FX.OnBossReward then
		FX.OnBossReward(d)
	end
end

-- ===== ПЕРЕРАБОТЧИК: лом летит из рюкзака в приёмник =====
local function converterParts()
	local base = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Base")
	local conv = base and base:FindFirstChild("Converter")
	return conv and conv:FindFirstChild("IntakeMouth"), conv
end

H.convertStart = function(d)
	local mouth, conv = converterParts()
	if mouth then
		FX.Ring(mouth.Position + Vector3.new(0, 1, 0), 6, C(120, 255, 90), 0.5)
	end
	if d.owner == player.UserId then
		U.play(U.Sounds.whoosh, 0.5, 0.8)
	end
end

H.convertTick = function(d)
	local mouth, conv = converterParts()
	local hrp = ownerRoot(d.owner)
	if not mouth or not hrp then
		return
	end
	local from = hrp.Position + hrp.CFrame.LookVector * -0.8 + Vector3.new(0, 1, 0)
	local to = mouth.Position
	-- все виды ресурсов идут в Переработчик одновременно: кусочки окрашены по ресурсам
	local ids = d.res or {}
	for k = 1, math.max(3, math.min(#ids, 5)) do
		local r = #ids > 0 and Config.ResourceById[ids[(k - 1) % #ids + 1]]
		local color = r and r.color:Lerp(Color3.new(0.2, 0.2, 0.2), math.random() * 0.35) or Color3.fromHSV(0.07, 0.4, 0.45 + math.random() * 0.3)
		local chunk = part({ mat = Enum.Material.CorrodedMetal, color = color, size = Vector3.new(0.5, 0.35, 0.45), cf = CFrame.new(from), life = 1.2 })
		local t0 = os.clock() + k * 0.08
		local spin = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.55, 0, 1)
			if not chunk.Parent then
				conn:Disconnect()
				return
			end
			local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 3.5, 0)
			chunk.CFrame = CFrame.new(p) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
			if a >= 1 then
				conn:Disconnect()
				chunk:Destroy()
			end
		end)
	end
	task.delay(0.6, function()
		FX.Burst(to, C(140, 255, 90), 6, 0.35, 6)
		if conv then
			local glow = conv:FindFirstChild("Glow")
			if glow then
				glow.Color = C(220, 255, 180)
				tw(glow, 0.35, { Color = C(120, 255, 90) })
			end
		end
	end)
	if d.owner == player.UserId and math.random() < 0.6 then
		FX.Popup(to + Vector3.new(math.random(-10, 10) / 10, 2.5, 0), "+" .. d.amount .. " 🔋", C(190, 255, 90), false)
		U.play(U.Sounds.tick, 0.25, 1.6 + math.random() * 0.3)
	end
end

H.convertEnd = function(d)
	local mouth = converterParts()
	if mouth then
		FX.Burst(mouth.Position, C(190, 255, 120), 30, 0.7, 14)
	end
	if d.owner == player.UserId then
		U.play(U.Sounds.pop, 0.7, 1.1)
	end
end

H.questdone = function(d)
	local hrp = ownerRoot(d.owner)
	if hrp then
		FX.Burst(hrp.Position + Vector3.new(0, 2, 0), ColorSequence.new(C(255, 240, 150), C(255, 170, 40)), 50, 0.9, 16)
		FX.Ring(hrp.Position, 8, C(255, 210, 60), 0.6)
	end
	if d.owner == player.UserId then
		U.play(U.Sounds.pop, 0.9, 0.8)
	end
end

local POPUP_COLORS = {
	rust = C(255, 170, 100),
	tech = C(150, 210, 255),
	bio = C(150, 255, 90),
	gold = C(255, 215, 40),
	dmg = C(255, 80, 70),
	crit = C(255, 230, 60),
	kill = C(200, 255, 120),
	battery = C(190, 255, 90),
}

-- ===== РАСХОДНИКИ: свой эффект и свой звук у каждого предмета (fx/sfx в ShopConfig) =====
local ShopCfg = require(Shared.ShopConfig)

-- звук: ключ из U.Sounds или номер ассета; владелец слышит в 2D, остальные — от персонажа
local function itemSound(sfx, owner, hrp)
	for _, s in ipairs(sfx or {}) do
		local id = U.Sounds[s[1]] or ("rbxassetid://" .. s[1])
		task.delay(s[4] or 0, function()
			if owner == player.UserId or not hrp then
				U.play(id, s[2] or 0.5, s[3] or 1)
			elseif hrp.Parent and U.Volume.master * U.Volume.sfx > 0 then
				local snd = Instance.new("Sound")
				snd.SoundId = id
				snd.Volume = (s[2] or 0.5) * U.Volume.master * U.Volume.sfx
				snd.PlaybackSpeed = s[3] or 1
				snd.RollOffMaxDistance = 70
				snd.Parent = hrp
				snd.Ended:Once(function()
					snd:Destroy()
				end)
				snd:Play()
				Debris:AddItem(snd, 6)
			end
		end)
	end
end

local CONSUME = {}
-- капли/брызги стекают вниз
CONSUME.drip = function(pos, col)
	FX.Burst(pos + Vector3.new(0, 2, 0), col, 30, 0.5, 8)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local d = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.35, cf = CFrame.new(pos + Vector3.new(math.cos(a) * 1.2, 3, math.sin(a) * 1.2)), color = col, tr = 0.1, life = 1 })
		tw(d, 0.7, { CFrame = d.CFrame - Vector3.new(0, 3, 0), Size = Vector3.one * 0.1, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end
-- пульс силы: два кольца и вспышка
CONSUME.pulse = function(pos, col)
	FX.Ring(pos, 7, col, 0.5)
	task.delay(0.15, function()
		FX.Ring(pos, 11, col, 0.6)
	end)
	FX.Burst(pos, ColorSequence.new(col:Lerp(C(255, 255, 255), 0.5), col), 40, 0.7, 16)
	if FX.ShakeEnabled then
		FX.Shake(0.25)
	end
end
CONSUME.sparkle = function(pos, col)
	FX.Burst(pos + Vector3.new(0, 1.5, 0), col, 45, 0.5, 10)
	FX.Burst(pos + Vector3.new(0, 1.5, 0), C(255, 255, 255), 15, 0.3, 6)
end
CONSUME.heal = function(pos, col)
	FX.Burst(pos, C(90, 255, 120), 30, 0.7, 6)
	FX.Burst(pos + Vector3.new(0, 2, 0), col, 30, 0.5, 9)
end
-- облако золотой краски перед игроком
CONSUME.spray = function(pos, col, hrp)
	local look = hrp and hrp.CFrame.LookVector or Vector3.zAxis
	for i = 1, 5 do
		task.delay(i * 0.06, function()
			FX.Burst(pos + look * (1.5 + i * 1.6), col, 18, 0.9, 5, SMOKE_TEX)
		end)
	end
	FX.Ring(pos - Vector3.new(0, 2.6, 0), 10, col, 0.8)
end
-- телепорт: столб света
CONSUME.teleport = function(pos, col)
	local col2 = col:Lerp(C(255, 255, 255), 0.4)
	local beam = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(30, 3, 3), cf = CFrame.new(pos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = col2, tr = 0.3, life = 1 })
	tw(beam, 0.7, { Size = Vector3.new(30, 0.1, 0.1), Transparency = 1 })
	FX.Ring(pos - Vector3.new(0, 2.6, 0), 5, col, 0.5, true)
	FX.Burst(pos, col, 40, 0.6, 14)
end
-- ракета взлетает и взрывается в небе
CONSUME.flare = function(pos, col)
	local r = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.7, cf = CFrame.new(pos), color = col, life = 2 })
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 18
	light.Brightness = 3
	light.Parent = r
	tw(r, 0.8, { CFrame = CFrame.new(pos + Vector3.new(0, 26, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for i = 1, 8 do
		task.delay(i * 0.09, function()
			if r.Parent then
				FX.Burst(r.Position, ColorSequence.new(C(255, 230, 150), col), 6, 0.6, 3, FIRE_TEX)
			end
		end)
	end
	task.delay(0.85, function()
		FX.Burst(pos + Vector3.new(0, 26, 0), ColorSequence.new(C(255, 240, 180), col), 70, 1.1, 30)
		r:Destroy()
	end)
end
CONSUME.convert = function(pos, col)
	FX.Ring(pos, 6, col, 0.6, true)
	FX.Burst(pos + Vector3.new(0, 1, 0), ColorSequence.new(C(255, 170, 80), col), 50, 0.6, 12)
end
-- ящик падает с неба и взрывается
CONSUME.bomb = function(pos, col)
	local ground = pos - Vector3.new(0, 2.6, 0)
	local box = part({ size = Vector3.new(2.4, 2.4, 2.4), cf = CFrame.new(ground + Vector3.new(0, 30, 0)), color = C(120, 90, 55), mat = Enum.Material.WoodPlanks, life = 2 })
	local stripe = part({ size = Vector3.new(2.5, 0.5, 2.5), cf = box.CFrame, color = col, life = 2 })
	tw(box, 0.55, { CFrame = CFrame.new(ground + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.3, 0.8, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw(stripe, 0.55, { CFrame = CFrame.new(ground + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.3, 0.8, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.58, function()
		box:Destroy()
		stripe:Destroy()
		local sph = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2, cf = CFrame.new(ground), color = col, tr = 0, life = 1 })
		tw(sph, 0.5, { Size = Vector3.one * 24, Transparency = 1 })
		FX.Ring(ground + Vector3.new(0, 0.3, 0), 12, col, 0.6)
		FX.Burst(ground, ColorSequence.new(C(255, 230, 120), C(255, 80, 20)), 60, 2.4, 30, FIRE_TEX)
		FX.Burst(ground, C(110, 100, 90), 30, 2.5, 14, SMOKE_TEX)
		FX.Shake(0.6)
	end)
end
CONSUME.confetti = function(pos, col)
	for _, c in ipairs({ C(255, 120, 200), C(120, 220, 255), C(255, 230, 90), C(130, 255, 120) }) do
		FX.Burst(pos + Vector3.new(0, 2, 0), c, 14, 0.45, 18)
	end
end
CONSUME.swarm = function(pos, col)
	FX.Ring(pos, 8, col, 0.6, true)
	FX.Burst(pos + Vector3.new(0, 1.5, 0), col, 50, 0.35, 20)
end
CONSUME.bubbles = function(pos, col)
	for i = 1, 10 do
		local b = part({ shape = Enum.PartType.Ball, size = Vector3.one * (0.3 + math.random() * 0.5), cf = CFrame.new(pos + Vector3.new(math.random(-15, 15) / 10, -1, math.random(-15, 15) / 10)), color = col, mat = Enum.Material.Glass, tr = 0.4, life = 2 })
		tw(b, 1 + math.random() * 0.6, { CFrame = b.CFrame + Vector3.new(0, 5 + math.random() * 3, 0), Transparency = 1 }, Enum.EasingStyle.Sine)
	end
	FX.Burst(pos, col, 25, 0.5, 8)
end
CONSUME.cloud = function(pos, col)
	FX.Burst(pos + Vector3.new(0, 3, 0), col, 50, 3, 12, SMOKE_TEX)
	FX.Ring(pos - Vector3.new(0, 2.6, 0), 20, col, 1)
	FX.Burst(pos + Vector3.new(0, 3, 0), C(255, 255, 255), 30, 0.4, 20)
end
CONSUME.goldfield = function(pos, col)
	local ground = pos - Vector3.new(0, 2.6, 0)
	FX.Burst(ground, C(110, 220, 80), 20, 0.6, 8)
	task.delay(0.35, function()
		FX.Ring(ground, 30, col, 1.1)
		FX.Burst(ground + Vector3.new(0, 1, 0), C(255, 220, 80), 80, 0.9, 30)
		FX.Shake(0.4)
	end)
end
CONSUME.rainbow = function(pos, col)
	FX.Ring(pos, 10, col, 0.7)
	FX.Burst(pos + Vector3.new(0, 1.5, 0), Config.RainbowSequence, 90, 0.8, 22)
	FX.Shake(0.4)
end

H.consume = function(d)
	local item = ShopCfg.ById[d.id]
	if not item or not item.fx then
		return
	end
	local hrp = ownerRoot(d.owner)
	local pos = hrp and hrp.Position or d.pos
	local col = item.fx.color or C(255, 255, 255)
	itemSound(item.sfx, d.owner, hrp)
	H.aura({ owner = d.owner, color = col, duration = 1.5, rainbow = item.fx.style == "rainbow" })
	local f = CONSUME[item.fx.style] or CONSUME.sparkle
	f(pos, col, hrp)
end

function FX.Init(renderer)
	Renderer = renderer
	folder = Instance.new("Folder")
	folder.Name = "ZSS_FX"
	folder.Parent = workspace

	Remotes.FX.OnClientEvent:Connect(function(kind, data)
		local h = H[kind]
		if h then
			local ok, err = pcall(h, data)
			if not ok then
				warn("[ZSS FX]", kind, err)
			end
		end
	end)

	Remotes.Popup.OnClientEvent:Connect(function(pos, text, kind)
		if kind == "dmg" and not FX.ShowDamage then
			return
		end
		local resId = typeof(kind) == "string" and kind:match("^res:(%a+)$")
		if resId then
			local r = Config.ResourceById[resId]
			local Icons = require(Shared.Icons)
			FX.Popup(pos, text, r and r.color or C(255, 255, 255), false, Icons.res and Icons.res[resId])
			return
		end
		FX.Popup(pos, text, POPUP_COLORS[kind] or C(255, 255, 255), kind == "gold" or kind == "kill" or kind == "crit")
	end)

	RunService:BindToRenderStep("ZSS_Shake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shakeAmp > 0.01 then
			local cam = workspace.CurrentCamera
			local a = shakeAmp
			-- плавная тряска на шуме Перлина вместо случайных скачков каждый кадр
			local t = os.clock() * 18
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(math.noise(t, 0.3) * a * 1.6), math.rad(math.noise(0.7, t) * a * 1.6), 0)
			shakeAmp = shakeAmp * math.exp(-dt * 5)
		else
			shakeAmp = 0
		end
	end)
end

return FX
