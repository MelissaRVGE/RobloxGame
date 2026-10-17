-- Дальность прорисовки «дорогих» мелочей карты: фонари, частицы и тени от мелкого декора.
-- Вблизи всё как было, вдали (где разницы не видно) свет и частицы выключаются — телефонам заметно легче.
-- Уровень берётся из настроек графики (НИЗКОЕ / СРЕДНЕЕ / ВЫСОКОЕ), на телефоне радиусы меньше.
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local L = {}

-- радиусы в студах по уровню качества: свет, частицы
local RADIUS = {
	[1] = { light = 90, emit = 70 },
	[2] = { light = 150, emit = 120 },
	[3] = { light = 240, emit = 200 },
}
local SMALL_PART = 3 -- деталь меньше этого по всем осям не отбрасывает тень на низком/среднем качестве

local level = 3
local lights, emitters = {}, {}
local small = {}
local shadowsOff = false
local smallShadowsOff = false

local function isPhone()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

local function worldPos(inst)
	local p = inst.Parent
	if p and p:IsA("Attachment") then
		return p.WorldPosition
	elseif p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
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
	elseif d:IsA("ParticleEmitter") then
		if d:GetAttribute("ZSS_LODOn") == nil then
			d:SetAttribute("ZSS_LODOn", d.Enabled)
		end
		emitters[d] = true
	elseif d:IsA("BasePart") and d.CastShadow then
		local s = d.Size
		if s.X < SMALL_PART and s.Y < SMALL_PART and s.Z < SMALL_PART then
			small[d] = true
			if smallShadowsOff then
				d.CastShadow = false
			end
		end
	end
end

local function unregister(d)
	lights[d] = nil
	emitters[d] = nil
	small[d] = nil
end

-- тени фонарей и мелкого декора включаются/выключаются по уровню; огромные списки обходим порциями
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
	task.spawn(function()
		local n = 0
		for p in pairs(small) do
			if p.Parent then
				p.CastShadow = not smallShadowsOff
			end
			n += 1
			if n % 1500 == 0 then
				task.wait()
			end
		end
	end)
end

function L.SetLevel(lv)
	level = math.clamp(lv or 3, 1, 3)
	applyShadows()
end

function L.Init()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
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

	-- раз в полсекунды обновляем, что включено: дешёвый проход по ~300 объектам
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
	end)
end

return L
