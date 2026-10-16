-- Плитки полей в стиле Bee Swarm Simulator: ровная сетка 4x4, на каждой плитке лежит 3D-ресурс.
-- Раскладка ресурсов детерминирована (одинакова на сервере и в редакторе): главный ресурс
-- занимает большую часть поля, второстепенные лежат пятнами и россыпью.
-- Используется сервером (Fields.Init) и для запекания вида полей в Studio.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)

local FieldTiles = {}
FieldTiles.Version = 2

-- сетка поля: resId по индексам [ix][iz] (0-based, ix вдоль X, iz вдоль Z)
function FieldTiles.Layout(cfg, index)
	local n = math.floor(cfg.size / Config.TileSize)
	local rng = Random.new(index * 7919 + 13)
	local cells = {}
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			table.insert(cells, { ix = ix, iz = iz })
		end
	end
	local grid = {}
	for ix = 0, n - 1 do
		grid[ix] = {}
	end
	local res = cfg.res or { { Config.ResourceByField[cfg.id] and Config.ResourceByField[cfg.id].id or "rust", 100 } }
	local total = 0
	for _, r in ipairs(res) do
		total += r[2]
	end
	-- второстепенные ресурсы: пятна (шум) + россыпь (случайность), остальное — главный
	local left = cells
	for k = #res, 2, -1 do
		local count = math.floor(#cells * res[k][2] / total + 0.5)
		local ox, oz = rng:NextNumber(0, 100), rng:NextNumber(0, 100)
		for _, c in ipairs(left) do
			c.s = math.noise(c.ix * 0.31 + ox, c.iz * 0.31 + oz, index + k * 0.37) * 0.6 + rng:NextNumber() * 0.55
		end
		table.sort(left, function(a, b)
			return a.s > b.s
		end)
		local rest = {}
		for i, c in ipairs(left) do
			if i <= count then
				grid[c.ix][c.iz] = res[k][1]
			else
				table.insert(rest, c)
			end
		end
		left = rest
	end
	for _, c in ipairs(left) do
		grid[c.ix][c.iz] = res[1][1]
	end
	return grid, n
end

local function floorTop(folder, cfg)
	local fl = folder:FindFirstChild("Floor")
	if fl and fl:IsA("BasePart") then
		return fl.Position.Y + fl.Size.Y / 2
	end
	return cfg.center.Y + 1
end

-- перестраивает плитки поля: размер, грунт, ресурс и его 3D-модель.
-- Без force пропускает уже собранное поле той же версии.
function FieldTiles.Build(folder, cfg, index, force)
	local tilesFolder = folder:FindFirstChild("Tiles")
	if not tilesFolder or not cfg.res then
		return
	end
	if not force and folder:GetAttribute("TilesV") == FieldTiles.Version then
		return
	end
	local grid, n = FieldTiles.Layout(cfg, index)
	local S = Config.TileSize
	local thick = Config.TileDepth + 1
	local top = floorTop(folder, cfg) + Config.TileDepth
	local x0 = cfg.center.X - cfg.size / 2
	local z0 = cfg.center.Z - cfg.size / 2
	local templates = RS.ZSS:FindFirstChild("FieldResMeshes")
	local Icons = require(RS.ZSS.Icons)
	local mat = Enum.Material[cfg.ground and cfg.ground.mat or "Ground"]
	local base = cfg.ground and cfg.ground.color or Color3.fromRGB(110, 100, 70)
	local rng = Random.new(index * 104729 + 7)
	for _, t in ipairs(tilesFolder:GetChildren()) do
		if t:IsA("BasePart") then
			local ix = math.clamp(math.floor((t.Position.X - x0) / S), 0, n - 1)
			local iz = math.clamp(math.floor((t.Position.Z - z0) / S), 0, n - 1)
			local resId = grid[ix][iz]
			local cx, cz = x0 + (ix + 0.5) * S, z0 + (iz + 0.5) * S
			t.Size = Vector3.new(S, thick, S)
			t.CFrame = CFrame.new(cx, top - thick / 2, cz)
			t.Material = mat
			-- лёгкая шахматка и разброс тона, чтобы читалась сетка, как в BSS
			local v = ((ix + iz) % 2 == 0 and 1.035 or 0.965) * rng:NextNumber(0.95, 1.05)
			t.Color = Color3.new(math.min(1, base.R * v), math.min(1, base.G * v), math.min(1, base.B * v))
			t.TopSurface = Enum.SurfaceType.Smooth
			t.BottomSurface = Enum.SurfaceType.Smooth
			t.Anchored = true
			t.CanCollide = true
			t.CastShadow = true
			t:SetAttribute("Kind", nil)
			t:SetAttribute("Res", resId)
			t:SetAttribute("TopY", top)
			t:SetAttribute("Fill", 1)
			for _, c in ipairs(t:GetChildren()) do
				if c.Name == "Icon" or c.Name == "Res" then
					c:Destroy()
				end
			end
			local tpl = templates and templates:FindFirstChild(resId)
			if tpl and tpl:IsA("BasePart") then
				local m = tpl:Clone()
				m.Name = "Res"
				local sc = rng:NextNumber(0.86, 1.04)
				m.Size = tpl.Size * sc
				m.Anchored = true
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				m.CastShadow = true
				local off = Vector3.new(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
				local lift = (tpl:GetAttribute("Lift") or 0) * sc
				m.CFrame = CFrame.new(cx + off.X, top + m.Size.Y / 2 + lift, cz + off.Z)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				m.Parent = t
			else
				local d = Instance.new("Decal")
				d.Name = "Res"
				d.Face = Enum.NormalId.Top
				d.Texture = Icons.res and Icons.res[resId] or ""
				d.Parent = t
			end
		end
	end
	folder:SetAttribute("TilesV", FieldTiles.Version)
end

return FieldTiles
