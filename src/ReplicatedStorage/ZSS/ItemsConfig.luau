-- Предметы, которые случайно выпадают с мест добычи, зомби и босса. Хранятся в рюкзаке.
local C = Color3.fromRGB
local I = {}

I.Tiers = {
	Common = { order = 1, name = "Common", color = C(200, 200, 200), weight = 600 },
	Uncommon = { order = 2, name = "Uncommon", color = C(110, 220, 80), weight = 250 },
	Rare = { order = 3, name = "Rare", color = C(60, 150, 255), weight = 110 },
	Epic = { order = 4, name = "Epic", color = C(180, 80, 255), weight = 34 },
	Legendary = { order = 5, name = "Legendary", color = C(255, 190, 30), weight = 6 },
}
I.TierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- use: heal / speed / energy / gems (что делает при использовании); value — цена продажи в батареях
I.List = {
	{ id = "nut", name = "Rusty Nut", tier = "Common", value = 40, desc = "It once held up a bridge. Now it only holds rust." },
	{ id = "wire", name = "Copper Wire", tier = "Common", value = 60, desc = "A coil of copper, valuable for soldering drones." },
	{ id = "oldbattery", name = "Old Battery", tier = "Common", value = 50, desc = "Almost dead. Almost." },
	{ id = "cans", name = "Canned Food", tier = "Common", value = 70, use = { heal = 30 }, desc = "Canned stew from 2019. Restores 30 health." },
	{ id = "tooth", name = "Zombie Tooth", tier = "Common", value = 55, desc = "A trophy. Don't ask where it came from." },
	{ id = "cog", name = "Gear Wheel", tier = "Uncommon", value = 150, desc = "Perfect for repairing rotors." },
	{ id = "chip", name = "Microchip", tier = "Uncommon", value = 220, desc = "The brain of an old robot vacuum." },
	{ id = "energydrink", name = "Energy Drink", tier = "Uncommon", value = 180, use = { speed = 8, time = 30 }, desc = "+8 speed for 30 seconds." },
	{ id = "bandage", name = "Bandages", tier = "Uncommon", value = 160, use = { heal = 70 }, desc = "Restore 70 health." },
	{ id = "dogtag", name = "Survivor Tag", tier = "Uncommon", value = 260, desc = "The name is worn off. They fought to the end." },
	{ id = "dronecell", name = "Drone Battery Pack", tier = "Rare", value = 600, use = { energy = 0.35 }, desc = "Recharges the whole swarm by 35%." },
	{ id = "slime", name = "Mutant Slime", tier = "Rare", value = 700, desc = "It glows and wiggles a little. Scientists will pay for it." },
	{ id = "radcrystal", name = "Radioactive Crystal", tier = "Rare", value = 900, desc = "Warm to the touch. Better not keep it in your pocket." },
	{ id = "keycard", name = "Keycard", tier = "Rare", value = 1000, desc = "Level A access. Which door it opens is a mystery." },
	{ id = "gemshard", name = "Gem Shard", tier = "Rare", value = 400, use = { gems = 1 }, desc = "Use it to get 1 gem. Ten shards make one pull." },
	{ id = "blueprint", name = "Drone Blueprint", tier = "Epic", value = 2500, use = { gems = 2 }, desc = "Use it to get 2 gems." },
	{ id = "plutonium", name = "Plutonium Rod", tier = "Epic", value = 4000, use = { energy = 1 }, desc = "Fully charges the whole swarm." },
	{ id = "mutantheart", name = "Mutant Heart", tier = "Epic", value = 5000, use = { heal = 9999 }, desc = "Still beating. Fully restores health." },
	{ id = "goldbar", name = "Gold Bar", tier = "Legendary", value = 15000, desc = "From the vault of a fallen bank. Prized by quest givers and crafters." },
	-- капсулы дронов (аналог Королевского желе и яиц): бесплатная крутка гачи где угодно
	{ id = "capsule", name = "Firmware Capsule", tier = "Epic", value = 3000, w = 0.2, use = { pull = true }, desc = "Flashes a random drone from the gacha. Counts as a normal pull (with pity)." },
	{ id = "goldcapsule", name = "Gold Capsule", tier = "Legendary", value = 12000, w = 0.15, use = { pull = "Epic" }, desc = "A gacha drone of Epic rarity or higher." },
	{ id = "starcapsule", name = "Star Capsule", tier = "Legendary", value = 25000, w = 0.03, use = { pull = "Legendary" }, desc = "A gacha drone of Legendary rarity or higher. Shines even in daylight." },
	{ id = "omegacore", name = "Omega Core", tier = "Legendary", value = 30000, use = { gems = 5 }, desc = "The power source of a secret drone. Gives 5 gems, but the best items are crafted from it." },
}

I.ById = {}
for i, it in ipairs(I.List) do
	it.index = i
	I.ById[it.id] = it
end

-- ===== БАЛАНС ВЫПАДЕНИЯ =====
-- Выпадение чисто случайное: каждый сбор имеет независимый шанс, поэтому предмет может
-- выпасть дважды подряд — а может не выпадать очень долго.
I.DropChance = {
	droneGather = 0.003, -- за каждый сбор дроном
	weaponSwing = 0.03, -- за удар оружием по лому
	zombieKill = 0.12, -- за убийство зомби
	consumKill = 0.05, -- расходник из магазина за убийство зомби (как в BSS)
}
-- рюкзак находок безлимитный: любое число видов предметов, стаки без потолка

-- выбрать случайный предмет; fieldIndex сдвигает шансы к редким (дальние локации богаче)
function I.Roll(rng, fieldIndex, luck)
	local f = 1 + (fieldIndex or 1) * 0.35 + (luck or 0)
	local total = 0
	local w = {}
	for _, key in ipairs(I.TierOrder) do
		local t = I.Tiers[key]
		w[key] = t.order >= 3 and t.weight * f or t.weight
		total += w[key]
	end
	local r = rng:NextNumber() * total
	local tier = "Common"
	for _, key in ipairs(I.TierOrder) do
		r -= w[key]
		if r <= 0 then
			tier = key
			break
		end
	end
	-- внутри редкости у предмета свой вес w (по умолчанию 1): капсулы дронов выпадают реже
	local pool, sum = {}, 0
	for _, it in ipairs(I.List) do
		if it.tier == tier then
			table.insert(pool, it)
			sum += it.w or 1
		end
	end
	local x = rng:NextNumber() * sum
	for _, it in ipairs(pool) do
		x -= it.w or 1
		if x <= 0 then
			return it
		end
	end
	return pool[#pool]
end

return I
