-- Процедурная сборка 3D-моделей дронов из конфига.
-- Модель смотрит вдоль -Z, PrimaryPart = "Core" (невидимый центр).
-- Атрибуты деталей: Tint (перекрашивается радугой/пульсом), Spin+SpinAxis (вращение вокруг своей оси),
-- Orbit (вращение вокруг центра дрона).
local Config = require(script.Parent.Config)

local Builder = {}

local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local Ball, Cyl = Enum.PartType.Ball, Enum.PartType.Cylinder
local Mat = Enum.Material
local R90 = math.rad(90)

-- ===== ТЕКСТУРЫ (MaterialVariant из бесплатных ассетов Creator Store, см. MaterialService.ZSS_Materials) =====
local VARIANT_BASE = {
	ZSS_D_Metal = Mat.Metal,
	ZSS_D_Carbon = Mat.SmoothPlastic,
	ZSS_D_Rust = Mat.CorrodedMetal,
	ZSS_D_RustChipped = Mat.CorrodedMetal,
	ZSS_D_Camo = Mat.Fabric,
	ZSS_D_Hazard = Mat.SmoothPlastic,
	ZSS_D_Gold = Mat.Foil,
	ZSS_D_SciFi = Mat.Metal,
	ZSS_D_Plate = Mat.DiamondPlate,
}
-- у этих текстур свои цвета — осветляем тонировку, чтобы рисунок не терялся
local KEEP_COLOR = { ZSS_D_Hazard = 0.8, ZSS_D_Gold = 0.75, ZSS_D_Camo = 0.55, ZSS_D_RustChipped = 0.35 }
-- базовая текстура по материалу
local DEFAULT_VARIANT = { Metal = "ZSS_D_Metal", CorrodedMetal = "ZSS_D_Rust", DiamondPlate = "ZSS_D_Plate", Foil = "ZSS_D_Gold" }
-- тёмные детали — карбон
local CARBON_PARTS = { Motor = true, Bottom = true, Lens = true, CannonBase = true, Cannon = true, Barrel = true, Camera = true, Rod = true, Cap = true, MagTip = false }
-- уникальная текстура корпуса каждого дрона
local BODY_VARIANT = {
	scout = "ZSS_D_Metal",
	collector = "ZSS_D_RustChipped",
	spark = "ZSS_D_Metal",
	buzzsaw = "ZSS_D_Plate",
	medic = "ZSS_D_Metal",
	magnet = "ZSS_D_SciFi",
	volt = "ZSS_D_SciFi",
	recycler = "ZSS_D_RustChipped",
	turret = "ZSS_D_Camo",
	plague = "ZSS_D_SciFi",
	inferno = "ZSS_D_RustChipped",
	overclock = "ZSS_D_Carbon",
	goliath = "ZSS_D_Hazard",
	midas = "ZSS_D_Gold",
	queen = "ZSS_D_Gold",
	necro = "ZSS_D_Carbon",
	apocalypse = "ZSS_D_RustChipped",
	mini = "ZSS_D_Gold",
}

local function applyVariant(p, name)
	local base = VARIANT_BASE[name]
	if not base then
		return
	end
	p.Material = base
	p.MaterialVariant = name
	local k = KEEP_COLOR[name]
	if k then
		p.Color = p.Color:Lerp(Color3.new(1, 1, 1), k)
	end
end

local function texturize(model, def)
	local bodyVariant = BODY_VARIANT[def.id]
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.9 and p.Material ~= Mat.Neon and p.Material ~= Mat.Glass and p.Material ~= Mat.Ice then
			if bodyVariant and (p.Name == "Body" or p.Name == "Jaw") then
				applyVariant(p, bodyVariant)
			elseif CARBON_PARTS[p.Name] then
				applyVariant(p, "ZSS_D_Carbon")
			elseif DEFAULT_VARIANT[p.Material.Name] then
				applyVariant(p, DEFAULT_VARIANT[p.Material.Name])
			end
		end
	end
end

local function newPart(model, o)
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
	p.Color = o.color or Color3.new(1, 1, 1)
	p.Material = o.mat or Mat.SmoothPlastic
	p.Transparency = o.tr or 0
	p.Reflectance = o.refl or 0
	p.Name = o.name or "Part"
	if o.tint then
		p:SetAttribute("Tint", true)
	end
	if o.spin then
		p:SetAttribute("Spin", o.spin)
		p:SetAttribute("SpinAxis", o.axis or "Y")
	end
	if o.orbit then
		p:SetAttribute("Orbit", o.orbit)
	end
	p.Parent = model
	return p
end

local function emitter(parent, o)
	local a = Instance.new("Attachment")
	a.Position = o.pos or Vector3.zero
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or SPARK_TEX
	e.Color = typeof(o.color) == "ColorSequence" and o.color or ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.size0 or 0.3),
		NumberSequenceKeypoint.new(1, o.size1 or 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.t0 or 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(o.life0 or 0.5, o.life1 or 1)
	e.Rate = o.rate or 10
	e.Speed = NumberRange.new(o.speed0 or 0.5, o.speed1 or 2)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.LightEmission = o.light or 1
	e.Acceleration = o.accel or Vector3.zero
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Parent = a
	return e
end

local function trail(part, p0, p1, color, life)
	local a0 = Instance.new("Attachment")
	a0.Position = p0
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = p1
	a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = life or 0.35
	tr.Color = ColorSequence.new(color)
	tr.Transparency = NumberSequence.new(0.25, 1)
	tr.LightEmission = 1
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Parent = part
	return tr
end

-- ===== ДРОНЫ ИЗ МЕШЕЙ (AI-генерация с PBR-текстурами, ReplicatedStorage.ZSS.DroneMeshes) =====
-- У шаблона корпус "Hull" и блоки винтов "RotorN" (атрибут Rotor). Над каждым блоком добавляются
-- крутящиеся лопасти и «размытие», снизу — светящееся кольцо редкости, а также все частицы и ауры.
local function meshLib()
	local zss = game:GetService("ReplicatedStorage"):FindFirstChild("ZSS")
	return zss and zss:FindFirstChild("DroneMeshes")
end

local function buildFromMesh(def, scale, tpl)
	local look = def.look
	local s = (look.size or 1) * (scale or 1)
	local rarity = Config.Rarities[def.rarity]
	local rainbow = rarity.rainbow == true
	local secret = def.rarity == "Secret"
	local rcol = rarity.color
	local c1, c2 = look.c1, look.c2
	local extras = look.extras or {}
	local function has(x)
		return table.find(extras, x) ~= nil
	end
	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("DroneId", def.id)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Mesh", true)
	if rainbow then
		model:SetAttribute("Rainbow", true)
	end
	if secret then
		model:SetAttribute("Secret", true)
	end
	local core = newPart(model, { name = "Core", size = Vector3.one * 0.2 * s, tr = 1 })
	model.PrimaryPart = core

	local hull = tpl:Clone()
	hull:PivotTo(CFrame.new())
	if s ~= 1 then
		hull:ScaleTo(s)
	end
	local rotors = {}
	for _, p in ipairs(hull:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = model
			if p:GetAttribute("Rotor") then
				table.insert(rotors, p)
			end
		end
	end
	hull:Destroy()
	local _, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2
	local topY = size.Y / 2

	-- крутящиеся лопасти над блоками винтов
	local bladeCol = secret and Color3.fromRGB(90, 20, 22) or Color3.fromRGB(70, 74, 82)
	for _, r in ipairs(rotors) do
		local len = math.clamp(math.max(r.Size.X, r.Size.Z) * 0.95, 0.6 * s, 1.9 * s)
		local top = r.Position + Vector3.new(0, r.Size.Y / 2 + 0.03 * s, 0)
		local bcf = CFrame.new(top)
		newPart(model, { name = "Blade", size = Vector3.new(len, 0.025 * s, 0.09 * s), cf = bcf * CFrame.Angles(0.12, 0, 0), color = bladeCol, mat = Mat.SmoothPlastic, tr = 0.35, spin = 30 })
		newPart(model, { name = "Blade", size = Vector3.new(len, 0.025 * s, 0.09 * s), cf = bcf * CFrame.Angles(0, R90, 0) * CFrame.Angles(0.12, 0, 0), color = bladeCol, mat = Mat.SmoothPlastic, tr = 0.35, spin = 30 })
		newPart(model, { name = "BladeBlur", shape = Cyl, size = Vector3.new(0.015 * s, len, len), cf = bcf * CFrame.new(0, 0.01 * s, 0) * CFrame.Angles(0, 0, R90), color = Color3.fromRGB(215, 225, 235), mat = Mat.SmoothPlastic, tr = 0.88 })
		newPart(model, { name = "Tip", shape = Ball, size = Vector3.one * 0.1 * s, cf = bcf * CFrame.new(0, 0.04 * s, 0), color = rcol, mat = Mat.Neon, tint = true })
	end

	-- кольцо редкости под днищем
	if rarity.order >= 2 then
		local rr = radius * 0.5
		local n = 28
		for k = 0, n - 1 do
			local ang = k / n * math.pi * 2
			local pos = Vector3.new(math.cos(ang) * rr, -topY * 0.92, math.sin(ang) * rr)
			newPart(model, { name = "RarityRing", size = Vector3.new(0.06 * s, 0.04 * s, 2 * math.pi * rr / n * 1.08), cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(ang), 0, math.cos(ang))), color = rcol, mat = Mat.Neon, tint = true, orbit = rarity.order >= 4 and 1.2 or nil })
		end
	end

	-- эффекты (те же, что у процедурных дронов)
	if has("sparks") then
		emitter(core, { color = Color3.fromRGB(255, 240, 120), rate = 8, size0 = 0.25 * s, speed0 = 2, speed1 = 5, life0 = 0.15, life1 = 0.35, pos = Vector3.new(0, topY, 0) })
	end
	if has("snow") then
		emitter(core, { color = Color3.fromRGB(230, 245, 255), rate = 7, size0 = 0.18 * s, size1 = 0.1 * s, speed0 = 0.5, speed1 = 1.5, life0 = 0.8, life1 = 1.5, accel = Vector3.new(0, -3, 0) })
	end
	if has("lightning") then
		emitter(core, { color = Color3.fromRGB(120, 230, 255), rate = 14, size0 = 0.3 * s, speed0 = 3, speed1 = 6, life0 = 0.1, life1 = 0.25 })
	end
	if has("toxic") then
		emitter(core, { texture = SMOKE_TEX, color = Color3.fromRGB(120, 255, 80), rate = 5, size0 = 0.6 * s, size1 = 1.4 * s, t0 = 0.55, life0 = 1, life1 = 1.8, speed0 = 0.3, speed1 = 0.8, light = 0.4, accel = Vector3.new(0, -0.8, 0) })
	end
	if has("ghost") then
		emitter(core, { color = Color3.fromRGB(210, 170, 255), rate = 10, size0 = 0.35 * s, life0 = 0.6, life1 = 1.2, speed0 = 0.2, speed1 = 0.8 })
		trail(core, Vector3.new(-0.7 * s, 0, 0), Vector3.new(0.7 * s, 0, 0), c1, 0.45)
	end
	if has("speedtrail") then
		trail(core, Vector3.new(0, -0.3 * s, 0), Vector3.new(0, 0.3 * s, 0), c2, 0.3)
	end
	if has("flame") then
		local fc = secret and ColorSequence.new(Color3.fromRGB(255, 40, 30), Color3.fromRGB(60, 0, 0)) or ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 10))
		emitter(core, { texture = FIRE_TEX, color = fc, rate = 26, size0 = 0.6 * s, size1 = 0.1 * s, t0 = 0.15, life0 = 0.3, life1 = 0.6, speed0 = 1, speed1 = 2.5, accel = Vector3.new(0, 5, 0), pos = Vector3.new(0, topY * 0.6, 0.2 * s), spread = Vector2.new(25, 25) })
	end
	if has("sparkles") then
		emitter(core, { color = rainbow and Config.RainbowSequence or Color3.fromRGB(255, 230, 120), rate = 9, size0 = 0.3 * s, speed0 = 0.5, speed1 = 1.5, life0 = 0.6, life1 = 1.2 })
	end
	if has("orbit") then
		for k = 0, 2 do
			local ang = k / 3 * math.pi * 2
			newPart(model, { name = "OrbitBall", shape = Ball, size = Vector3.one * 0.3 * s, cf = CFrame.new(math.cos(ang) * (radius + 0.5 * s), 0.1 * s, math.sin(ang) * (radius + 0.5 * s)), color = c2, mat = Mat.Neon, tint = true, orbit = 2.4 })
		end
	end
	if has("souls") then
		emitter(core, { color = Config.RainbowSequence, rate = 10, size0 = 0.4 * s, size1 = 0, life0 = 0.8, life1 = 1.6, speed0 = 0.5, speed1 = 1.2, accel = Vector3.new(0, 2.5, 0) })
	end
	-- новые дроны: пыль из-под бура, искры грозы, частицы времени, всасывание в ядро
	if has("drilldust") then
		emitter(core, { texture = SMOKE_TEX, color = ColorSequence.new(Color3.fromRGB(200, 150, 100), Color3.fromRGB(110, 80, 55)), rate = 4, size0 = 0.3 * s, size1 = 0.9 * s, t0 = 0.5, life0 = 0.6, life1 = 1.1, speed0 = 0.5, speed1 = 1.2, pos = Vector3.new(0, -topY, 0), accel = Vector3.new(0, -1, 0) })
		emitter(core, { color = Color3.fromRGB(255, 170, 60), rate = 6, size0 = 0.15 * s, speed0 = 2, speed1 = 4, life0 = 0.15, life1 = 0.3, pos = Vector3.new(0, -topY, 0) })
	end
	if has("storm") then
		emitter(core, { texture = SMOKE_TEX, color = ColorSequence.new(Color3.fromRGB(90, 100, 130), Color3.fromRGB(50, 55, 75)), rate = 4, size0 = 0.5 * s, size1 = 1.2 * s, t0 = 0.6, life0 = 0.8, life1 = 1.4, speed0 = 0.2, speed1 = 0.6, pos = Vector3.new(0, topY + 0.3 * s, 0) })
	end
	if has("clock") then
		emitter(core, { color = ColorSequence.new(Color3.fromRGB(140, 245, 255), Color3.fromRGB(255, 230, 150)), rate = 8, size0 = 0.22 * s, size1 = 0, life0 = 1, life1 = 1.6, speed0 = 0.3, speed1 = 0.8, accel = Vector3.new(0, 1.2, 0) })
		for k = 0, 1 do
			local ang = k * math.pi
			newPart(model, { name = "OrbitBall", shape = Ball, size = Vector3.one * 0.22 * s, cf = CFrame.new(math.cos(ang) * (radius + 0.4 * s), 0.2 * s, math.sin(ang) * (radius + 0.4 * s)), color = Color3.fromRGB(140, 245, 255), mat = Mat.Neon, orbit = -1.6 })
		end
	end
	if has("void") then
		emitter(core, { color = ColorSequence.new(Color3.fromRGB(255, 60, 80), Color3.fromRGB(90, 0, 20)), rate = 14, size0 = 0.25 * s, size1 = 0, life0 = 0.5, life1 = 0.9, speed0 = 0.4, speed1 = 1, spread = Vector2.new(180, 180) })
		emitter(core, { texture = SMOKE_TEX, color = ColorSequence.new(Color3.fromRGB(40, 0, 10), Color3.fromRGB(0, 0, 0)), rate = 5, size0 = 0.6 * s, size1 = 1.4 * s, t0 = 0.5, life0 = 0.8, life1 = 1.4, speed0 = 0.3, speed1 = 0.8, light = 0 })
	end
	if rarity.order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rcol
		light.Range = 5 * s + 4
		light.Brightness = 1.2
		light.Parent = core
	end
	if secret then
		emitter(core, { texture = FIRE_TEX, color = ColorSequence.new(Color3.fromRGB(255, 50, 30), Color3.fromRGB(80, 0, 0)), rate = 12, size0 = 0.25 * s, life0 = 0.6, life1 = 1.4, speed0 = 1, speed1 = 3, accel = Vector3.new(0, 2, 0) })
	end
	return model
end

function Builder.Build(def, scale)
	local lib = meshLib()
	local tpl = lib and lib:FindFirstChild(def.id)
	if tpl then
		return buildFromMesh(def, scale, tpl)
	end
	local look = def.look
	local s = (look.size or 1) * (scale or 1)
	local rarity = Config.Rarities[def.rarity]
	local rainbow = rarity.rainbow == true
	local secret = def.rarity == "Secret"
	local c1, c2 = look.c1, look.c2
	local mat = Mat[look.mat or "SmoothPlastic"]
	local rcol = rarity.color
	local eyeCol = look.eye or rcol
	local extras = look.extras or {}
	local function has(x)
		return table.find(extras, x) ~= nil
	end
	local dark = Color3.fromRGB(38, 40, 46)
	local ghost = has("ghost")
	local bodyTr = ghost and 0.35 or (look.mat == "Glass" and 0.25 or 0)

	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("DroneId", def.id)
	model:SetAttribute("Rarity", def.rarity)
	if rainbow then
		model:SetAttribute("Rainbow", true)
	end
	if secret then
		model:SetAttribute("Secret", true)
	end

	local core = newPart(model, { name = "Core", size = Vector3.one * 0.2 * s, tr = 1 })
	model.PrimaryPart = core

	-- ===== КОРПУС =====
	local radius, topY = 1 * s, 1 * s
	local body = look.body
	local skullEyes = false
	if body == "ball" then
		newPart(model, { name = "Body", shape = Ball, size = Vector3.one * 2 * s, color = c1, mat = mat, tr = bodyTr })
		newPart(model, { name = "Band", shape = Cyl, size = Vector3.new(0.32 * s, 2.1 * s, 2.1 * s), cf = CFrame.Angles(0, 0, R90), color = c2, mat = Mat.Metal, tint = rainbow or secret })
		radius, topY = 1 * s, 1 * s
	elseif body == "box" then
		newPart(model, { name = "Body", size = Vector3.new(2.1, 1.3, 2.3) * s, color = c1, mat = mat, tr = bodyTr })
		newPart(model, { name = "Top", size = Vector3.new(1.5, 0.35, 1.7) * s, cf = CFrame.new(0, 0.8 * s, 0), color = c2, mat = Mat.Metal, tint = rainbow or secret })
		newPart(model, { name = "Bottom", size = Vector3.new(1.7, 0.3, 1.9) * s, cf = CFrame.new(0, -0.78 * s, 0), color = dark, mat = Mat.Metal })
		-- боковые пластины
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "Plate", size = Vector3.new(0.12, 0.8, 1.6) * s, cf = CFrame.new(sx * 1.08 * s, 0, 0), color = c2, mat = Mat.Metal, tint = rainbow or secret })
		end
		radius, topY = 1.15 * s, 0.98 * s
	elseif body == "cyl" then
		newPart(model, { name = "Body", shape = Cyl, size = Vector3.new(1.4 * s, 2.2 * s, 2.2 * s), cf = CFrame.Angles(0, 0, R90), color = c1, mat = mat, tr = bodyTr })
		newPart(model, { name = "Ring", shape = Cyl, size = Vector3.new(0.25 * s, 2.35 * s, 2.35 * s), cf = CFrame.new(0, 0.35 * s, 0) * CFrame.Angles(0, 0, R90), color = c2, mat = Mat.Neon, tint = true })
		newPart(model, { name = "Dome", shape = Ball, size = Vector3.one * 1.3 * s, cf = CFrame.new(0, 0.6 * s, 0), color = c1, mat = Mat.Glass, tr = 0.3 })
		radius, topY = 1.1 * s, 0.9 * s
	elseif body == "disc" then
		newPart(model, { name = "Body", shape = Cyl, size = Vector3.new(0.6 * s, 2.8 * s, 2.8 * s), cf = CFrame.Angles(0, 0, R90), color = c1, mat = mat })
		newPart(model, { name = "Dome", shape = Ball, size = Vector3.one * 1.3 * s, cf = CFrame.new(0, 0.3 * s, 0), color = c2, mat = Mat.Metal, tint = rainbow or secret })
		newPart(model, { name = "Rim", shape = Cyl, size = Vector3.new(0.2 * s, 2.9 * s, 2.9 * s), cf = CFrame.Angles(0, 0, R90), color = rcol, mat = Mat.Neon, tint = true })
		radius, topY = 1.4 * s, 0.45 * s
	elseif body == "diamond" then
		newPart(model, { name = "Body", size = Vector3.one * 1.6 * s, cf = CFrame.Angles(math.rad(45), 0, math.rad(35.26)), color = c1, mat = mat, tr = bodyTr })
		newPart(model, { name = "Inner", shape = Ball, size = Vector3.one * 1.0 * s, color = c2, mat = Mat.Neon, tint = true, tr = 0.1 })
		radius, topY = 1.0 * s, 1.2 * s
	elseif body == "skull" then
		newPart(model, { name = "Body", shape = Ball, size = Vector3.one * 2.1 * s, cf = CFrame.new(0, 0.2 * s, 0), color = c1, mat = mat })
		newPart(model, { name = "Jaw", size = Vector3.new(1.3, 0.55, 1.2) * s, cf = CFrame.new(0, -0.75 * s, -0.35 * s), color = c1, mat = mat })
		for i = -2, 2 do
			newPart(model, { name = "Tooth", size = Vector3.new(0.18, 0.25, 0.1) * s, cf = CFrame.new(i * 0.24 * s, -0.5 * s, -0.96 * s), color = Color3.fromRGB(230, 225, 210) })
		end
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "Socket", shape = Ball, size = Vector3.one * 0.62 * s, cf = CFrame.new(sx * 0.4 * s, 0.25 * s, -0.78 * s), color = Color3.new(0, 0, 0) })
			newPart(model, { name = "Eye", shape = Ball, size = Vector3.one * 0.36 * s, cf = CFrame.new(sx * 0.4 * s, 0.25 * s, -0.95 * s), color = eyeCol, mat = Mat.Neon, tint = rainbow })
		end
		-- трещина с свечением
		newPart(model, { name = "Crack", size = Vector3.new(0.08, 0.9, 0.08) * s, cf = CFrame.new(0.15 * s, 0.85 * s, -0.75 * s) * CFrame.Angles(0.5, 0, 0.3), color = c2, mat = Mat.Neon, tint = true })
		skullEyes = true
		radius, topY = 1.05 * s, 1.25 * s
	else
		newPart(model, { name = "Body", shape = Ball, size = Vector3.one * 2 * s, color = c1, mat = mat })
	end

	-- ===== ГЛАЗ =====
	if not skullEyes then
		newPart(model, { name = "Lens", shape = Cyl, size = Vector3.new(0.18 * s, 0.85 * s, 0.85 * s), cf = CFrame.new(0, 0.05 * s, -radius + 0.02 * s) * CFrame.Angles(0, R90, 0), color = dark, mat = Mat.Metal })
		newPart(model, { name = "Eye", shape = Ball, size = Vector3.one * 0.55 * s, cf = CFrame.new(0, 0.05 * s, -radius - 0.02 * s), color = eyeCol, mat = Mat.Neon, tint = rainbow })
	end

	-- ===== ВИНТЫ =====
	local n = look.rotors or 4
	local armLen = radius + 0.95 * s
	local hubY = topY * 0.35
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2 + (n == 2 and math.pi / 2 or 0)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hub = dir * armLen + Vector3.new(0, hubY, 0)
		local start = dir * radius * 0.4 + Vector3.new(0, hubY * 0.5, 0)
		local mid = (start + hub) / 2
		newPart(model, { name = "Arm", size = Vector3.new(0.22 * s, 0.18 * s, (hub - start).Magnitude), cf = CFrame.lookAt(mid, hub), color = c2, mat = Mat.Metal, tint = rainbow or secret })
		newPart(model, { name = "Motor", shape = Cyl, size = Vector3.new(0.45 * s, 0.42 * s, 0.42 * s), cf = CFrame.new(hub) * CFrame.Angles(0, 0, R90), color = dark, mat = Mat.Metal })
		newPart(model, { name = "Tip", shape = Ball, size = Vector3.one * 0.2 * s, cf = CFrame.new(hub - Vector3.new(0, 0.26 * s, 0)), color = rcol, mat = Mat.Neon, tint = true })
		local bladeCol = secret and Color3.fromRGB(60, 10, 12) or Color3.fromRGB(70, 72, 78)
		local bcf = CFrame.new(hub + Vector3.new(0, 0.26 * s, 0)) * CFrame.Angles(0, a, 0)
		newPart(model, { name = "Blade", size = Vector3.new(1.6 * s, 0.05 * s, 0.22 * s), cf = bcf, color = bladeCol, mat = Mat.SmoothPlastic, tr = 0.15, spin = 28 })
		newPart(model, { name = "Blade", size = Vector3.new(1.6 * s, 0.05 * s, 0.22 * s), cf = bcf * CFrame.Angles(0, R90, 0), color = bladeCol, mat = Mat.SmoothPlastic, tr = 0.15, spin = 28 })
	end

	-- ===== ДЕТАЛИ =====
	if has("antenna") then
		newPart(model, { name = "Antenna", shape = Cyl, size = Vector3.new(1.2 * s, 0.08 * s, 0.08 * s), cf = CFrame.new(0.35 * s, topY + 0.5 * s, 0.3 * s) * CFrame.Angles(0, 0, R90), color = dark, mat = Mat.Metal })
		newPart(model, { name = "AntennaTip", shape = Ball, size = Vector3.one * 0.22 * s, cf = CFrame.new(0.35 * s, topY + 1.1 * s, 0.3 * s), color = rcol, mat = Mat.Neon, tint = true })
	end
	if has("camera") then
		newPart(model, { name = "Camera", shape = Ball, size = Vector3.one * 0.55 * s, cf = CFrame.new(0, -radius * 0.75, -radius * 0.45), color = dark, mat = Mat.Metal })
		newPart(model, { name = "CamLens", shape = Ball, size = Vector3.one * 0.22 * s, cf = CFrame.new(0, -radius * 0.78, -radius * 0.45 - 0.22 * s), color = Color3.fromRGB(255, 60, 60), mat = Mat.Neon })
	end
	if has("claw") then
		newPart(model, { name = "ClawBar", size = Vector3.new(1.1, 0.15, 0.2) * s, cf = CFrame.new(0, -radius - 0.05 * s, -0.2 * s), color = c2, mat = Mat.Metal })
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "Claw", size = Vector3.new(0.15, 0.8, 0.2) * s, cf = CFrame.new(sx * 0.45 * s, -radius - 0.4 * s, -0.2 * s) * CFrame.Angles(0, 0, sx * 0.35), color = c2, mat = Mat.Metal })
			newPart(model, { name = "ClawTip", size = Vector3.new(0.15, 0.35, 0.2) * s, cf = CFrame.new(sx * 0.42 * s, -radius - 0.82 * s, -0.2 * s) * CFrame.Angles(0, 0, -sx * 0.6), color = dark, mat = Mat.Metal })
		end
	end
	if has("coil") then
		newPart(model, { name = "Rod", shape = Cyl, size = Vector3.new(1.0 * s, 0.14 * s, 0.14 * s), cf = CFrame.new(0, topY + 0.4 * s, 0) * CFrame.Angles(0, 0, R90), color = dark, mat = Mat.Metal })
		for k = 0, 2 do
			local d = (0.9 - k * 0.2) * s
			newPart(model, { name = "Coil", shape = Cyl, size = Vector3.new(0.1 * s, d, d), cf = CFrame.new(0, topY + 0.15 * s + k * 0.28 * s, 0) * CFrame.Angles(0, 0, R90), color = c2, mat = Mat.Neon, tint = true })
		end
		newPart(model, { name = "CoilBall", shape = Ball, size = Vector3.one * 0.3 * s, cf = CFrame.new(0, topY + 0.95 * s, 0), color = c2, mat = Mat.Neon, tint = true })
	end
	if has("sparks") then
		emitter(model:FindFirstChild("Body") or core, { color = Color3.fromRGB(255, 240, 120), rate = 8, size0 = 0.25 * s, speed0 = 2, speed1 = 5, life0 = 0.15, life1 = 0.35, pos = Vector3.new(0, topY, 0) })
	end
	if has("saw") then
		local scf = CFrame.new(0, -0.05 * s, -radius - 0.55 * s) * CFrame.Angles(0, R90, 0)
		newPart(model, { name = "Saw", shape = Cyl, size = Vector3.new(0.1 * s, 2.0 * s, 2.0 * s), cf = scf, color = Color3.fromRGB(215, 218, 225), mat = Mat.DiamondPlate, refl = 0.2, spin = 18, axis = "X" })
		newPart(model, { name = "SawHub", shape = Cyl, size = Vector3.new(0.16 * s, 0.6 * s, 0.6 * s), cf = scf, color = Color3.fromRGB(220, 40, 40), mat = Mat.Neon, tint = rainbow })
		for k = 0, 7 do
			local ang = k / 8 * math.pi * 2
			local off = Vector3.new(math.cos(ang) * 1.02 * s, math.sin(ang) * 1.02 * s, -radius - 0.55 * s + 0)
			newPart(model, { name = "Tooth", size = Vector3.new(0.25, 0.25, 0.08) * s, cf = CFrame.new(Vector3.new(off.X, off.Y - 0.05 * s, off.Z)) * CFrame.Angles(0, 0, ang + math.rad(45)), color = Color3.fromRGB(180, 182, 190), mat = Mat.Metal })
		end
	end
	if has("cross") then
		local red = Color3.fromRGB(235, 30, 40)
		newPart(model, { name = "Cross", size = Vector3.new(1.2, 0.12, 0.38) * s, cf = CFrame.new(0, topY + 0.06 * s, 0), color = red, mat = Mat.Neon })
		newPart(model, { name = "Cross", size = Vector3.new(0.38, 0.12, 1.2) * s, cf = CFrame.new(0, topY + 0.06 * s, 0), color = red, mat = Mat.Neon })
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "Cross", size = Vector3.new(0.06, 0.7, 0.22) * s, cf = CFrame.new(sx * 1.15 * s, 0, 0), color = red, mat = Mat.Neon })
			newPart(model, { name = "Cross", size = Vector3.new(0.06, 0.22, 0.7) * s, cf = CFrame.new(sx * 1.15 * s, 0, 0), color = red, mat = Mat.Neon })
		end
	end
	if has("icicles") then
		local rng = Random.new(7)
		for k = 1, 6 do
			local ang = k / 6 * math.pi * 2
			local r = 0.55 * s
			local h = rng:NextNumber(0.5, 0.95) * s
			newPart(model, { name = "Icicle", size = Vector3.new(0.2 * s, h, 0.2 * s), cf = CFrame.new(math.cos(ang) * r, -radius * 0.7 - h / 2, math.sin(ang) * r) * CFrame.Angles(0, ang, 0.1), color = Color3.fromRGB(200, 235, 255), mat = Mat.Ice, tr = 0.15 })
		end
	end
	if has("snow") then
		emitter(core, { color = Color3.fromRGB(230, 245, 255), rate = 7, size0 = 0.18 * s, size1 = 0.1 * s, speed0 = 0.5, speed1 = 1.5, life0 = 0.8, life1 = 1.5, accel = Vector3.new(0, -3, 0) })
	end
	if has("magnet") then
		local red, grey = Color3.fromRGB(220, 35, 35), Color3.fromRGB(200, 200, 205)
		newPart(model, { name = "MagTop", size = Vector3.new(1.3, 0.32, 0.36) * s, cf = CFrame.new(0, -radius + 0.05 * s, 0), color = red, mat = Mat.Metal })
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "MagLeg", size = Vector3.new(0.34, 0.75, 0.36) * s, cf = CFrame.new(sx * 0.48 * s, -radius - 0.4 * s, 0), color = red, mat = Mat.Metal })
			newPart(model, { name = "MagTip", size = Vector3.new(0.36, 0.25, 0.38) * s, cf = CFrame.new(sx * 0.48 * s, -radius - 0.88 * s, 0), color = grey, mat = Mat.Metal })
		end
	end
	if has("lightning") then
		emitter(core, { color = Color3.fromRGB(120, 230, 255), rate = 14, size0 = 0.3 * s, speed0 = 3, speed1 = 6, life0 = 0.1, life1 = 0.25 })
	end
	if has("canister") then
		for _, sx in ipairs({ -1, 1 }) do
			local cf = CFrame.new(sx * (radius + 0.25 * s), -0.1 * s, 0.3 * s) * CFrame.Angles(0, 0, R90)
			newPart(model, { name = "Canister", shape = Cyl, size = Vector3.new(1.0 * s, 0.6 * s, 0.6 * s), cf = cf, color = Color3.fromRGB(220, 230, 220), mat = Mat.Glass, tr = 0.45 })
			newPart(model, { name = "Liquid", shape = Cyl, size = Vector3.new(0.75 * s, 0.45 * s, 0.45 * s), cf = cf * CFrame.new(-0.08 * s, 0, 0), color = c2, mat = Mat.Neon, tint = rainbow })
			newPart(model, { name = "Cap", shape = Cyl, size = Vector3.new(0.12 * s, 0.64 * s, 0.64 * s), cf = cf * CFrame.new(0.52 * s, 0, 0), color = dark, mat = Mat.Metal })
		end
	end
	if has("guns") then
		for _, sx in ipairs({ -1, 1 }) do
			local gcf = CFrame.new(sx * 0.62 * s, -0.35 * s, -radius - 0.25 * s) * CFrame.Angles(0, R90, 0)
			newPart(model, { name = "Barrel", shape = Cyl, size = Vector3.new(1.3 * s, 0.26 * s, 0.26 * s), cf = gcf, color = Color3.fromRGB(30, 30, 34), mat = Mat.Metal })
			newPart(model, { name = "Muzzle", shape = Cyl, size = Vector3.new(0.1 * s, 0.2 * s, 0.2 * s), cf = gcf * CFrame.new(-0.66 * s, 0, 0), color = Color3.fromRGB(255, 70, 40), mat = Mat.Neon })
		end
	end
	if has("toxic") then
		emitter(core, { texture = SMOKE_TEX, color = Color3.fromRGB(120, 255, 80), rate = 5, size0 = 0.6 * s, size1 = 1.4 * s, t0 = 0.55, life0 = 1, life1 = 1.8, speed0 = 0.3, speed1 = 0.8, light = 0.4, accel = Vector3.new(0, -0.8, 0) })
	end
	if ghost then
		emitter(core, { color = Color3.fromRGB(210, 170, 255), rate = 10, size0 = 0.35 * s, life0 = 0.6, life1 = 1.2, speed0 = 0.2, speed1 = 0.8 })
		trail(core, Vector3.new(-0.7 * s, 0, 0), Vector3.new(0.7 * s, 0, 0), c1, 0.45)
	end
	if has("speedtrail") then
		trail(core, Vector3.new(0, -0.3 * s, 0), Vector3.new(0, 0.3 * s, 0), c2, 0.3)
	end
	if has("flame") then
		local fc = secret and ColorSequence.new(Color3.fromRGB(255, 40, 30), Color3.fromRGB(60, 0, 0)) or ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 10))
		emitter(core, { texture = FIRE_TEX, color = fc, rate = 30, size0 = 0.7 * s, size1 = 0.1 * s, t0 = 0.1, life0 = 0.3, life1 = 0.6, speed0 = 1, speed1 = 2.5, accel = Vector3.new(0, 5, 0), pos = Vector3.new(0, topY * 0.7, 0.2 * s), spread = Vector2.new(25, 25) })
	end
	if has("vents") then
		for _, sx in ipairs({ -1, 1 }) do
			for k = -1, 1 do
				newPart(model, { name = "Vent", size = Vector3.new(0.08, 0.12, 1.1) * s, cf = CFrame.new(sx * 1.12 * s, k * 0.28 * s, 0), color = Color3.fromRGB(255, 130, 30), mat = Mat.Neon })
			end
		end
	end
	if has("cannon") then
		local ccf = CFrame.new(0, topY + 0.32 * s, -0.35 * s) * CFrame.Angles(0, R90, 0)
		newPart(model, { name = "CannonBase", size = Vector3.new(0.9, 0.35, 0.9) * s, cf = CFrame.new(0, topY + 0.12 * s, 0), color = dark, mat = Mat.Metal })
		newPart(model, { name = "Cannon", shape = Cyl, size = Vector3.new(1.9 * s, 0.5 * s, 0.5 * s), cf = ccf, color = secret and Color3.fromRGB(40, 20, 22) or dark, mat = Mat.Metal })
		newPart(model, { name = "CannonGlow", shape = Cyl, size = Vector3.new(0.12 * s, 0.42 * s, 0.42 * s), cf = ccf * CFrame.new(-0.96 * s, 0, 0), color = rcol, mat = Mat.Neon, tint = true })
	end
	if has("sparkles") then
		emitter(core, { color = rainbow and Config.RainbowSequence or Color3.fromRGB(255, 230, 120), rate = 9, size0 = 0.3 * s, speed0 = 0.5, speed1 = 1.5, life0 = 0.6, life1 = 1.2 })
	end
	if has("crown") then
		local gold = Color3.fromRGB(255, 210, 60)
		newPart(model, { name = "CrownBase", shape = Cyl, size = Vector3.new(0.28 * s, 1.1 * s, 1.1 * s), cf = CFrame.new(0, topY + 0.1 * s, 0) * CFrame.Angles(0, 0, R90), color = gold, mat = Mat.Foil })
		for k = 0, 4 do
			local ang = k / 5 * math.pi * 2
			newPart(model, { name = "CrownSpike", size = Vector3.new(0.22, 0.22, 0.22) * s, cf = CFrame.new(math.cos(ang) * 0.45 * s, topY + 0.38 * s, math.sin(ang) * 0.45 * s) * CFrame.Angles(math.rad(45), ang, math.rad(45)), color = gold, mat = Mat.Foil })
		end
		newPart(model, { name = "Gem", shape = Ball, size = Vector3.one * 0.26 * s, cf = CFrame.new(0, topY + 0.15 * s, -0.55 * s), color = Color3.fromRGB(255, 40, 90), mat = Mat.Neon })
	end
	if has("wings") then
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, { name = "Wing", size = Vector3.new(1.7, 0.06, 0.95) * s, cf = CFrame.new(sx * (radius + 0.8 * s), 0.45 * s, 0.5 * s) * CFrame.Angles(0, sx * 0.4, sx * 0.35), color = Color3.fromRGB(255, 225, 140), mat = Mat.Glass, tr = 0.4 })
		end
	end
	if has("orbit") then
		for k = 0, 2 do
			local ang = k / 3 * math.pi * 2
			newPart(model, { name = "OrbitBall", shape = Ball, size = Vector3.one * 0.32 * s, cf = CFrame.new(math.cos(ang) * 1.9 * s, 0.1 * s, math.sin(ang) * 1.9 * s), color = c2, mat = Mat.Neon, tint = true, orbit = 2.4 })
		end
	end
	if has("prism") then
		for k = 0, 3 do
			local ang = k / 4 * math.pi * 2 + math.rad(45)
			newPart(model, { class = "WedgePart", name = "Shard", size = Vector3.new(0.25, 0.7, 0.4) * s, cf = CFrame.new(math.cos(ang) * 0.95 * s, -0.75 * s, math.sin(ang) * 0.95 * s) * CFrame.Angles(0, -ang, math.rad(180)), color = Color3.new(1, 1, 1), mat = Mat.Neon, tint = true, tr = 0.1 })
		end
	end
	if has("souls") then
		emitter(core, { color = Config.RainbowSequence, rate = 10, size0 = 0.4 * s, size1 = 0, life0 = 0.8, life1 = 1.6, speed0 = 0.5, speed1 = 1.2, accel = Vector3.new(0, 2.5, 0) })
	end
	if has("spikes") then
		for k = 0, 5 do
			local ang = k / 6 * math.pi * 2 + math.pi / 6
			local dir = Vector3.new(math.cos(ang), -0.15, math.sin(ang)).Unit
			local pos = dir * (radius + 0.3 * s)
			newPart(model, { name = "Spike", size = Vector3.new(0.22, 0.85, 0.22) * s, cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-R90, 0, 0), color = secret and Color3.fromRGB(255, 30, 30) or c2, mat = Mat.Neon, tint = true })
		end
	end

	-- ===== АУРА РЕДКОСТИ =====
	if rarity.order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rcol
		light.Range = 5 * s + 4
		light.Brightness = 1.2
		light.Parent = core
	end
	if secret then
		emitter(core, { texture = FIRE_TEX, color = ColorSequence.new(Color3.fromRGB(255, 50, 30), Color3.fromRGB(80, 0, 0)), rate = 12, size0 = 0.25 * s, life0 = 0.6, life1 = 1.4, speed0 = 1, speed1 = 3, accel = Vector3.new(0, 2, 0) })
	end

	texturize(model, def)
	return model
end

-- Выставляет камеру ViewportFrame так, чтобы модель целиком помещалась в кадр.
function Builder.SetupViewport(vpf, model, yaw, pitch, distMult)
	local cam = vpf.CurrentCamera
	if not cam then
		cam = Instance.new("Camera")
		cam.Parent = vpf
		vpf.CurrentCamera = cam
	end
	cam.FieldOfView = 40
	model:PivotTo(CFrame.new())
	model.Parent = vpf
	local cf, size = model:GetBoundingBox()
	local r = size.Magnitude / 2
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2)) * (distMult or 1.05)
	local dir = (CFrame.Angles(0, yaw or math.rad(25), 0) * CFrame.Angles(pitch or math.rad(18), 0, 0)).LookVector
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	return cam, cf.Position
end

return Builder
