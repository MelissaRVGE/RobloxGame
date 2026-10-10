-- Процедурные цветы и клумбы (используется при сборке карты в редакторе)
local F = {}
local C = Color3.fromRGB

F.Palettes = {
	{ petal = C(255, 120, 160), center = C(255, 220, 90) }, -- розовые
	{ petal = C(255, 245, 250), center = C(255, 200, 60) }, -- ромашки
	{ petal = C(255, 205, 60), center = C(150, 80, 30) }, -- подсолнухи
	{ petal = C(150, 120, 255), center = C(255, 240, 160) }, -- фиалки
	{ petal = C(255, 90, 70), center = C(40, 30, 30) }, -- маки
	{ petal = C(110, 190, 255), center = C(255, 255, 255) }, -- васильки
	{ petal = C(255, 160, 60), center = C(255, 230, 120) }, -- настурции
}

local function part(parent, props)
	local p = Instance.new(props.class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		p.Shape = props.shape
	end
	p.Size = props.size
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.mat or Enum.Material.SmoothPlastic
	p.Name = props.name or "Part"
	p.Parent = parent
	return p
end

-- один цветок: стебель, два листа, венчик из лепестков и сердцевина
function F.Flower(parent, pos, height, pal, rng, scale)
	scale = scale or 1
	local h = height * scale
	local m = Instance.new("Model")
	m.Name = "Flower"
	local lean = CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.18, 0.18))
	local base = CFrame.new(pos) * lean
	part(m, { name = "Stem", shape = Enum.PartType.Cylinder, size = Vector3.new(h, 0.09 * scale, 0.09 * scale), cf = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color = C(70, 150, 60), mat = Enum.Material.Grass })
	for k, s in ipairs({ -1, 1 }) do
		part(m, { name = "Leaf", shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.06, 0.2) * scale, cf = base * CFrame.new(s * 0.22 * scale, h * (0.25 + k * 0.15), 0) * CFrame.Angles(0, 0, s * 0.5), color = C(80, 170, 70), mat = Enum.Material.Grass })
	end
	local head = base * CFrame.new(0, h, 0) * CFrame.Angles(math.rad(-15), 0, 0)
	local n = rng:NextInteger(5, 7)
	local pr = 0.24 * scale
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		part(m, { name = "Petal", shape = Enum.PartType.Ball, size = Vector3.new(0.34, 0.07, 0.2) * scale, cf = head * CFrame.Angles(0, a, 0) * CFrame.new(pr, 0, 0) * CFrame.Angles(0, 0, 0.25), color = pal.petal:Lerp(C(255, 255, 255), rng:NextNumber(0, 0.15)) })
	end
	part(m, { name = "Center", shape = Enum.PartType.Ball, size = Vector3.new(0.2, 0.12, 0.2) * scale, cf = head * CFrame.new(0, 0.04 * scale, 0), color = pal.center })
	m.Parent = parent
	return m
end

-- клумба: круг/прямоугольник с низкой травкой и цветами
function F.Bed(parent, cf, sizeX, sizeZ, opts)
	opts = opts or {}
	local rng = Random.new(opts.seed or 1)
	local m = Instance.new("Model")
	m.Name = opts.name or "FlowerBed"
	local count = opts.count or math.floor(sizeX * sizeZ * 1.4)
	local pals = opts.palettes or F.Palettes
	-- группы одного цвета выглядят аккуратнее, чем пёстрая каша
	for i = 1, count do
		local u, v = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)
		local zone = math.floor((u + 0.5) * #pals * 0.999) + 1
		local pal = pals[(zone + (opts.shift or 0) - 1) % #pals + 1]
		local p = (cf * CFrame.new(u * sizeX * 0.9, 0, v * sizeZ * 0.9)).Position
		F.Flower(m, p, rng:NextNumber(0.8, 1.4) * (opts.height or 1), pal, rng, opts.scale or 1)
	end
	-- травяные кочки
	for i = 1, math.floor(count * 0.5) do
		local u, v = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)
		local p = cf * CFrame.new(u * sizeX * 0.95, 0.12, v * sizeZ * 0.95)
		part(m, { name = "Tuft", shape = Enum.PartType.Ball, size = Vector3.new(rng:NextNumber(0.5, 0.9), 0.3, rng:NextNumber(0.5, 0.9)) * (opts.scale or 1), cf = p, color = C(90, 165, 70):Lerp(C(120, 190, 80), rng:NextNumber()), mat = Enum.Material.Grass })
	end
	m.Parent = parent
	return m
end

return F
