-- Случайные предметы для рюкзака: выпадают с мест добычи, зомби и босса
local RS = game:GetService("ReplicatedStorage")
local Items = require(RS.ZSS.ItemsConfig)
local Buffs = require(RS.ZSS.BuffsConfig)
local Shop = require(RS.ZSS.ShopConfig)
local Remotes = RS.ZSS.Remotes
local Data = require(script.Parent.Data)

local Loot = {}
local rng = Random.new()
local lastFullWarn = {}

function Loot.IsNight()
	return workspace:GetAttribute("ZSS_Night") == true
end

-- выдать конкретный предмет с уведомлением и эффектом
function Loot.Give(player, item, pos)
	if Data.AddItem(player, item.id, 1) then
		Remotes.FX:FireClient(player, "itemdrop", { id = item.id, pos = pos })
		require(script.Parent.Quests).Event(player, "find")
		return true
	end
	local now = os.clock()
	if not lastFullWarn[player] or now - lastFullWarn[player] > 20 then
		lastFullWarn[player] = now
		Remotes.Notify:FireClient(player, "🎒 No room in your backpack for the find “" .. item.name .. "”.", "bad")
	end
	return false
end

-- честный бросок: chance за событие (ночью x2). Периодичности нет — может выпасть
-- два раза подряд или не выпасть очень долго.
function Loot.TryDrop(player, kind, fieldIndex, pos)
	local chance = Items.DropChance[kind] or 0
	if Loot.IsNight() then
		chance *= 2
	end
	-- перк удачи за финал цепочки Профессора
	local p = Data.Get(player)
	if p and p.perks and p.perks.luck then
		chance *= 1 + p.perks.luck
	end
	-- бафф «Удача»
	chance *= Buffs.Mult(player, "luck") * (player:GetAttribute("ZSS_Luck") or 1)
	if rng:NextNumber() >= chance then
		return nil
	end
	local item = Items.Roll(rng, fieldIndex, Loot.IsNight() and 0.5 or 0)
	if pos then
		-- находка падает ящичком на землю — её нужно подобрать
		require(script.Parent.Drops).SpawnItem(player, item, pos)
	else
		Loot.Give(player, item, pos)
	end
	return item
end

-- несколько предметов с повышенной удачей (босс)
function Loot.Many(player, count, luck, pos)
	local got = {}
	for _ = 1, count do
		local item = Items.Roll(rng, 6, luck)
		if Loot.Give(player, item, pos) then
			table.insert(got, item)
		end
	end
	return got
end

-- расходники с зомби: на ранних полях — дешёвые, дальше и с босса — всё дороже и реже
local CONSUM_CAP = { 2500, 6000, 20000, 45000, 250000 }

function Loot.RollConsum(fieldIndex, luck)
	local cap = (CONSUM_CAP[fieldIndex or 1] or math.huge) * (1 + (luck or 0))
	local pool, total = {}, 0
	for _, it in ipairs(Shop.Items) do
		if it.slot == "consumable" and it.use and it.price <= cap then
			local w = it.price ^ -0.6
			table.insert(pool, { it, w })
			total += w
		end
	end
	local r = rng:NextNumber() * total
	for _, e in ipairs(pool) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return pool[#pool][1]
end

-- расходник падает ящичком на землю (как находка), подбирается касанием
local function spawnConsum(player, it, pos)
	local drop = { id = it.id, name = it.name, tier = Items.TierOrder[math.clamp(it.grade, 1, #Items.TierOrder)], consum = true }
	require(script.Parent.Drops).SpawnItem(player, drop, pos)
end

function Loot.TryConsum(player, fieldIndex, pos)
	local chance = Items.DropChance.consumKill or 0
	if Loot.IsNight() then
		chance *= 2
	end
	chance *= Buffs.Mult(player, "luck") * (player:GetAttribute("ZSS_Luck") or 1)
	if rng:NextNumber() >= chance then
		return nil
	end
	local it = Loot.RollConsum(fieldIndex, 0)
	spawnConsum(player, it, pos)
	return it
end

-- босс: несколько расходников без ограничения по цене
function Loot.ManyConsum(player, count, pos)
	for _ = 1, count do
		spawnConsum(player, Loot.RollConsum(6, 0), pos)
	end
end

return Loot
