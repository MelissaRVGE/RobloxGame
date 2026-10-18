-- Квесты NPC: прогресс по событиям, принятие и сдача, награды
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Q = require(RS.ZSS.QuestsConfig)
local Items = require(RS.ZSS.ItemsConfig)
local Remotes = RS.ZSS.Remotes
local Data = require(script.Parent.Data)

local Quests = {}
Quests.OnPerk = nil -- вызывается после получения перка (пересчёт характеристик)

local function state(p, npcId)
	p.quests = p.quests or {}
	local s = p.quests[npcId]
	if not s then
		s = { stage = 1, active = false, prog = {}, v = Q.Version }
		p.quests[npcId] = s
	end
	s.prog = s.prog or {}
	-- цепочки поменялись: переводим номер задания на новую цепочку, прогресс текущего — с нуля
	if (s.v or 1) ~= Q.Version then
		local map = Q.ById[npcId] and Q.ById[npcId].migrate
		if map and (s.v or 1) == 1 then
			s.stage = map[math.clamp(s.stage, 1, #map)]
		end
		s.prog = {}
		s.v = Q.Version
	end
	return s
end

local function rOrder(r)
	return Config.Rarities[r] and Config.Rarities[r].order or 99
end

-- текущее значение цели (счётчики или состояние профиля)
local function goalValue(p, s, g, i)
	local t = g.t
	if t == "deliver" then
		return math.min(p.bag and p.bag[g.id] or 0, g.n)
	elseif t == "own" then
		for _, id in pairs(p.drones) do
			local d = Config.DroneById[id]
			if d and rOrder(d.rarity) >= rOrder(g.rarity) then
				return 1
			end
		end
		return 0
	elseif t == "swarm" then
		return math.min(#p.equipped, g.n)
	elseif t == "cells" then
		return math.min(p.dockSlots or Config.Hive.startCells, g.n)
	elseif t == "killTotal" then
		return math.min(p.kills or 0, g.n)
	end
	return math.min(s.prog[i] or 0, g.n)
end

function Quests.View(p)
	local out = {}
	for _, npc in ipairs(Q.NPCs) do
		local s = state(p, npc.id)
		local q = npc.quests[s.stage]
		local v = { stage = s.stage, total = #npc.quests, active = s.active and q ~= nil, done = q == nil }
		if q and s.active then
			v.goals = {}
			local all = true
			for i, g in ipairs(q.goals) do
				local cur = goalValue(p, s, g, i)
				v.goals[i] = cur
				if cur < g.n then
					all = false
				end
			end
			v.ready = all
		end
		out[npc.id] = v
	end
	return out
end

local function matches(g, data)
	data = data or {}
	if g.t == "kill" then
		return (not g.field or g.field == data.field) and (not g.night or data.night == true) and (not g.ghost or data.ghost == true)
	elseif g.t == "scrap" then
		return (not g.field or g.field == data.field) and (not g.res or g.res == data.res)
	elseif g.t == "use" then
		return g.id == data.id or (not g.id and not data.find)
	elseif g.t == "craft" then
		return not g.slot or g.slot == data.slot
	end
	return true
end

-- событие из игры (kill, scrap, convert, find, pull, use, craft, bagUp, pickup, charged, bossKill, bossDamage)
function Quests.Event(player, kind, data, amount)
	local p = Data.Get(player)
	if not p then
		return
	end
	local changed = false
	for _, npc in ipairs(Q.NPCs) do
		local s = state(p, npc.id)
		local q = s.active and npc.quests[s.stage]
		if q then
			for i, g in ipairs(q.goals) do
				if g.t == kind and matches(g, data) and (s.prog[i] or 0) < g.n then
					s.prog[i] = math.min(g.n, (s.prog[i] or 0) + (amount or 1))
					changed = true
				end
			end
		end
	end
	if changed then
		Data.MarkDirty(player)
	end
end

local function giveReward(player, p, r)
	if r.batteries then
		Data.AddBatteries(player, r.batteries)
	end
	if r.gems then
		Data.AddGems(player, r.gems)
	end
	-- находки для крафта; если в рюкзаке нет места, не влезшее продаётся за батареи
	local sold = 0
	for id, n in pairs(r.items or {}) do
		local had = p.bag and p.bag[id] or 0
		local lost = n
		if Data.AddItem(player, id, n) then
			lost = math.max(0, had + n - Items.StackMax)
		end
		if lost > 0 and Items.ById[id] then
			sold += Items.ById[id].value * lost
		end
	end
	if sold > 0 then
		Data.AddBatteries(player, sold)
	end
	for id, n in pairs(r.consum or {}) do
		p.consum = p.consum or {}
		p.consum[id] = (p.consum[id] or 0) + n
	end
	if r.pumpkins then
		p.pumpkins = (p.pumpkins or 0) + r.pumpkins
	end
	if r.cosmetic then
		p.cosmetics = p.cosmetics or {}
		p.cosmetics[r.cosmetic] = true
		if r.cosmetic == "witchhat" then
			task.defer(require(script.Parent.Halloween).ApplyHat, player)
		end
	end
	if r.perk then
		p.perks = p.perks or {}
		for k, v in pairs(r.perk) do
			p.perks[k] = (p.perks[k] or 0) + v
		end
		if Quests.OnPerk then
			Quests.OnPerk(player)
		end
	end
	return sold
end

local function nearNpc(player, npcId)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
	local npc = folder and folder:FindFirstChild(npcId)
	if not hrp or not npc then
		return false
	end
	return (npc:GetPivot().Position - hrp.Position).Magnitude < 22
end

function Quests.Action(player, npcId, action)
	local npc = Q.ById[npcId]
	local p = Data.Get(player)
	if not npc or not p then
		return { ok = false, err = "Unknown NPC" }
	end
	if not nearNpc(player, npcId) then
		return { ok = false, err = "Get closer to " .. npc.name }
	end
	local s = state(p, npcId)
	local q = npc.quests[s.stage]
	if not q then
		return { ok = false, err = "All quests complete!" }
	end
	if action == "accept" then
		if s.active then
			return { ok = false, err = "Quest already taken" }
		end
		s.active = true
		s.prog = {}
		Data.MarkDirty(player)
		return { ok = true, msg = "📜 New quest: " .. q.title }
	elseif action == "turnin" then
		if not s.active then
			return { ok = false, err = "Take the quest first" }
		end
		for i, g in ipairs(q.goals) do
			if goalValue(p, s, g, i) < g.n then
				return { ok = false, err = "Not done yet: " .. Q.GoalText(g, g.id and Items.ById[g.id] and Items.ById[g.id].name) }
			end
		end
		-- забираем принесённые предметы
		local take = {}
		for _, g in ipairs(q.goals) do
			if g.t == "deliver" then
				take[g.id] = (take[g.id] or 0) + g.n
			end
		end
		local ok = Data.HasMats(p, take)
		if not ok then
			return { ok = false, err = "Not enough items to hand in" }
		end
		Data.TakeMats(p, take)
		local sold = giveReward(player, p, q.reward)
		s.stage += 1
		s.active = false
		s.prog = {}
		Data.MarkDirty(player)
		Remotes.FX:FireAllClients("questdone", { owner = player.UserId, npc = npcId })
		local msg = "✔ Quest “" .. q.title .. "” complete!"
		if sold > 0 then
			msg ..= " Backpack full, some finds were sold for 🔋 " .. sold
		end
		return { ok = true, msg = msg, reward = q.reward, perkText = q.perkText }
	end
	return { ok = false, err = "bad action" }
end

function Quests.Init()
	Data.QuestView = Quests.View
end

return Quests
