-- Процедурные 3D-модели оружия и снаряжения (с текстурами из MaterialService.ZSS_Materials)
-- Оружие: Handle в начале координат, рабочая часть вдоль +Y.
-- Снаряжение: невидимый Root в центре части тела, детали строятся под размер этой части (box).
local IB = {}
local C = Color3.fromRGB
local M = Enum.Material
local Ball, Cyl = Enum.PartType.Ball, Enum.PartType.Cylinder
local R90 = math.rad(90)
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"

local VBASE = {
	ZSS_D_Metal = M.Metal, ZSS_D_Carbon = M.SmoothPlastic, ZSS_D_Rust = M.CorrodedMetal, ZSS_D_RustChipped = M.CorrodedMetal,
	ZSS_D_Camo = M.Fabric, ZSS_D_Hazard = M.SmoothPlastic, ZSS_D_Gold = M.Foil, ZSS_D_SciFi = M.Metal, ZSS_D_Plate = M.DiamondPlate,
	ZSS_I_Leather = M.Leather, ZSS_I_LeatherBlack = M.Leather, ZSS_I_Burlap = M.Fabric, ZSS_I_Kevlar = M.Fabric,
	ZSS_I_DarkPlate = M.DiamondPlate, ZSS_I_Tread = M.Rubber, ZSS_I_Denim = M.Fabric, ZSS_I_Wood = M.Wood,
	-- новые PBR-текстуры для предметов высоких уровней
	ZSSG_W_Damascus = M.Metal, ZSSG_W_Obsidian = M.Slate, ZSSG_W_GoldEngraved = M.Foil, ZSSG_W_DragonScale = M.Leather,
	ZSSG_W_Circuit = M.SmoothPlastic, ZSSG_W_Bone = M.Limestone, ZSSG_W_Titanium = M.Metal, ZSSG_W_Crystal = M.Ice,
	ZSSG_W_Magma = M.CrackedLava, ZSSG_W_Hazmat = M.Rubber, ZSSG_W_Steel = M.Metal, ZSSG_W_LeatherBlack = M.Leather,
	ZSSG_W_Leather = M.Leather, ZSSG_W_Plate = M.DiamondPlate, ZSSG_W_Carbon = M.SmoothPlastic, ZSSG_W_Wood = M.Wood,
	-- ткани рюкзаков
	ZSSG_B_Nylon = M.Fabric, ZSSG_B_Patchwork = M.Fabric, ZSSG_B_Molle = M.Fabric,
	ZSSG_B_Fur = M.Fabric, ZSSG_B_Quilted = M.Fabric,
}

-- Улучшенные PBR-текстуры снаряжения (MaterialService, ZSSG_W_*). Старые остаются как запасные.
local UPGRADE = {
	ZSS_D_Metal = "ZSSG_W_Steel",
	ZSS_I_Wood = "ZSSG_W_Wood",
	ZSS_I_Leather = "ZSSG_W_Leather",
	ZSS_I_LeatherBlack = "ZSSG_W_LeatherBlack",
	ZSS_D_Carbon = "ZSSG_W_Carbon",
	ZSS_D_SciFi = "ZSSG_W_SciFi",
	ZSS_I_DarkPlate = "ZSSG_W_Plate",
	ZSS_D_Plate = "ZSSG_W_Plate",
	ZSS_I_Kevlar = "ZSSG_W_Kevlar",
	ZSS_D_Camo = "ZSSG_W_Camo",
	ZSS_I_Tread = "ZSSG_W_Tread",
}
local UPGRADE_BASE = {
	ZSSG_W_Steel = M.Metal, ZSSG_W_Wood = M.Wood, ZSSG_W_Leather = M.Leather, ZSSG_W_LeatherBlack = M.Leather,
	ZSSG_W_Carbon = M.SmoothPlastic, ZSSG_W_SciFi = M.Metal, ZSSG_W_Plate = M.DiamondPlate, ZSSG_W_Kevlar = M.Fabric,
	ZSSG_W_Camo = M.Fabric, ZSSG_W_Tread = M.Rubber,
}
IB.UseUpgraded = true

local function P(model, o)
	local p = Instance.new(o.class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape and p:IsA("Part") then
		p.Shape = o.shape
	end
	p.Size = o.size
	p.CFrame = o.cf or CFrame.new()
	p.Color = o.color or C(255, 255, 255)
	p.Material = o.mat or M.SmoothPlastic
	if o.v and VBASE[o.v] then
		local v = (IB.UseUpgraded and UPGRADE[o.v]) or o.v
		p.Material = UPGRADE_BASE[v] or VBASE[o.v]
		p.MaterialVariant = v
	end
	p.Transparency = o.tr or 0
	p.Reflectance = o.refl or 0
	p.Name = o.name or "Part"
	p.Parent = model
	return p
end

local function emit(parent, color, texture, rate, size, speed, life, accel)
	local a = Instance.new("Attachment")
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK_TEX
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.Size = NumberSequence.new(size or 0.3, 0)
	e.Lifetime = NumberRange.new((life or 0.4) * 0.6, life or 0.4)
	e.Rate = rate or 10
	e.Speed = NumberRange.new((speed or 2) * 0.5, speed or 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Acceleration = accel or Vector3.zero
	e.Parent = a
	return e
end

local function vcyl(model, o)
	-- цилиндр вдоль оси Y
	o.shape = Cyl
	o.size = Vector3.new(o.len, o.d, o.d)
	o.cf = (o.cf or CFrame.new()) * CFrame.Angles(0, 0, R90)
	return P(model, o)
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- ===================== ОРУЖИЕ =====================
local W = {}

W.scraper = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.38, cf = CFrame.new(0, 0, 0), color = C(70, 50, 35), v = "ZSS_I_LeatherBlack" })
	vcyl(m, { len = 3, d = 0.3, cf = CFrame.new(0, 2.1, 0), color = C(150, 110, 70), v = "ZSS_I_Wood" })
	P(m, { size = Vector3.new(1.5, 1.3, 0.14), cf = CFrame.new(0, 4.1, 0.05) * CFrame.Angles(math.rad(12), 0, 0), color = C(200, 170, 140), v = "ZSS_D_RustChipped" })
	P(m, { size = Vector3.new(1.52, 0.18, 0.18), cf = CFrame.new(0, 3.5, 0), color = C(130, 230, 60), mat = M.Neon })
	return h
end

W.pipe = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.48, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 3.6, d = 0.4, cf = CFrame.new(0, 2.4, 0), color = C(200, 170, 150), v = "ZSS_D_Rust" })
	vcyl(m, { len = 0.5, d = 0.62, cf = CFrame.new(0, 4.25, 0), color = C(150, 150, 155), v = "ZSS_D_Metal" })
	for k = 0, 2 do
		vcyl(m, { len = 0.18, d = 0.44, cf = CFrame.new(0, 1.2 + k * 1.1, 0), color = C(220, 40, 40), mat = M.SmoothPlastic })
	end
	P(m, { size = Vector3.new(0.3, 0.3, 0.9), cf = CFrame.new(0, 4.25, 0.45), color = C(150, 150, 155), v = "ZSS_D_Metal" })
	return h
end

W.bat = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.38, color = C(40, 40, 40), v = "ZSS_I_Tread" })
	vcyl(m, { len = 1.4, d = 0.42, cf = CFrame.new(0, 1.3, 0), color = C(210, 170, 120), v = "ZSS_I_Wood" })
	vcyl(m, { len = 1.4, d = 0.58, cf = CFrame.new(0, 2.6, 0), color = C(210, 170, 120), v = "ZSS_I_Wood" })
	vcyl(m, { len = 1.6, d = 0.74, cf = CFrame.new(0, 4.0, 0), color = C(210, 170, 120), v = "ZSS_I_Wood" })
	P(m, { shape = Ball, size = Vector3.one * 0.74, cf = CFrame.new(0, 4.8, 0), color = C(210, 170, 120), v = "ZSS_I_Wood" })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local y = 3.4 + (k % 3) * 0.5
		P(m, { size = Vector3.new(0.06, 0.06, 0.7), cf = CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.45), color = C(170, 170, 170), mat = M.Metal })
	end
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		P(m, { size = Vector3.new(0.08, 0.08, 0.3), cf = CFrame.new(0, 3.2 + k * 0.12, 0) * CFrame.Angles(0, a, 0.5) * CFrame.new(0, 0, -0.4), color = C(90, 90, 90), mat = M.Metal })
	end
	return h
end

W.machete = function(m)
	local h = P(m, { name = "Handle", size = Vector3.new(0.35, 1.3, 0.5), color = C(40, 30, 25), v = "ZSS_I_LeatherBlack" })
	P(m, { size = Vector3.new(0.4, 0.15, 0.8), cf = CFrame.new(0, 0.72, 0), color = C(120, 120, 125), v = "ZSS_D_Metal" })
	P(m, { size = Vector3.new(0.08, 3.3, 0.7), cf = CFrame.new(0, 2.45, 0.05), color = C(200, 200, 205), v = "ZSS_D_Metal", refl = 0.15 })
	P(m, { size = Vector3.new(0.09, 3.2, 0.1), cf = CFrame.new(0, 2.45, -0.32), color = C(240, 240, 245), mat = M.Metal, refl = 0.3 })
	P(m, { class = "WedgePart", size = Vector3.new(0.08, 0.6, 0.7), cf = CFrame.new(0, 4.4, 0.05) * CFrame.Angles(0, math.pi, 0), color = C(200, 200, 205), v = "ZSS_D_Metal" })
	P(m, { size = Vector3.new(0.1, 1.4, 0.12), cf = CFrame.new(0, 2.3, 0.2), color = C(150, 40, 40), mat = M.SmoothPlastic, tr = 0.2 })
	return h
end

W.fireaxe = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.4, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 3.2, d = 0.34, cf = CFrame.new(0, 2.2, 0), color = C(220, 190, 140), v = "ZSS_I_Wood" })
	P(m, { size = Vector3.new(0.3, 0.7, 1.3), cf = CFrame.new(0, 3.8, 0.2), color = C(200, 25, 25), mat = M.SmoothPlastic, refl = 0.1 })
	P(m, { class = "WedgePart", size = Vector3.new(0.28, 1.2, 0.6), cf = CFrame.new(0, 3.8, -0.7) * CFrame.Angles(R90, 0, 0), color = C(210, 210, 215), v = "ZSS_D_Metal" })
	P(m, { class = "WedgePart", size = Vector3.new(0.25, 0.4, 0.8), cf = CFrame.new(0, 3.8, 1.25) * CFrame.Angles(-R90, 0, 0), color = C(200, 25, 25), mat = M.SmoothPlastic })
	return h
end

W.sledge = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.4, d = 0.42, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 3.6, d = 0.36, cf = CFrame.new(0, 2.4, 0), color = C(200, 170, 120), v = "ZSS_I_Wood" })
	P(m, { size = Vector3.new(1.0, 1.0, 2.2), cf = CFrame.new(0, 4.5, 0), color = C(140, 140, 150), v = "ZSS_I_DarkPlate" })
	for _, z in ipairs({ -1.15, 1.15 }) do
		P(m, { size = Vector3.new(1.1, 1.1, 0.12), cf = CFrame.new(0, 4.5, z), color = C(240, 190, 30), v = "ZSS_D_Hazard" })
	end
	return h
end

W.chainsaw = function(m)
	local h = P(m, { name = "Handle", size = Vector3.new(0.35, 1.2, 0.35), color = C(30, 30, 30), v = "ZSS_I_Tread" })
	P(m, { size = Vector3.new(0.9, 1.4, 1.5), cf = CFrame.new(0, 1.3, 0.3), color = C(255, 140, 30), mat = M.SmoothPlastic, refl = 0.05 })
	P(m, { size = Vector3.new(0.92, 0.5, 1.0), cf = CFrame.new(0, 1.2, 0.5), color = C(40, 40, 40), v = "ZSS_D_Carbon" })
	P(m, { size = Vector3.new(0.15, 3.4, 0.55), cf = CFrame.new(0, 3.6, 0), color = C(190, 190, 195), v = "ZSS_D_Metal" })
	for _, z in ipairs({ -0.32, 0.32 }) do
		P(m, { name = "Chain", size = Vector3.new(0.17, 3.5, 0.08), cf = CFrame.new(0, 3.62, z), color = C(60, 60, 60), mat = M.DiamondPlate })
	end
	P(m, { shape = Cyl, size = Vector3.new(0.17, 0.62, 0.62), cf = CFrame.new(0, 5.3, 0), color = C(60, 60, 60), mat = M.DiamondPlate })
	P(m, { size = Vector3.new(0.2, 0.2, 1.2), cf = CFrame.new(0, 2.2, -0.35), color = C(30, 30, 30), mat = M.SmoothPlastic })
	return h
end

W.baton = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.42, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 0.25, d = 0.7, cf = CFrame.new(0, 0.75, 0), color = C(60, 60, 70), v = "ZSS_D_Metal" })
	vcyl(m, { len = 3.2, d = 0.34, cf = CFrame.new(0, 2.5, 0), color = C(40, 40, 45), v = "ZSS_D_Carbon" })
	for k = 0, 3 do
		vcyl(m, { name = "Coil", len = 0.12, d = 0.52, cf = CFrame.new(0, 2.0 + k * 0.6, 0), color = C(80, 220, 255), mat = M.Neon })
	end
	local tip = P(m, { shape = Ball, size = Vector3.one * 0.55, cf = CFrame.new(0, 4.2, 0), color = C(120, 240, 255), mat = M.Neon })
	emit(tip, C(120, 230, 255), nil, 18, 0.35, 5, 0.25)
	local l = Instance.new("PointLight")
	l.Color = C(100, 220, 255)
	l.Range = 8
	l.Parent = tip
	return h
end

W.scythe = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.4, color = C(40, 40, 50), v = "ZSS_I_Tread" })
	vcyl(m, { len = 5, d = 0.3, cf = CFrame.new(0, 3.1, 0), color = C(120, 110, 140), v = "ZSS_D_SciFi" })
	for k = 0, 2 do
		vcyl(m, { len = 0.12, d = 0.42, cf = CFrame.new(0, 1.6 + k * 1.6, 0), color = C(200, 80, 255), mat = M.Neon })
	end
	P(m, { size = Vector3.new(0.45, 0.6, 0.45), cf = CFrame.new(0, 5.6, 0), color = C(70, 60, 90), v = "ZSS_D_SciFi" })
	-- дуга плазменного лезвия
	local last
	for k = 0, 7 do
		local t = k / 7
		local a = math.rad(-10 - t * 150)
		local r = 2.2
		local pos = Vector3.new(0, 5.6 + math.sin(-a) * 0.6 - t * 0.9, -math.sin(t * math.pi) * 0.2 - t * r)
		last = P(m, { size = Vector3.new(0.08, 0.5 - t * 0.35, 0.55), cf = CFrame.new(pos) * CFrame.Angles(-0.4 - t * 0.6, 0, 0), color = C(210, 120, 255), mat = M.Neon, tr = 0.1 })
	end
	emit(last, ColorSequence.new(C(220, 140, 255), C(80, 200, 255)), nil, 20, 0.4, 2, 0.5)
	local l = Instance.new("PointLight")
	l.Color = C(200, 120, 255)
	l.Range = 10
	l.Parent = last
	return h
end

-- ===================== НОВОЕ ОРУЖИЕ И ИНСТРУМЕНТЫ ДОБЫЧИ =====================
W.shiv = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.2, d = 0.34, color = C(30, 30, 34), v = "ZSS_I_Tread" })
	for k = 0, 3 do
		vcyl(m, { len = 0.12, d = 0.38, cf = CFrame.new(0, -0.45 + k * 0.3, 0), color = C(40, 120, 220), mat = M.SmoothPlastic })
	end
	P(m, { size = Vector3.new(0.5, 0.12, 0.3), cf = CFrame.new(0, 0.66, 0), color = C(120, 120, 125), v = "ZSS_D_Metal" })
	P(m, { size = Vector3.new(0.07, 1.5, 0.3), cf = CFrame.new(0, 1.45, 0), color = C(190, 175, 160), v = "ZSS_D_RustChipped", refl = 0.1 })
	P(m, { class = "WedgePart", size = Vector3.new(0.07, 0.45, 0.3), cf = CFrame.new(0, 2.42, 0), color = C(200, 190, 175), v = "ZSS_D_RustChipped" })
	return h
end

W.shovel = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.1, d = 0.36, color = C(40, 40, 40), v = "ZSS_I_Tread" })
	P(m, { size = Vector3.new(0.9, 0.16, 0.16), cf = CFrame.new(0, -0.6, 0), color = C(40, 40, 40), v = "ZSS_I_Tread" })
	vcyl(m, { len = 2.4, d = 0.3, cf = CFrame.new(0, 1.7, 0), color = C(95, 110, 70), v = "ZSS_I_Wood" })
	P(m, { size = Vector3.new(1.25, 1.5, 0.12), cf = CFrame.new(0, 3.55, 0.08) * CFrame.Angles(math.rad(10), 0, 0), color = C(90, 105, 70), v = "ZSS_D_Metal" })
	P(m, { class = "WedgePart", size = Vector3.new(1.25, 0.45, 0.12), cf = CFrame.new(0, 4.5, 0.25) * CFrame.Angles(math.rad(10), 0, 0), color = C(150, 150, 150), v = "ZSS_D_Metal" })
	return h
end

W.pickaxe = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.4, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 3.2, d = 0.34, cf = CFrame.new(0, 2.2, 0), color = C(170, 130, 85), v = "ZSS_I_Wood" })
	P(m, { size = Vector3.new(0.4, 0.5, 0.6), cf = CFrame.new(0, 3.9, 0), color = C(80, 80, 88), v = "ZSS_I_DarkPlate" })
	for _, s in ipairs({ -1, 1 }) do
		P(m, { size = Vector3.new(0.3, 0.32, 1.3), cf = CFrame.new(0, 3.85 - 0.12, s * 0.9) * CFrame.Angles(s * 0.25, 0, 0), color = C(160, 165, 175), v = "ZSS_D_Metal", refl = 0.1 })
		P(m, { class = "WedgePart", size = Vector3.new(0.3, 0.32, 0.5), cf = CFrame.new(0, 3.62, s * 1.75) * CFrame.Angles(s * 0.25 + (s > 0 and 0 or math.pi), 0, 0) * CFrame.Angles(-R90, 0, 0), color = C(200, 205, 215), v = "ZSS_D_Metal" })
	end
	return h
end

W.magrake = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.38, color = C(30, 30, 30), v = "ZSS_I_Tread" })
	vcyl(m, { len = 3.4, d = 0.3, cf = CFrame.new(0, 2.3, 0), color = C(60, 100, 200), v = "ZSS_D_SciFi" })
	P(m, { size = Vector3.new(2.2, 0.3, 0.3), cf = CFrame.new(0, 4.1, 0), color = C(220, 40, 40), mat = M.Metal })
	for k = -3, 3 do
		P(m, { size = Vector3.new(0.12, 0.7, 0.12), cf = CFrame.new(k * 0.33, 4.45, -0.15) * CFrame.Angles(-0.4, 0, 0), color = C(200, 200, 210), v = "ZSS_D_Metal" })
		P(m, { shape = Ball, size = Vector3.one * 0.18, cf = CFrame.new(k * 0.33, 4.75, -0.3), color = C(120, 200, 255), mat = M.Neon })
	end
	local core = P(m, { size = Vector3.new(0.5, 0.5, 0.5), cf = CFrame.new(0, 3.6, 0), color = C(80, 160, 255), mat = M.Neon })
	emit(core, C(140, 210, 255), nil, 6, 0.25, 2, 0.4)
	return h
end

W.jackhammer = function(m)
	local h = P(m, { name = "Handle", size = Vector3.new(1.6, 0.35, 0.35), color = C(30, 30, 30), v = "ZSS_I_Tread" })
	for _, s in ipairs({ -1, 1 }) do
		P(m, { size = Vector3.new(0.3, 0.7, 0.3), cf = CFrame.new(s * 0.7, 0.4, 0), color = C(30, 30, 30), v = "ZSS_I_Tread" })
	end
	P(m, { size = Vector3.new(1.0, 1.6, 0.9), cf = CFrame.new(0, 1.4, 0), color = C(250, 190, 30), mat = M.SmoothPlastic, refl = 0.05 })
	P(m, { size = Vector3.new(1.02, 0.25, 0.92), cf = CFrame.new(0, 1.0, 0), color = C(30, 30, 30), v = "ZSS_D_Hazard" })
	vcyl(m, { len = 1.2, d = 0.55, cf = CFrame.new(0, 2.7, 0), color = C(70, 72, 80), v = "ZSS_I_DarkPlate" })
	vcyl(m, { name = "Bit", len = 1.5, d = 0.22, cf = CFrame.new(0, 3.95, 0), color = C(180, 185, 195), v = "ZSS_D_Metal" })
	P(m, { class = "WedgePart", size = Vector3.new(0.22, 0.4, 0.22), cf = CFrame.new(0, 4.9, 0) * CFrame.Angles(math.pi, 0, 0), color = C(200, 205, 215), v = "ZSS_D_Metal" })
	return h
end

W.vacuum = function(m)
	local h = P(m, { name = "Handle", size = Vector3.new(0.4, 1.1, 0.4), color = C(30, 30, 34), v = "ZSS_I_Tread" })
	P(m, { size = Vector3.new(1.0, 1.0, 1.4), cf = CFrame.new(0, 1.1, 0.3), color = C(70, 180, 120), mat = M.SmoothPlastic, refl = 0.05 })
	local tank = vcyl(m, { len = 0.9, d = 0.8, cf = CFrame.new(0, 1.2, 0.95), color = C(160, 230, 255), mat = M.Glass, tr = 0.35 })
	emit(tank, C(180, 240, 255), nil, 8, 0.2, 1.5, 0.5)
	vcyl(m, { len = 2.8, d = 0.38, cf = CFrame.new(0, 3.0, 0), color = C(50, 55, 60), v = "ZSS_D_Carbon" })
	vcyl(m, { len = 0.5, d = 0.9, cf = CFrame.new(0, 4.5, 0), color = C(60, 65, 70), v = "ZSS_D_Metal" })
	local mouth = vcyl(m, { len = 0.12, d = 0.7, cf = CFrame.new(0, 4.78, 0), color = C(120, 255, 200), mat = M.Neon })
	local l = Instance.new("PointLight")
	l.Color = C(120, 255, 200)
	l.Range = 7
	l.Parent = mouth
	return h
end

W.plasmacutter = function(m)
	local h = P(m, { name = "Handle", size = Vector3.new(0.4, 1.2, 0.5), color = C(35, 35, 40), v = "ZSS_I_Tread" })
	P(m, { size = Vector3.new(0.7, 1.4, 1.1), cf = CFrame.new(0, 1.2, 0.2), color = C(80, 80, 95), v = "ZSS_D_SciFi" })
	for k = 0, 2 do
		P(m, { size = Vector3.new(0.72, 0.1, 1.12), cf = CFrame.new(0, 0.8 + k * 0.4, 0.2), color = C(255, 120, 40), mat = M.Neon })
	end
	vcyl(m, { len = 2.2, d = 0.3, cf = CFrame.new(0, 3.0, 0), color = C(150, 150, 165), v = "ZSS_D_Metal" })
	vcyl(m, { len = 0.4, d = 0.5, cf = CFrame.new(0, 4.2, 0), color = C(60, 60, 70), v = "ZSS_D_Carbon" })
	local tip = P(m, { shape = Ball, size = Vector3.one * 0.35, cf = CFrame.new(0, 4.5, 0), color = C(255, 160, 60), mat = M.Neon })
	emit(tip, ColorSequence.new(C(255, 230, 140), C(255, 90, 20)), FIRE_TEX, 25, 0.3, 3, 0.25, Vector3.new(0, 3, 0))
	local l = Instance.new("PointLight")
	l.Color = C(255, 150, 60)
	l.Range = 9
	l.Parent = tip
	return h
end

-- ===================== ОРУЖИЕ И ИНСТРУМЕНТЫ ВЫСОКИХ УРОВНЕЙ =====================
local function light(part, color, range, br)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 8
	l.Brightness = br or 1.2
	l.Parent = part
	return l
end

-- обмотанная рукоять с навершием
local function grip(m, color, v, pommelV, pommelColor)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.38, color = color or C(40, 32, 28), v = v or "ZSSG_W_LeatherBlack" })
	for k = 0, 3 do
		vcyl(m, { len = 0.07, d = 0.41, cf = CFrame.new(0, -0.42 + k * 0.28, 0), color = C(25, 25, 28), v = "ZSS_I_Tread" })
	end
	vcyl(m, { len = 0.2, d = 0.48, cf = CFrame.new(0, -0.72, 0), color = pommelColor or C(160, 165, 175), v = pommelV or "ZSSG_W_Steel" })
	return h
end

-- симметричное остриё: основание в baseCf, вершина на h выше
local function tip(m, baseCf, h, w, t, o)
	for _, s in ipairs({ -1, 1 }) do
		P(m, { class = "WedgePart", size = Vector3.new(t, h, w / 2), cf = baseCf * CFrame.new(0, h / 2, s * w / 4) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), color = o.color, v = o.v, mat = o.mat, tr = o.tr, refl = o.refl })
	end
end

W.spear = function(m)
	local h = grip(m, C(45, 35, 30))
	vcyl(m, { len = 4, d = 0.26, cf = CFrame.new(0, 2.65, 0), color = C(150, 165, 200), v = "ZSSG_W_Titanium" })
	for _, y in ipairs({ 1.4, 3.9 }) do
		vcyl(m, { len = 0.12, d = 0.33, cf = CFrame.new(0, y, 0), color = C(255, 210, 120), v = "ZSSG_W_GoldEngraved" })
	end
	vcyl(m, { len = 0.35, d = 0.38, cf = CFrame.new(0, 4.75, 0), color = C(170, 175, 185), v = "ZSSG_W_Steel" })
	P(m, { size = Vector3.new(0.1, 0.9, 0.5), cf = CFrame.new(0, 5.35, 0), color = C(225, 230, 240), v = "ZSSG_W_Damascus", refl = 0.12 })
	tip(m, CFrame.new(0, 5.8, 0), 0.65, 0.5, 0.1, { color = C(225, 230, 240), v = "ZSSG_W_Damascus", refl = 0.12 })
	for _, s in ipairs({ -1, 1 }) do
		P(m, { size = Vector3.new(0.08, 0.45, 0.12), cf = CFrame.new(0, 5.0, s * 0.3) * CFrame.Angles(s * 0.6, 0, 0), color = C(200, 205, 215), v = "ZSSG_W_Damascus" })
	end
	P(m, { size = Vector3.new(0.03, 0.9, 0.16), cf = CFrame.new(0.15, 4.35, 0.12) * CFrame.Angles(0.15, 0, 0.1), color = C(200, 30, 40), mat = M.Fabric })
	return h
end

W.katana = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.4, d = 0.32, color = C(25, 25, 30), v = "ZSSG_W_LeatherBlack" })
	for k = 0, 4 do
		P(m, { size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(0, -0.5 + k * 0.25, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), color = C(225, 210, 180), mat = M.Fabric })
	end
	vcyl(m, { len = 0.12, d = 0.4, cf = CFrame.new(0, -0.74, 0), color = C(255, 200, 110), v = "ZSSG_W_GoldEngraved" })
	vcyl(m, { len = 0.1, d = 0.78, cf = CFrame.new(0, 0.76, 0), color = C(255, 200, 110), v = "ZSSG_W_GoldEngraved" })
	P(m, { size = Vector3.new(0.12, 0.2, 0.36), cf = CFrame.new(0, 0.9, 0), color = C(255, 200, 110), v = "ZSSG_W_GoldEngraved" })
	-- слегка изогнутый клинок из трёх сегментов
	local cf = CFrame.new(0, 1.0, 0)
	for k = 1, 3 do
		cf = cf * CFrame.Angles(-0.05, 0, 0)
		P(m, { size = Vector3.new(0.07, 1.25, 0.3), cf = cf * CFrame.new(0, 0.62, 0), color = C(225, 230, 240), v = "ZSSG_W_Damascus", refl = 0.2 })
		P(m, { size = Vector3.new(0.075, 1.25, 0.05), cf = cf * CFrame.new(0, 0.62, -0.13), color = C(250, 252, 255), mat = M.Metal, refl = 0.45 })
		cf = cf * CFrame.new(0, 1.24, 0)
	end
	tip(m, cf, 0.45, 0.3, 0.07, { color = C(235, 238, 245), v = "ZSSG_W_Damascus", refl = 0.25 })
	return h
end

W.bonecleaver = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.4, d = 0.42, color = C(80, 50, 35), v = "ZSSG_W_Leather" })
	vcyl(m, { len = 0.3, d = 0.52, cf = CFrame.new(0, -0.75, 0), color = C(235, 225, 200), v = "ZSSG_W_Bone" })
	P(m, { size = Vector3.new(0.16, 2.6, 1.3), cf = CFrame.new(0, 2.15, 0.35), color = C(238, 228, 205), v = "ZSSG_W_Bone" })
	for k = 0, 5 do
		P(m, { shape = Ball, size = Vector3.new(0.3, 0.32, 0.3), cf = CFrame.new(0, 1.0 + k * 0.45, -0.32), color = C(225, 215, 190), v = "ZSSG_W_Bone" })
	end
	for k = 0, 6 do
		P(m, { class = "WedgePart", size = Vector3.new(0.12, 0.22, 0.22), cf = CFrame.new(0, 1.0 + k * 0.36, 1.1) * CFrame.Angles(0, math.pi, 0), color = C(250, 245, 230), v = "ZSSG_W_Bone" })
	end
	for _, y in ipairs({ 1.7, 2.6 }) do
		P(m, { size = Vector3.new(0.18, 0.35, 0.08), cf = CFrame.new(0, y, 0.35) * CFrame.Angles(0.5, 0, 0), color = C(255, 40, 50), mat = M.Neon })
	end
	return h
end

W.lavaaxe = function(m)
	local h = grip(m, C(30, 25, 25), nil, "ZSSG_W_Obsidian", C(60, 50, 70))
	vcyl(m, { len = 3.3, d = 0.34, cf = CFrame.new(0, 2.25, 0), color = C(45, 40, 50), v = "ZSSG_W_Obsidian" })
	P(m, { size = Vector3.new(0.4, 1.0, 0.7), cf = CFrame.new(0, 4.1, 0), color = C(255, 255, 255), v = "ZSSG_W_Magma" })
	for i = 0, 3 do
		P(m, { size = Vector3.new(0.2, 1.75 - i * 0.3, 0.32), cf = CFrame.new(0, 4.1, 0.5 + i * 0.3), color = C(255, 200, 160), v = "ZSSG_W_Magma" })
	end
	local edge = P(m, { size = Vector3.new(0.22, 1.0, 0.07), cf = CFrame.new(0, 4.1, 1.62), color = C(255, 120, 30), mat = M.Neon })
	P(m, { class = "WedgePart", size = Vector3.new(0.25, 0.45, 0.6), cf = CFrame.new(0, 4.1, -0.6) * CFrame.Angles(-R90, 0, 0), color = C(50, 45, 55), v = "ZSSG_W_Obsidian" })
	emit(edge, ColorSequence.new(C(255, 230, 140), C(255, 80, 20)), FIRE_TEX, 14, 0.35, 1.5, 0.4, Vector3.new(0, 3, 0))
	light(edge, C(255, 130, 40), 9)
	return h
end

W.thunderhammer = function(m)
	local h = grip(m, C(40, 40, 50), nil, "ZSSG_W_GoldEngraved", C(255, 210, 120))
	vcyl(m, { len = 3.2, d = 0.36, cf = CFrame.new(0, 2.2, 0), color = C(150, 160, 190), v = "ZSSG_W_Titanium" })
	for k = 0, 2 do
		vcyl(m, { name = "Coil", len = 0.08, d = 0.44, cf = CFrame.new(0, 1.6 + k * 0.7, 0), color = C(120, 230, 255), mat = M.Neon })
	end
	P(m, { size = Vector3.new(1.1, 1.1, 2.1), cf = CFrame.new(0, 4.45, 0), color = C(150, 160, 190), v = "ZSSG_W_Titanium" })
	P(m, { size = Vector3.new(1.14, 0.26, 2.14), cf = CFrame.new(0, 4.45, 0), color = C(255, 210, 120), v = "ZSSG_W_GoldEngraved" })
	for _, z in ipairs({ -1.1, 1.1 }) do
		P(m, { size = Vector3.new(1.25, 1.25, 0.16), cf = CFrame.new(0, 4.45, z), color = C(255, 210, 120), v = "ZSSG_W_GoldEngraved" })
		P(m, { size = Vector3.new(0.5, 0.5, 0.06), cf = CFrame.new(0, 4.45, z * 1.06) * CFrame.Angles(0, 0, math.rad(45)), color = C(120, 230, 255), mat = M.Neon })
	end
	local core = P(m, { size = Vector3.new(1.16, 0.08, 1.4), cf = CFrame.new(0, 4.62, 0), color = C(120, 230, 255), mat = M.Neon })
	emit(core, C(150, 230, 255), nil, 16, 0.35, 5, 0.25)
	light(core, C(120, 220, 255), 10)
	return h
end

W.crystalblade = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.3, d = 0.36, color = C(60, 70, 95), v = "ZSSG_W_Titanium" })
	vcyl(m, { len = 0.22, d = 0.46, cf = CFrame.new(0, -0.72, 0), color = C(140, 220, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
	P(m, { size = Vector3.new(0.26, 0.26, 1.3), cf = CFrame.new(0, 0.78, 0), color = C(110, 130, 170), v = "ZSSG_W_Titanium" })
	for _, s in ipairs({ -1, 1 }) do
		P(m, { size = Vector3.new(0.22, 0.5, 0.22), cf = CFrame.new(0, 0.95, s * 0.6) * CFrame.Angles(s * 0.5, 0, 0), color = C(150, 225, 255), v = "ZSSG_W_Crystal", tr = 0.15 })
	end
	P(m, { size = Vector3.new(0.12, 3.1, 0.5), cf = CFrame.new(0, 2.5, 0), color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.12 })
	local core = P(m, { size = Vector3.new(0.13, 3.0, 0.1), cf = CFrame.new(0, 2.5, 0), color = C(120, 220, 255), mat = M.Neon, tr = 0.3 })
	tip(m, CFrame.new(0, 4.05, 0), 0.75, 0.5, 0.12, { color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.12 })
	emit(core, C(180, 240, 255), nil, 10, 0.25, 1, 0.6)
	light(core, C(130, 220, 255), 9)
	return h
end

W.dragonglaive = function(m)
	local h = grip(m, C(120, 25, 25), "ZSSG_W_DragonScale", "ZSSG_W_GoldEngraved", C(255, 200, 110))
	vcyl(m, { len = 3.8, d = 0.3, cf = CFrame.new(0, 2.55, 0), color = C(140, 30, 30), v = "ZSSG_W_DragonScale" })
	for _, y in ipairs({ 1.2, 2.6, 4.4 }) do
		vcyl(m, { len = 0.14, d = 0.38, cf = CFrame.new(0, y, 0), color = C(255, 200, 110), v = "ZSSG_W_GoldEngraved" })
	end
	for _, s in ipairs({ -1, 1 }) do
		P(m, { class = "WedgePart", size = Vector3.new(0.1, 0.5, 0.3), cf = CFrame.new(0, 4.55, s * 0.28) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), color = C(245, 235, 210), v = "ZSSG_W_Bone" })
	end
	local cf = CFrame.new(0, 4.5, 0)
	local last
	for i = 0, 3 do
		cf = cf * CFrame.Angles(-0.13, 0, 0)
		last = P(m, { size = Vector3.new(0.1, 0.6, 0.55 - i * 0.06), cf = cf * CFrame.new(0, 0.3, 0.08), color = C(255, 175, 90), v = "ZSSG_W_Damascus", refl = 0.15 })
		P(m, { size = Vector3.new(0.11, 0.6, 0.05), cf = cf * CFrame.new(0, 0.3, 0.33 - i * 0.03), color = C(255, 120, 40), mat = M.Neon })
		cf = cf * CFrame.new(0, 0.58, 0)
	end
	tip(m, cf * CFrame.new(0, 0, 0.06), 0.55, 0.36, 0.1, { color = C(255, 175, 90), v = "ZSSG_W_Damascus", refl = 0.15 })
	emit(last, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 12, 0.35, 1.5, 0.4, Vector3.new(0, 3, 0))
	light(last, C(255, 140, 50), 9)
	return h
end

W.obsidianscythe = function(m)
	local h = grip(m, C(30, 25, 40), nil, "ZSSG_W_Obsidian", C(70, 55, 90))
	vcyl(m, { len = 5, d = 0.3, cf = CFrame.new(0, 3.1, 0), color = C(55, 45, 70), v = "ZSSG_W_Obsidian" })
	for k = 0, 2 do
		vcyl(m, { len = 0.1, d = 0.4, cf = CFrame.new(0, 1.6 + k * 1.6, 0), color = C(190, 90, 255), mat = M.Neon })
	end
	P(m, { size = Vector3.new(0.5, 0.65, 0.5), cf = CFrame.new(0, 5.6, 0), color = C(60, 50, 80), v = "ZSSG_W_Obsidian" })
	local last
	for k = 0, 7 do
		local t = k / 7
		local pos = Vector3.new(0, 5.75 - t * 1.0 + math.sin(t * math.pi) * 0.45, -0.2 - t * 2.3)
		local cf = CFrame.new(pos) * CFrame.Angles(-0.35 - t * 0.6, 0, 0)
		last = P(m, { size = Vector3.new(0.12, 0.55 - t * 0.4, 0.36), cf = cf, color = C(60, 45, 80), v = "ZSSG_W_Obsidian" })
		P(m, { size = Vector3.new(0.13, 0.08, 0.36), cf = cf * CFrame.new(0, -(0.55 - t * 0.4) / 2, 0), color = C(200, 100, 255), mat = M.Neon })
	end
	emit(last, ColorSequence.new(C(220, 140, 255), C(110, 40, 200)), nil, 16, 0.4, 2, 0.5)
	light(last, C(190, 90, 255), 10)
	return h
end

W.gravhammer = function(m)
	local h = grip(m, C(40, 45, 60), "ZSSG_W_Carbon", "ZSSG_W_Titanium", C(150, 160, 190))
	vcyl(m, { len = 3.3, d = 0.36, cf = CFrame.new(0, 2.25, 0), color = C(60, 70, 95), v = "ZSSG_W_Circuit" })
	P(m, { shape = Cyl, size = Vector3.new(2.2, 1.3, 1.3), cf = CFrame.new(0, 4.5, 0) * CFrame.Angles(0, R90, 0), color = C(70, 80, 105), v = "ZSSG_W_Circuit" })
	for _, z in ipairs({ -0.75, 0, 0.75 }) do
		P(m, { shape = Cyl, size = Vector3.new(0.1, 1.38, 1.38), cf = CFrame.new(0, 4.5, z) * CFrame.Angles(0, R90, 0), color = C(190, 110, 255), mat = M.Neon })
	end
	for _, z in ipairs({ -1.15, 1.15 }) do
		P(m, { shape = Cyl, size = Vector3.new(0.14, 1.0, 1.0), cf = CFrame.new(0, 4.5, z) * CFrame.Angles(0, R90, 0), color = C(150, 160, 190), v = "ZSSG_W_Titanium" })
	end
	local ring = P(m, { shape = Cyl, size = Vector3.new(0.06, 2.6, 2.6), cf = CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, R90), color = C(200, 130, 255), mat = M.Neon, tr = 0.45 })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		P(m, { shape = Ball, size = Vector3.one * 0.22, cf = CFrame.new(math.cos(a) * 1.25, 4.5, math.sin(a) * 1.25), color = C(220, 170, 255), mat = M.Neon })
	end
	emit(ring, C(200, 140, 255), nil, 10, 0.3, 1, 0.6)
	light(ring, C(180, 100, 255), 10)
	return h
end

W.omegasaber = function(m)
	local h = vcyl(m, { name = "Handle", len = 1.4, d = 0.38, color = C(50, 55, 72), v = "ZSSG_W_Circuit" })
	for k = 0, 2 do
		vcyl(m, { len = 0.06, d = 0.41, cf = CFrame.new(0, -0.4 + k * 0.3, 0), color = C(80, 255, 230), mat = M.Neon })
	end
	vcyl(m, { len = 0.45, d = 0.5, cf = CFrame.new(0, 0.9, 0), color = C(160, 170, 195), v = "ZSSG_W_Titanium" })
	for _, s in ipairs({ -1, 1 }) do
		P(m, { class = "WedgePart", size = Vector3.new(0.12, 0.4, 0.5), cf = CFrame.new(0, 0.95, s * 0.45) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), color = C(160, 170, 195), v = "ZSSG_W_Titanium" })
	end
	local blade = vcyl(m, { len = 3.8, d = 0.24, cf = CFrame.new(0, 3.05, 0), color = C(220, 255, 250), mat = M.Neon })
	vcyl(m, { len = 3.9, d = 0.44, cf = CFrame.new(0, 3.05, 0), color = C(60, 255, 220), mat = M.Neon, tr = 0.72 })
	P(m, { shape = Ball, size = Vector3.one * 0.44, cf = CFrame.new(0, 5.0, 0), color = C(60, 255, 220), mat = M.Neon, tr = 0.72 })
	emit(blade, C(120, 255, 230), nil, 14, 0.25, 1, 0.5)
	light(blade, C(60, 255, 220), 12, 1.6)
	return h
end

-- инструменты
local function pistolGrip(m, color, v)
	local h = P(m, { name = "Handle", size = Vector3.new(0.42, 1.2, 0.5), color = color or C(30, 30, 34), v = v or "ZSS_I_Tread" })
	P(m, { size = Vector3.new(0.12, 0.5, 0.36), cf = CFrame.new(0, 0.3, -0.32), color = C(30, 30, 34), v = "ZSS_I_Tread" })
	return h
end

W.drillgun = function(m)
	local h = pistolGrip(m)
	P(m, { size = Vector3.new(0.72, 1.0, 1.5), cf = CFrame.new(0, 1.15, 0.25), color = C(255, 200, 40), v = "ZSSG_W_Hazmat" })
	P(m, { size = Vector3.new(0.74, 0.3, 1.52), cf = CFrame.new(0, 1.35, 0.25), color = C(30, 30, 34), v = "ZSSG_W_Carbon" })
	P(m, { size = Vector3.new(0.6, 0.45, 0.75), cf = CFrame.new(0, -0.75, 0.05), color = C(60, 70, 95), v = "ZSSG_W_Circuit" })
	vcyl(m, { len = 0.55, d = 0.52, cf = CFrame.new(0, 1.9, 0), color = C(170, 175, 185), v = "ZSSG_W_Steel" })
	for k = 0, 7 do
		P(m, { name = "Bit", size = Vector3.new(0.16, 0.3, 0.42 - k * 0.03), cf = CFrame.new(0, 2.3 + k * 0.26, 0) * CFrame.Angles(0, k * math.rad(40), 0), color = C(160, 175, 210), v = "ZSSG_W_Titanium", refl = 0.1 })
	end
	vcyl(m, { len = 2.1, d = 0.12, cf = CFrame.new(0, 3.2, 0), color = C(160, 175, 210), v = "ZSSG_W_Titanium" })
	P(m, { class = "WedgePart", size = Vector3.new(0.14, 0.3, 0.14), cf = CFrame.new(0, 4.4, 0) * CFrame.Angles(math.pi, 0, 0), color = C(200, 205, 215), v = "ZSSG_W_Steel" })
	return h
end

W.harvester = function(m)
	local h = grip(m)
	vcyl(m, { len = 2.9, d = 0.32, cf = CFrame.new(0, 2.0, 0), color = C(255, 200, 40), v = "ZSSG_W_Hazmat" })
	P(m, { size = Vector3.new(1.9, 0.14, 1.25), cf = CFrame.new(0, 4.25, -0.1), color = C(255, 200, 40), v = "ZSSG_W_Hazmat" })
	for _, x in ipairs({ -0.92, 0.92 }) do
		P(m, { size = Vector3.new(0.12, 1.05, 1.25), cf = CFrame.new(x, 3.8, -0.1), color = C(255, 200, 40), v = "ZSSG_W_Hazmat" })
	end
	P(m, { shape = Cyl, size = Vector3.new(1.65, 0.6, 0.6), cf = CFrame.new(0, 3.75, -0.15), color = C(80, 85, 95), v = "ZSSG_W_Plate" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		P(m, { size = Vector3.new(1.6, 0.06, 0.38), cf = CFrame.new(0, 3.75, -0.15) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, 0.42), color = C(200, 205, 215), v = "ZSSG_W_Damascus", refl = 0.1 })
	end
	return h
end

W.magnetcannon = function(m)
	local h = pistolGrip(m)
	vcyl(m, { len = 2.4, d = 0.7, cf = CFrame.new(0, 1.9, 0.1), color = C(60, 70, 95), v = "ZSSG_W_Circuit" })
	for k = 0, 3 do
		vcyl(m, { name = "Coil", len = 0.1, d = 0.78, cf = CFrame.new(0, 1.0 + k * 0.55, 0.1), color = C(80, 220, 255), mat = M.Neon })
	end
	for _, x in ipairs({ -0.32, 0.32 }) do
		P(m, { size = Vector3.new(0.26, 0.95, 0.3), cf = CFrame.new(x, 3.5, 0.1), color = C(220, 40, 45), v = "ZSSG_N_RedPaint" })
		P(m, { size = Vector3.new(0.27, 0.28, 0.31), cf = CFrame.new(x, 4.05, 0.1), color = C(210, 215, 225), v = "ZSSG_W_Steel" })
	end
	local arc = P(m, { size = Vector3.new(0.4, 0.06, 0.06), cf = CFrame.new(0, 4.05, 0.1), color = C(140, 230, 255), mat = M.Neon })
	emit(arc, C(150, 230, 255), nil, 16, 0.25, 4, 0.2)
	light(arc, C(100, 220, 255), 8)
	return h
end

W.excavator = function(m)
	local h = grip(m)
	vcyl(m, { len = 2.8, d = 0.34, cf = CFrame.new(0, 2.0, 0), color = C(255, 195, 35), v = "ZSSG_W_Hazmat" })
	vcyl(m, { len = 2.0, d = 0.14, cf = CFrame.new(0.28, 2.3, 0), color = C(225, 230, 240), mat = M.Metal, refl = 0.35 })
	vcyl(m, { len = 1.2, d = 0.22, cf = CFrame.new(0.28, 1.6, 0), color = C(50, 50, 55), v = "ZSSG_W_Carbon" })
	P(m, { size = Vector3.new(1.45, 1.1, 0.14), cf = CFrame.new(0, 4.0, 0.35) * CFrame.Angles(-0.2, 0, 0), color = C(255, 195, 35), v = "ZSSG_W_Hazmat" })
	P(m, { size = Vector3.new(1.45, 0.14, 1.0), cf = CFrame.new(0, 3.45, -0.1), color = C(255, 195, 35), v = "ZSSG_W_Hazmat" })
	for _, x in ipairs({ -0.72, 0.72 }) do
		P(m, { size = Vector3.new(0.12, 1.0, 0.95), cf = CFrame.new(x, 3.9, -0.08), color = C(230, 175, 30), v = "ZSSG_W_Hazmat" })
	end
	for k = -1.5, 1.5 do
		P(m, { class = "WedgePart", size = Vector3.new(0.22, 0.12, 0.35), cf = CFrame.new(k * 0.4, 3.45, -0.75) * CFrame.Angles(0, math.pi, 0), color = C(190, 195, 205), v = "ZSSG_W_Steel" })
	end
	return h
end

W.laserdrill = function(m)
	local h = pistolGrip(m, C(40, 45, 60), "ZSSG_W_Carbon")
	vcyl(m, { len = 1.6, d = 0.8, cf = CFrame.new(0, 1.4, 0.1), color = C(160, 170, 200), v = "ZSSG_W_Titanium" })
	for k = 0, 3 do
		vcyl(m, { len = 0.08, d = 0.95, cf = CFrame.new(0, 0.85 + k * 0.35, 0.1), color = C(60, 65, 75), v = "ZSSG_W_Plate" })
	end
	vcyl(m, { len = 0.5, d = 0.45, cf = CFrame.new(0, 2.45, 0.1), color = C(40, 40, 45), v = "ZSSG_W_Carbon" })
	vcyl(m, { len = 0.1, d = 0.36, cf = CFrame.new(0, 2.72, 0.1), color = C(255, 50, 60), mat = M.Neon })
	local beam = vcyl(m, { len = 1.6, d = 0.09, cf = CFrame.new(0, 3.55, 0.1), color = C(255, 60, 70), mat = M.Neon, tr = 0.15 })
	P(m, { shape = Ball, size = Vector3.one * 0.3, cf = CFrame.new(0, 4.35, 0.1), color = C(255, 120, 120), mat = M.Neon })
	emit(beam, C(255, 150, 120), nil, 16, 0.2, 3, 0.25)
	light(beam, C(255, 60, 70), 8)
	return h
end

W.cryoextractor = function(m)
	local h = pistolGrip(m, C(50, 60, 80), "ZSSG_W_Carbon")
	vcyl(m, { len = 1.5, d = 0.75, cf = CFrame.new(0, 1.45, 0.1), color = C(200, 240, 255), v = "ZSSG_W_Crystal", tr = 0.2 })
	vcyl(m, { len = 1.3, d = 0.45, cf = CFrame.new(0, 1.45, 0.1), color = C(140, 230, 255), mat = M.Neon, tr = 0.35 })
	for _, y in ipairs({ 0.68, 2.22 }) do
		vcyl(m, { len = 0.12, d = 0.82, cf = CFrame.new(0, y, 0.1), color = C(170, 180, 200), v = "ZSSG_W_Titanium" })
	end
	vcyl(m, { len = 1.2, d = 0.22, cf = CFrame.new(0, 2.85, 0.1), color = C(170, 180, 200), v = "ZSSG_W_Titanium" })
	tip(m, CFrame.new(0, 3.45, 0.1), 0.6, 0.55, 0.3, { color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
	local noz = P(m, { shape = Ball, size = Vector3.one * 0.26, cf = CFrame.new(0, 3.45, 0.1), color = C(200, 245, 255), mat = M.Neon })
	emit(noz, C(220, 250, 255), nil, 14, 0.4, 2, 0.6, Vector3.new(0, -1, 0))
	light(noz, C(150, 230, 255), 8)
	return h
end

W.gravitywell = function(m)
	local h = grip(m, C(40, 45, 60), "ZSSG_W_Carbon", "ZSSG_W_Titanium")
	vcyl(m, { len = 2.7, d = 0.3, cf = CFrame.new(0, 1.95, 0), color = C(60, 70, 95), v = "ZSSG_W_Circuit" })
	local cy = 4.1
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		P(m, { size = Vector3.new(0.18, 0.52, 0.22), cf = CFrame.new(0, cy, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, 0.88), color = C(150, 160, 190), v = "ZSSG_W_Titanium" })
	end
	P(m, { shape = Cyl, size = Vector3.new(0.08, 1.6, 1.6), cf = CFrame.new(0, cy, 0), color = C(190, 100, 255), mat = M.Neon, tr = 0.3 })
	local core = P(m, { shape = Ball, size = Vector3.one * 0.85, cf = CFrame.new(0, cy, 0), color = C(10, 5, 20), mat = M.SmoothPlastic, refl = 0.3 })
	emit(core, ColorSequence.new(C(220, 170, 255), C(90, 30, 180)), nil, 18, 0.25, 1.5, 0.5)
	light(core, C(170, 90, 255), 10)
	return h
end

W.lavaforge = function(m)
	local h = grip(m, C(30, 25, 25), nil, "ZSSG_W_Obsidian", C(60, 50, 70))
	vcyl(m, { len = 2.0, d = 0.34, cf = CFrame.new(0, 1.6, 0), color = C(45, 40, 50), v = "ZSSG_W_Obsidian" })
	vcyl(m, { len = 1.3, d = 1.15, cf = CFrame.new(0, 3.2, 0), color = C(255, 255, 255), v = "ZSSG_W_Magma" })
	for _, y in ipairs({ 2.6, 3.8 }) do
		vcyl(m, { len = 0.12, d = 1.22, cf = CFrame.new(0, y, 0), color = C(55, 50, 60), v = "ZSSG_W_Obsidian" })
	end
	local melt = vcyl(m, { len = 0.08, d = 0.95, cf = CFrame.new(0, 3.88, 0), color = C(255, 140, 30), mat = M.Neon })
	P(m, { class = "WedgePart", size = Vector3.new(0.4, 0.35, 0.5), cf = CFrame.new(0, 3.75, -0.75) * CFrame.Angles(0, math.pi, 0), color = C(55, 50, 60), v = "ZSSG_W_Obsidian" })
	emit(melt, ColorSequence.new(C(255, 230, 140), C(255, 70, 20)), FIRE_TEX, 18, 0.4, 2, 0.45, Vector3.new(0, 4, 0))
	light(melt, C(255, 130, 40), 10)
	return h
end

W.nanoswarm = function(m)
	local h = grip(m, C(40, 45, 60), "ZSSG_W_Carbon", "ZSSG_W_Titanium")
	vcyl(m, { len = 2.6, d = 0.3, cf = CFrame.new(0, 1.9, 0), color = C(60, 70, 95), v = "ZSSG_W_Circuit" })
	local cy = 3.9
	local core = P(m, { size = Vector3.new(0.55, 0.55, 0.55), cf = CFrame.new(0, cy, 0), color = C(70, 80, 105), v = "ZSSG_W_Circuit" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local pos = CFrame.new(0, cy, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, (k % 2 == 0) and 0.25 or -0.25, 0.62)
		P(m, { size = Vector3.new(0.38, 0.38, 0.38), cf = pos * CFrame.Angles(0.4, 0.3, 0), color = C(70, 80, 105), v = "ZSSG_W_Circuit" })
		P(m, { size = Vector3.new(0.4, 0.06, 0.4), cf = pos * CFrame.Angles(0.4, 0.3, 0), color = C(80, 255, 220), mat = M.Neon })
	end
	emit(core, C(120, 255, 230), nil, 30, 0.12, 3, 0.6)
	light(core, C(80, 255, 220), 9)
	return h
end

W.singularity = function(m)
	local h = grip(m, C(60, 45, 30), "ZSSG_W_Leather", "ZSSG_W_GoldEngraved", C(255, 210, 120))
	vcyl(m, { len = 2.6, d = 0.32, cf = CFrame.new(0, 1.9, 0), color = C(255, 210, 120), v = "ZSSG_W_GoldEngraved" })
	local cy = 4.05
	for i, rot in ipairs({ CFrame.Angles(0, 0, 0), CFrame.Angles(R90, 0, 0), CFrame.Angles(0, 0, R90) }) do
		for k = 0, 13 do
			local a = k / 14 * math.pi * 2
			P(m, { size = Vector3.new(0.1, 0.12, 0.42), cf = CFrame.new(0, cy, 0) * rot * CFrame.Angles(0, a, 0) * CFrame.new(0.6 + i * 0.12, 0, 0), color = C(255, 210, 120), v = "ZSSG_W_GoldEngraved" })
		end
	end
	local core = P(m, { shape = Ball, size = Vector3.one * 0.6, cf = CFrame.new(0, cy, 0), color = C(240, 220, 255), mat = M.Neon })
	P(m, { shape = Ball, size = Vector3.one * 0.95, cf = CFrame.new(0, cy, 0), color = C(170, 110, 255), mat = M.Neon, tr = 0.7 })
	emit(core, ColorSequence.new(C(255, 240, 200), C(170, 110, 255)), nil, 20, 0.25, 2, 0.5)
	light(core, C(220, 180, 255), 12, 1.6)
	return h
end

function IB.Weapon(item)
	local m = newModel(item.id)
	local f = W[item.id] or W.scraper
	local handle = f(m)
	handle.Name = "Handle"
	m.PrimaryPart = handle
	m:SetAttribute("ItemId", item.id)
	return m
end

-- ===================== СНАРЯЖЕНИЕ =====================
-- цвета/текстуры по уровню
local ARMOR = {
	{ main = C(210, 190, 150), v = "ZSS_I_Burlap", trim = C(110, 80, 50), trimV = "ZSS_I_Leather" },
	{ main = C(150, 100, 60), v = "ZSS_I_Leather", trim = C(60, 40, 30), trimV = "ZSS_I_LeatherBlack" },
	{ main = C(90, 95, 80), v = "ZSS_I_Kevlar", trim = C(50, 55, 45), trimV = "ZSS_D_Camo" },
	{ main = C(200, 210, 180), v = "ZSS_D_Camo", trim = C(70, 75, 70), trimV = "ZSS_I_DarkPlate" },
	{ main = C(80, 80, 95), v = "ZSS_D_SciFi", trim = C(255, 190, 30), trimV = "ZSS_D_Hazard" },
}

local function root(m)
	local r = P(m, { name = "Root", size = Vector3.one * 0.2, tr = 1 })
	m.PrimaryPart = r
	return r
end

-- стили снаряжения уровней 6–15 (общие для брони, шлемов, перчаток и ботинок)
local HI = {
	[6] = { main = C(165, 175, 200), v = "ZSSG_W_Titanium", trim = C(80, 85, 100), trimV = "ZSSG_W_Plate", plates = true },
	[7] = { main = C(175, 40, 40), v = "ZSSG_W_DragonScale", trim = C(255, 200, 110), trimV = "ZSSG_W_GoldEngraved", spikes = C(245, 235, 210), spikeV = "ZSSG_W_Bone", glow = C(255, 120, 40) },
	[8] = { main = C(238, 228, 205), v = "ZSSG_W_Bone", trim = C(70, 50, 40), trimV = "ZSSG_W_Leather", ribs = true, spikes = C(245, 235, 210), spikeV = "ZSSG_W_Bone" },
	[9] = { main = C(255, 205, 40), v = "ZSSG_W_Hazmat", trim = C(40, 40, 44), trimV = "ZSS_I_Tread", tanks = true, glow = C(130, 255, 80) },
	[10] = { main = C(175, 225, 255), v = "ZSSG_W_Crystal", trim = C(90, 100, 130), trimV = "ZSSG_W_Titanium", crystals = true, glow = C(120, 220, 255) },
	[11] = { main = C(255, 230, 210), v = "ZSSG_W_Magma", trim = C(50, 45, 55), trimV = "ZSSG_W_Obsidian", glow = C(255, 120, 30), fire = true },
	[12] = { main = C(70, 55, 90), v = "ZSSG_W_Obsidian", trim = C(45, 40, 55), trimV = "ZSSG_W_Obsidian", spikes = C(60, 50, 75), spikeV = "ZSSG_W_Obsidian", glow = C(190, 90, 255) },
	[13] = { main = C(60, 70, 92), v = "ZSSG_W_Circuit", trim = C(35, 38, 48), trimV = "ZSSG_W_Carbon", glow = C(80, 230, 255) },
	[14] = { main = C(255, 215, 130), v = "ZSSG_W_GoldEngraved", trim = C(150, 25, 35), trimV = "ZSSG_W_Leather", gem = C(255, 50, 80), cape = C(170, 20, 35), plates = true },
	[15] = { main = C(205, 215, 235), v = "ZSSG_W_Titanium", trim = C(55, 62, 82), trimV = "ZSSG_W_Circuit", glow = C(80, 255, 230), reactor = true, wings = true, plates = true },
}
IB.HighStyles = HI

local function glowLight(part, st, range)
	if st.glow then
		local l = Instance.new("PointLight")
		l.Color = st.glow
		l.Range = range or 6
		l.Brightness = 1
		l.Parent = part
	end
end

local function armorHigh(m, t, box)
	local st = HI[t]
	local w, h, d = box.X, box.Y, box.Z
	P(m, { name = "Vest", size = Vector3.new(w * 1.08, h * 0.94, d * 1.3), cf = CFrame.new(0, -h * 0.02, 0), color = st.main, v = st.v })
	P(m, { size = Vector3.new(w * 0.62, h * 0.13, d * 1.34), cf = CFrame.new(0, h * 0.48, 0), color = st.trim, v = st.trimV })
	P(m, { name = "Belt", size = Vector3.new(w * 1.1, h * 0.12, d * 1.34), cf = CFrame.new(0, -h * 0.42, 0), color = st.trim, v = st.trimV })
	P(m, { size = Vector3.new(w * 0.2, h * 0.14, 0.08), cf = CFrame.new(0, -h * 0.42, -d * 0.7), color = C(255, 215, 130), v = "ZSSG_W_GoldEngraved" })
	-- наплечники всегда, слоистые
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			P(m, { name = "Pauldron", size = Vector3.new(w * (0.46 - k * 0.08), h * 0.16, d * (1.5 - k * 0.15)), cf = CFrame.new(sx * w * (0.52 + k * 0.06), h * (0.47 - k * 0.14), 0) * CFrame.Angles(0, 0, -sx * (0.28 + k * 0.12)), color = k == 0 and st.main or st.trim, v = k == 0 and st.v or st.trimV })
		end
		if st.spikes then
			for k = 0, 2 do
				P(m, { class = "WedgePart", size = Vector3.new(0.1, h * 0.22, h * 0.14), cf = CFrame.new(sx * w * (0.4 + k * 0.1), h * 0.62, (k - 1) * d * 0.35) * CFrame.Angles(0, R90 * sx, -sx * 0.4), color = st.spikes, v = st.spikeV })
			end
		end
	end
	if st.plates then
		for k = 0, 2 do
			P(m, { name = "Plate", size = Vector3.new(w * (0.78 - k * 0.1), h * 0.2, 0.12), cf = CFrame.new(0, h * (0.28 - k * 0.22), -d * 0.68 - k * 0.02) * CFrame.Angles(-0.08, 0, 0), color = st.main:Lerp(C(255, 255, 255), 0.08 * k), v = st.v })
			P(m, { size = Vector3.new(w * (0.8 - k * 0.1), 0.04, 0.13), cf = CFrame.new(0, h * (0.18 - k * 0.22), -d * 0.68 - k * 0.02), color = st.trim, v = st.trimV })
		end
	end
	if st.ribs then
		for k = 0, 3 do
			for _, sx in ipairs({ -1, 1 }) do
				P(m, { size = Vector3.new(w * 0.38, h * 0.06, 0.1), cf = CFrame.new(sx * w * 0.2, h * (0.3 - k * 0.17), -d * 0.68) * CFrame.Angles(0, 0, sx * 0.25), color = st.main, v = st.v })
			end
		end
		P(m, { size = Vector3.new(w * 0.08, h * 0.75, 0.12), cf = CFrame.new(0, h * 0.05, -d * 0.69), color = st.main, v = st.v })
		local sk = P(m, { name = "Skull", shape = Ball, size = Vector3.new(w * 0.3, h * 0.28, 0.22), cf = CFrame.new(0, h * 0.32, -d * 0.74), color = st.main, v = st.v })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { shape = Ball, size = Vector3.one * w * 0.07, cf = sk.CFrame * CFrame.new(sx * w * 0.06, 0, -0.1), color = C(255, 60, 40), mat = M.Neon })
		end
	end
	if st.tanks then
		for _, sx in ipairs({ -1, 1 }) do
			local tk = P(m, { shape = Cyl, size = Vector3.new(h * 0.8, w * 0.28, w * 0.28), cf = CFrame.new(sx * w * 0.22, 0, d * 0.85) * CFrame.Angles(0, 0, R90), color = C(220, 225, 230), v = "ZSSG_W_Steel" })
			P(m, { shape = Cyl, size = Vector3.new(h * 0.4, w * 0.29, w * 0.29), cf = tk.CFrame, color = st.glow, mat = M.Neon, tr = 0.3 })
		end
		local visor = P(m, { size = Vector3.new(w * 0.5, h * 0.18, 0.08), cf = CFrame.new(0, h * 0.2, -d * 0.68), color = st.glow, mat = M.Neon })
		glowLight(visor, st)
	end
	if st.crystals then
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2
			P(m, { name = "Crystal", size = Vector3.new(w * 0.1, h * (0.3 + (k % 3) * 0.1), w * 0.1), cf = CFrame.new(math.cos(a) * w * 0.38, h * 0.55, math.sin(a) * d * 0.5) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), color = st.main, v = st.v, tr = 0.1 })
		end
		local core = P(m, { size = Vector3.new(w * 0.22, w * 0.22, 0.1), cf = CFrame.new(0, h * 0.15, -d * 0.7) * CFrame.Angles(0, 0, math.rad(45)), color = st.glow, mat = M.Neon })
		glowLight(core, st)
	end
	if st.fire then
		local crack = P(m, { size = Vector3.new(w * 0.06, h * 0.7, 0.08), cf = CFrame.new(0, 0, -d * 0.68), color = st.glow, mat = M.Neon })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(w * 0.35, w * 0.05, 0.08), cf = CFrame.new(sx * w * 0.15, h * 0.1, -d * 0.68) * CFrame.Angles(0, 0, sx * 0.5), color = st.glow, mat = M.Neon })
		end
		emit(crack, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 6, 0.3, 1.5, 0.4, Vector3.new(0, 3, 0))
		glowLight(crack, st)
	elseif st.glow and not st.tanks and not st.crystals and not st.reactor then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(0.06, h * 0.75, 0.06), cf = CFrame.new(sx * w * 0.4, 0, -d * 0.67), color = st.glow, mat = M.Neon })
		end
		local c = P(m, { size = Vector3.new(w * 0.3, 0.06, 0.06), cf = CFrame.new(0, h * 0.3, -d * 0.67), color = st.glow, mat = M.Neon })
		glowLight(c, st)
	end
	if st.gem then
		local g = P(m, { name = "Gem", size = Vector3.new(w * 0.16, w * 0.16, 0.14), cf = CFrame.new(0, h * 0.36, -d * 0.74) * CFrame.Angles(0, 0, math.rad(45)), color = st.gem, mat = M.Glass, refl = 0.4 })
		local l = Instance.new("PointLight")
		l.Color = st.gem
		l.Range = 4
		l.Parent = g
	end
	if st.cape then
		P(m, { name = "Cape", size = Vector3.new(w * 1.0, h * 1.5, 0.06), cf = CFrame.new(0, -h * 0.28, d * 0.72) * CFrame.Angles(-0.08, 0, 0), color = st.cape, mat = M.Fabric })
	end
	if st.reactor then
		local core = P(m, { name = "Reactor", shape = Cyl, size = Vector3.new(0.18, h * 0.42, h * 0.42), cf = CFrame.new(0, h * 0.12, -d * 0.74) * CFrame.Angles(0, R90, 0), color = st.glow, mat = M.Neon })
		P(m, { shape = Cyl, size = Vector3.new(0.14, h * 0.55, h * 0.55), cf = CFrame.new(0, h * 0.12, -d * 0.7) * CFrame.Angles(0, R90, 0), color = st.trim, v = st.trimV })
		glowLight(core, st, 9)
		P(m, { name = "Backpack", size = Vector3.new(w * 0.75, h * 0.8, d * 0.5), cf = CFrame.new(0, 0, d * 0.85), color = st.trim, v = st.trimV })
	end
	if st.wings then
		for _, sx in ipairs({ -1, 1 }) do
			for k = 0, 3 do
				local f = P(m, { name = "Wing", size = Vector3.new(w * (0.9 - k * 0.15), 0.08, d * 0.32), cf = CFrame.new(sx * w * (0.55 + k * 0.08), h * (0.35 - k * 0.22), d * 1.15) * CFrame.Angles(0, 0, sx * (0.55 - k * 0.15)) * CFrame.new(sx * w * 0.35, 0, 0), color = st.glow, mat = M.Neon, tr = 0.25 + k * 0.1 })
				if k == 0 then
					emit(f, st.glow, nil, 6, 0.2, 1, 0.6)
				end
			end
		end
	end
end

-- качественные 3D-модели брони (ReplicatedStorage.ZSS.ArmorMeshes/armorN, один MeshPart).
-- Используются собственные оси меша: грудь смотрит в -Z, Yaw (градусы) доворачивает меш, если он сгенерирован боком.
-- SX / SY / SZ — размер относительно торса по осям (меш растягивается, чтобы обернуть торс),
-- Up — сдвиг вверх (доля высоты торса), Back — сдвиг назад (доля глубины торса).
-- общая палитра комплекта уровня (по шлему): поддоспешник под 3D-бронёй, рукава перчаток и голенища ботинок.
-- { цвет, MaterialVariant или nil, материал без варианта }
-- Поддоспешник облегает торс, чтобы в просветах брони была ткань/кольчуга, а не рубашка игрока.
local SET_COLORS = {
	{ C(196, 180, 128), "ZSS_I_Burlap" }, -- строительная каска: светлый брезент
	{ C(140, 24, 28), "ZSS_I_Leather" }, -- мотошлем: красная кожа
	{ C(92, 98, 72), "ZSS_D_Camo" }, -- военная каска: камуфляж
	{ C(76, 84, 56), "ZSS_I_Kevlar" }, -- противогаз: оливковый брезент
	{ C(46, 44, 48), "ZSSG_W_Steel" }, -- «Жнец»: воронёное железо
	{ C(46, 70, 150), "ZSSG_B_Quilted" }, -- «Бастион»: синяя ткань, как гребень шлема
	{ C(110, 26, 24), "ZSSG_W_DragonScale" },
	{ C(84, 58, 40), "ZSS_I_Leather" },
	{ C(226, 216, 160), nil, M.Rubber }, -- химзащита: светлая резина
	{ C(150, 200, 240), "ZSSG_W_Crystal" },
	{ C(52, 36, 30), "ZSSG_W_Magma" },
	{ C(28, 22, 38), "ZSSG_W_Obsidian" },
	{ C(30, 48, 110), "ZSSG_W_Circuit" }, -- нано: тёмно-синий
	{ C(128, 20, 30), "ZSSG_B_Quilted" },
	{ C(232, 236, 242), nil, M.SmoothPlastic }, -- «Омега»: белый глянец
}

local function armorMesh(m, t, box)
	local z = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	local lib = z and z:FindFirstChild("ArmorMeshes")
	local tpl = lib and lib:FindFirstChild("armor" .. t)
	local src = tpl and tpl:FindFirstChildWhichIsA("BasePart", true)
	if not src then
		return false
	end
	local w, h, d = box.X, box.Y, box.Z
	local yaw = math.rad(tpl:GetAttribute("Yaw") or 0)
	local size = Vector3.new(w * (tpl:GetAttribute("SX") or 1.5), h * (tpl:GetAttribute("SY") or 1.2), d * (tpl:GetAttribute("SZ") or 2.3))
	if math.abs(math.cos(yaw)) < 0.5 then
		size = Vector3.new(size.Z, size.Y, size.X)
	end
	local under = SET_COLORS[t]
	if under and tpl:GetAttribute("Under") ~= false then
		P(m, { name = "Under", size = Vector3.new(w * 1.04, h * 0.98, d * 1.08), color = under[1], v = under[2], mat = under[3] })
		-- у R15 верхний торс ниже ширины; пояс закрывает LowerTorso, чтобы броня не обрывалась над поясом
		if h < w * 0.9 then
			P(m, { name = "Belt", size = Vector3.new(w * 1.06, h * 0.3, d * 1.12), cf = CFrame.new(0, -h * 0.62, 0), color = under[1], v = under[2], mat = under[3] })
		end
	end
	local p = src:Clone()
	p.Size = size
	p.CFrame = CFrame.new(0, h * (tpl:GetAttribute("Up") or -0.04), d * (tpl:GetAttribute("Back") or 0)) * CFrame.Angles(0, yaw, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Name = "Vest"
	p.Parent = m
	local st = HI[t] or ARMOR[t]
	if st and st.glow then
		local l = Instance.new("PointLight")
		l.Color = st.glow
		l.Range = 7
		l.Brightness = 1.2
		l.Parent = p
	end
	return true
end

function IB.Armor(item, box)
	box = box or Vector3.new(2, 1.6, 1)
	local t = item.tier
	do
		local m = newModel(item.id)
		root(m)
		if armorMesh(m, t, box) then
			return m
		end
		m:Destroy()
	end
	if t >= 6 and HI[t] then
		local m = newModel(item.id)
		root(m)
		armorHigh(m, t, box)
		return m
	end
	local st = ARMOR[t]
	local m = newModel(item.id)
	root(m)
	local w, h, d = box.X, box.Y, box.Z
	P(m, { name = "Vest", size = Vector3.new(w * 1.07, h * 0.92, d * 1.28), cf = CFrame.new(0, -h * 0.02, 0), color = st.main, v = st.v })
	-- воротник
	P(m, { size = Vector3.new(w * 0.6, h * 0.12, d * 1.3), cf = CFrame.new(0, h * 0.48, 0), color = st.trim, v = st.trimV })
	if t >= 2 then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(w * 0.12, h * 0.95, d * 1.32), cf = CFrame.new(sx * w * 0.28, 0, 0), color = st.trim, v = st.trimV })
		end
		for k = 0, 2 do
			P(m, { shape = Ball, size = Vector3.one * 0.12, cf = CFrame.new(-w * 0.28, h * (0.3 - k * 0.3), -d * 0.66), color = C(200, 200, 200), mat = M.Metal })
		end
	end
	if t >= 3 then
		P(m, { name = "Plate", size = Vector3.new(w * 0.62, h * 0.55, 0.14), cf = CFrame.new(0, h * 0.1, -d * 0.68), color = C(110, 115, 105), v = "ZSS_I_DarkPlate" })
		for k = -1, 1 do
			P(m, { name = "Pouch", size = Vector3.new(w * 0.22, h * 0.24, 0.3), cf = CFrame.new(k * w * 0.3, -h * 0.32, -d * 0.74), color = st.trim:Lerp(C(255, 255, 255), 0.3), v = "ZSS_I_Kevlar" })
		end
	end
	if t >= 4 then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { name = "Pauldron", size = Vector3.new(w * 0.42, h * 0.22, d * 1.45), cf = CFrame.new(sx * w * 0.5, h * 0.45, 0) * CFrame.Angles(0, 0, -sx * 0.25), color = st.trim, v = st.trimV })
		end
		P(m, { name = "Radio", size = Vector3.new(w * 0.2, h * 0.35, 0.25), cf = CFrame.new(w * 0.28, h * 0.25, -d * 0.78), color = C(40, 40, 40), v = "ZSS_D_Carbon" })
		P(m, { size = Vector3.new(0.05, h * 0.5, 0.05), cf = CFrame.new(w * 0.32, h * 0.65, -d * 0.78), color = C(30, 30, 30), mat = M.SmoothPlastic })
	end
	if t >= 5 then
		local core = P(m, { name = "Reactor", shape = Cyl, size = Vector3.new(0.3, h * 0.5, h * 0.5), cf = CFrame.new(0, h * 0.1, -d * 0.78) * CFrame.Angles(0, R90, 0), color = C(255, 160, 30), mat = M.Neon })
		local l = Instance.new("PointLight")
		l.Color = C(255, 170, 40)
		l.Range = 8
		l.Parent = core
		P(m, { name = "Backpack", size = Vector3.new(w * 0.8, h * 0.85, d * 0.6), cf = CFrame.new(0, 0, d * 0.85), color = C(70, 70, 85), v = "ZSS_D_SciFi" })
		for _, sx in ipairs({ -1, 1 }) do
			local ex = P(m, { name = "Exhaust", shape = Cyl, size = Vector3.new(h * 0.6, 0.3, 0.3), cf = CFrame.new(sx * w * 0.3, h * 0.55, d * 1.05) * CFrame.Angles(0, 0, R90), color = C(40, 40, 45), v = "ZSS_D_Carbon" })
			emit(ex, C(255, 160, 60), FIRE_TEX, 8, 0.4, 2, 0.4, Vector3.new(0, 4, 0))
		end
		for k = -1, 1, 2 do
			P(m, { size = Vector3.new(0.06, h * 0.8, 0.06), cf = CFrame.new(k * w * 0.42, 0, -d * 0.66), color = C(255, 170, 40), mat = M.Neon })
		end
	end
	return m
end

local function helmetHigh(m, t, hs)
	local st = HI[t]
	if t == 8 then
		-- череп вождя
		P(m, { name = "Skull", shape = Ball, size = Vector3.new(hs * 1.25, hs * 1.2, hs * 1.32), cf = CFrame.new(0, hs * 0.15, 0), color = st.main, v = st.v })
		P(m, { size = Vector3.new(hs * 0.95, hs * 0.35, hs * 0.5), cf = CFrame.new(0, -hs * 0.35, -hs * 0.45), color = st.main, v = st.v })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { shape = Ball, size = Vector3.new(hs * 0.3, hs * 0.26, 0.2), cf = CFrame.new(sx * hs * 0.24, hs * 0.12, -hs * 0.62), color = C(20, 10, 10), mat = M.SmoothPlastic })
			P(m, { shape = Ball, size = Vector3.one * hs * 0.1, cf = CFrame.new(sx * hs * 0.24, hs * 0.12, -hs * 0.7), color = C(255, 60, 40), mat = M.Neon })
			P(m, { class = "WedgePart", name = "Tusk", size = Vector3.new(hs * 0.12, hs * 0.5, hs * 0.18), cf = CFrame.new(sx * hs * 0.38, -hs * 0.4, -hs * 0.7) * CFrame.Angles(0, 0, sx * 0.3), color = C(250, 245, 230), v = st.v })
			P(m, { class = "WedgePart", name = "Horn", size = Vector3.new(hs * 0.2, hs * 0.85, hs * 0.35), cf = CFrame.new(sx * hs * 0.6, hs * 0.72, 0) * CFrame.Angles(0, 0, -sx * 0.6), color = C(90, 70, 55), v = "ZSSG_W_Leather" })
		end
		return
	end
	if t == 14 then
		-- золотая корона на капюшоне
		P(m, { name = "Hood", shape = Ball, size = Vector3.one * hs * 1.3, cf = CFrame.new(0, hs * 0.08, 0.05), color = st.trim, v = st.trimV })
		P(m, { shape = Cyl, size = Vector3.new(hs * 0.3, hs * 1.3, hs * 1.3), cf = CFrame.new(0, hs * 0.55, 0) * CFrame.Angles(0, 0, R90), color = st.main, v = st.v })
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			P(m, { class = "WedgePart", name = "Point", size = Vector3.new(hs * 0.12, hs * 0.4, hs * 0.28), cf = CFrame.new(math.cos(a) * hs * 0.6, hs * 0.85, math.sin(a) * hs * 0.6) * CFrame.Angles(0, -a + R90, 0), color = st.main, v = st.v })
			if k % 2 == 0 then
				P(m, { shape = Ball, size = Vector3.one * hs * 0.14, cf = CFrame.new(math.cos(a) * hs * 0.66, hs * 0.55, math.sin(a) * hs * 0.66), color = st.gem, mat = M.Glass, refl = 0.4 })
			end
		end
		return
	end
	-- закрытый шлем-база
	P(m, { name = "Shell", shape = Ball, size = Vector3.new(hs * 1.3, hs * 1.32, hs * 1.36), cf = CFrame.new(0, hs * 0.1, 0), color = st.main, v = st.v, tr = t == 10 and 0.08 or 0 })
	P(m, { name = "Crest", size = Vector3.new(hs * 0.14, hs * 0.22, hs * 1.3), cf = CFrame.new(0, hs * 0.78, 0.02), color = st.trim, v = st.trimV })
	P(m, { name = "Jaw", size = Vector3.new(hs * 0.9, hs * 0.3, hs * 0.35), cf = CFrame.new(0, -hs * 0.36, -hs * 0.48), color = st.trim, v = st.trimV })
	local visorColor = st.glow or C(20, 20, 26)
	local visor = P(m, { name = "Visor", size = Vector3.new(hs * 0.95, hs * (t == 13 and 0.38 or 0.14), 0.1), cf = CFrame.new(0, hs * 0.12, -hs * 0.67), color = visorColor, mat = st.glow and M.Neon or M.Glass, refl = st.glow and 0 or 0.4 })
	glowLight(visor, st)
	if t == 9 then
		visor.Size = Vector3.new(hs * 0.95, hs * 0.55, 0.1)
		visor.Material = M.Glass
		visor.Color = C(150, 255, 120)
		visor.Transparency = 0.35
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { name = "Filter", shape = Cyl, size = Vector3.new(hs * 0.3, hs * 0.34, hs * 0.34), cf = CFrame.new(sx * hs * 0.32, -hs * 0.36, -hs * 0.62) * CFrame.Angles(0, R90 + sx * 0.5, 0), color = C(60, 60, 66), v = "ZSS_I_Tread" })
		end
	end
	if st.spikes or t == 7 then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { class = "WedgePart", name = "Horn", size = Vector3.new(hs * 0.2, hs * 0.9, hs * 0.38), cf = CFrame.new(sx * hs * 0.5, hs * 0.78, 0.1) * CFrame.Angles(0, 0, -sx * 0.5), color = st.spikes or st.trim, v = st.spikeV or st.trimV })
		end
	end
	if st.crystals then
		for k = -2, 2 do
			P(m, { name = "Crystal", size = Vector3.new(hs * 0.14, hs * (0.55 - math.abs(k) * 0.1), hs * 0.14), cf = CFrame.new(k * hs * 0.2, hs * 0.85, -hs * 0.2) * CFrame.Angles(0, math.rad(45), k * 0.18), color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
		end
	end
	if st.fire then
		emit(visor, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 6, 0.25, 1, 0.4, Vector3.new(0, 3, 0))
	end
	if st.plates then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { name = "Cheek", size = Vector3.new(0.12, hs * 0.6, hs * 0.75), cf = CFrame.new(sx * hs * 0.66, -hs * 0.05, -hs * 0.1), color = st.trim, v = st.trimV })
		end
	end
	if t == 15 then
		local halo = P(m, { name = "Halo", shape = Cyl, size = Vector3.new(0.08, hs * 1.3, hs * 1.3), cf = CFrame.new(0, hs * 1.05, 0.1) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon, tr = 0.15 })
		P(m, { shape = Cyl, size = Vector3.new(0.09, hs * 1.05, hs * 1.05), cf = halo.CFrame, color = C(0, 0, 0), tr = 1 })
		emit(halo, st.glow, nil, 8, 0.15, 0.6, 0.6)
	end
end

-- качественные 3D-модели шлемов (ReplicatedStorage.ZSS.HelmetMeshes/helmetN):
-- шаблон нормирован по ширине 2 студа, лицом к -Z; Fit — ширина относительно головы, Up — сдвиг вверх
local function helmetMesh(m, t, hs)
	local z = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	local lib = z and z:FindFirstChild("HelmetMeshes")
	local tpl = lib and lib:FindFirstChild("helmet" .. t)
	if not tpl then
		return false
	end
	local c = tpl:Clone()
	c:ScaleTo(c:GetScale() * hs * (tpl:GetAttribute("Fit") or 1.4) / 2)
	-- у сгенерированного меша лицевая сторона смотрит по его собственной оси -Z, а pivot шаблона
	-- бывает повёрнут, поэтому одиночную деталь ставим по её локальным осям (+ поправка Yaw)
	local at = CFrame.new(0, hs * (tpl:GetAttribute("Up") or 0.15), 0) * CFrame.Angles(0, math.rad(tpl:GetAttribute("Yaw") or 0), 0)
	local parts = {}
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	if #parts == 1 then
		parts[1].CFrame = at
	else
		c:PivotTo(at)
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Name = "Shell"
		p.Parent = m
	end
	c:Destroy()
	-- закрытый шлем: голова прячется, внутри тёмная подложка (чтобы сквозь прорези не было видно квадратной головы)
	if tpl:GetAttribute("Closed") then
		m:SetAttribute("HideHead", true)
		P(m, { name = "Inner", shape = Ball, size = Vector3.one * hs * 0.72, cf = CFrame.new(0, hs * 0.08, 0), color = C(12, 12, 16), mat = M.SmoothPlastic })
	end
	return true
end

function IB.Helmet(item, hs)
	hs = hs or 1.2
	local t = item.tier
	local m = newModel(item.id)
	root(m)
	if helmetMesh(m, t, hs) then
		return m
	end
	if t >= 6 and HI[t] then
		helmetHigh(m, t, hs)
		return m
	end
	if t == 1 then
		P(m, { name = "Dome", shape = Ball, size = Vector3.new(hs * 1.15, hs * 0.95, hs * 1.15), cf = CFrame.new(0, hs * 0.28, 0), color = C(255, 200, 30), mat = M.SmoothPlastic, refl = 0.1 })
		P(m, { name = "Brim", shape = Cyl, size = Vector3.new(0.08, hs * 1.45, hs * 1.45), cf = CFrame.new(0, hs * 0.2, -hs * 0.05) * CFrame.Angles(0, 0, R90), color = C(240, 185, 25), mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(hs * 0.15, hs * 0.5, hs * 1.2), cf = CFrame.new(0, hs * 0.55, 0), color = C(240, 185, 25), mat = M.SmoothPlastic })
		local lamp = P(m, { name = "Lamp", shape = Cyl, size = Vector3.new(0.18, hs * 0.3, hs * 0.3), cf = CFrame.new(0, hs * 0.42, -hs * 0.56) * CFrame.Angles(0, R90, 0), color = C(255, 250, 200), mat = M.Neon })
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Left
		s.Range = 14
		s.Brightness = 1.5
		s.Parent = lamp
	elseif t == 2 then
		P(m, { name = "Shell", shape = Ball, size = Vector3.one * hs * 1.32, cf = CFrame.new(0, hs * 0.08, 0), color = C(200, 30, 30), mat = M.SmoothPlastic, refl = 0.25 })
		P(m, { name = "Visor", size = Vector3.new(hs * 0.9, hs * 0.38, 0.12), cf = CFrame.new(0, hs * 0.08, -hs * 0.62) * CFrame.Angles(math.rad(-8), 0, 0), color = C(20, 20, 30), mat = M.Glass, tr = 0.15, refl = 0.4 })
		P(m, { size = Vector3.new(hs * 0.12, hs * 0.1, hs * 1.33), cf = CFrame.new(0, hs * 0.72, 0), color = C(255, 255, 255), mat = M.SmoothPlastic })
	elseif t == 3 then
		P(m, { name = "Dome", shape = Ball, size = Vector3.new(hs * 1.2, hs * 0.95, hs * 1.25), cf = CFrame.new(0, hs * 0.28, 0.02), color = C(200, 210, 180), v = "ZSS_D_Camo" })
		P(m, { name = "Rim", shape = Cyl, size = Vector3.new(0.1, hs * 1.28, hs * 1.32), cf = CFrame.new(0, hs * 0.14, 0) * CFrame.Angles(0, 0, R90), color = C(70, 80, 60), v = "ZSS_I_Kevlar" })
		P(m, { size = Vector3.new(hs * 0.06, hs * 0.75, hs * 0.06), cf = CFrame.new(-hs * 0.55, -hs * 0.2, 0), color = C(40, 35, 30), mat = M.Fabric })
		P(m, { size = Vector3.new(hs * 0.06, hs * 0.75, hs * 0.06), cf = CFrame.new(hs * 0.55, -hs * 0.2, 0), color = C(40, 35, 30), mat = M.Fabric })
		P(m, { name = "NVGMount", size = Vector3.new(hs * 0.3, hs * 0.2, hs * 0.2), cf = CFrame.new(0, hs * 0.55, -hs * 0.6), color = C(40, 40, 40), v = "ZSS_D_Carbon" })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { shape = Cyl, size = Vector3.new(hs * 0.35, hs * 0.18, hs * 0.18), cf = CFrame.new(sx * hs * 0.13, hs * 0.48, -hs * 0.78) * CFrame.Angles(0, R90, 0), color = C(30, 30, 30), v = "ZSS_D_Carbon" })
			P(m, { shape = Cyl, size = Vector3.new(0.04, hs * 0.13, hs * 0.13), cf = CFrame.new(sx * hs * 0.13, hs * 0.48, -hs * 0.96) * CFrame.Angles(0, R90, 0), color = C(60, 255, 90), mat = M.Neon })
		end
	elseif t == 4 then
		P(m, { name = "Hood", shape = Ball, size = Vector3.one * hs * 1.3, cf = CFrame.new(0, hs * 0.1, 0.03), color = C(80, 90, 70), v = "ZSS_I_Kevlar" })
		P(m, { name = "Mask", size = Vector3.new(hs * 0.9, hs * 0.75, hs * 0.25), cf = CFrame.new(0, 0, -hs * 0.55), color = C(45, 45, 45), v = "ZSS_I_Tread" })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { name = "Lens", shape = Cyl, size = Vector3.new(0.08, hs * 0.3, hs * 0.3), cf = CFrame.new(sx * hs * 0.2, hs * 0.12, -hs * 0.69) * CFrame.Angles(0, R90, 0), color = C(120, 255, 80), mat = M.Neon, tr = 0.1 })
			P(m, { name = "Filter", shape = Cyl, size = Vector3.new(hs * 0.32, hs * 0.32, hs * 0.32), cf = CFrame.new(sx * hs * 0.3, -hs * 0.28, -hs * 0.68) * CFrame.Angles(0, R90 + sx * 0.5, 0), color = C(220, 190, 40), v = "ZSS_D_Hazard" })
		end
	else
		P(m, { name = "Shell", shape = Ball, size = Vector3.one * hs * 1.32, cf = CFrame.new(0, hs * 0.08, 0), color = C(30, 30, 34), v = "ZSS_D_Carbon" })
		local visor = P(m, { name = "Visor", size = Vector3.new(hs * 0.95, hs * 0.14, 0.1), cf = CFrame.new(0, hs * 0.12, -hs * 0.65), color = C(255, 20, 30), mat = M.Neon })
		local l = Instance.new("PointLight")
		l.Color = C(255, 30, 40)
		l.Range = 6
		l.Parent = visor
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { class = "WedgePart", name = "Horn", size = Vector3.new(hs * 0.18, hs * 0.75, hs * 0.35), cf = CFrame.new(sx * hs * 0.48, hs * 0.75, 0.05) * CFrame.Angles(0, 0, -sx * 0.45), color = C(20, 20, 22), v = "ZSS_D_Carbon" })
		end
		for k = -2, 2 do
			P(m, { name = "Spike", size = Vector3.new(hs * 0.1, hs * 0.35, hs * 0.1), cf = CFrame.new(0, hs * 0.72, k * hs * 0.18) * CFrame.Angles(k * 0.2, 0, 0), color = C(255, 30, 40), mat = M.Neon })
		end
	end
	return m
end

local GLOVES = {
	{ main = C(230, 220, 190), v = "ZSS_I_Burlap", knuck = nil },
	{ main = C(150, 100, 60), v = "ZSS_I_Leather", knuck = C(60, 40, 30) },
	{ main = C(60, 60, 55), v = "ZSS_I_LeatherBlack", knuck = C(110, 115, 105), knuckV = "ZSS_I_DarkPlate" },
	{ main = C(150, 150, 160), v = "ZSS_D_Metal", knuck = C(255, 190, 30), knuckV = "ZSS_D_Hazard", servo = true },
	{ main = C(60, 60, 75), v = "ZSS_D_SciFi", knuck = C(80, 220, 255), neon = true },
}

local function gloveHigh(m, t, box)
	local st = HI[t]
	P(m, { name = "Glove", size = box * Vector3.new(1.2, 1.12, 1.2), color = st.main, v = st.v, tr = t == 10 and 0.08 or 0 })
	P(m, { name = "Cuff", size = Vector3.new(box.X * 1.36, box.Y * 0.4, box.Z * 1.36), cf = CFrame.new(0, box.Y * 0.55, 0), color = st.trim, v = st.trimV })
	P(m, { name = "Knuckles", size = Vector3.new(box.X * 1.05, box.Y * 0.3, 0.12), cf = CFrame.new(0, -box.Y * 0.2, -box.Z * 0.64), color = st.trim, v = st.trimV })
	if st.spikes then
		for k = -1, 1 do
			P(m, { class = "WedgePart", name = "Claw", size = Vector3.new(0.08, box.Y * 0.45, box.Z * 0.3), cf = CFrame.new(k * box.X * 0.32, -box.Y * 0.55, -box.Z * 0.62) * CFrame.Angles(math.pi, 0, 0), color = st.spikes, v = st.spikeV })
		end
	end
	if st.crystals then
		for k = -1, 1 do
			P(m, { size = Vector3.new(0.12, box.Y * 0.5, 0.12), cf = CFrame.new(k * box.X * 0.3, box.Y * 0.3, -box.Z * 0.55) * CFrame.Angles(-0.5, 0, k * 0.3), color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
		end
	end
	if st.gem then
		P(m, { size = Vector3.new(box.X * 0.3, box.X * 0.3, 0.1), cf = CFrame.new(0, box.Y * 0.1, -box.Z * 0.66) * CFrame.Angles(0, 0, math.rad(45)), color = st.gem, mat = M.Glass, refl = 0.4 })
	end
	if st.glow then
		local g = P(m, { name = "Coil", shape = Cyl, size = Vector3.new(0.06, box.X * 1.4, box.Z * 1.4), cf = CFrame.new(0, box.Y * 0.32, 0) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon })
		if st.fire then
			emit(g, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 5, 0.2, 1, 0.3, Vector3.new(0, 2, 0))
		else
			emit(g, st.glow, nil, 4, 0.12, 2, 0.3)
		end
	end
end

-- 3D-перчатки и ботинки (ReplicatedStorage.ZSS.GloveMeshes/glovesN, BootMeshes/bootsN).
-- Меш натягивается на кисть (стопу) и часть предплечья (голени): box — кисть или стопа,
-- reach — сколько захватить выше неё. Лицевая сторона меша смотрит по его собственной оси -Z;
-- атрибуты шаблона SX/SY/SZ, Up, Fwd, Yaw — поправки размера, сдвига и поворота (по умолчанию — def).
-- Блочная рука толще меша, поэтому под ним рукав/голенище в цвет снаряжения (sleeve = { color, variant }).
local function limbMesh(m, libName, key, box, reach, glow, sleeve, def)
	local z = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	local lib = z and z:FindFirstChild(libName)
	local tpl = lib and lib:FindFirstChild(key)
	local src = tpl and tpl:FindFirstChildWhichIsA("BasePart", true)
	if not src then
		return false
	end
	local hgt = box.Y + reach
	if sleeve and tpl:GetAttribute("Sleeve") ~= false then
		P(m, { name = "Sleeve", size = Vector3.new(box.X * 1.06, hgt, box.Z * 1.06), cf = CFrame.new(0, (hgt - box.Y) / 2, 0), color = sleeve[1], v = sleeve[2], mat = sleeve[3] })
	end
	local yaw = math.rad(tpl:GetAttribute("Yaw") or 0)
	local size = Vector3.new(box.X * (tpl:GetAttribute("SX") or def.X), hgt * (tpl:GetAttribute("SY") or def.Y), box.Z * (tpl:GetAttribute("SZ") or def.Z))
	if math.abs(math.cos(yaw)) < 0.5 then
		size = Vector3.new(size.Z, size.Y, size.X)
	end
	local p = src:Clone()
	p.Size = size
	p.CFrame = CFrame.new(0, (hgt - box.Y) / 2 + hgt * (tpl:GetAttribute("Up") or 0), -box.Z * (tpl:GetAttribute("Fwd") or 0)) * CFrame.Angles(0, yaw, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Name = "Shell"
	for _, c in ipairs(p:GetChildren()) do
		c:Destroy()
	end
	p.Parent = m
	if glow then
		local l = Instance.new("PointLight")
		l.Color = glow
		l.Range = 4
		l.Brightness = 0.8
		l.Parent = p
	end
	return true
end

-- перчатка шире руки, но не настолько, чтобы влезать в торс; ботинки не должны задевать друг друга
local GLOVE_FIT = Vector3.new(1.45, 1.08, 1.7)
local BOOT_FIT = Vector3.new(1.15, 1.04, 1.5)

function IB.Glove(item, box, reach)
	box = box or Vector3.new(0.6, 0.5, 0.6)
	do
		local m = newModel(item.id)
		root(m)
		local st = HI[item.tier] or GLOVES[item.tier]
		if limbMesh(m, "GloveMeshes", item.id, box, reach or box.Y * 1.6, st and st.glow, SET_COLORS[item.tier] or (st and { st.main, st.v }), GLOVE_FIT) then
			return m
		end
		m:Destroy()
	end
	if item.tier >= 6 and HI[item.tier] then
		local m = newModel(item.id)
		root(m)
		gloveHigh(m, item.tier, box)
		return m
	end
	local st = GLOVES[item.tier]
	local m = newModel(item.id)
	root(m)
	P(m, { name = "Glove", size = box * Vector3.new(1.18, 1.12, 1.18), color = st.main, v = st.v })
	P(m, { name = "Cuff", size = Vector3.new(box.X * 1.3, box.Y * 0.35, box.Z * 1.3), cf = CFrame.new(0, box.Y * 0.55, 0), color = st.main:Lerp(C(0, 0, 0), 0.25), v = st.v })
	if st.knuck then
		P(m, { name = "Knuckles", size = Vector3.new(box.X * 1.0, box.Y * 0.3, 0.1), cf = CFrame.new(0, -box.Y * 0.2, -box.Z * 0.62), color = st.knuck, v = st.knuckV, mat = st.neon and M.Neon or nil })
	end
	if st.servo then
		for k = -1, 1 do
			P(m, { shape = Cyl, size = Vector3.new(box.Y * 0.9, 0.12, 0.12), cf = CFrame.new(k * box.X * 0.3, 0, box.Z * 0.62) * CFrame.Angles(0, 0, R90), color = C(40, 40, 40), v = "ZSS_D_Carbon" })
		end
	end
	if st.neon then
		local g = P(m, { name = "Coil", shape = Cyl, size = Vector3.new(0.08, box.X * 1.35, box.Z * 1.35), cf = CFrame.new(0, box.Y * 0.3, 0) * CFrame.Angles(0, 0, R90), color = C(80, 220, 255), mat = M.Neon })
		emit(g, C(120, 230, 255), nil, 6, 0.15, 3, 0.25)
	end
	return m
end

local BOOTS = {
	{ main = C(220, 60, 50), v = "ZSS_I_Denim", sole = C(240, 240, 240) },
	{ main = C(60, 45, 35), v = "ZSS_I_LeatherBlack", sole = C(30, 30, 30), laces = true },
	{ main = C(60, 140, 255), v = "ZSS_D_Carbon", sole = C(250, 250, 250), stripe = C(255, 255, 255) },
	{ main = C(110, 115, 105), v = "ZSS_I_DarkPlate", sole = C(30, 30, 30), armor = C(200, 210, 180) },
	{ main = C(70, 70, 85), v = "ZSS_D_SciFi", sole = C(40, 40, 45), jet = true },
}

local function bootHigh(m, t, box)
	local st = HI[t]
	P(m, { name = "Boot", size = box * Vector3.new(1.2, 1.15, 1.16), color = st.main, v = st.v, tr = t == 10 and 0.08 or 0 })
	P(m, { name = "Sole", size = Vector3.new(box.X * 1.24, box.Y * 0.32, box.Z * 1.28), cf = CFrame.new(0, -box.Y * 0.5, -box.Z * 0.03), color = st.trim, v = st.trimV })
	P(m, { name = "Shaft", size = Vector3.new(box.X * 1.22, box.Y * 0.85, box.Z * 0.78), cf = CFrame.new(0, box.Y * 0.75, box.Z * 0.1), color = st.main, v = st.v })
	P(m, { name = "Toe", size = Vector3.new(box.X * 1.0, box.Y * 0.55, 0.14), cf = CFrame.new(0, -0.02, -box.Z * 0.6), color = st.trim, v = st.trimV })
	P(m, { name = "Shin", size = Vector3.new(box.X * 0.9, box.Y * 1.0, 0.12), cf = CFrame.new(0, box.Y * 0.75, -box.Z * 0.32), color = st.trim, v = st.trimV })
	if st.spikes then
		P(m, { class = "WedgePart", name = "Spur", size = Vector3.new(0.08, box.Y * 0.4, box.Z * 0.35), cf = CFrame.new(0, -box.Y * 0.2, box.Z * 0.72), color = st.spikes, v = st.spikeV })
	end
	if st.gem then
		P(m, { size = Vector3.new(box.X * 0.3, box.X * 0.3, 0.1), cf = CFrame.new(0, box.Y * 0.75, -box.Z * 0.4) * CFrame.Angles(0, 0, math.rad(45)), color = st.gem, mat = M.Glass, refl = 0.4 })
	end
	if st.glow then
		local j = P(m, { name = "Jet", shape = Cyl, size = Vector3.new(0.1, box.X * 0.8, box.X * 0.8), cf = CFrame.new(0, -box.Y * 0.68, box.Z * 0.2) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(0.05, box.Y * 1.3, 0.05), cf = CFrame.new(sx * box.X * 0.62, box.Y * 0.4, 0), color = st.glow, mat = M.Neon })
		end
		if st.fire or t == 7 then
			emit(j, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 10, 0.3, 2, 0.3, Vector3.new(0, -4, 0))
		else
			emit(j, st.glow, nil, 6, 0.15, 2, 0.3, Vector3.new(0, -3, 0))
		end
	end
end

function IB.Boot(item, box, reach)
	box = box or Vector3.new(0.6, 0.4, 0.8)
	do
		local m = newModel(item.id)
		root(m)
		local st = HI[item.tier] or BOOTS[item.tier]
		if limbMesh(m, "BootMeshes", item.id, box, reach or box.Y * 1.5, st and st.glow, SET_COLORS[item.tier] or (st and { st.main, st.v }), BOOT_FIT) then
			return m
		end
		m:Destroy()
	end
	if item.tier >= 6 and HI[item.tier] then
		local m = newModel(item.id)
		root(m)
		bootHigh(m, item.tier, box)
		return m
	end
	local st = BOOTS[item.tier]
	local m = newModel(item.id)
	root(m)
	P(m, { name = "Boot", size = box * Vector3.new(1.18, 1.15, 1.15), color = st.main, v = st.v })
	P(m, { name = "Sole", size = Vector3.new(box.X * 1.22, box.Y * 0.3, box.Z * 1.25), cf = CFrame.new(0, -box.Y * 0.5, -box.Z * 0.03), color = st.sole, v = "ZSS_I_Tread" })
	P(m, { name = "Shaft", size = Vector3.new(box.X * 1.2, box.Y * 0.8, box.Z * 0.75), cf = CFrame.new(0, box.Y * 0.75, box.Z * 0.1), color = st.main, v = st.v })
	if st.laces then
		for k = 0, 2 do
			P(m, { size = Vector3.new(box.X * 0.7, 0.05, 0.05), cf = CFrame.new(0, box.Y * (0.1 + k * 0.3), -box.Z * 0.45), color = C(200, 190, 160), mat = M.Fabric })
		end
	end
	if st.stripe then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(0.04, box.Y * 0.25, box.Z * 0.9), cf = CFrame.new(sx * box.X * 0.6, 0, 0) * CFrame.Angles(0.4, 0, 0), color = st.stripe, mat = M.SmoothPlastic })
		end
	end
	if st.armor then
		P(m, { name = "Shin", size = Vector3.new(box.X * 1.0, box.Y * 1.1, 0.12), cf = CFrame.new(0, box.Y * 0.75, -box.Z * 0.35), color = st.armor, v = "ZSS_D_Camo" })
		P(m, { name = "Toe", size = Vector3.new(box.X * 1.0, box.Y * 0.5, 0.15), cf = CFrame.new(0, 0, -box.Z * 0.6), color = C(150, 150, 155), v = "ZSS_D_Metal" })
	end
	if st.jet then
		local j = P(m, { name = "Jet", shape = Cyl, size = Vector3.new(0.12, box.X * 0.8, box.X * 0.8), cf = CFrame.new(0, -box.Y * 0.68, box.Z * 0.2) * CFrame.Angles(0, 0, R90), color = C(255, 150, 40), mat = M.Neon })
		emit(j, ColorSequence.new(C(255, 220, 120), C(255, 80, 20)), FIRE_TEX, 14, 0.35, 3, 0.3, Vector3.new(0, -6, 0))
		P(m, { size = Vector3.new(0.05, box.Y * 1.4, 0.05), cf = CFrame.new(box.X * 0.6, box.Y * 0.4, 0), color = C(80, 220, 255), mat = M.Neon })
	end
	return m
end

-- ===================== РЮКЗАКИ =====================
-- Невидимый Root в центре торса, рюкзак строится на спине (+Z), лямки идут через плечи на грудь (-Z).
-- armored = поверх брони (рюкзак и лямки чуть дальше от тела).
local BLACK = C(0, 0, 0)
local BP = {
	bp_old = { main = C(200, 60, 50), v = "ZSSG_B_Nylon", pocket = C(40, 70, 150), pocketV = "ZSSG_B_Nylon", strap = C(35, 35, 40), strapV = "ZSSG_B_Molle", round = true },
	bp_sack = { main = C(185, 160, 120), v = "ZSS_I_Burlap", strap = C(140, 110, 70), strapV = "ZSS_I_Burlap", nopocket = true, round = true, bw = 0.7, bh = 0.8 },
	bp_denim = { main = C(80, 110, 170), v = "ZSSG_B_Patchwork", pocket = C(50, 75, 130), pocketV = "ZSS_I_Denim", strap = C(120, 80, 50), strapV = "ZSSG_W_Leather", round = true },
	bp_hiker = { main = C(230, 120, 40), v = "ZSSG_B_Nylon", pocket = C(60, 70, 80), pocketV = "ZSSG_B_Nylon", strap = C(40, 45, 50), strapV = "ZSSG_B_Molle", bh = 1.0, by = 0.06, side = true, chest = true },
	bp_scrapper = { main = C(120, 95, 70), v = "ZSSG_W_Leather", pocket = C(200, 150, 110), pocketV = "ZSS_D_Rust", strap = C(40, 35, 30), strapV = "ZSSG_W_LeatherBlack", trim = C(240, 190, 30), trimV = "ZSS_D_Hazard", glow = C(120, 255, 80) },
	bp_raid = { main = C(120, 130, 85), v = "ZSS_D_Camo", pocket = C(95, 105, 70), pocketV = "ZSS_D_Camo", strap = C(55, 60, 45), strapV = "ZSSG_B_Molle", side = true, chest = true, flap = true },
	bp_tactical = { main = C(70, 75, 62), v = "ZSSG_B_Molle", pocket = C(58, 62, 52), pocketV = "ZSSG_B_Molle", strap = C(35, 38, 32), strapV = "ZSSG_B_Molle", side = true, chest = true, flap = true },
	bp_hazmat = { main = C(240, 200, 40), v = "ZSSG_W_Hazmat", strap = C(40, 40, 44), strapV = "ZSS_I_Tread", trim = C(40, 40, 44), trimV = "ZSS_I_Tread", nopocket = true, glow = C(130, 255, 80), bd = 0.5 },
	bp_reactor = { main = C(95, 100, 115), v = "ZSS_D_SciFi", pocket = C(50, 52, 60), pocketV = "ZSSG_W_Carbon", strap = C(40, 40, 45), strapV = "ZSSG_W_Carbon", trim = C(50, 52, 60), trimV = "ZSSG_W_Carbon", glow = C(80, 220, 255), nopocket = true },
	bp_bone = { main = C(120, 90, 65), v = "ZSSG_B_Fur", strap = C(70, 50, 40), strapV = "ZSSG_W_Leather", nopocket = true, bh = 0.95, bd = 0.7, round = true, bone = C(238, 228, 205) },
	bp_dragon = { main = C(170, 35, 35), v = "ZSSG_W_DragonScale", pocket = C(130, 25, 25), pocketV = "ZSSG_W_DragonScale", strap = C(255, 200, 110), strapV = "ZSSG_W_GoldEngraved", trim = C(255, 200, 110), trimV = "ZSSG_W_GoldEngraved", glow = C(255, 120, 40), round = true },
	bp_crystal = { main = C(95, 105, 135), v = "ZSSG_W_Titanium", strap = C(60, 65, 85), strapV = "ZSS_I_DarkPlate", trim = C(60, 65, 85), trimV = "ZSS_I_DarkPlate", glow = C(120, 220, 255), nopocket = true },
	bp_magma = { main = C(70, 45, 35), v = "ZSSG_W_Magma", strap = C(30, 25, 30), strapV = "ZSSG_W_Obsidian", trim = C(30, 25, 30), trimV = "ZSSG_W_Obsidian", glow = C(255, 110, 20), nopocket = true, bd = 0.66 },
	bp_obsidian = { main = C(40, 34, 52), v = "ZSSG_W_Obsidian", strap = C(30, 26, 38), strapV = "ZSSG_W_Obsidian", trim = C(25, 22, 30), trimV = "ZSSG_W_Obsidian", glow = C(190, 90, 255), nopocket = true, round = true, chest = true },
	bp_nano = { main = C(40, 50, 62), v = "ZSSG_W_Circuit", pocket = C(28, 34, 44), pocketV = "ZSSG_W_Carbon", strap = C(28, 34, 44), strapV = "ZSSG_W_Carbon", trim = C(28, 34, 44), trimV = "ZSSG_W_Carbon", glow = C(80, 255, 230) },
	bp_royal = { main = C(255, 205, 90), v = "ZSSG_W_GoldEngraved", strap = C(150, 20, 35), strapV = "ZSSG_B_Quilted", trim = C(150, 20, 35), trimV = "ZSSG_B_Quilted", nopocket = true, round = true, gem = C(255, 40, 70) },
	bp_omega = { main = C(205, 215, 235), v = "ZSSG_W_Titanium", strap = C(55, 62, 82), strapV = "ZSSG_W_Circuit", trim = C(55, 62, 82), trimV = "ZSSG_W_Circuit", glow = C(80, 255, 230), nopocket = true, chest = true },
}
IB.BackpackStyles = BP

local function bpLight(part, color, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 6
	l.Brightness = 1
	l.Parent = part
end

-- диск, обращённый к спине (ось цилиндра вдоль Z)
local function disc(m, o)
	o.shape = Cyl
	o.size = Vector3.new(o.th or 0.08, o.dia, o.dia)
	o.cf = o.cf * CFrame.Angles(0, R90, 0)
	return P(m, o)
end

local BX = {}

BX.bp_old = function(m, st, g)
	-- брелок сбоку
	local x = g.bw / 2 + 0.05
	P(m, { shape = Cyl, size = Vector3.new(0.04, 0.22, 0.22), cf = CFrame.new(x, g.top - g.bh * 0.1, g.cz), color = C(200, 200, 205), mat = M.Metal })
	local charm = P(m, { name = "Charm", shape = Ball, size = Vector3.one * 0.22, cf = CFrame.new(x + 0.02, g.top - g.bh * 0.3, g.cz), color = C(255, 220, 60), mat = M.Neon })
	bpLight(charm, C(255, 220, 60), 3)
end

BX.bp_sack = function(m, st, g)
	-- горловина, стянутая верёвкой
	local neckY = g.top + g.bd * 0.45
	P(m, { name = "Neck", shape = Cyl, size = Vector3.new(g.bh * 0.25, g.bd * 0.5, g.bd * 0.5), cf = CFrame.new(0, neckY, g.cz) * CFrame.Angles(0, 0, R90), color = st.main:Lerp(BLACK, 0.1), v = st.v })
	P(m, { name = "Rope", shape = Cyl, size = Vector3.new(0.08, g.bd * 0.56, g.bd * 0.56), cf = CFrame.new(0, neckY - g.bh * 0.05, g.cz) * CFrame.Angles(0, 0, R90), color = C(110, 80, 50), v = "ZSSG_W_Leather" })
	for _, sx in ipairs({ -1, 1 }) do
		P(m, { name = "Rope", size = Vector3.new(0.06, g.bh * 0.4, 0.06), cf = CFrame.new(sx * 0.1, neckY - g.bh * 0.25, g.back + 0.02) * CFrame.Angles(0, 0, sx * 0.25), color = C(110, 80, 50), v = "ZSSG_W_Leather" })
	end
	-- заплатка
	P(m, { size = Vector3.new(g.bw * 0.28, g.bh * 0.22, 0.04), cf = CFrame.new(-g.bw * 0.15, g.cy - g.bh * 0.15, g.back + 0.01) * CFrame.Angles(0, 0, 0.15), color = C(120, 95, 70), v = "ZSS_I_Burlap" })
end

BX.bp_denim = function(m, st, g)
	local patches = { { C(220, 50, 50), -0.22, 0.2 }, { C(255, 210, 40), 0.24, 0.26 }, { C(80, 200, 90), 0.2, -0.05 } }
	for i, pt in ipairs(patches) do
		disc(m, { th = 0.05, dia = g.bw * 0.2, cf = CFrame.new(g.bw * pt[2], g.cy + g.bh * pt[3], g.back + 0.02), color = pt[1], mat = M.Fabric })
		if i == 2 then
			P(m, { size = Vector3.new(g.bw * 0.08, g.bw * 0.08, 0.04), cf = CFrame.new(g.bw * pt[2], g.cy + g.bh * pt[3], g.back + 0.05) * CFrame.Angles(0, 0, math.rad(45)), color = C(220, 50, 50), mat = M.SmoothPlastic })
		end
	end
	-- значки
	for k = 0, 2 do
		disc(m, { th = 0.04, dia = 0.14, cf = CFrame.new(-g.bw * 0.3 + k * 0.17, g.cy + g.bh * 0.36, g.back + 0.03), color = ({ C(255, 255, 255), C(255, 120, 200), C(120, 200, 255) })[k + 1], mat = M.SmoothPlastic, refl = 0.2 })
	end
end

BX.bp_hiker = function(m, st, g)
	-- спальник сверху
	local roll = P(m, { name = "Bedroll", shape = Cyl, size = Vector3.new(g.bw * 1.15, g.bd * 0.7, g.bd * 0.7), cf = CFrame.new(0, g.top + g.bd * 0.32, g.cz), color = C(60, 115, 75), v = "ZSSG_B_Quilted" })
	for _, sx in ipairs({ -1, 1 }) do
		P(m, { shape = Cyl, size = Vector3.new(0.08, g.bd * 0.74, g.bd * 0.74), cf = roll.CFrame * CFrame.new(sx * g.bw * 0.35, 0, 0), color = C(30, 30, 30), v = "ZSSG_B_Molle" })
		-- алюминиевая рама
		P(m, { shape = Cyl, size = Vector3.new(g.bh * 1.05, 0.08, 0.08), cf = CFrame.new(sx * g.bw * 0.48, g.cy, g.cz - g.bd * 0.42) * CFrame.Angles(0, 0, R90), color = C(200, 205, 215), mat = M.Metal, refl = 0.2 })
	end
	-- фляга
	local fx = g.bw / 2 + g.bw * 0.18
	P(m, { shape = Cyl, size = Vector3.new(g.bh * 0.32, 0.26, 0.26), cf = CFrame.new(fx, g.cy + g.bh * 0.12, g.cz) * CFrame.Angles(0, 0, R90), color = C(150, 160, 150), v = "ZSSG_W_Steel" })
	P(m, { shape = Cyl, size = Vector3.new(0.06, 0.14, 0.14), cf = CFrame.new(fx, g.cy + g.bh * 0.3, g.cz) * CFrame.Angles(0, 0, R90), color = C(30, 30, 30), mat = M.Rubber })
end

BX.bp_scrapper = function(m, st, g)
	-- шестерня сбоку
	local gx = g.bw / 2 + 0.06
	local cog = P(m, { name = "Cog", shape = Cyl, size = Vector3.new(0.12, g.bh * 0.5, g.bh * 0.5), cf = CFrame.new(gx, g.cy + g.bh * 0.1, g.cz), color = C(170, 140, 100), v = "ZSS_D_Rust" })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		P(m, { size = Vector3.new(0.12, 0.12, 0.12), cf = cog.CFrame * CFrame.new(0, math.cos(a) * g.bh * 0.27, math.sin(a) * g.bh * 0.27), color = C(170, 140, 100), v = "ZSS_D_Rust" })
	end
	-- труба переработчика
	local pipe = P(m, { shape = Cyl, size = Vector3.new(g.bh * 0.45, 0.24, 0.24), cf = CFrame.new(-g.bw * 0.28, g.top + g.bh * 0.15, g.cz) * CFrame.Angles(0, 0, R90), color = C(90, 90, 95), v = "ZSSG_W_Steel" })
	local ring = P(m, { shape = Cyl, size = Vector3.new(0.08, 0.28, 0.28), cf = pipe.CFrame * CFrame.new(g.bh * 0.2, 0, 0), color = st.glow, mat = M.Neon })
	emit(ring, st.glow, nil, 6, 0.15, 2, 0.5, Vector3.new(0, 3, 0))
	-- знак переработки на кармане
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, { size = Vector3.new(0.05, g.bw * 0.16, 0.04), cf = CFrame.new(g.pocketX, g.pocketY, g.pocketZ + 0.02) * CFrame.Angles(0, 0, a) * CFrame.new(0, -g.bw * 0.05, 0) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon })
	end
	bpLight(ring, st.glow, 5)
end

BX.bp_raid = function(m, st, g)
	for k = -1, 1 do
		P(m, { name = "Pouch", size = Vector3.new(g.bw * 0.26, g.bh * 0.22, g.bd * 0.22), cf = CFrame.new(k * g.bw * 0.3, g.cy + g.bh * 0.12, g.back + g.bd * 0.1), color = st.pocket, v = st.pocketV })
		disc(m, { th = 0.04, dia = 0.08, cf = CFrame.new(k * g.bw * 0.3, g.cy + g.bh * 0.2, g.back + g.bd * 0.22), color = C(30, 30, 30), mat = M.SmoothPlastic })
	end
	-- коврик снизу
	P(m, { shape = Cyl, size = Vector3.new(g.bw * 1.05, g.bd * 0.55, g.bd * 0.55), cf = CFrame.new(0, g.cy - g.bh / 2 - g.bd * 0.2, g.cz + g.bd * 0.05), color = C(45, 55, 45), v = "ZSS_I_Tread" })
end

BX.bp_tactical = function(m, st, g)
	-- рация с антенной
	local rx = -g.bw / 2 - g.bw * 0.08
	P(m, { name = "Radio", size = Vector3.new(0.22, g.bh * 0.32, 0.3), cf = CFrame.new(rx, g.cy + g.bh * 0.25, g.cz), color = C(40, 40, 40), v = "ZSSG_W_Carbon" })
	P(m, { shape = Cyl, size = Vector3.new(g.bh * 0.9, 0.05, 0.05), cf = CFrame.new(rx, g.top + g.bh * 0.35, g.cz) * CFrame.Angles(0, 0, R90), color = C(25, 25, 25), mat = M.Rubber })
	local tip = P(m, { shape = Ball, size = Vector3.one * 0.12, cf = CFrame.new(rx, g.top + g.bh * 0.8, g.cz), color = C(255, 40, 40), mat = M.Neon })
	bpLight(tip, C(255, 40, 40), 3)
	-- нашивка с черепом
	P(m, { size = Vector3.new(g.bw * 0.34, g.bh * 0.18, 0.04), cf = CFrame.new(0, g.cy + g.bh * 0.08, g.back + 0.02), color = C(30, 32, 28), mat = M.Fabric })
	P(m, { shape = Ball, size = Vector3.new(g.bh * 0.12, g.bh * 0.12, 0.05), cf = CFrame.new(0, g.cy + g.bh * 0.09, g.back + 0.04), color = C(220, 220, 210), mat = M.SmoothPlastic })
end

BX.bp_hazmat = function(m, st, g)
	-- стеклянный бак со слизью
	local tz = g.back + g.bd * 0.35
	local tank = P(m, { name = "Tank", shape = Cyl, size = Vector3.new(g.bh * 0.85, g.bw * 0.5, g.bw * 0.5), cf = CFrame.new(0, g.cy, tz) * CFrame.Angles(0, 0, R90), color = C(220, 255, 220), mat = M.Glass, tr = 0.45, refl = 0.2 })
	local slime = P(m, { name = "Slime", shape = Cyl, size = Vector3.new(g.bh * 0.6, g.bw * 0.42, g.bw * 0.42), cf = CFrame.new(0, g.cy - g.bh * 0.1, tz) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon, tr = 0.15 })
	for _, sy in ipairs({ -1, 1 }) do
		P(m, { shape = Cyl, size = Vector3.new(0.14, g.bw * 0.56, g.bw * 0.56), cf = CFrame.new(0, g.cy + sy * g.bh * 0.44, tz) * CFrame.Angles(0, 0, R90), color = C(70, 70, 75), v = "ZSSG_W_Steel" })
	end
	emit(slime, st.glow, nil, 5, 0.12, 0.8, 1, Vector3.new(0, 1.5, 0))
	bpLight(slime, st.glow, 7)
	-- полосы опасности
	for k = -2, 2 do
		P(m, { size = Vector3.new(0.06, g.bh * 0.9, g.bd * 1.02), cf = CFrame.new(k * g.bw * 0.2, g.cy, g.cz) * CFrame.Angles(0, 0, 0.5), color = C(30, 30, 30), mat = M.SmoothPlastic })
	end
end

BX.bp_reactor = function(m, st, g)
	local core = disc(m, { name = "Core", th = 0.12, dia = g.bw * 0.5, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.06), color = st.glow, mat = M.Neon })
	disc(m, { th = 0.1, dia = g.bw * 0.66, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.03), color = st.trim, v = st.trimV })
	disc(m, { th = 0.14, dia = g.bw * 0.2, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.1), color = C(230, 255, 255), mat = M.Neon })
	bpLight(core, st.glow, 9)
	for _, sx in ipairs({ -1, 1 }) do
		local ex = P(m, { name = "Exhaust", shape = Cyl, size = Vector3.new(g.bh * 0.5, 0.26, 0.26), cf = CFrame.new(sx * g.bw * 0.32, g.top + g.bh * 0.12, g.cz - g.bd * 0.1) * CFrame.Angles(0, 0, R90), color = C(40, 40, 45), v = "ZSSG_W_Carbon" })
		emit(ex, st.glow, nil, 8, 0.25, 2, 0.4, Vector3.new(0, 3, 0))
		P(m, { size = Vector3.new(0.05, g.bh * 0.7, 0.05), cf = CFrame.new(sx * g.bw * 0.45, g.cy, g.back + 0.02), color = st.glow, mat = M.Neon })
	end
end

BX.bp_bone = function(m, st, g)
	-- рёбра поверх шкуры
	for k = 0, 3 do
		local y = g.cy + g.bh * (0.3 - k * 0.2)
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(g.bw * 0.5, g.bh * 0.06, 0.1), cf = CFrame.new(sx * g.bw * 0.24, y, g.back + 0.03) * CFrame.Angles(0, -sx * 0.35, sx * 0.2), color = st.bone, v = "ZSSG_W_Bone" })
		end
	end
	P(m, { size = Vector3.new(g.bw * 0.1, g.bh * 0.9, 0.14), cf = CFrame.new(0, g.cy, g.back + 0.05), color = st.bone, v = "ZSSG_W_Bone" })
	-- череп сверху
	local sk = P(m, { name = "Skull", shape = Ball, size = Vector3.new(g.bw * 0.42, g.bw * 0.38, g.bw * 0.42), cf = CFrame.new(0, g.top + g.bd * 0.35, g.cz + g.bd * 0.1), color = st.bone, v = "ZSSG_W_Bone" })
	for _, sx in ipairs({ -1, 1 }) do
		P(m, { shape = Ball, size = Vector3.one * g.bw * 0.08, cf = sk.CFrame * CFrame.new(sx * g.bw * 0.09, 0, g.bw * 0.18), color = C(255, 50, 30), mat = M.Neon })
		P(m, { class = "WedgePart", name = "Horn", size = Vector3.new(g.bw * 0.08, g.bw * 0.35, g.bw * 0.14), cf = sk.CFrame * CFrame.new(sx * g.bw * 0.22, g.bw * 0.2, 0) * CFrame.Angles(0, 0, -sx * 0.6), color = C(90, 70, 55), v = "ZSSG_W_Leather" })
	end
end

BX.bp_dragon = function(m, st, g)
	-- шипы вдоль хребта
	for k = 0, 4 do
		P(m, { class = "WedgePart", name = "Spike", size = Vector3.new(0.08, g.bh * 0.16, g.bd * 0.3), cf = CFrame.new(0, g.cy + g.bh * (0.45 - k * 0.22), g.back + g.bd * 0.12) * CFrame.Angles(0, R90, 0), color = C(245, 235, 210), v = "ZSSG_W_Bone" })
	end
	-- сложенные крылья
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			P(m, { name = "Wing", size = Vector3.new(0.06, g.bh * (0.95 - k * 0.2), g.bd * 0.8), cf = CFrame.new(sx * (g.bw / 2 + 0.05 + k * 0.04), g.cy + g.bh * 0.2 - k * g.bh * 0.08, g.cz + g.bd * 0.1) * CFrame.Angles(-0.5 - k * 0.15, sx * 0.15, 0), color = C(120 - k * 20, 20, 25), v = "ZSSG_W_DragonScale" })
		end
	end
	local gem = P(m, { name = "Gem", size = Vector3.new(g.bw * 0.16, g.bw * 0.16, 0.12), cf = CFrame.new(0, g.cy - g.bh * 0.05, g.pocketZ + 0.06) * CFrame.Angles(0, 0, math.rad(45)), color = st.glow, mat = M.Neon })
	emit(gem, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 5, 0.25, 1, 0.5, Vector3.new(0, 3, 0))
	bpLight(gem, st.glow, 6)
end

BX.bp_crystal = function(m, st, g)
	local list = { { -0.3, 0.55, 0.3 }, { 0, 0.75, 0 }, { 0.28, 0.6, -0.25 }, { -0.12, 0.45, 0.6 }, { 0.15, 0.4, -0.6 } }
	for i, c in ipairs(list) do
		P(m, { name = "Crystal", size = Vector3.new(g.bw * 0.13, g.bh * c[2], g.bw * 0.13), cf = CFrame.new(g.bw * c[1], g.top + g.bh * c[2] * 0.35, g.cz + (i % 2 == 0 and 0.05 or -0.05)) * CFrame.Angles(0, math.rad(45), c[3] * 0.6), color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
	end
	for k = 0, 2 do
		P(m, { name = "Crystal", size = Vector3.new(g.bw * 0.1, g.bw * 0.1, g.bd * 0.5), cf = CFrame.new((k - 1) * g.bw * 0.28, g.cy - g.bh * 0.1 + (k % 2) * g.bh * 0.2, g.back + g.bd * 0.15) * CFrame.Angles(0, 0, math.rad(45)), color = C(170, 230, 255), v = "ZSSG_W_Crystal", tr = 0.1 })
	end
	local core = P(m, { size = Vector3.new(g.bw * 0.22, g.bw * 0.22, 0.08), cf = CFrame.new(0, g.cy + g.bh * 0.2, g.back + 0.03) * CFrame.Angles(0, 0, math.rad(45)), color = st.glow, mat = M.Neon })
	emit(core, st.glow, nil, 6, 0.2, 1, 0.6)
	bpLight(core, st.glow, 8)
end

BX.bp_magma = function(m, st, g)
	local crack = P(m, { size = Vector3.new(0.07, g.bh * 0.8, 0.04), cf = CFrame.new(0, g.cy, g.back + 0.01), color = st.glow, mat = M.Neon })
	for k = 0, 3 do
		local sx = k % 2 == 0 and -1 or 1
		P(m, { size = Vector3.new(g.bw * 0.32, 0.06, 0.04), cf = CFrame.new(sx * g.bw * 0.14, g.cy + g.bh * (0.28 - k * 0.18), g.back + 0.01) * CFrame.Angles(0, 0, sx * 0.45), color = st.glow, mat = M.Neon })
	end
	bpLight(crack, st.glow, 8)
	-- труба плавильни
	local pipe = P(m, { shape = Cyl, size = Vector3.new(g.bh * 0.55, 0.32, 0.32), cf = CFrame.new(g.bw * 0.26, g.top + g.bh * 0.2, g.cz - g.bd * 0.1) * CFrame.Angles(0, 0, R90), color = C(30, 25, 30), v = "ZSSG_W_Obsidian" })
	local mouth = P(m, { shape = Cyl, size = Vector3.new(0.06, 0.3, 0.3), cf = pipe.CFrame * CFrame.new(g.bh * 0.28, 0, 0), color = st.glow, mat = M.Neon })
	emit(mouth, ColorSequence.new(C(255, 220, 120), C(255, 60, 20)), FIRE_TEX, 14, 0.45, 2.5, 0.5, Vector3.new(0, 5, 0))
end

BX.bp_obsidian = function(m, st, g)
	-- светящиеся швы сундука
	for _, sy in ipairs({ -0.42, 0.42 }) do
		P(m, { size = Vector3.new(g.bw * 1.03, 0.05, g.bd * 1.03), cf = CFrame.new(0, g.cy + g.bh * sy, g.cz), color = st.glow, mat = M.Neon })
	end
	for _, sx in ipairs({ -0.48, 0.48 }) do
		P(m, { size = Vector3.new(0.05, g.bh * 0.85, g.bd * 1.03), cf = CFrame.new(g.bw * sx, g.cy, g.cz), color = st.glow, mat = M.Neon })
	end
	-- кольцо рун за спиной (из отдельных сегментов, чтобы сундук был виден сквозь него)
	local rc = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.2)
	local r = g.bh * 0.55
	local rune
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local seg = P(m, { name = "Rune", size = Vector3.new(r * 0.42, 0.06, 0.04), cf = rc * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0), color = st.glow, mat = M.Neon, tr = k % 3 == 0 and 0 or 0.3 })
		rune = rune or seg
	end
	-- глиф в центре
	P(m, { size = Vector3.new(0.06, g.bh * 0.4, 0.04), cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.02), color = st.glow, mat = M.Neon })
	P(m, { size = Vector3.new(g.bw * 0.2, g.bw * 0.2, 0.04), cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.02) * CFrame.Angles(0, 0, math.rad(45)), color = st.glow, mat = M.Neon, tr = 0.4 })
	emit(rune, st.glow, nil, 8, 0.18, 0.8, 0.8)
	bpLight(rune, st.glow, 8)
end

BX.bp_nano = function(m, st, g)
	for k = 0, 3 do
		P(m, { size = Vector3.new(g.bw * (0.3 + (k % 2) * 0.3), 0.04, 0.03), cf = CFrame.new((k % 2 == 0 and -0.15 or 0.05) * g.bw, g.cy + g.bh * (0.35 - k * 0.2), g.back + 0.01), color = st.glow, mat = M.Neon })
		P(m, { size = Vector3.new(0.04, g.bh * 0.18, 0.03), cf = CFrame.new((k - 1.5) * g.bw * 0.25, g.cy + g.bh * (0.25 - (k % 2) * 0.3), g.back + 0.01), color = st.glow, mat = M.Neon })
	end
	-- голограмма над рюкзаком
	local holo = P(m, { name = "Holo", shape = Cyl, size = Vector3.new(0.04, g.bw * 0.7, g.bw * 0.7), cf = CFrame.new(0, g.top + g.bh * 0.15, g.cz) * CFrame.Angles(0, 0, R90), color = st.glow, mat = M.Neon, tr = 0.5 })
	P(m, { size = Vector3.one * g.bw * 0.16, cf = CFrame.new(0, g.top + g.bh * 0.38, g.cz) * CFrame.Angles(math.rad(45), math.rad(45), 0), color = st.glow, mat = M.Neon, tr = 0.35 })
	emit(holo, st.glow, nil, 6, 0.1, 0.6, 0.8, Vector3.new(0, 1, 0))
	bpLight(holo, st.glow, 7)
end

BX.bp_royal = function(m, st, g)
	-- рубины по углам и корона-эмблема
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			P(m, { shape = Ball, size = Vector3.one * g.bw * 0.1, cf = CFrame.new(sx * g.bw * 0.38, g.cy + sy * g.bh * 0.32, g.back + 0.03), color = st.gem, mat = M.Glass, refl = 0.4 })
		end
	end
	local cy = g.cy + g.bh * 0.02
	P(m, { size = Vector3.new(g.bw * 0.4, g.bh * 0.12, 0.08), cf = CFrame.new(0, cy - g.bh * 0.08, g.back + 0.04), color = C(255, 215, 110), v = "ZSSG_W_GoldEngraved" })
	for k = -1, 1 do
		P(m, { class = "WedgePart", size = Vector3.new(0.08, g.bh * (k == 0 and 0.2 or 0.14), g.bw * 0.1), cf = CFrame.new(k * g.bw * 0.15, cy + g.bh * 0.04, g.back + 0.04) * CFrame.Angles(0, R90, 0), color = C(255, 215, 110), v = "ZSSG_W_GoldEngraved" })
	end
	local ruby = P(m, { name = "Gem", size = Vector3.new(g.bw * 0.12, g.bw * 0.12, 0.1), cf = CFrame.new(0, cy - g.bh * 0.08, g.back + 0.09) * CFrame.Angles(0, 0, math.rad(45)), color = st.gem, mat = M.Glass, refl = 0.4 })
	bpLight(ruby, st.gem, 4)
	emit(ruby, C(255, 230, 150), nil, 3, 0.15, 0.5, 0.6)
end

BX.bp_omega = function(m, st, g)
	-- портал в карманное измерение
	local portal = disc(m, { name = "Portal", th = 0.06, dia = g.bh * 0.75, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.04), color = C(170, 80, 255), mat = M.Neon })
	disc(m, { th = 0.08, dia = g.bh * 0.5, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.05), color = C(10, 0, 25), mat = M.SmoothPlastic })
	disc(m, { th = 0.1, dia = g.bh * 0.2, cf = CFrame.new(0, g.cy + g.bh * 0.05, g.back + 0.06), color = st.glow, mat = M.Neon })
	emit(portal, ColorSequence.new(st.glow, C(170, 80, 255)), nil, 10, 0.2, 1, 0.6)
	bpLight(portal, C(170, 80, 255), 9)
	-- энергетические крылья
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local f = P(m, { name = "Wing", size = Vector3.new(g.bw * (0.9 - k * 0.15), 0.06, g.bd * 0.3), cf = CFrame.new(sx * g.bw * (0.45 + k * 0.06), g.cy + g.bh * (0.35 - k * 0.22), g.cz) * CFrame.Angles(0, 0, sx * (0.55 - k * 0.15)) * CFrame.new(sx * g.bw * 0.4, 0, 0), color = st.glow, mat = M.Neon, tr = 0.25 + k * 0.1 })
			if k == 0 then
				emit(f, st.glow, nil, 6, 0.2, 1, 0.6)
			end
		end
	end
end

-- лямки через плечи на грудь (видны спереди)
local function bpStraps(m, st, w, h, zb, zf)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * w * 0.25
		P(m, { name = "Strap", size = Vector3.new(w * 0.13, h * 0.8, 0.06), cf = CFrame.new(x, -h * 0.02, zf - 0.03), color = st.strap, v = st.strapV })
		P(m, { name = "Strap", size = Vector3.new(w * 0.13, 0.08, zb - zf + 0.06), cf = CFrame.new(x, h * 0.5 + 0.04, (zb + zf) / 2), color = st.strap, v = st.strapV })
		P(m, { name = "Buckle", size = Vector3.new(w * 0.15, 0.1, 0.05), cf = CFrame.new(x, -h * 0.3, zf - 0.07), color = C(190, 190, 195), mat = M.Metal })
	end
	if st.chest then
		P(m, { name = "ChestStrap", size = Vector3.new(w * 0.52, 0.08, 0.05), cf = CFrame.new(0, h * 0.18, zf - 0.07), color = st.strap, v = st.strapV })
	end
end

-- качественные 3D-модели рюкзаков (ReplicatedStorage.ZSS.BackpackMeshes/<id>):
-- шаблон с центром габаритов в начале координат, сторона к спине игрока смотрит в -Z.
-- Fit / Height — предельные ширина и высота относительно торса, Up — сдвиг вверх (доля высоты торса),
-- Sink — какая доля глубины модели (лямки сзади) уходит в спину.
local function backpackMesh(m, id, st, w, h, zb)
	local z = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	local lib = z and z:FindFirstChild("BackpackMeshes")
	local tpl = lib and lib:FindFirstChild(id)
	if not tpl then
		return false
	end
	local c = tpl:Clone()
	local _, size = c:GetBoundingBox()
	local k = math.min(w * (tpl:GetAttribute("Fit") or 0.9) / size.X, h * (tpl:GetAttribute("Height") or 1.0) / size.Y)
	c:ScaleTo(c:GetScale() * k)
	local _, sz = c:GetBoundingBox()
	c:PivotTo(CFrame.new(0, h * (tpl:GetAttribute("Up") or 0), zb + sz.Z * (0.5 - (tpl:GetAttribute("Sink") or 0.06))))
	local first
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			p.Name = "Bag"
			p.Parent = m
			first = first or p
		end
	end
	c:Destroy()
	if first and (st.glow or st.gem) then
		bpLight(first, st.glow or st.gem, 7)
	end
	return first ~= nil
end

function IB.Backpack(item, box, armored)
	box = box or Vector3.new(2, 1.6, 1)
	local st = BP[item.id] or BP.bp_old
	local m = newModel(item.id)
	root(m)
	local w, h, d = box.X, box.Y, box.Z
	local zb = armored and d * 0.85 or d * 0.52 -- спина (или 3D-броня на спине)
	local zf = -(armored and d * 0.7 or d * 0.53) -- грудь
	if backpackMesh(m, item.id, st, w, h, zb) then
		bpStraps(m, st, w, h, zb, zf)
		return m
	end
	local g = { bw = w * (st.bw or 0.8), bh = h * (st.bh or 0.86), bd = d * (st.bd or 0.6) }
	g.cy = h * (st.by or -0.04)
	g.cz = zb + g.bd / 2
	g.back = zb + g.bd
	g.top = g.cy + g.bh / 2
	-- корпус
	P(m, { name = "Bag", size = Vector3.new(g.bw, g.bh, g.bd), cf = CFrame.new(0, g.cy, g.cz), color = st.main, v = st.v })
	if st.round then
		P(m, { name = "Lid", shape = Cyl, size = Vector3.new(g.bw, g.bd, g.bd), cf = CFrame.new(0, g.top, g.cz), color = st.main, v = st.v })
	end
	-- окантовка дна
	P(m, { name = "Base", size = Vector3.new(g.bw * 1.03, g.bh * 0.08, g.bd * 1.04), cf = CFrame.new(0, g.cy - g.bh * 0.46, g.cz), color = st.trim or st.strap, v = st.trimV or st.strapV })
	-- клапан
	if st.flap then
		P(m, { name = "Flap", size = Vector3.new(g.bw * 1.02, g.bh * 0.3, 0.08), cf = CFrame.new(0, g.cy + g.bh * 0.34, g.back + 0.04), color = st.pocket or st.main, v = st.pocketV or st.v })
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { size = Vector3.new(0.12, 0.08, 0.06), cf = CFrame.new(sx * g.bw * 0.25, g.cy + g.bh * 0.2, g.back + 0.09), color = C(30, 30, 30), mat = M.SmoothPlastic })
		end
	end
	-- передний карман с молнией
	g.pocketX, g.pocketY, g.pocketZ = 0, g.cy - g.bh * 0.18, g.back + g.bd * 0.15
	if not st.nopocket then
		P(m, { name = "Pocket", size = Vector3.new(g.bw * 0.72, g.bh * 0.4, g.bd * 0.3), cf = CFrame.new(0, g.pocketY, g.back + g.bd * 0.15 - 0.01), color = st.pocket or st.main, v = st.pocketV or st.v })
		P(m, { name = "Zip", size = Vector3.new(g.bw * 0.66, 0.04, 0.03), cf = CFrame.new(0, g.pocketY + g.bh * 0.12, g.back + g.bd * 0.3), color = C(40, 40, 40), mat = M.Metal })
		P(m, { size = Vector3.new(0.06, 0.14, 0.04), cf = CFrame.new(g.bw * 0.22, g.pocketY + g.bh * 0.08, g.back + g.bd * 0.31), color = C(200, 200, 205), mat = M.Metal })
		g.pocketZ = g.back + g.bd * 0.3
	end
	-- боковые карманы
	if st.side then
		for _, sx in ipairs({ -1, 1 }) do
			P(m, { name = "SidePocket", size = Vector3.new(g.bw * 0.16, g.bh * 0.42, g.bd * 0.7), cf = CFrame.new(sx * (g.bw / 2 + g.bw * 0.07), g.cy - g.bh * 0.2, g.cz), color = st.pocket or st.main, v = st.pocketV or st.v })
		end
	end
	bpStraps(m, st, w, h, zb, zf)
	if BX[item.id] then
		BX[item.id](m, st, g)
	end
	return m
end

-- Модель для превью (перчатки/ботинки парой, шлем с головой-манекеном)
-- 3D-модели новых расходников: заготовка по типу (kind) + два цвета предмета
local function consumableModel(m, o)
	local c1, c2 = o.c1, o.c2
	local k = o.kind
	local dark = C(55, 58, 64)
	if k == "can" then -- канистра-маслёнка с носиком
		vcyl(m, { len = 1.7, d = 1.3, color = c1, v = "ZSS_D_Metal" })
		vcyl(m, { len = 0.5, d = 1.34, cf = CFrame.new(0, 0.1, 0), color = c2, mat = M.SmoothPlastic })
		vcyl(m, { len = 0.25, d = 0.9, cf = CFrame.new(0, 0.95, 0), color = dark, v = "ZSS_D_Metal" })
		P(m, { size = Vector3.new(0.18, 1.1, 0.18), cf = CFrame.new(0.25, 1.4, 0) * CFrame.Angles(0, 0, -0.6), color = C(190, 190, 195), mat = M.Metal })
		P(m, { shape = Ball, size = Vector3.one * 0.22, cf = CFrame.new(0.72, 1.75, 0), color = c2, mat = M.Neon })
	elseif k == "spray" then -- баллончик
		vcyl(m, { len = 2.2, d = 0.9, color = c1, mat = M.Metal, refl = 0.15 })
		vcyl(m, { len = 0.5, d = 0.92, cf = CFrame.new(0, -0.6, 0), color = c2, mat = M.SmoothPlastic })
		P(m, { shape = Ball, size = Vector3.new(0.9, 0.5, 0.9), cf = CFrame.new(0, 1.1, 0), color = c1, mat = M.Metal })
		vcyl(m, { len = 0.35, d = 0.3, cf = CFrame.new(0, 1.45, 0), color = C(240, 240, 240) })
		P(m, { size = Vector3.new(0.12, 0.12, 0.3), cf = CFrame.new(0, 1.5, -0.18), color = dark })
	elseif k == "syringe" then -- шприц-инъектор
		vcyl(m, { len = 1.9, d = 0.55, color = C(230, 240, 255), mat = M.Glass, tr = 0.35, refl = 0.2 })
		vcyl(m, { len = 1.3, d = 0.46, cf = CFrame.new(0, -0.2, 0), color = c1, mat = M.Neon, tr = 0.1 })
		vcyl(m, { len = 0.14, d = 1.0, cf = CFrame.new(0, 0.95, 0), color = dark, v = "ZSSG_W_Carbon" })
		vcyl(m, { len = 0.7, d = 0.16, cf = CFrame.new(0, 1.35, 0), color = c2, mat = M.Metal })
		vcyl(m, { len = 0.12, d = 0.6, cf = CFrame.new(0, 1.75, 0), color = c1, mat = M.SmoothPlastic })
		vcyl(m, { len = 0.8, d = 0.06, cf = CFrame.new(0, -1.35, 0), color = C(220, 225, 235), mat = M.Metal })
	elseif k == "flare" then -- сигнальная ракета
		vcyl(m, { len = 2.3, d = 0.6, color = c1, mat = M.SmoothPlastic })
		vcyl(m, { len = 0.3, d = 0.64, cf = CFrame.new(0, 0.6, 0), color = C(240, 240, 240) })
		vcyl(m, { len = 0.3, d = 0.64, cf = CFrame.new(0, -0.6, 0), color = C(240, 240, 240) })
		P(m, { shape = Ball, size = Vector3.one * 0.62, cf = CFrame.new(0, 1.15, 0), color = c2, mat = M.Neon })
		local f = P(m, { size = Vector3.one * 0.1, cf = CFrame.new(0, 1.3, 0), tr = 1 })
		emit(f, ColorSequence.new(c2, c1), SPARK_TEX, 14, 0.25, 2.5, 0.5, Vector3.new(0, 3, 0))
	elseif k == "device" then -- карманный прибор с экраном и антенной
		P(m, { size = Vector3.new(1.4, 1.9, 0.6), color = c1, v = "ZSS_D_SciFi" })
		P(m, { size = Vector3.new(1.05, 0.8, 0.06), cf = CFrame.new(0, 0.35, -0.31), color = c2, mat = M.Neon, tr = 0.1 })
		for i = -1, 1 do
			P(m, { shape = Ball, size = Vector3.one * 0.22, cf = CFrame.new(i * 0.35, -0.5, -0.3), color = i == 0 and c2 or C(230, 230, 230), mat = i == 0 and M.Neon or M.SmoothPlastic })
		end
		vcyl(m, { len = 0.8, d = 0.08, cf = CFrame.new(0.5, 1.3, 0), color = C(200, 200, 205), mat = M.Metal })
		P(m, { shape = Ball, size = Vector3.one * 0.2, cf = CFrame.new(0.5, 1.72, 0), color = c2, mat = M.Neon })
	elseif k == "crate" then -- ящик со взрывчаткой
		P(m, { size = Vector3.new(1.8, 1.6, 1.8), color = c1, mat = M.WoodPlanks })
		for _, y in ipairs({ -0.55, 0.55 }) do
			P(m, { size = Vector3.new(1.86, 0.22, 1.86), cf = CFrame.new(0, y, 0), color = dark, v = "ZSS_D_Metal" })
		end
		P(m, { size = Vector3.new(1.0, 0.5, 0.05), cf = CFrame.new(0, 0, -0.92), color = c2, v = "ZSS_D_Hazard" })
		P(m, { shape = Ball, size = Vector3.one * 0.3, cf = CFrame.new(0, 0.95, 0), color = C(255, 60, 40), mat = M.Neon })
	elseif k == "coin" then -- огромная счастливая гайка
		local hex = P(m, { shape = Cyl, size = Vector3.new(0.5, 1.9, 1.9), cf = CFrame.Angles(0, math.rad(90), 0), color = c1, mat = M.Metal, refl = 0.25 })
		hex.Name = "Nut"
		vcyl(m, { len = 0.55, d = 0.8, cf = CFrame.Angles(math.rad(90), 0, 0), color = C(30, 30, 30) })
		P(m, { shape = Ball, size = Vector3.one * 0.35, cf = CFrame.new(0.6, 0.6, -0.3), color = c2, mat = M.Neon })
	elseif k == "box" then -- коробка с ручкой
		P(m, { size = Vector3.new(1.9, 1.3, 1.4), color = c1, mat = M.Cardboard })
		P(m, { size = Vector3.new(1.95, 0.2, 1.45), cf = CFrame.new(0, 0.55, 0), color = c2, mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(0.9, 0.12, 0.12), cf = CFrame.new(0, 0.95, 0), color = dark })
		for _, x in ipairs({ -0.45, 0.45 }) do
			P(m, { size = Vector3.new(0.12, 0.35, 0.12), cf = CFrame.new(x, 0.8, 0), color = dark })
		end
		P(m, { shape = Ball, size = Vector3.one * 0.4, cf = CFrame.new(0, 0, -0.72), color = c2, mat = M.Neon })
	elseif k == "tube" then -- тюбик с гелем
		P(m, { shape = Cyl, size = Vector3.new(2.0, 0.9, 0.9), cf = CFrame.Angles(0, 0, math.rad(90)), color = c2, mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(1.0, 0.12, 0.6), cf = CFrame.new(0, -1.05, 0), color = c2, mat = M.SmoothPlastic })
		vcyl(m, { len = 0.4, d = 0.45, cf = CFrame.new(0, 1.15, 0), color = c1, mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(0.9, 0.9, 0.04), cf = CFrame.new(0, 0, -0.45), color = c1, mat = M.Neon, tr = 0.2 })
	elseif k == "vial" then -- колба с жидкостью
		P(m, { shape = Ball, size = Vector3.one * 1.5, cf = CFrame.new(0, -0.3, 0), color = C(230, 240, 255), mat = M.Glass, tr = 0.4, refl = 0.2 })
		P(m, { shape = Ball, size = Vector3.one * 1.25, cf = CFrame.new(0, -0.38, 0), color = c1, mat = M.Neon, tr = 0.15 })
		vcyl(m, { len = 0.9, d = 0.45, cf = CFrame.new(0, 0.75, 0), color = C(230, 240, 255), mat = M.Glass, tr = 0.4 })
		vcyl(m, { len = 0.35, d = 0.52, cf = CFrame.new(0, 1.3, 0), color = c2, mat = M.Wood })
		local f = P(m, { size = Vector3.one * 0.1, cf = CFrame.new(0, -0.2, 0), tr = 1 })
		emit(f, c1, SPARK_TEX, 6, 0.18, 1, 0.8, Vector3.new(0, 1, 0))
	elseif k == "jar" then -- банка с бактериями
		vcyl(m, { len = 1.6, d = 1.4, color = C(230, 240, 255), mat = M.Glass, tr = 0.45, refl = 0.15 })
		vcyl(m, { len = 1.2, d = 1.25, cf = CFrame.new(0, -0.15, 0), color = c1, mat = M.Neon, tr = 0.25 })
		vcyl(m, { len = 0.3, d = 1.5, cf = CFrame.new(0, 0.9, 0), color = c2, v = "ZSS_D_Metal" })
		for i = 1, 4 do
			P(m, { shape = Ball, size = Vector3.one * 0.25, cf = CFrame.new(math.cos(i * 1.6) * 0.35, -0.4 + i * 0.22, math.sin(i * 1.6) * 0.35), color = c1:Lerp(C(255, 255, 255), 0.5), mat = M.Neon })
		end
	elseif k == "cup" then -- стакан-коктейль с трубочкой
		vcyl(m, { len = 1.8, d = 1.2, color = C(235, 245, 255), mat = M.Glass, tr = 0.4, refl = 0.15 })
		vcyl(m, { len = 1.2, d = 1.05, cf = CFrame.new(0, -0.2, 0), color = c1, mat = M.SmoothPlastic, tr = 0.05 })
		vcyl(m, { len = 0.35, d = 1.08, cf = CFrame.new(0, 0.55, 0), color = c2, mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(0.12, 1.6, 0.12), cf = CFrame.new(0.25, 1.1, 0) * CFrame.Angles(0, 0, -0.3), color = c2, mat = M.Neon })
		P(m, { shape = Ball, size = Vector3.one * 0.45, cf = CFrame.new(-0.35, 0.95, 0), color = C(255, 60, 70) })
	elseif k == "seed" then -- семя-мутант
		P(m, { shape = Ball, size = Vector3.new(1.3, 1.8, 1.3), color = c1, mat = M.SmoothPlastic })
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			P(m, { size = Vector3.new(0.08, 1.4, 0.08), cf = CFrame.new(math.cos(a) * 0.55, 0, math.sin(a) * 0.55) * CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), color = c2, mat = M.Neon })
		end
		P(m, { size = Vector3.new(0.15, 0.6, 0.15), cf = CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, 0.3), color = C(90, 200, 70) })
		P(m, { size = Vector3.new(0.5, 0.08, 0.3), cf = CFrame.new(-0.25, 1.3, 0) * CFrame.Angles(0, 0, 0.5), color = C(110, 230, 80) })
	end
end

function IB.Consumable(item)
	local m = newModel(item.id)
	root(m)
	if item.id == "medkit" then
		P(m, { size = Vector3.new(2.2, 1.6, 1), color = C(240, 240, 240), mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(0.8, 0.3, 0.5), cf = CFrame.new(0, 0.95, 0), color = C(60, 60, 60), mat = M.SmoothPlastic })
		P(m, { size = Vector3.new(0.9, 0.3, 0.06), cf = CFrame.new(0, 0, -0.52), color = C(220, 30, 40), mat = M.Neon })
		P(m, { size = Vector3.new(0.3, 0.9, 0.06), cf = CFrame.new(0, 0, -0.52), color = C(220, 30, 40), mat = M.Neon })
	elseif item.id == "energycell" then
		vcyl(m, { len = 2.2, d = 1, color = C(60, 140, 220), v = "ZSS_D_SciFi" })
		vcyl(m, { len = 1.6, d = 1.04, color = C(80, 230, 255), mat = M.Neon, tr = 0.35 })
		vcyl(m, { len = 0.3, d = 0.5, cf = CFrame.new(0, 1.25, 0), color = C(60, 60, 60), v = "ZSS_D_Metal" })
	elseif item.id == "adrenaline" then
		vcyl(m, { len = 1.8, d = 0.6, color = C(230, 240, 255), mat = M.Glass, tr = 0.3, refl = 0.2 })
		vcyl(m, { len = 1.1, d = 0.5, cf = CFrame.new(0, -0.25, 0), color = C(255, 60, 120), mat = M.Neon, tr = 0.15 })
		vcyl(m, { len = 0.12, d = 1.0, cf = CFrame.new(0, 0.9, 0), color = C(70, 75, 90), v = "ZSSG_W_Carbon" })
		vcyl(m, { len = 0.8, d = 0.16, cf = CFrame.new(0, 1.35, 0), color = C(70, 75, 90), v = "ZSSG_W_Carbon" })
		vcyl(m, { len = 0.12, d = 0.55, cf = CFrame.new(0, 1.78, 0), color = C(70, 75, 90), v = "ZSSG_W_Carbon" })
		vcyl(m, { len = 0.7, d = 0.06, cf = CFrame.new(0, -1.25, 0), color = C(220, 225, 235), mat = M.Metal })
	elseif item.model then
		consumableModel(m, item.model)
	else
		P(m, { shape = Ball, size = Vector3.new(1.4, 1.7, 1.4), color = C(90, 120, 50), v = "ZSS_D_Camo" })
		vcyl(m, { len = 0.5, d = 0.6, cf = CFrame.new(0, 0.95, 0), color = C(150, 150, 155), v = "ZSS_D_Metal" })
		P(m, { size = Vector3.new(0.2, 1.1, 0.25), cf = CFrame.new(0.45, 0.6, 0) * CFrame.Angles(0, 0, -0.3), color = C(170, 170, 175), mat = M.Metal })
	end
	return m
end

-- карточка магазина: сама 3D-модель в своих пропорциях, без поддоспешника и рукавов.
-- Возвращает MeshPart в начале координат (лицом к -Z) и его ширину, или nil, если шаблона нет.
local function previewMesh(m, libName, key, torso)
	local z = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	local lib = z and z:FindFirstChild(libName)
	local tpl = lib and lib:FindFirstChild(key)
	local src = tpl and tpl:FindFirstChildWhichIsA("BasePart", true)
	if not src then
		return nil
	end
	local yaw = math.rad(tpl:GetAttribute("Yaw") or 0)
	local side = math.abs(math.cos(yaw)) < 0.5
	local w, h, d = src.Size.X, src.Size.Y, src.Size.Z
	if side then
		w, d = d, w
	end
	if torso then
		-- часть жилетов сгенерирована узкой и глубокой; в карточке приводим к пропорциям торса
		w = math.max(w, h * 0.85)
		d = math.min(d, w * 0.8)
	end
	local p = src:Clone()
	for _, c in ipairs(p:GetChildren()) do
		c:Destroy()
	end
	p.Size = side and Vector3.new(d, h, w) or Vector3.new(w, h, d)
	p.CFrame = CFrame.Angles(0, yaw, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Name = "Shell"
	p.Parent = m
	return p, w
end

function IB.Preview(item)
	if item.slot == "consumable" then
		return IB.Consumable(item)
	elseif item.slot == "weapon" or item.slot == "tool" then
		local m = IB.Weapon(item)
		-- наклон относительно собственной ориентации рукояти (цилиндры повёрнуты на 90°)
		m:PivotTo(CFrame.Angles(0, 0, math.rad(-35)) * m:GetPivot())
		return m
	elseif item.slot == "armor" then
		local m = newModel(item.id)
		root(m)
		if previewMesh(m, "ArmorMeshes", "armor" .. item.tier, true) then
			return m
		end
		m:Destroy()
		return IB.Armor(item)
	elseif item.slot == "backpack" then
		-- рюкзак повёрнут к камере передним карманом
		local m = IB.Backpack(item)
		m:PivotTo(CFrame.Angles(0, math.pi, 0))
		return m
	elseif item.slot == "helmet" then
		local m = IB.Helmet(item)
		if not m:GetAttribute("HideHead") then
			P(m, { name = "Mannequin", shape = Ball, size = Vector3.one * 1.1, color = C(225, 215, 200), mat = M.SmoothPlastic })
		end
		return m
	else
		local holder = newModel(item.id)
		local lib = item.slot == "gloves" and "GloveMeshes" or "BootMeshes"
		local left, w = previewMesh(holder, lib, item.id)
		if left then
			root(holder)
			local right = previewMesh(holder, lib, item.id)
			left.CFrame = CFrame.new(-w * 0.62, 0, 0) * CFrame.Angles(0, -0.25, 0) * left.CFrame
			right.CFrame = CFrame.new(w * 0.62, 0, 0) * CFrame.Angles(0, 0.25, 0) * right.CFrame
			return holder
		end
		for _, sx in ipairs({ -1, 1 }) do
			local one = item.slot == "gloves" and IB.Glove(item) or IB.Boot(item)
			one:PivotTo(CFrame.new(sx * 0.55, 0, 0) * CFrame.Angles(0, sx * 0.25, 0))
			for _, c in ipairs(one:GetChildren()) do
				c.Parent = holder
			end
			one:Destroy()
		end
		return holder
	end
end

function IB.Build(item)
	return IB.Preview(item)
end

return IB
