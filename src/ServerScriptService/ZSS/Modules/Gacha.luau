-- Гача: шансы, гарант (pity), выдача дронов. Всё считается только на сервере.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes

local Gacha = {}
local Data, Drones
local rng = Random.new()
local busy = {}

local function rollRarity()
	local r = rng:NextInteger(1, Config.WeightTotal)
	local acc = 0
	for _, key in ipairs(Config.RarityOrder) do
		acc += Config.Rarities[key].weight
		if r <= acc then
			return key
		end
	end
	return "Uncommon"
end

-- Одна крутка. Счётчики гаранта растут на 1; если какой-то достиг порога — выдаётся самая высокая из сработавших.
-- Выпадение редкости сбрасывает счётчики этой редкости и всех более низких (гарант «эта редкость или выше»).
function Gacha.RollOne(p)
	for _, rule in ipairs(Config.Pity) do
		p.pity[rule.rarity] += 1
	end
	local rarity, byPity = nil, false
	for _, rule in ipairs(Config.Pity) do -- порядок: Secret, Mythic, Legendary
		if p.pity[rule.rarity] >= rule.pulls then
			rarity, byPity = rule.rarity, true
			break
		end
	end
	if not rarity then
		rarity = rollRarity()
	end
	local order = Config.Rarities[rarity].order
	for _, rule in ipairs(Config.Pity) do
		if order >= Config.Rarities[rule.rarity].order then
			p.pity[rule.rarity] = 0
		end
	end
	local pool = Config.DronesByRarity[rarity]
	return pool[rng:NextInteger(1, #pool)], rarity, byPity
end

-- капсула дрона (находка): одна крутка где угодно. minRarity = нижняя граница редкости
-- (такие капсулы гарант не трогают); без неё — обычная крутка с гарантом.
function Gacha.Capsule(player, minRarity)
	local p = Data.Get(player)
	if not p then
		return nil
	end
	local def, rarity
	if minRarity and Config.Rarities[minRarity] then
		rarity = rollRarity()
		if Config.Rarities[rarity].order < Config.Rarities[minRarity].order then
			rarity = minRarity
		end
		local pool = Config.DronesByRarity[rarity]
		def = pool[rng:NextInteger(1, #pool)]
	else
		def, rarity = Gacha.RollOne(p)
		p.totalPulls += 1
	end
	local isNew = not p.seen[def.id]
	Data.AddDrone(p, def.id)
	Drones.Rebuild(player)
	Data.MarkDirty(player)
	local rar = Config.Rarities[rarity]
	Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = rar.color, duration = 2.5, rainbow = rar.rainbow })
	if rar.order >= 4 then
		local msg = ("✨ %s opened a capsule: %s drone “%s”!"):format(player.DisplayName, rar.label, def.name)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				Remotes.Notify:FireClient(other, msg, rarity)
			end
		end
	end
	return def, rarity, isNew
end

function Gacha.Pull(player, count)
	if count ~= 1 and count ~= 10 then
		return { ok = false, err = "Invalid number of pulls" }
	end
	local p = Data.Get(player)
	if not p then
		return { ok = false, err = "Data is still loading..." }
	end
	if busy[player] then
		return { ok = false, err = "Wait..." }
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Config.GachaZone.center).Magnitude > Config.GachaZone.radius + 10 then
		return { ok = false, err = "You can only pull the gacha in the Drone Lab!" }
	end
	local cost = count == 10 and Config.Pull10Cost or Config.PullCost
	if (p.gems or 0) < cost then
		return { ok = false, err = ("💎 Not enough gems! You need %d, you have %d"):format(cost, p.gems or 0) }
	end

	busy[player] = true
	p.gems -= cost
	local results = {}
	for _ = 1, count do
		local def, rarity, byPity = Gacha.RollOne(p)
		local isNew = not p.seen[def.id]
		Data.AddDrone(p, def.id)
		p.totalPulls += 1
		table.insert(results, { id = def.id, rarity = rarity, new = isNew, pity = byPity })
	end
	busy[player] = nil

	Drones.Rebuild(player)
	Data.MarkDirty(player)

	-- объявление для других игроков о редких дронах
	for _, r in ipairs(results) do
		local rar = Config.Rarities[r.rarity]
		if rar.order >= 4 then
			local msg = ("✨ %s pulled a %s drone “%s”!"):format(player.DisplayName, rar.label, Config.DroneById[r.id].name)
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					Remotes.Notify:FireClient(other, msg, r.rarity)
				end
			end
		end
	end

	return { ok = true, results = results, pity = p.pity, gems = p.gems, totalPulls = p.totalPulls }
end

-- обмен батарей на гемы (в Лаборатории)
function Gacha.BuyGems(player, index)
	local p = Data.Get(player)
	local pack = Config.GemPacks[index]
	if not p or not pack then
		return { ok = false, err = "bad" }
	end
	if p.batteries < pack.cost then
		return { ok = false, err = ("🔋 You need %d batteries"):format(pack.cost) }
	end
	p.batteries -= pack.cost
	p.gems = (p.gems or 0) + pack.gems
	Data.MarkDirty(player)
	return { ok = true, gems = pack.gems }
end

function Gacha.Init(dataModule, dronesModule)
	Data, Drones = dataModule, dronesModule
end

return Gacha
