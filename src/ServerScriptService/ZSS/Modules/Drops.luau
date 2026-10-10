-- Выпадение в мире: БАФФЫ (светящиеся сферы) и ПРЕДМЕТЫ (ящички-находки).
-- Баффы появляются на полях сами и иногда падают из зомби — подобрал, и он сразу действует.
-- Предметы падают ящичком там, где были найдены; подойди — и предмет улетит в рюкзак.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Buffs = require(RS.ZSS.BuffsConfig)
local Items = require(RS.ZSS.ItemsConfig)
local Icons = require(RS.ZSS.Icons)
local Remotes = RS.ZSS.Remotes

local Drops = {}
local Data, Fields, Equipment, Drones
local rng = Random.new()
local folder
local crates = {} -- part -> {owner, item, born}
local lastNote = {}

local function getFolder()
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("Pickups") or Instance.new("Folder")
		folder.Name = "Pickups"
		folder.Parent = workspace
	end
	return folder
end

local function billboard(parent, image, size, offset, glowColor)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.StudsOffset = offset
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	if glowColor then
		local g = Instance.new("ImageLabel")
		g.Name = "Glow"
		g.BackgroundTransparency = 1
		g.Size = UDim2.fromScale(1.7, 1.7)
		g.Position = UDim2.fromScale(-0.35, -0.35)
		g.Image = Icons.glow
		g.ImageColor3 = glowColor
		g.ImageTransparency = 0.25
		g.Parent = bb
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.Parent = bb
	bb.Parent = parent
	return bb
end

local function sparkle(parent, color, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.45, 0)
	pe.Parent = parent
end

-- ===== БАФФЫ =====
-- добавить ступени: время восстанавливается до полного, ступеней не больше MaxStacks
local expiry = {}
function Drops.AddStacks(player, id, n)
	local b = Buffs.ById[id]
	if not b or b.time <= 0 then
		return 0
	end
	local stacks = math.min(Buffs.MaxStacks, Buffs.Stacks(player, id) + (n or 1))
	local untilT = workspace:GetServerTimeNow() + b.time
	player:SetAttribute("ZSS_BuffN_" .. id, stacks)
	player:SetAttribute("ZSS_Buff_" .. id, untilT)
	if id == "speed" then
		Equipment.RefreshSpeed(player)
		-- по окончании вернуть обычную скорость (если бафф не продлили)
		local token = {}
		expiry[player] = token
		task.delay(b.time + 0.05, function()
			if expiry[player] == token and player.Parent then
				Equipment.RefreshSpeed(player)
			end
		end)
	end
	return stacks
end

function Drops.ApplyBuff(player, b)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local stacks
	if b.id == "heal" then
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + b.value)
		end
		Remotes.FX:FireAllClients("heal", { owner = player.UserId })
	elseif b.id == "charge" then
		if Drones and Drones.AddEnergy then
			Drones.AddEnergy(player, b.value)
		end
	else
		stacks = Drops.AddStacks(player, b.id, 1)
	end
	Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = b.color, duration = 1.2 })
	-- мгновенные баффы — сообщением; скопление видно в панели баффов над хотбаром
	if not stacks then
		Remotes.Notify:FireClient(player, ("%s — %s"):format(b.name, b.desc), "speed")
	end
end

function Drops.SpawnBuff(b, pos, fieldId)
	local p = Instance.new("Part")
	p.Name = "BuffPickup"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2.8, 2.8, 2.8)
	p.Material = Enum.Material.ForceField
	p.Color = b.color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.CFrame = CFrame.new(pos)
	p:SetAttribute("Buff", b.id)
	p:SetAttribute("Field", fieldId)
	p:SetAttribute("BaseY", pos.Y)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.2, 1.2, 1.2)
	core.Material = Enum.Material.Neon
	core.Color = b.color:Lerp(Color3.new(1, 1, 1), 0.35)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.CFrame = p.CFrame
	core.Parent = p
	local light = Instance.new("PointLight")
	light.Color = b.color
	light.Range = 12
	light.Brightness = 2
	light.Parent = p
	billboard(p, Icons.buffs[b.id] or Icons.speed, 2.2, Vector3.new(0, 3, 0), b.color)
	sparkle(p, b.color, 10)
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
		Drops.ApplyBuff(player, b)
		require(script.Parent.Quests).Event(player, "pickup")
		Remotes.FX:FireAllClients("pickup", { pos = p.Position, owner = player.UserId, color = b.color })
		p:Destroy()
	end)
	p.Parent = getFolder()
	task.delay(Buffs.Field.lifetime, function()
		if p.Parent then
			p:Destroy()
		end
	end)
	return p
end

-- сфера из убитого зомби — только боевая
function Drops.ZombieKilled(pos, field)
	if rng:NextNumber() >= Buffs.ZombieChance then
		return
	end
	if field and Drops.CountOnField(field) >= Buffs.Field.perField then
		return
	end
	local y = field and field.cfg.center.Y or pos.Y - 2
	Drops.SpawnBuff(Buffs.Roll(rng, "combat"), Vector3.new(pos.X, y + 3.2, pos.Z), field and field.cfg.id)
end

function Drops.CountOnField(field)
	local n = 0
	for _, p in ipairs(getFolder():GetChildren()) do
		if p.Name == "BuffPickup" and p:GetAttribute("Field") == field.cfg.id then
			n += 1
		end
	end
	return n
end

-- Баффы от активности игрока: cat = "gather" (добыча) или "combat" (бой).
-- Сфера появляется рядом с местом активности, с паузой для каждого игрока.
local lastActivity = {} -- player -> { gather = t, combat = t }
function Drops.OnActivity(player, cat, pos, field)
	if not player or not field or field.cfg.boss then
		return
	end
	local rule = cat == "combat" and Buffs.Combat or Buffs.Gather
	local now = os.clock()
	local last = lastActivity[player] or {}
	lastActivity[player] = last
	if last[cat] and now - last[cat] < rule.cooldown then
		return
	end
	if rng:NextNumber() >= rule.chance * Buffs.Mult(player, "luck") then
		return
	end
	if Drops.CountOnField(field) >= Buffs.Field.perField then
		return
	end
	last[cat] = now
	-- точка в 3–7 студах от места активности, внутри поля
	local c = field.cfg.center
	local h = field.half - 3
	local a = rng:NextNumber() * math.pi * 2
	local d = rng:NextNumber(3, 7)
	local x = math.clamp(pos.X + math.cos(a) * d, c.X - h, c.X + h)
	local z = math.clamp(pos.Z + math.sin(a) * d, c.Z - h, c.Z + h)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { getFolder(), workspace:FindFirstChild("Zombies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(Vector3.new(x, c.Y + 40, z), Vector3.new(0, -80, 0), params)
	Drops.SpawnBuff(Buffs.Roll(rng, cat), Vector3.new(x, (hit and hit.Position.Y or c.Y) + 2.6, z), field.cfg.id)
end

-- равномерно по полю: выбирается самая пустая четверть
local function spawnOnField(field)
	local c = field.cfg.center
	local h = field.half - 4
	local counts = { 0, 0, 0, 0 }
	local mine = 0
	for _, p in ipairs(getFolder():GetChildren()) do
		if p.Name == "BuffPickup" and p:GetAttribute("Field") == field.cfg.id then
			mine += 1
			local q = (p.Position.X >= c.X and 1 or 0) + (p.Position.Z >= c.Z and 2 or 0) + 1
			counts[q] += 1
		end
	end
	if mine >= Buffs.Field.perField then
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
	local x = c.X + ((q % 2 == 1) and 1 or -1) * rng:NextNumber(3, h)
	local z = c.Z + ((q >= 2) and 1 or -1) * rng:NextNumber(3, h)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { getFolder(), workspace:FindFirstChild("Zombies") }
	local hit = workspace:Raycast(Vector3.new(x, c.Y + 40, z), Vector3.new(0, -80, 0), params)
	Drops.SpawnBuff(Buffs.Roll(rng), Vector3.new(x, (hit and hit.Position.Y or c.Y) + 2.6, z), field.cfg.id)
end

-- ===== ПРЕДМЕТЫ (ящички-находки) =====
local function collect(part, player)
	local info = crates[part]
	if not info or info.taken then
		return
	end
	if Data.AddItem(player, info.item.id, 1) then
		info.taken = true
		crates[part] = nil
		Remotes.FX:FireClient(player, "itemdrop", { id = info.item.id, pos = part.Position })
		require(script.Parent.Quests).Event(player, "find")
		part:Destroy()
	else
		local now = os.clock()
		if not lastNote[player] or now - lastNote[player] > 15 then
			lastNote[player] = now
			Remotes.Notify:FireClient(player, "🎒 В рюкзаке нет места для «" .. info.item.name .. "». Продай или используй предметы!", "bad")
		end
	end
end

function Drops.SpawnItem(owner, item, pos)
	local tier = Items.Tiers[item.tier]
	local p = Instance.new("Part")
	p.Name = "ItemPickup"
	p.Size = Vector3.new(1.7, 1.4, 1.7)
	p.Material = Enum.Material.WoodPlanks
	p.MaterialVariant = "ZSSG_Wood"
	p.Color = Color3.fromRGB(170, 120, 70)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	local ground = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { getFolder(), workspace:FindFirstChild("Zombies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(ground + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	if hit then
		ground = hit.Position
	end
	p.CFrame = CFrame.new(ground + Vector3.new(0, 1.6, 0))
	p:SetAttribute("BaseY", ground.Y + 1.6)
	p:SetAttribute("Item", item.id)
	p:SetAttribute("Owner", owner.UserId)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.FillColor = tier.color
	hl.OutlineColor = tier.color
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = p
	local light = Instance.new("PointLight")
	light.Color = tier.color
	light.Range = 10
	light.Brightness = 1.6
	light.Parent = p
	billboard(p, Icons.items[item.id] or Icons.lootCrate, 2, Vector3.new(0, 2.6, 0), tier.color)
	sparkle(p, tier.color, item.tier == "Common" and 4 or 12)
	crates[p] = { owner = owner, item = item, born = os.clock() }
	p.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local info = crates[p]
		if player and info and (player == info.owner or os.clock() - info.born > Buffs.Loot.ownerTime) then
			collect(p, player)
		end
	end)
	p.Parent = getFolder()
	Remotes.FX:FireClient(owner, "lootspawn", { id = item.id, pos = p.Position })
	task.delay(Buffs.Loot.lifetime, function()
		if p.Parent then
			crates[p] = nil
			p:Destroy()
		end
	end)
	return p
end

function Drops.Init(dataModule, fieldsModule, equipmentModule, dronesModule)
	Data, Fields, Equipment, Drones = dataModule, fieldsModule, equipmentModule, dronesModule
	getFolder()
	-- сферы больше не появляются сами — только от активности игрока (Drops.OnActivity)
	-- магнит: находка сама притягивается, когда владелец рядом
	task.spawn(function()
		while true do
			task.wait(0.25)
			for part, info in pairs(crates) do
				if not part.Parent then
					crates[part] = nil
				else
					local open = os.clock() - info.born > Buffs.Loot.ownerTime
					for _, pl in ipairs(Players:GetPlayers()) do
						if pl == info.owner or open then
							local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
							if hrp and (hrp.Position - part.Position).Magnitude <= Buffs.Loot.magnet then
								collect(part, pl)
								break
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		lastNote[pl] = nil
		lastActivity[pl] = nil
	end)
end

return Drops
