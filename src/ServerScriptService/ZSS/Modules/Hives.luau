-- Ульи-зарядки: 6 стен с сотами (по одной на игрока), покупка новых сот
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Icons = require(RS.ZSS.Icons)
local Remotes = RS.ZSS.Remotes

local Hives = {}
local Data, Drones
local owners = {} -- hiveIndex -> player
local folder
local C = Color3.fromRGB

local COL_FREE = C(70, 220, 255) -- свободное зарядное гнездо
local COL_IDLE = C(80, 90, 100) -- стойка без хозяина

-- одно зарядное гнездо: металлическая шайба, светящееся кольцо, тёмный контакт и индикатор
local AXIS = CFrame.Angles(0, math.rad(90), 0) -- цилиндр осью вдоль Z (лицом наружу)
local function makeSlot(folder, frame, c)
	local base = frame * Config.CellOffset(c, 0)
	local m = Instance.new("Model")
	m.Name = "Slot_" .. c
	local function p(name, size, cf, color, mat, shape)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.CastShadow = false
		x.Shape = shape or Enum.PartType.Cylinder
		x.Size = size
		x.CFrame = cf
		x.Color = color
		x.Material = mat
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		x.Parent = m
		return x
	end
	p("Housing", Vector3.new(0.34, 1.48, 1.48), base * CFrame.new(0, 0, -0.1) * AXIS, C(48, 52, 58), Enum.Material.Metal)
	p("Ring", Vector3.new(0.06, 1.24, 1.24), base * CFrame.new(0, 0, -0.29) * AXIS, COL_FREE, Enum.Material.Neon)
	p("Core", Vector3.new(0.08, 0.96, 0.96), base * CFrame.new(0, 0, -0.31) * AXIS, C(22, 26, 32), Enum.Material.SmoothPlastic)
	p("Pin", Vector3.new(0.12, 0.26, 0.26), base * CFrame.new(0, 0, -0.34) * AXIS, COL_FREE, Enum.Material.Neon)
	p("Led", Vector3.new(0.5, 0.08, 0.06), base * CFrame.new(0, -0.66, -0.29), COL_FREE, Enum.Material.Neon, Enum.PartType.Block)
	m.Parent = folder
	return m
end

function Hives.Index(player)
	for i = 1, Config.Hive.count do
		if owners[i] == player then
			return i
		end
	end
	return nil
end

function Hives.Owner(i)
	return owners[i]
end

-- позиция дрона в соте
function Hives.CellPos(i, c)
	return (Config.HiveFrames[i] * Config.CellOffset(c, 0.9)).Position
end

-- точка перед ульем (для телепорта)
function Hives.FrontPos(i)
	local f = Config.HiveFrames[i]
	return Vector3.new(f.X, 4, f.Z) + f.LookVector * 9
end

local function hiveModel(i)
	return folder and folder:FindFirstChild("Hive_" .. i)
end

function Hives.Refresh(i)
	local model = hiveModel(i)
	if not model or not Data or not Drones then
		return
	end
	local owner = owners[i]
	local p = owner and Data.Get(owner)
	-- видно столько гнёзд, сколько куплено (у свободной стойки — 3 потухших)
	local slots = p and (p.dockSlots or Config.Hive.startCells) or Config.Hive.startCells
	local docked = owner and Drones.DockedCells(owner) or {}
	local folder = model:FindFirstChild("Slots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Slots"
		folder.Parent = model
	end
	for _, s in ipairs(folder:GetChildren()) do
		local n = tonumber(s.Name:match("%d+"))
		if not n or n > slots then
			s:Destroy()
		end
	end
	for c = 1, slots do
		local s = folder:FindFirstChild("Slot_" .. c) or makeSlot(folder, Config.HiveFrames[i], c)
		local col
		if not owner then
			col = COL_IDLE
		elseif docked[c] then
			col = docked[c]
		else
			col = COL_FREE
		end
		for _, name in ipairs({ "Ring", "Pin", "Led" }) do
			local part = s:FindFirstChild(name)
			if part then
				part.Color = col
				part.Material = owner and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
		s:SetAttribute("Charging", docked[c] ~= nil)
	end
	local prompt = model:FindFirstChild("ChargePrompt", true)
	if prompt then
		if owner then
			prompt.ActionText = "Зарядить / забрать дронов"
			prompt.ObjectText = "⚡ Станция №" .. i .. " • " .. owner.DisplayName
		else
			prompt.ActionText = "Занять станцию"
			prompt.ObjectText = "⚡ Станция зарядки №" .. i
		end
	end
	local plate = model:FindFirstChild("NamePlate", true)
	local gui = plate and plate:FindFirstChildOfClass("SurfaceGui")
	if gui then
		local name = gui:FindFirstChild("Owner", true)
		local sub = gui:FindFirstChild("Sub", true)
		if name then
			name.Text = owner and owner.DisplayName or "СВОБОДНО"
		end
		if sub then
			sub.Text = owner and ("⚡ Гнёзда: %d / %d"):format(slots, Config.Hive.maxCells) or "Подойди и займи (E)"
		end
	end
	model:SetAttribute("OwnerId", owner and owner.UserId or 0)
end

function Hives.RefreshPlayer(player)
	local i = Hives.Index(player)
	if i then
		Hives.Refresh(i)
	end
end

-- игрок сам подходит к свободной станции и занимает её
function Hives.Claim(player, i)
	if Hives.Index(player) then
		return false, "У тебя уже есть станция №" .. Hives.Index(player)
	end
	if owners[i] then
		return false, "Эта станция уже занята"
	end
	owners[i] = player
	player:SetAttribute("ZSS_Hive", i)
	Hives.Refresh(i)
	Remotes.FX:FireAllClients("hiveClaim", { hive = i, owner = player.UserId })
	return true
end

function Hives.Release(player)
	local i = Hives.Index(player)
	if i then
		owners[i] = nil
		if player.Parent then
			player:SetAttribute("ZSS_Hive", nil)
		end
		Hives.Refresh(i)
	end
end

-- покупка сот в Мастерской
function Hives.BuyCell(player, qty)
	local p = Data.Get(player)
	if not p then
		return { ok = false }
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Config.CellShop.center).Magnitude > Config.CellShop.radius + 6 then
		return { ok = false, err = "Гнёзда покупаются в Мастерской у станций зарядки" }
	end
	qty = math.clamp(math.floor(tonumber(qty) or 1), 1, 10)
	local bought = 0
	for _ = 1, qty do
		local n = (p.dockSlots or Config.Hive.startCells) + 1
		if n > Config.Hive.maxCells then
			break
		end
		local cost = Config.CellCost(n)
		if p.batteries < cost then
			break
		end
		p.batteries -= cost
		p.dockSlots = n
		bought += 1
	end
	if bought == 0 then
		if (p.dockSlots or 3) >= Config.Hive.maxCells then
			return { ok = false, err = "Станция уже полностью застроена (50/50)" }
		end
		return { ok = false, err = ("🔋 Нужно %d батарей"):format(Config.CellCost((p.dockSlots or 3) + 1)) }
	end
	Data.MarkDirty(player)
	Hives.RefreshPlayer(player)
	Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
	return { ok = true, msg = ("⚡ Куплено гнёзд: %d. Теперь %d / %d"):format(bought, p.dockSlots, Config.Hive.maxCells) }
end

function Hives.Init(dataModule, dronesModule, onCharge)
	Data, Drones = dataModule, dronesModule
	folder = workspace:WaitForChild("Map"):WaitForChild("Base"):WaitForChild("Hives", 10)
	Drones.HiveIndex = Hives.Index
	Drones.CellPos = Hives.CellPos
	Drones.OnDockChanged = Hives.RefreshPlayer
	if folder then
		for i = 1, Config.Hive.count do
			local model = hiveModel(i)
			local prompt = model and model:FindFirstChild("ChargePrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					local mine = Hives.Index(player)
					if not owners[i] then
						local ok, err = Hives.Claim(player, i)
						Remotes.Notify:FireClient(player, ok and ("⚡ Теперь станция №" .. i .. " твоя! Нажми E ещё раз, чтобы зарядить дронов") or err, ok and "good" or "bad")
						return
					end
					if mine ~= i then
						Remotes.Notify:FireClient(player, "Это станция игрока " .. owners[i].DisplayName .. (mine and (". Твоя — №" .. mine) or ""), "bad")
						return
					end
					onCharge(player)
				end)
			end
			Hives.Refresh(i)
		end
	end
	-- анимация заряжающихся сот делает клиент (атрибут Charging)
	Players.PlayerRemoving:Connect(Hives.Release)
end

return Hives
