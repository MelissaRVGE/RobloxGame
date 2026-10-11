-- Смена дня/ночи и ускорения на полях
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Icons = require(RS.ZSS.Icons)
local Remotes = RS.ZSS.Remotes

local World = {}
local Fields, Equipment
local rng = Random.new()

-- ===== ДЕНЬ / НОЧЬ =====
local DN = Config.DayNight
local CYCLE = DN.day + DN.night

-- фаза цикла в секундах (0..CYCLE); клиент считает так же по атрибуту ZSS_CycleStart
function World.Phase()
	local start = workspace:GetAttribute("ZSS_CycleStart") or 0
	return (workspace:GetServerTimeNow() - start) % CYCLE
end

function World.IsNight()
	return World.Phase() >= DN.day
end

local function startCycle()
	-- сервер стартует утром (четверть дня уже прошла)
	workspace:SetAttribute("ZSS_CycleStart", workspace:GetServerTimeNow() - DN.day * 0.1)
	workspace:SetAttribute("ZSS_DayLength", DN.day)
	workspace:SetAttribute("ZSS_NightLength", DN.night)
	local was = nil
	task.spawn(function()
		while true do
			local night = World.IsNight()
			if night ~= was then
				workspace:SetAttribute("ZSS_Night", night)
				if was ~= nil then
					if night then
						Remotes.Notify:FireAllClients("🌙 Наступила ночь! Зомби и босс бьют x2, но и награды x2", "night")
					else
						Remotes.Notify:FireAllClients("☀ Рассвет! Зомби снова слабее", "good")
					end
				end
				was = night
			end
			task.wait(1)
		end
	end)
end

-- ===== УСКОРЕНИЯ =====
local SP = Config.SpeedPickup
local pickupFolder

local function makePickup(field, pos)
	local p = Instance.new("Part")
	p.Name = "SpeedPickup"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2.6, 2.6, 2.6)
	p.Material = Enum.Material.ForceField
	p.Color = Color3.fromRGB(80, 230, 255)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(pos)
	p:SetAttribute("Field", field.cfg.id)
	p:SetAttribute("BaseY", pos.Y)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.3, 1.3, 1.3)
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(150, 255, 255)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CFrame = p.CFrame
	core.Parent = p
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(80, 230, 255)
	light.Range = 12
	light.Brightness = 2
	light.Parent = p
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(1.6, 0, 1.6, 0)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Icons.speed
	img.Parent = bb
	bb.Parent = p
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(120, 255, 255))
	pe.LightEmission = 1
	pe.Rate = 12
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Parent = p
	local taken = false
	p.Touched:Connect(function(hit)
		if taken then
			return
		end
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not player or not hum or hum.Health <= 0 then
			return
		end
		taken = true
		Equipment.AddSpeedBuff(player, SP.bonus, SP.duration)
		require(script.Parent.Quests).Event(player, "pickup")
		Remotes.FX:FireAllClients("pickup", { pos = p.Position, owner = player.UserId })
		Remotes.Notify:FireClient(player, ("⚡ Ускорение! +%d к скорости на %d сек"):format(SP.bonus, SP.duration), "speed")
		p:Destroy()
	end)
	p.Parent = pickupFolder
	task.delay(SP.lifetime, function()
		if p.Parent then
			p:Destroy()
		end
	end)
	return p
end

-- равномерно: поле делится на 4 четверти, выбирается самая пустая
local function spawnOn(field)
	local c = field.cfg.center
	local h = field.half - 4
	local counts = { 0, 0, 0, 0 }
	local mine = {}
	for _, p in ipairs(pickupFolder:GetChildren()) do
		if p:GetAttribute("Field") == field.cfg.id then
			table.insert(mine, p)
			local q = (p.Position.X >= c.X and 1 or 0) + (p.Position.Z >= c.Z and 2 or 0) + 1
			counts[q] += 1
		end
	end
	if #mine >= SP.perField then
		return
	end
	local best, bc = {}, math.huge
	for q = 1, 4 do
		if counts[q] < bc then
			best, bc = { q }, counts[q]
		elseif counts[q] == bc then
			table.insert(best, q)
		end
	end
	local q = best[rng:NextInteger(1, #best)] - 1
	local sx = (q % 2 == 1) and 1 or -1
	local sz = (q >= 2) and 1 or -1
	local x = c.X + sx * rng:NextNumber(3, h)
	local z = c.Z + sz * rng:NextNumber(3, h)
	-- высота: над плитами поля
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { pickupFolder, workspace:FindFirstChild("Zombies") }
	local hit = workspace:Raycast(Vector3.new(x, c.Y + 40, z), Vector3.new(0, -80, 0), params)
	local y = (hit and hit.Position.Y or c.Y) + 2.4
	makePickup(field, Vector3.new(x, y, z))
end

local function startPickups()
	pickupFolder = workspace:FindFirstChild("Pickups") or Instance.new("Folder")
	pickupFolder.Name = "Pickups"
	pickupFolder.Parent = workspace
	for _, f in ipairs(Fields.List) do
		if not f.cfg.boss then
			task.spawn(function()
				task.wait(rng:NextNumber(3, 12))
				while true do
					pcall(spawnOn, f)
					task.wait(rng:NextNumber(SP.minDelay, SP.maxDelay))
				end
			end)
		end
	end
end

-- таблички и ворота на карте показывают требования из конфига (их числа меняются при балансе)
local function syncMapReqs()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local byTier = {}
	for _, f in ipairs(Config.Fields) do
		if f.tier then
			byTier[f.tier] = f
		end
		local folder = map:FindFirstChild("Fields") and map.Fields:FindFirstChild(f.id)
		local board = folder and folder:FindFirstChild("InfoBoard")
		if board then
			for _, t in ipairs(board:GetDescendants()) do
				if t:IsA("TextLabel") and t.Text:find("Нужно дронов") then
					t.Text = "🤖 Нужно дронов: " .. f.req
				end
			end
		end
		if f.boss then
			local arena = map:FindFirstChild("BossArena")
			for _, t in ipairs(arena and arena:GetDescendants() or {}) do
				if t:IsA("TextLabel") and t.Text:find("БОСС") and t.Text:find("HP") then
					local hp = tostring(f.zombies.hp):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^%s+", "")
					t.Text = ("БОСС • %s HP • НУЖНО %d ДРОНОВ"):format(hp, f.req)
				end
			end
		end
	end
	local gates = map:FindFirstChild("TierGates")
	for _, gate in ipairs(gates and gates:GetChildren() or {}) do
		local n = tonumber(gate.Name:match("^Gate_(%d+)$"))
		if n and byTier[n] then
			gate:SetAttribute("Req", byTier[n].req)
		end
	end
end

function World.Init(fieldsModule, equipmentModule)
	Fields, Equipment = fieldsModule, equipmentModule
	task.spawn(syncMapReqs)
	startCycle()
	-- сферы-баффы на полях теперь в модуле Drops (разные виды баффов)
end

return World
