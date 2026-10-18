-- Хэллоуин на клиенте: светящиеся тыквы на плитках полей и эффекты способностей хэллоуинских дронов
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local U = require(script.Parent.U)
local FX = require(script.Parent.FX)

local HFX = {}
local C = Color3.fromRGB
local player = Players.LocalPlayer
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local ORANGE = C(255, 140, 30)
local PURPLE = C(170, 90, 255)

local part, tw = FX.Part, FX.Tween

local function pumpkinTemplate()
	local lib = Shared:FindFirstChild("HalloweenMeshes")
	return lib and lib:FindFirstChild("Pumpkin")
end

-- ===== ТЫКВЫ НА ПЛИТКАХ =====
-- плитка с атрибутом Pumpkin получает светящуюся 3D-тыкву, которая едет вместе с плиткой
local shown = {} -- tile -> { model, light, t0 }
local folder

local function addPumpkin(tile)
	if shown[tile] then
		return
	end
	local tpl = pumpkinTemplate()
	local p
	if tpl then
		p = tpl:Clone()
	else
		p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2.4, 1.9, 2.4)
		p.Color = ORANGE
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Name = "FieldPumpkin"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local k = 2.6 / math.max(p.Size.X, p.Size.Z)
	p.Size *= k
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 9
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = p
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(C(255, 200, 80), ORANGE)
	pe.LightEmission = 1
	pe.Rate = 3
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.4, 1.2)
	pe.Acceleration = Vector3.new(0, 1.5, 0)
	pe.Size = NumberSequence.new(0.3, 0)
	pe.Parent = p
	p.Parent = folder
	shown[tile] = { model = p, t0 = os.clock() + math.random() * 3, scale = 0 }
end

local function removePumpkin(tile, popped)
	local s = shown[tile]
	if not s then
		return
	end
	shown[tile] = nil
	local p = s.model
	if popped then
		tw(p, 0.25, { Size = p.Size * 1.35, Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.3, function()
			p:Destroy()
		end)
	else
		p:Destroy()
	end
end

local function watchTile(tile)
	if not tile:IsA("BasePart") then
		return
	end
	local function upd()
		if tile:GetAttribute("Pumpkin") then
			addPumpkin(tile)
		else
			removePumpkin(tile, true)
		end
	end
	tile:GetAttributeChangedSignal("Pumpkin"):Connect(upd)
	if tile:GetAttribute("Pumpkin") then
		addPumpkin(tile)
	end
end

local function step()
	local t = os.clock()
	for tile, s in pairs(shown) do
		if not tile.Parent then
			removePumpkin(tile)
		else
			-- плавно вырастает при появлении, покачивается и светится «дыханием»
			s.scale = math.min(1, s.scale + 0.04)
			local e = s.scale < 1 and (1 - (1 - s.scale) ^ 3) or 1
			local top = tile.CFrame.Position + Vector3.new(0, tile.Size.Y / 2 + 1.3 + math.sin(t * 2 + s.t0) * 0.15, 0)
			s.model.CFrame = CFrame.new(top) * CFrame.Angles(0, t * 0.6 + s.t0, 0) * CFrame.new(0, -1.3 * (1 - e), 0)
			local light = s.model:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = (1.3 + math.sin(t * 3 + s.t0) * 0.4) * e
			end
		end
	end
end

-- ===== ЭФФЕКТЫ СПОСОБНОСТЕЙ =====
local H = FX.Handlers

H.pumpkinpop = function(d)
	FX.Burst(d.pos + Vector3.new(0, 1.3, 0), ColorSequence.new(C(255, 210, 90), ORANGE), 24, 0.7, 12)
	FX.Ring(d.pos, 3, ORANGE, 0.4)
	U.play(U.Sounds.glock, 0.5, 1.4)
end

-- Тыквёныш: тыква летит по дуге и взрывается огнём
H.pumpkinbomb = function(d)
	local from = FX.DronePos(d.owner, d.key)
	if not from then
		return
	end
	local ball = part({ shape = Enum.PartType.Ball, size = Vector3.new(1.2, 1, 1.2), cf = CFrame.new(from), color = ORANGE, mat = Enum.Material.SmoothPlastic, life = 1 })
	local to = d.to
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.45, 0, 1)
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0)
		ball.CFrame = CFrame.new(p) * CFrame.Angles(a * 8, a * 5, 0)
		if a >= 1 then
			conn:Disconnect()
			ball:Destroy()
			FX.Ring(to, d.radius, ORANGE, 0.5)
			FX.Burst(to, ColorSequence.new(C(255, 220, 90), C(255, 70, 10)), 36, 1.6, 22, FIRE_TEX)
			FX.Burst(to, C(255, 150, 40), 16, 0.5, 16)
			U.play(U.Sounds.boom, 0.35, 1.4)
		end
	end)
end

-- Вдова: нити паутины ко всем зомби
H.web = function(d)
	local from = FX.DronePos(d.owner, d.key) or d.pos
	FX.Ring(d.pos, d.radius, C(230, 235, 245), 0.6, true)
	for _, p in ipairs(d.points) do
		FX.Beam(from, p, C(235, 240, 250), 0.08, 0.9)
		local net = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.1, 4, 4), cf = CFrame.new(p - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = C(240, 240, 250), mat = Enum.Material.ForceField, life = 6 })
		tw(net, 5.5, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	end
end

-- Призрак: фиолетовые призрачные следы к целям
H.haunt = function(d)
	local from = FX.DronePos(d.owner, d.key)
	for _, p in ipairs(d.points) do
		if from then
			FX.Beam(from, p, PURPLE, 0.25, 0.7)
		end
		FX.Burst(p, ColorSequence.new(C(230, 200, 255), PURPLE), 18, 1, 8)
		local ghost = part({ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 2, 1.4), cf = CFrame.new(p), color = C(220, 200, 255), mat = Enum.Material.ForceField, life = 1.6 })
		tw(ghost, 1.4, { CFrame = CFrame.new(p + Vector3.new(0, 9, 0)), Transparency = 1 }, Enum.EasingStyle.Sine)
	end
	U.play(U.Sounds.whoosh, 0.4, 0.7)
end

-- Джек-о-Дрон: огненный взрыв фонаря
H.lantern = function(d)
	local pos, r = d.pos, d.radius
	FX.Ring(pos, r, ORANGE, 0.6, true)
	task.delay(0.6, function()
		local sph = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2, cf = CFrame.new(pos), color = C(255, 200, 80), life = 1.2 })
		tw(sph, 0.6, { Size = Vector3.one * r * 2, Transparency = 1, Color = C(255, 70, 10) })
		FX.Ring(pos, r * 1.2, ORANGE, 0.8)
		FX.Burst(pos, ColorSequence.new(C(255, 230, 120), C(255, 60, 10)), 70, 3, 36, FIRE_TEX)
		FX.Burst(pos, C(255, 170, 60), 30, 0.8, 26)
		U.play(U.Sounds.boom, 0.6, 1.1)
		local hrp = FX.OwnerRoot(player.UserId)
		if hrp and (hrp.Position - pos).Magnitude < 80 then
			FX.Shake(0.7)
		end
	end)
end

-- Жнец: зелёный серп по кругу и души, улетающие вверх
H.harvest = function(d)
	local pos, r = d.pos, d.radius
	local blade = part({ size = Vector3.new(0.3, 0.2, r * 2.2), cf = CFrame.new(pos), color = C(160, 255, 120), tr = 0.2, life = 1 })
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.5, 0, 1)
		blade.CFrame = CFrame.new(pos) * CFrame.Angles(0, a * math.pi * 2, 0) * CFrame.new(0, 0, -r * 0.55)
		blade.Transparency = 0.2 + 0.8 * a
		if a >= 1 then
			conn:Disconnect()
		end
	end)
	FX.Ring(pos, r, C(150, 255, 110), 0.6)
	local from = FX.DronePos(d.owner, d.key)
	for _, p in ipairs(d.points) do
		if from then
			FX.Beam(from, p, C(150, 255, 110), 0.25, 0.6)
		end
		local soul = part({ shape = Enum.PartType.Ball, size = Vector3.one * 1.4, cf = CFrame.new(p), color = C(170, 255, 140), tr = 0.2, life = 1.6 })
		tw(soul, 1.4, { CFrame = CFrame.new(p + Vector3.new(0, 14, 0)), Size = Vector3.one * 0.2, Transparency = 1 })
	end
	U.play(U.Sounds.whoosh, 0.6, 0.55)
end

-- Тыквенный Король: небо темнеет, огненные тыквы падают на поле
H.terror = function(d)
	local pos, r = d.pos, d.radius
	local ground = Vector3.new(pos.X, pos.Y - 2.6, pos.Z)
	for i = 0, 2 do
		task.delay(i * 0.45, function()
			FX.Ring(pos, r, ORANGE, 0.5, true)
			U.play(U.Sounds.tick, 0.6, 0.45)
		end)
	end
	for i = 1, 10 do
		task.delay(0.2 + i * 0.1, function()
			local a = math.random() * math.pi * 2
			local p = ground + Vector3.new(math.cos(a) * math.random(2, r * 0.6), 0, math.sin(a) * math.random(2, r * 0.6))
			local pk = part({ shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2, 2.4), cf = CFrame.new(p + Vector3.new(0, 40, 0)), color = ORANGE, mat = Enum.Material.Neon, life = 2 })
			tw(pk, 0.9, { CFrame = CFrame.new(p) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.9, function()
				pk:Destroy()
				FX.Burst(p, ColorSequence.new(C(255, 220, 90), C(255, 40, 10)), 26, 1.8, 20, FIRE_TEX)
			end)
		end)
	end
	task.delay(1.4, function()
		local shell = part({ shape = Enum.PartType.Ball, size = Vector3.one * 4, cf = CFrame.new(ground), color = PURPLE, mat = Enum.Material.ForceField, life = 3 })
		tw(shell, 1.4, { Size = Vector3.one * r * 2.4, Transparency = 1 })
		local core = part({ shape = Enum.PartType.Ball, size = Vector3.one * 4, cf = CFrame.new(ground), color = C(255, 200, 90), life = 2 })
		tw(core, 0.8, { Size = Vector3.one * r * 1.4, Transparency = 1, Color = ORANGE })
		FX.Ring(pos, r * 1.3, ORANGE, 1.1)
		FX.Burst(ground, ColorSequence.new(C(255, 220, 120), PURPLE), 110, 4, 50, SMOKE_TEX)
		U.play(U.Sounds.boom, 1, 0.55)
		local hrp = FX.OwnerRoot(player.UserId)
		if hrp and (hrp.Position - pos).Magnitude < 150 then
			FX.Shake(1.6)
		end
	end)
end

function HFX.Init()
	if not Config.HalloweenOn() then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "ZSS_FieldPumpkins"
	folder.Parent = workspace
	task.spawn(function()
		local fields = workspace:WaitForChild("Map"):WaitForChild("Fields")
		local function hook(inst)
			if inst.Parent and inst.Parent.Name == "Tiles" then
				watchTile(inst)
			end
		end
		for _, d in ipairs(fields:GetDescendants()) do
			hook(d)
		end
		fields.DescendantAdded:Connect(hook)
	end)
	RunService.RenderStepped:Connect(step)
end

return HFX
