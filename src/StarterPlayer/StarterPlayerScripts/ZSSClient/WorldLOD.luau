-- Дальность прорисовки «дорогих» мелочей карты: фонари, частицы, надписи, мелкий декор и тени.
-- Вблизи всё как было, вдали (где разницы не видно) свет, частицы и мелочь выключаются — телефонам заметно легче.
-- Уровень берётся из настроек графики (LOW / MEDIUM / HIGH / AUTO), на телефоне радиусы меньше.
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local L = {}

-- радиусы в студах по уровню качества: свет, частицы, надписи на стенах, мелкий декор (0 = без ограничения)
local RADIUS = {
	[1] = { light = 70, emit = 60, gui = 100, decor = 130 },
	[2] = { light = 150, emit = 120, gui = 170, decor = 240 },
	[3] = { light = 240, emit = 200, gui = 0, decor = 0 },
}
local SMALL_PART = 3 -- деталь меньше этого по всем осям не отбрасывает тень на низком/среднем качестве
local DECOR_PART = 8 -- деталь меньше этого по всем осям прячется вдали на низком/среднем качестве
local SIGN_PART = 14 -- надписи прячем вдали только на табличках; большие SurfaceGui — это картинки земли/стен, их не трогаем
local CELL = 48 -- мелкий декор собран в клетки сетки, чтобы не обходить тысячи деталей каждый раз
-- группы карты, где лежит только декор (поля, NPC, ворота и доски лидеров не трогаем)
local DECOR_GROUPS = { "Props", "Nature", "ThemeDecor", "Decor_Composed", "HalloweenZone", "Roads", "GachaZone", "ShopZone", "Base", "BossArena" }

local level = 3
local map
local lights, emitters, guis = {}, {}, {}
local small = {}
local cells = {} -- [key] = { center = Vector3, parts = {}, hidden = bool }
local partCell = {}
local shadowsOff = false
local smallShadowsOff = false
local decorGroups = {}
local defaults = {}
local dronesFolder

local function isPhone()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end
L.IsPhone = isPhone

local function worldPos(inst)
	local p = inst.Parent
	if p and p:IsA("Attachment") then
		return p.WorldPosition
	elseif p and p:IsA("BasePart") then
		return p.Position
	elseif p and p:IsA("Model") then
		local pp = p.PrimaryPart
		return pp and pp.Position
	end
	return nil
end

local function isDecor(d)
	for g in pairs(decorGroups) do
		if d:IsDescendantOf(g) then
			return true
		end
	end
	return false
end

local function addDecor(d)
	local p = d.Position
	local key = math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)
	local c = cells[key]
	if not c then
		c = { center = Vector3.new((math.floor(p.X / CELL) + 0.5) * CELL, 0, (math.floor(p.Z / CELL) + 0.5) * CELL), parts = {}, hidden = false }
		cells[key] = c
	end
	c.parts[d] = true
	partCell[d] = c
	if c.hidden then
		d.LocalTransparencyModifier = 1
	end
end

local function isSign(g)
	local p = g.Adornee or g.Parent
	if not (p and p:IsA("BasePart")) then
		return false
	end
	local s = p.Size
	return math.max(s.X, s.Y, s.Z) < SIGN_PART
end

local function register(d)
	if d:IsA("Light") then
		if d:GetAttribute("ZSS_LODOn") == nil then
			d:SetAttribute("ZSS_LODOn", d.Enabled)
			d:SetAttribute("ZSS_LODShadows", d.Shadows)
		end
		lights[d] = true
		if shadowsOff then
			d.Shadows = false
		end
	elseif d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
		if d:GetAttribute("ZSS_LODOn") == nil then
			d:SetAttribute("ZSS_LODOn", d.Enabled)
		end
		emitters[d] = true
	elseif d:IsA("BillboardGui") or (d:IsA("SurfaceGui") and isSign(d)) then
		if d:GetAttribute("ZSS_LODMax") == nil then
			d:SetAttribute("ZSS_LODMax", d.MaxDistance)
		end
		guis[d] = true
		local r = RADIUS[level].gui
		if r > 0 then
			local base = d:GetAttribute("ZSS_LODMax")
			d.MaxDistance = (base == 0 or base > r) and r or base
		end
	elseif d:IsA("BasePart") then
		local s = d.Size
		if d.CastShadow and s.X < SMALL_PART and s.Y < SMALL_PART and s.Z < SMALL_PART then
			small[d] = true
			if smallShadowsOff then
				d.CastShadow = false
			end
		end
		if d.Transparency < 1 and s.X < DECOR_PART and s.Y < DECOR_PART and s.Z < DECOR_PART and isDecor(d) then
			addDecor(d)
		end
	end
end

local function unregister(d)
	lights[d] = nil
	emitters[d] = nil
	guis[d] = nil
	small[d] = nil
	local c = partCell[d]
	if c then
		c.parts[d] = nil
		partCell[d] = nil
	end
end

-- обход огромных списков порциями, чтобы не было рывка
local function chunked(list, fn)
	task.spawn(function()
		local n = 0
		for x in pairs(list) do
			if x.Parent then
				fn(x)
			end
			n += 1
			if n % 1500 == 0 then
				task.wait()
			end
		end
	end)
end

-- тени фонарей и мелкого декора включаются/выключаются по уровню
local function applyShadows()
	local wantLightShadows = level >= 3 and not isPhone()
	local wantSmall = level >= 3
	if shadowsOff == not wantLightShadows and smallShadowsOff == not wantSmall then
		return
	end
	shadowsOff = not wantLightShadows
	smallShadowsOff = not wantSmall
	for lt in pairs(lights) do
		lt.Shadows = (not shadowsOff) and lt:GetAttribute("ZSS_LODShadows") == true
	end
	chunked(small, function(p)
		p.CastShadow = not smallShadowsOff
	end)
end

local function applyGuis()
	local r = RADIUS[level].gui
	for g in pairs(guis) do
		local base = g:GetAttribute("ZSS_LODMax") or 0
		g.MaxDistance = (r > 0 and (base == 0 or base > r)) and r or base
	end
end

-- облака и блики окружения: на низком качестве выключены
local function applyLighting()
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		if defaults.clouds == nil then
			defaults.clouds = clouds.Enabled
		end
		clouds.Enabled = defaults.clouds and level >= 2
	end
	if defaults.spec == nil then
		defaults.spec = Lighting.EnvironmentSpecularScale
	end
	Lighting.EnvironmentSpecularScale = level >= 2 and defaults.spec or 0
end

-- рой: на низком качестве дроны без подсветки, частиц и шлейфов; на среднем — без подсветки
local function droneFx(d)
	if d:IsA("Light") then
		d.Enabled = level >= 3
	elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
		d.Enabled = level >= 2
	end
end

local function applyDrones()
	if not dronesFolder then
		return
	end
	for _, d in ipairs(dronesFolder:GetDescendants()) do
		droneFx(d)
	end
end

local function updateDecor(at)
	local r = RADIUS[level].decor
	for _, c in pairs(cells) do
		local dx, dz = c.center.X - at.X, c.center.Z - at.Z
		local hide = r > 0 and (dx * dx + dz * dz) > (r + CELL) * (r + CELL)
		if hide ~= c.hidden then
			c.hidden = hide
			local v = hide and 1 or 0
			for p in pairs(c.parts) do
				p.LocalTransparencyModifier = v
			end
		end
	end
end

function L.SetLevel(lv)
	lv = math.clamp(lv or 3, 1, 3)
	local changed = lv ~= level
	level = lv
	applyShadows()
	applyLighting()
	if changed then
		applyGuis()
		applyDrones()
	end
end

function L.GetLevel()
	return level
end

function L.Init()
	task.spawn(function()
		dronesFolder = workspace:WaitForChild("ZSS_Drones", 60)
		if dronesFolder then
			dronesFolder.DescendantAdded:Connect(droneFx)
			applyDrones()
		end
	end)
	map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	for _, name in ipairs(DECOR_GROUPS) do
		local g = map:FindFirstChild(name)
		if g then
			decorGroups[g] = true
		end
	end
	-- карта приходит частями (StreamingEnabled): учитываем и то, что подгрузится позже
	task.spawn(function()
		local n = 0
		for _, d in ipairs(map:GetDescendants()) do
			register(d)
			n += 1
			if n % 2000 == 0 then
				task.wait()
			end
		end
	end)
	map.DescendantAdded:Connect(register)
	map.DescendantRemoving:Connect(unregister)
	map.ChildAdded:Connect(function(c)
		if table.find(DECOR_GROUPS, c.Name) then
			decorGroups[c] = true
		end
	end)

	-- раз в полсекунды обновляем, что включено: дешёвый проход по ~500 объектам и ~200 клеткам
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local at = cam.Focus.Position
		local r = RADIUS[level]
		local k = isPhone() and 0.75 or 1
		local lr, er = r.light * k, r.emit * k
		for lt in pairs(lights) do
			local p = worldPos(lt)
			if p then
				local on = lt:GetAttribute("ZSS_LODOn") == true and (p - at).Magnitude < lr + (lt.Range or 0)
				if lt.Enabled ~= on then
					lt.Enabled = on
				end
			end
		end
		for e in pairs(emitters) do
			local p = worldPos(e)
			if p then
				local on = e:GetAttribute("ZSS_LODOn") == true and (p - at).Magnitude < er
				if e.Enabled ~= on then
					e.Enabled = on
				end
			end
		end
		updateDecor(at)
	end)
end

return L
