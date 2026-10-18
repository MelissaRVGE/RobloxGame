-- Хэллоуин: тыквы на полях, Призрачная ночь (зомби-призраки), Тыквенный Колосс,
-- ведьма (обмен тыкв и шляпа) и гача «Тыквенный котёл». Всё выключается Config.Halloween.enabled.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local HC = Config.Halloween
local Remotes = RS.ZSS.Remotes

local Halloween = {}
local Data, Fields, Drones, Loot
local rng = Random.new()
local busy = {}

local C = Color3.fromRGB
local ORANGE = C(255, 140, 30)

-- обмен у ведьмы: тыквы на награды
Halloween.Offers = {
	{ id = "gems", name = "Bag of Gems", desc = "10 💎 for the main gacha", cost = 60, gems = 10, icon = "gem" },
	{ id = "luckycoin", name = "Lucky Nut x2", desc = "Consumable: luck for finds", cost = 40, consum = { luckycoin = 2 }, icon = "luckycoin" },
	{ id = "gatherextract", name = "Gatherer's Extract", desc = "Consumable: big gathering boost", cost = 120, consum = { gatherextract = 1 }, icon = "gatherextract" },
	{ id = "capsule", name = "Firmware Capsule", desc = "A drone from the main pool", cost = 150, items = { capsule = 1 }, icon = "capsule" },
	{ id = "cocktail", name = "Survivor Cocktail", desc = "Consumable: every buff at once", cost = 200, consum = { cocktail = 1 }, icon = "cocktail" },
	{ id = "goldcapsule", name = "Gold Capsule", desc = "An Epic or better drone", cost = 500, items = { goldcapsule = 1 }, icon = "goldcapsule" },
	{ id = "starcapsule", name = "Star Capsule", desc = "A Legendary or better drone", cost = 1500, items = { starcapsule = 1 }, icon = "starcapsule" },
	{ id = "supershake", name = "Apocalypse Super Cocktail", desc = "The rarest consumable", cost = 3000, consum = { supershake = 1 }, icon = "supershake" },
}
Halloween.OfferById = {}
for _, o in ipairs(Halloween.Offers) do
	Halloween.OfferById[o.id] = o
end

local function on()
	return Config.HalloweenOn()
end

local function profile(player)
	local p = Data.Get(player)
	if p then
		p.pumpkins = p.pumpkins or 0
		p.hpity = p.hpity or { Legendary = 0, Mythic = 0, Secret = 0 }
		p.hpulls = p.hpulls or 0
		p.trophies = p.trophies or 0
		p.cosmetics = p.cosmetics or {}
	end
	return p
end

function Halloween.AddPumpkins(player, n, pos)
	local p = profile(player)
	if not p or n <= 0 then
		return
	end
	n = math.floor(n)
	p.pumpkins += n
	Data.MarkDirty(player)
	if pos then
		Remotes.Popup:FireClient(player, pos, "🎃 +" .. n, "pumpkin")
	end
	require(script.Parent.Quests).Event(player, "pumpkin", nil, n)
end

-- ===== ТЫКВЫ НА ПОЛЯХ =====
local function fieldValue(field)
	return HC.pumpkins.value[math.clamp(field.index, 1, #HC.pumpkins.value)] or 1
end

local function placePumpkin(field)
	local free = {}
	for _, t in ipairs(field.tiles) do
		if not t.pumpkin and not t.gold then
			table.insert(free, t)
		end
	end
	if #free == 0 then
		return
	end
	local t = free[rng:NextInteger(1, #free)]
	t.pumpkin = true
	t.part:SetAttribute("Pumpkin", fieldValue(field))
end

local function fillField(field)
	local n = 0
	for _, t in ipairs(field.tiles) do
		if t.pumpkin then
			n += 1
		end
	end
	for _ = n + 1, HC.pumpkins.perField do
		placePumpkin(field)
	end
end

-- вызывается из Fields.Collect: сбор плитки с тыквой даёт тыквы (лом собирается как обычно)
function Halloween.OnCollect(player, tile)
	if not tile.pumpkin or not on() then
		return
	end
	tile.pumpkin = false
	tile.part:SetAttribute("Pumpkin", nil)
	local field = tile.field
	Halloween.AddPumpkins(player, fieldValue(field), Fields.TopPos(tile) + Vector3.new(0, 1.5, 0))
	Remotes.FX:FireClient(player, "pumpkinpop", { pos = Fields.TopPos(tile) })
	task.delay(rng:NextNumber(HC.pumpkins.respawn[1], HC.pumpkins.respawn[2]), function()
		fillField(field)
	end)
end

-- ===== ПРИЗРАЧНАЯ НОЧЬ =====
local function meshLib()
	return RS.ZSS:FindFirstChild("HalloweenMeshes")
end

local function weldTo(base, p, offset)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	return p
end

-- надеть тыквенную голову на голову персонажа (зомби-призрак или Колосс)
local function pumpkinHead(model, head, scale)
	local lib = meshLib()
	local tpl = lib and lib:FindFirstChild("PumpkinHead")
	if not tpl or not head then
		return nil
	end
	local p = tpl:Clone()
	p.Name = "PumpkinHead"
	local s = head.Size.Y * (scale or 1.9) / math.max(p.Size.Y, 0.01)
	p.Size *= s
	weldTo(head, p, CFrame.new(0, p.Size.Y * 0.12, 0))
	p.Parent = model
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 10 * (scale or 1.9) / 1.9 * head.Size.Y
	light.Brightness = 1.6
	light.Parent = p
	head.Transparency = 1
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	return p
end

-- зомби-призрак: полупрозрачное фиолетовое тело, тыквенная голова, огоньки
function Halloween.Decorate(z)
	if not on() or not Loot.IsNight() or rng:NextNumber() > HC.ghosts.chance then
		return
	end
	z.ghost = true
	local m = z.model
	m:SetAttribute("Ghost", true)
	z.cfg = table.clone(z.cfg)
	z.cfg.name = "Ghost " .. z.cfg.name
	m.Name = z.cfg.name
	z.hum.MaxHealth = math.floor(z.hum.MaxHealth * HC.ghosts.hp)
	z.hum.Health = z.hum.MaxHealth
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Head" then
			d.Color = d.Color:Lerp(C(150, 90, 230), 0.55)
			d.Transparency = math.max(d.Transparency, 0.35)
		elseif d:IsA("Decal") then
			d.Transparency = math.max(d.Transparency, 0.4)
		end
	end
	local head = m:FindFirstChild("Head")
	pumpkinHead(m, head, 1.9)
	local torso = m:FindFirstChild("Torso")
	if torso then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(C(200, 150, 255), C(255, 150, 40))
		pe.LightEmission = 1
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.Acceleration = Vector3.new(0, 2, 0)
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Transparency = NumberSequence.new(0.2, 1)
		pe.Parent = torso
		local light = Instance.new("PointLight")
		light.Color = C(170, 110, 255)
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = torso
	end
	local bb = m:FindFirstChild("HP")
	local name = bb and bb:FindFirstChild("Name", true)
	if name and name:IsA("TextLabel") then
		name.Text = "👻 " .. z.cfg.name
		name.TextColor3 = C(220, 180, 255)
	end
end

-- награда за призрака: тыквы и второй шанс на расходник
function Halloween.OnZombieDeath(z, killer)
	if not z.ghost or not on() then
		return
	end
	local g = HC.ghosts
	Halloween.AddPumpkins(killer, rng:NextInteger(g.pumpkins[1], g.pumpkins[2]) * (z.field.index >= 3 and 2 or 1), z.root.Position + Vector3.new(0, 5, 0))
	for _ = 2, g.consumMult do
		Loot.TryConsum(killer, z.field.index, z.root.Position)
	end
end

-- ===== ТЫКВЕННЫЙ КОЛОСС =====
function Halloween.DecorateBoss(model)
	if not on() then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	-- всё, что приварено к голове (глаза, пластина, шипы), прячется под тыкву
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")) and d.Part0 == head and d.Part1 and d.Part1 ~= model:FindFirstChild("Torso") then
			d.Part1.Transparency = 1
		end
	end
	local ph = pumpkinHead(model, head, 2.1)
	if ph then
		local fire = Instance.new("Fire")
		fire.Color = ORANGE
		fire.SecondaryColor = C(255, 60, 10)
		fire.Heat = 12
		fire.Size = ph.Size.Y * 0.35
		fire.Parent = ph
	end
	model:SetAttribute("Pumpkin", true)
	local bb = model:FindFirstChild("HP")
	local name = bb and bb:FindFirstChild("Name", true)
	if name and name:IsA("TextLabel") then
		name.Text = "🎃 " .. HC.boss.name
	end
end

function Halloween.OnBossKill(player, k, pos)
	if not on() then
		return 0
	end
	local p = profile(player)
	if not p then
		return 0
	end
	local n = math.floor(rng:NextInteger(HC.boss.pumpkins[1], HC.boss.pumpkins[2]) * k)
	p.trophies += 1
	Halloween.AddPumpkins(player, n, pos)
	Remotes.Notify:FireClient(player, ("🏆 Pumpkin Colossus trophy #%d! +%d 🎃"):format(p.trophies, n), "Legendary")
	return n
end

-- ===== ГАЧА «ТЫКВЕННЫЙ КОТЁЛ» =====
local function rollRarity()
	local W = HC.gacha.weights
	local total = 0
	for _, key in ipairs(Config.RarityOrder) do
		total += W[key] or 0
	end
	local r = rng:NextInteger(1, total)
	for _, key in ipairs(Config.RarityOrder) do
		r -= W[key] or 0
		if r <= 0 then
			return key
		end
	end
	return "Uncommon"
end

local function rollOne(p)
	local rules = HC.gacha.pity
	for _, rule in ipairs(rules) do
		p.hpity[rule.rarity] = (p.hpity[rule.rarity] or 0) + 1
	end
	local rarity, byPity
	for _, rule in ipairs(rules) do
		if p.hpity[rule.rarity] >= rule.pulls then
			rarity, byPity = rule.rarity, true
			break
		end
	end
	rarity = rarity or rollRarity()
	local order = Config.Rarities[rarity].order
	for _, rule in ipairs(rules) do
		if order >= Config.Rarities[rule.rarity].order then
			p.hpity[rule.rarity] = 0
		end
	end
	local pool = Config.EventPool.halloween[rarity]
	return pool[rng:NextInteger(1, #pool)], rarity, byPity
end

function Halloween.InZone(player, extra)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - HC.zone.center).Magnitude <= HC.zone.radius + (extra or 12)
end

function Halloween.Pull(player, count)
	if not on() then
		return { ok = false, err = "The Halloween event is over" }
	end
	if count ~= 1 and count ~= 10 then
		return { ok = false, err = "Invalid number of pulls" }
	end
	local p = profile(player)
	if not p then
		return { ok = false, err = "Data is still loading..." }
	end
	if busy[player] then
		return { ok = false, err = "Wait..." }
	end
	if not Halloween.InZone(player) then
		return { ok = false, err = "You can only pull at the Pumpkin Cauldron in the Haunted Grove!" }
	end
	local cost = count == 10 and HC.gacha.pull10Cost or HC.gacha.pullCost
	if p.pumpkins < cost then
		return { ok = false, err = ("🎃 Not enough pumpkins! You need %d, you have %d"):format(cost, p.pumpkins) }
	end
	busy[player] = true
	p.pumpkins -= cost
	local results = {}
	for _ = 1, count do
		local def, rarity, byPity = rollOne(p)
		local isNew = not p.seen[def.id]
		Data.AddDrone(p, def.id)
		p.hpulls += 1
		table.insert(results, { id = def.id, rarity = rarity, new = isNew, pity = byPity })
	end
	busy[player] = nil
	Drones.Rebuild(player)
	Data.MarkDirty(player)
	for _, r in ipairs(results) do
		local rar = Config.Rarities[r.rarity]
		if rar.order >= 4 then
			local msg = ("🎃 %s pulled a %s Halloween drone “%s”!"):format(player.DisplayName, rar.label, Config.DroneById[r.id].name)
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					Remotes.Notify:FireClient(other, msg, r.rarity)
				end
			end
		end
	end
	require(script.Parent.Quests).Event(player, "hpull", nil, count)
	return { ok = true, results = results, pumpkins = p.pumpkins }
end

-- ===== ВЕДЬМА: ОБМЕН И ШЛЯПА =====
local function nearWitch(player)
	local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
	local w = npcs and npcs:FindFirstChild("witch")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return w ~= nil and hrp ~= nil and (w:GetPivot().Position - hrp.Position).Magnitude < 26
end

function Halloween.Trade(player, offerId)
	if not on() then
		return { ok = false, err = "The Halloween event is over" }
	end
	local o = Halloween.OfferById[offerId]
	local p = profile(player)
	if not o or not p then
		return { ok = false, err = "Unknown offer" }
	end
	if not nearWitch(player) then
		return { ok = false, err = "Get closer to the Witch" }
	end
	if p.pumpkins < o.cost then
		return { ok = false, err = ("🎃 You need %d pumpkins"):format(o.cost) }
	end
	if o.items then
		for id, n in pairs(o.items) do
			if not Data.AddItem(player, id, n) then
				return { ok = false, err = "🎒 No room for finds in your backpack" }
			end
		end
	end
	p.pumpkins -= o.cost
	if o.gems then
		Data.AddGems(player, o.gems)
	end
	for id, n in pairs(o.consum or {}) do
		p.consum = p.consum or {}
		p.consum[id] = (p.consum[id] or 0) + n
	end
	Data.MarkDirty(player)
	return { ok = true, msg = "🧙 The Witch traded you: " .. o.name, pumpkins = p.pumpkins }
end

-- шляпа ведьмы (награда за финал квестов ведьмы): надевается на голову
local function applyHat(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local old = char:FindFirstChild("ZSS_WitchHat")
	if old then
		old:Destroy()
	end
	local p = profile(player)
	if not p or not p.cosmetics.witchhat or p.cosmetics.hatOff then
		return
	end
	local lib = meshLib()
	local tpl = lib and lib:FindFirstChild("WitchHat")
	if not tpl then
		return
	end
	-- шляпа по размеру головы: ширина полей ~2.6 ширины головы, сидит на макушке
	local hat = tpl:Clone()
	hat.Name = "ZSS_WitchHat"
	local k = head.Size.X * 2.4 / math.max(hat.Size.X, hat.Size.Z)
	hat.Size *= k
	weldTo(head, hat, CFrame.new(0, head.Size.Y * 0.5 + hat.Size.Y * 0.36, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	hat.Parent = char
end
Halloween.ApplyHat = applyHat

function Halloween.SetHat(player, wear)
	local p = profile(player)
	if not p or not p.cosmetics.witchhat then
		return { ok = false, err = "Finish the Witch's quests to earn the hat" }
	end
	p.cosmetics.hatOff = not wear
	Data.MarkDirty(player)
	applyHat(player)
	return { ok = true }
end

-- ===== ДАННЫЕ ДЛЯ КЛИЕНТА =====
function Halloween.Snapshot(p, snap)
	snap.pumpkins = p.pumpkins or 0
	snap.hpity = p.hpity or { Legendary = 0, Mythic = 0, Secret = 0 }
	snap.hpulls = p.hpulls or 0
	snap.trophies = p.trophies or 0
	snap.cosmetics = p.cosmetics or {}
end

function Halloween.Init(dataModule, fieldsModule, dronesModule)
	Data, Fields, Drones = dataModule, fieldsModule, dronesModule
	Loot = require(script.Parent.Loot)
	workspace:SetAttribute("ZSS_Halloween", on())
	if not on() then
		-- событие закончилось: декор, роща, ведьма и котёл убираются из мира
		local map = workspace:FindFirstChild("Map")
		if map then
			for _, path in ipairs({ { "HalloweenZone" }, { "Base", "HalloweenDecor" }, { "NPCs", "witch" } }) do
				local inst = map
				for _, n in ipairs(path) do
					inst = inst and inst:FindFirstChild(n)
				end
				if inst then
					inst:Destroy()
				end
			end
			-- всё, что роща убрала (мешки в проходе, сосны, бочка), возвращается на место:
			-- у каждой копии в бэкапе атрибут Into = путь родителя внутри Map ("Base/SpawnDecor/Wall")
			local backup = game:GetService("ServerStorage"):FindFirstChild("ZSS_HalloweenBackup")
			if backup then
				for _, b in ipairs(backup:GetDescendants()) do
					local into = b:GetAttribute("Into")
					if into then
						local parent = map
						for n in string.gmatch(into, "[^/]+") do
							parent = parent and parent:FindFirstChild(n)
						end
						if parent then
							b:Clone().Parent = parent
						end
					end
				end
			end
		end
		return
	end
	for _, f in ipairs(Fields.List) do
		if not f.cfg.boss and #f.tiles > 0 then
			fillField(f)
		end
	end
end

return Halloween
