-- Магазин: оружие (бить зомби), инструменты (добывать ресурсы) и снаряжение
local C = Color3.fromRGB
local S = {}

S.Slots = {
	{ key = "weapon", name = "Weapons", icon = "⚔" },
	{ key = "tool", name = "Tools", icon = "⛏" },
	{ key = "armor", name = "Armor", icon = "🛡" },
	{ key = "helmet", name = "Helmets", icon = "⛑" },
	{ key = "gloves", name = "Gloves", icon = "🧤" },
	{ key = "boots", name = "Boots", icon = "🥾" },
	{ key = "backpack", name = "Backpacks", icon = "🎒" },
	{ key = "consumable", name = "Consumables", icon = "🧪" },
}

-- хотбар: ячейка 1 — оружие, ячейка 2 — инструмент (с собой только по одному),
-- дальше свободные ячейки под любой используемый предмет (см. ZSS/Hotbar)
S.HotbarWeapons = 2
S.HotbarOrder = { "weapon", "tool" }

-- грейд предмета (цвет рамки)
S.Grades = {
	[1] = { name = "Common", color = C(200, 200, 200) },
	[2] = { name = "Sturdy", color = C(110, 220, 80) },
	[3] = { name = "Military", color = C(60, 150, 255) },
	[4] = { name = "Elite", color = C(180, 80, 255) },
	[5] = { name = "Prototype", color = C(255, 190, 30) },
	[6] = { name = "Relic", color = C(255, 70, 110) },
	[7] = { name = "Absolute", color = C(70, 255, 230) },
}

S.DefaultWeapon = "shiv"
S.DefaultTool = "scraper"
S.DefaultBackpack = "bp_old"

S.Items = {
	-- ===== ОРУЖИЕ (только урон по зомби) =====
	{ id = "shiv", slot = "weapon", name = "Shiv", price = 0, grade = 1,
		desc = "A homemade knife made of rebar and electrical tape. Better than nothing.",
		stats = { dmg = 7, radius = 4.5, cd = 0.4, fx = "none" } },
	{ id = "pipe", slot = "weapon", name = "Rusty Pipe", price = 3000, grade = 1,
		desc = "A length of plumbing wrapped in tape. An apocalypse classic.",
		stats = { dmg = 12, radius = 5, cd = 0.45, fx = "none" } },
	{ id = "bat", slot = "weapon", name = "Nail Bat", price = 8200, grade = 2,
		desc = "A wooden bat studded with nails and barbed wire.",
		stats = { dmg = 20, radius = 5.5, cd = 0.45, fx = "none" } },
	{ id = "machete", slot = "weapon", name = "Machete", price = 23000, grade = 2,
		desc = "A broad blade for the jungle, and for zombies.",
		stats = { dmg = 32, radius = 6, cd = 0.4, fx = "none" } },
	{ id = "fireaxe", slot = "weapon", name = "Fire Axe", price = 62000, grade = 3,
		desc = "A red axe from a fire station board. Sets zombies on fire.",
		stats = { dmg = 52, radius = 6.5, cd = 0.45, fx = "fire" } },
	{ id = "sledge", slot = "weapon", name = "Sledgehammer", price = 170000, grade = 3,
		desc = "A heavy sledgehammer. Every hit is a shockwave.",
		stats = { dmg = 90, radius = 8, cd = 0.6, fx = "shock" } },
	{ id = "chainsaw", slot = "weapon", name = "Chainsaw", price = 470000, grade = 4,
		desc = "A roaring chainsaw. Very fast hits.",
		stats = { dmg = 85, radius = 7, cd = 0.25, fx = "sparks" } },
	{ id = "baton", slot = "weapon", name = "Shock Baton", price = 1300000, grade = 4,
		desc = "A shock baton with a coil. Strikes everyone nearby with lightning.",
		stats = { dmg = 180, radius = 9, cd = 0.4, fx = "zap" } },
	{ id = "scythe", slot = "weapon", name = "Plasma Scythe", price = 3600000, grade = 5,
		desc = "A prototype with a plasma blade. Cuts everything in a wide radius.",
		stats = { dmg = 310, radius = 11, cd = 0.35, fx = "plasma" } },

	-- ===== ИНСТРУМЕНТЫ (только добыча ресурсов с полей) =====
	{ id = "scraper", slot = "tool", name = "Scraper", price = 0, grade = 1,
		desc = "The starter scraper shovel. Rakes up everything lying on the field.",
		stats = { gather = 2, radius = 4.5, cd = 0.45, fx = "none" } },
	{ id = "shovel", slot = "tool", name = "Entrenching Shovel", price = 1500, grade = 1,
		desc = "A short army shovel. Scoops up one and a half times more.",
		stats = { gather = 3, radius = 4.75, cd = 0.45, fx = "none" } },
	{ id = "pickaxe", slot = "tool", name = "Pickaxe", price = 4400, grade = 2,
		desc = "A steel pickaxe. Breaks up packed piles.",
		stats = { gather = 4, radius = 5, cd = 0.44, fx = "none" } },
	{ id = "magrake", slot = "tool", name = "Magnetic Rake", price = 13000, grade = 3,
		desc = "A rake with magnets. Small parts stick on their own.",
		stats = { gather = 5, radius = 5.25, cd = 0.43, fx = "sparks" } },
	{ id = "jackhammer", slot = "tool", name = "Jackhammer", price = 37000, grade = 3,
		desc = "Splits whole piles apart. Every hit is a shockwave.",
		stats = { gather = 6, radius = 5.5, cd = 0.42, fx = "shock" } },
	{ id = "vacuum", slot = "tool", name = "Scrap Vacuum", price = 110000, grade = 4,
		desc = "A backpack cyclone vacuum. Sucks up everything around.",
		stats = { gather = 7, radius = 5.75, cd = 0.41, fx = "zap" } },
	{ id = "plasmacutter", slot = "tool", name = "Plasma Cutter", price = 310000, grade = 5,
		desc = "An industrial cutter that melts scrap straight into ingots.",
		stats = { gather = 8, radius = 6, cd = 0.4, fx = "plasma" } },

	-- ===== БРОНЯ =====
	{ id = "armor1", slot = "armor", name = "Burlap Jacket", price = 1200, grade = 1, tier = 1,
		desc = "Stitched from old sacks. At least it's some protection.", stats = { hp = 20, def = 0.05 } },
	{ id = "armor2", slot = "armor", name = "Leather Vest", price = 3400, grade = 2, tier = 2,
		desc = "Thick leather with straps and rivets.", stats = { hp = 40, def = 0.1 } },
	{ id = "armor3", slot = "armor", name = "Bulletproof Vest", price = 9400, grade = 3, tier = 3,
		desc = "A Kevlar vest with plates and pouches.", stats = { hp = 75, def = 0.18 } },
	{ id = "armor4", slot = "armor", name = "Tactical Armor", price = 26000, grade = 4, tier = 4,
		desc = "An army kit with camo shoulder pads.", stats = { hp = 120, def = 0.25 } },
	{ id = "armor5", slot = "armor", name = "Titan Exoskeleton", price = 74000, grade = 5, tier = 5,
		desc = "A powered frame with a reactor on the back.", stats = { hp = 200, def = 0.35 } },

	-- ===== ШЛЕМЫ =====
	{ id = "helmet1", slot = "helmet", name = "Hard Hat", price = 1000, grade = 1, tier = 1,
		desc = "A yellow hard hat with a flashlight.", stats = { hp = 10, def = 0.03 } },
	{ id = "helmet2", slot = "helmet", name = "Motorcycle Helmet", price = 2800, grade = 2, tier = 2,
		desc = "A full-face helmet with a tinted visor.", stats = { hp = 20, def = 0.06 } },
	{ id = "helmet3", slot = "helmet", name = "Combat Helmet", price = 7800, grade = 3, tier = 3,
		desc = "A camo helmet with night-vision goggles.", stats = { hp = 35, def = 0.09 } },
	{ id = "helmet4", slot = "helmet", name = "Gas Mask Helmet", price = 22000, grade = 4, tier = 4,
		desc = "Protects against radiation and toxins. Two filters.", stats = { hp = 55, def = 0.12 } },
	{ id = "helmet5", slot = "helmet", name = "Reaper Helmet", price = 61000, grade = 5, tier = 5,
		desc = "A black horned helmet with a crimson visor. Zombies fear it.", stats = { hp = 80, def = 0.16 } },

	-- ===== ПЕРЧАТКИ =====
	{ id = "gloves1", slot = "gloves", name = "Work Gloves", price = 1100, grade = 1, tier = 1,
		desc = "Cotton gloves. Makes picking up scrap easier.", stats = { scrap = 0.10 } },
	{ id = "gloves2", slot = "gloves", name = "Leather Gloves", price = 3100, grade = 2, tier = 2,
		desc = "Tough leather that won't tear on shards.", stats = { scrap = 0.20 } },
	{ id = "gloves3", slot = "gloves", name = "Tactical Gloves", price = 8600, grade = 3, tier = 3,
		desc = "With protective knuckle pads.", stats = { scrap = 0.35 } },
	{ id = "gloves4", slot = "gloves", name = "Manipulator Gloves", price = 24000, grade = 4, tier = 4,
		desc = "Mechanical fingers with servo motors.", stats = { scrap = 0.55 } },
	{ id = "gloves5", slot = "gloves", name = "Tesla Power Gloves", price = 68000, grade = 5, tier = 5,
		desc = "Electromagnetic gloves. Scrap sticks to them on its own.", stats = { scrap = 0.80 } },

	-- ===== БОТИНКИ =====
	{ id = "boots1", slot = "boots", name = "Sneakers", price = 800, grade = 1, tier = 1,
		desc = "Old sneakers. At least you can run in them.", stats = { speed = 2, jump = 0 } },
	{ id = "boots2", slot = "boots", name = "Army Boots", price = 2200, grade = 2, tier = 2,
		desc = "Lace-up leather army boots.", stats = { speed = 4, jump = 0 } },
	{ id = "boots3", slot = "boots", name = "Runner's Shoes", price = 6300, grade = 3, tier = 3,
		desc = "Light and springy. Perfect for running from zombies.", stats = { speed = 6, jump = 3 } },
	{ id = "boots4", slot = "boots", name = "Swift Boots", price = 18000, grade = 4, tier = 4,
		desc = "Armored boots with shock absorbers.", stats = { speed = 9, jump = 5 } },
	{ id = "boots5", slot = "boots", name = "Jet Boots", price = 49000, grade = 5, tier = 5,
		desc = "Mini engines in the soles. Very fast and very high.", stats = { speed = 13, jump = 9 } },

	-- ===== РАСХОДНИКИ (складываются, используются из хотбара) =====
	{ id = "medkit", slot = "consumable", name = "Medkit", price = 500, grade = 2, icon = "medkit", stack = true,
		desc = "Instantly restores 60 health.", stats = { heal = 60 } },
	{ id = "energycell", slot = "consumable", name = "Energy Cell", price = 3000, grade = 3, icon = "energycell", stack = true,
		desc = "Recharges the whole swarm by 50% right in the field.", stats = { energy = 0.5 } },
	{ id = "grenade", slot = "consumable", name = "Grenade", price = 1000, grade = 3, icon = "grenade", stack = true,
		desc = "An explosion within 14 studs: 350 damage to all zombies.", stats = { dmg = 350, radius = 14 } },
	{ id = "adrenaline", slot = "consumable", name = "Adrenaline", price = 800, grade = 3, icon = "adrenaline", stack = true,
		desc = "An adrenaline shot: +4 stacks of the Speed Boost buff (up to x1.5 speed).", stats = { stacks = 4 } },

	-- ===== НОВОЕ ОРУЖИЕ (высокие уровни) =====
	{ id = "spear", slot = "weapon", name = "Harpoon Spear", price = 9800000, grade = 5,
		desc = "A titanium shaft and a barbed Damascus tip.", stats = { dmg = 380, radius = 12, cd = 0.38, fx = "none" } },
	{ id = "katana", slot = "weapon", name = "Ronin Katana", price = 27000000, grade = 5,
		desc = "A Damascus steel blade with a golden guard. Very fast hits.", stats = { dmg = 470, radius = 11, cd = 0.28, fx = "sparks" } },
	{ id = "bonecleaver", slot = "weapon", name = "Bone Cleaver", price = 74000000, grade = 6,
		desc = "Carved from mutant bone. The serrated edge tears things apart.", stats = { dmg = 600, radius = 11.5, cd = 0.4, fx = "none" } },
	{ id = "lavaaxe", slot = "weapon", name = "Magma Axe", price = 200000000, grade = 6,
		desc = "A blade of cooled lava. Fire still smolders inside.", stats = { dmg = 800, radius = 12, cd = 0.45, fx = "fire" } },
	{ id = "thunderhammer", slot = "weapon", name = "Thunderer Hammer", price = 560000000, grade = 6,
		desc = "Titanium and engraved gold. Every hit is a lightning strike.", stats = { dmg = 1100, radius = 13, cd = 0.55, fx = "zap" } },
	{ id = "crystalblade", slot = "weapon", name = "Crystal Sword", price = 1500000000, grade = 6,
		desc = "Grown from a radioactive crystal. It glows and rings.", stats = { dmg = 1400, radius = 12.5, cd = 0.35, fx = "sparks" } },
	{ id = "dragonglaive", slot = "weapon", name = "Dragon Glaive", price = 4200000000, grade = 7,
		desc = "A shaft in dragon scales with a curved blade that breathes fire.", stats = { dmg = 2000, radius = 14, cd = 0.4, fx = "fire" } },
	{ id = "obsidianscythe", slot = "weapon", name = "Obsidian Scythe", price = 12000000000, grade = 7,
		desc = "Black volcanic glass with purple veins of energy.", stats = { dmg = 2800, radius = 15, cd = 0.38, fx = "plasma" } },
	{ id = "gravhammer", slot = "weapon", name = "Gravity Hammer", price = 32000000000, grade = 7,
		desc = "Warps space around each hit. Zombies get flattened.", stats = { dmg = 4000, radius = 16, cd = 0.5, fx = "shock" } },
	{ id = "omegasaber", slot = "weapon", name = "Omega Saber", price = 88000000000, grade = 7,
		desc = "A blade of pure energy. The peak of weapons science.", stats = { dmg = 6000, radius = 16, cd = 0.25, fx = "plasma" } },

	-- ===== НОВЫЕ ИНСТРУМЕНТЫ =====
	{ id = "drillgun", slot = "tool", name = "Hand Drill", price = 890000, grade = 5,
		desc = "A cordless drill with a titanium spiral bit.", stats = { gather = 10, radius = 6.25, cd = 0.39, fx = "sparks" } },
	{ id = "harvester", slot = "tool", name = "Rotor Reaper", price = 2600000, grade = 5,
		desc = "A spinning bladed drum that grinds up whole piles.", stats = { gather = 12, radius = 6.5, cd = 0.38, fx = "none" } },
	{ id = "magnetcannon", slot = "tool", name = "Magnet Cannon", price = 7500000, grade = 6,
		desc = "An electromagnet that pulls metal from dozens of feet away.", stats = { gather = 14, radius = 6.75, cd = 0.38, fx = "zap" } },
	{ id = "excavator", slot = "tool", name = "Hydraulic Bucket", price = 22000000, grade = 6,
		desc = "A hydraulic mini excavator bucket. Scoops by the ton.", stats = { gather = 16, radius = 7, cd = 0.37, fx = "shock" } },
	{ id = "laserdrill", slot = "tool", name = "Laser Drill", price = 63000000, grade = 6,
		desc = "Cuts piles with a beam and fuses the resources into bricks.", stats = { gather = 18, radius = 7.2, cd = 0.36, fx = "plasma" } },
	{ id = "cryoextractor", slot = "tool", name = "Cryo Extractor", price = 180000000, grade = 6,
		desc = "Freezes a pile and shatters it into clean parts.", stats = { gather = 20, radius = 7.4, cd = 0.36, fx = "sparks" } },
	{ id = "gravitywell", slot = "tool", name = "Gravity Funnel", price = 530000000, grade = 7,
		desc = "A miniature black hole that sucks in everything around.", stats = { gather = 22, radius = 7.6, cd = 0.35, fx = "zap" } },
	{ id = "lavaforge", slot = "tool", name = "Magma Smelter", price = 1500000000, grade = 7,
		desc = "Melts scrap right in your hands. Hot!", stats = { gather = 25, radius = 7.8, cd = 0.34, fx = "fire" } },
	{ id = "nanoswarm", slot = "tool", name = "Nano Collector", price = 4500000000, grade = 7,
		desc = "A swarm of nanobots takes scrap apart atom by atom.", stats = { gather = 27, radius = 7.9, cd = 0.34, fx = "zap" } },
	{ id = "singularity", slot = "tool", name = "Singularity Collector", price = 13000000000, grade = 7,
		desc = "Golden rings hold a singularity in place. Collects everything.", stats = { gather = 30, radius = 8, cd = 0.33, fx = "plasma" } },
}

-- ===== НОВОЕ СНАРЯЖЕНИЕ: уровни 6–15 =====
local GEAR_NEW = {
	armor = {
		{ "Bastion Plate Armor", "Overlapping titanium plates and massive pauldrons." },
		{ "Dragon Scale Armor", "Red scales with gold trim and spikes." },
		{ "Bone Carapace", "Mutant ribs and a skull on leather straps." },
		{ "Hive Hazmat Suit", "A sealed suit with antidote tanks." },
		{ "Crystal Armor", "Radioactive crystals have grown right through the armor." },
		{ "Magma Armor", "Red-hot stone with lava in the cracks." },
		{ "Obsidian Armor", "Black glass and purple veins of energy." },
		{ "Ghost Nanosuit", "The circuits on the armor glow and rearrange themselves." },
		{ "Royal Armor", "Engraved gold, a ruby, and a crimson cape." },
		{ "Omega Exoskeleton", "A chest reactor and energy wings." },
	},
	helmet = {
		{ "Bastion Helmet", "A closed titanium helmet with a visor slit." },
		{ "Dragon Helmet", "Horns and scales, with eyes of fire." },
		{ "Chieftain Skull", "A fanged skull. Zombies think you're one of them." },
		{ "Hazmat Helmet", "Panoramic glass and a double filter." },
		{ "Crystal Crown", "Shining crystals above the brow." },
		{ "Magma Helmet", "Smoldering stone with a fiery slit." },
		{ "Obsidian Mask", "A smooth black mask with purple eyes." },
		{ "Ghost Nano Helmet", "A one-piece augmented reality visor." },
		{ "Crown of the Wastes", "A golden crown with rubies." },
		{ "Omega Helmet", "A force field and a halo of pure energy." },
	},
	gloves = {
		{ "Titanium Gauntlets", "Steel fingers scoop scrap like a bucket." },
		{ "Dragon Claws", "Scaled gloves with golden claws." },
		{ "Bone Bracers", "Mutant finger bones on straps." },
		{ "Hazmat Gloves", "Rubber that protects against any slime." },
		{ "Crystal Gloves", "The crystals attract valuable parts." },
		{ "Lava Fists", "Melt scrap on touch." },
		{ "Obsidian Gauntlets", "Heavy and indestructible." },
		{ "Nano Gloves", "Nanobots sort scrap right in your palm." },
		{ "Royal Gloves", "Gold and rubies that pull in valuables on their own." },
		{ "Omega Gloves", "A gravity grip for any resource." },
	},
	boots = {
		{ "Titanium Sabatons", "Light titanium with springs in the heel." },
		{ "Dragon Boots", "Scales and a trail of fire." },
		{ "Bone Greaves", "They tread silently, like a predator." },
		{ "Hazmat Boots", "Cushioned rubber for long jumps." },
		{ "Crystal Boots", "They push off the ground like springs." },
		{ "Lava Walkers", "They leave smoldering footprints." },
		{ "Obsidian Boots", "Dark power speeds up every step." },
		{ "Nano Boots", "The soles adapt to any surface." },
		{ "Royal Boots", "Golden spurs and rubies." },
		{ "Omega Gravity Boots", "Anti-gravity: almost like flying." },
	},
}
local GEAR_PRICE = { 170000, 480000, 1300000, 3800000, 11000000, 30000000, 83000000, 230000000, 650000000, 1800000000 }
local GEAR_SLOT_MULT = { armor = 1.2, helmet = 1.0, gloves = 1.1, boots = 0.8 }
local GEAR_GRADE = { 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 }
local GEAR_STATS = {
	armor = function(k) return { hp = 260 + k * 120 + k * k * 20, def = 0.36 + k * 0.022 } end,
	helmet = function(k) return { hp = 100 + k * 50 + k * k * 8, def = 0.17 + k * 0.012 } end,
	gloves = function(k) return { scrap = 0.8 + k * 0.3 } end,
	boots = function(k) return { speed = 13 + math.floor(k * 1.5), jump = 9 + k } end,
}
for _, slot in ipairs({ "armor", "helmet", "gloves", "boots" }) do
	for k, nd in ipairs(GEAR_NEW[slot]) do
		table.insert(S.Items, {
			id = slot .. (5 + k),
			slot = slot,
			name = nd[1],
			desc = nd[2],
			price = math.floor(GEAR_PRICE[k] * GEAR_SLOT_MULT[slot] / 10 + 0.5) * 10,
			grade = GEAR_GRADE[k],
			tier = 5 + k,
			stats = GEAR_STATS[slot](k),
		})
	end
end

-- ===== РЮКЗАКИ (видны на спине) =====
-- cap — бонус к вместимости (умножает вместимость уровня рюкзака: x(1 + cap)); каждый следующий
-- рюкзак вмещает примерно в 1.3 раза больше предыдущего, чтобы покупка новой модели ощущалась, conv — больше батарей
-- за переработку, cspeed — быстрее работает Переработчик. Бонус переработки есть не у всех.
local BACKPACKS = {
	{ "bp_old", "School Backpack", 0, 1, { cap = 0 }, "A worn backpack with a keychain. Better than nothing." },
	{ "bp_sack", "Canvas Duffel", 2500, 1, { cap = 0.35 }, "A sack on a rope. Holds a little more scrap." },
	{ "bp_denim", "Denim Backpack", 7200, 2, { cap = 0.8, conv = 0.05 }, "Sewn from old jeans and covered in patches. Lucky: recycling pays more." },
	{ "bp_hiker", "Hiking Backpack", 21000, 2, { cap = 1.4 }, "A frame pack with a sleeping bag and a canteen." },
	{ "bp_scrapper", "Recycler's Bag", 61000, 3, { cap = 2.1, conv = 0.12, cspeed = 0.25 }, "A built-in sorter: scrap recycles faster and for more." },
	{ "bp_raid", "Army Raid Pack", 180000, 3, { cap = 3 }, "Camo and a pile of pouches for maximum space." },
	{ "bp_tactical", "Tactical MOLLE Pack", 510000, 4, { cap = 4.2, cspeed = 0.15 }, "MOLLE webbing, a radio, and quick unloading." },
	{ "bp_hazmat", "Isotope Chem Container", 1500000, 4, { cap = 5.8, conv = 0.2 }, "A tank of neutralizer that dissolves scrap into pure energy." },
	{ "bp_reactor", "Mini Reactor Pack", 4300000, 5, { cap = 7.8, conv = 0.15, cspeed = 0.4 }, "The reactor charges batteries right on your back." },
	{ "bp_bone", "Bone Crate", 13000000, 5, { cap = 10.5 }, "Mutant hide stretched over a monster's ribs. Huge and creepy." },
	{ "bp_dragon", "Dragon Pack", 36000000, 6, { cap = 14, conv = 0.3 }, "Scales, gold, and folded wings. Smolders from within." },
	{ "bp_crystal", "Crystal Pack", 110000000, 6, { cap = 18.5, cspeed = 0.6 }, "Radioactive crystals hum and speed up recycling." },
	{ "bp_magma", "Magma Smelter", 310000000, 6, { cap = 24, conv = 0.45, cspeed = 0.5 }, "Melts scrap on the go. Fire pours out of the pipe." },
	{ "bp_obsidian", "Obsidian Chest", 880000000, 7, { cap = 32 }, "Black glass with purple runes. Bigger on the inside." },
	{ "bp_nano", "Ghost Nano Pack", 2600000000, 7, { cap = 42, conv = 0.6, cspeed = 0.8 }, "Nanobots sort the scrap while a hologram counts batteries." },
	{ "bp_royal", "Royal Chest", 7400000000, 7, { cap = 55 }, "Engraved gold, rubies, and velvet. Fit for the king of the wastes." },
	{ "bp_omega", "Omega Dimensional Pack", 22000000000, 7, { cap = 71, conv = 0.8, cspeed = 1.2 }, "A portal to a pocket dimension and energy wings." },
}
for k, b in ipairs(BACKPACKS) do
	table.insert(S.Items, { id = b[1], slot = "backpack", name = b[2], price = b[3], grade = b[4], stats = b[5], desc = b[6], tier = k })
end

-- ===== НОВЫЕ РАСХОДНИКИ (аналоги предметов Bee Swarm Simulator, свои под пустошь) =====
-- use — что делает предмет (см. Equipment.Use):
--   buffs = { id = ступени } — ступени баффов (BuffsConfig), heal = N или "full", energy = доля заряда роя,
--   home — телепорт к улью, gold = { r, t } — плитки вокруг золотые (x5), goldAll = t — всё поле золотое,
--   refill — кучи поля снова полные, orbs = { n, cat } — сферы баффов рядом, minis = { n, t } — мини-дроны,
--   convert — весь рюкзак сразу в батареи, bomb = { r, mult, dmg } — сбор кучи вокруг + урон зомби.
-- field = true — работает только на поле. model — 3D-модель карточки (ItemBuilder), fx — эффект, sfx — звук.
-- В магазине не продаются (noShop): выпадают только с зомби и босса и из наград.
local CONSUMABLES = {
	{ "lube", "Drone Grease", 400, 1, "A drop of machine oil in every motor. Perks up the swarm.",
		{ energy = 0.15, buffs = { dgather = 1 } }, { kind = "can", c1 = C(70, 120, 60), c2 = C(240, 200, 70) },
		{ color = C(240, 200, 70), style = "drip" }, { { "9116328427", 0.6, 1.1 }, { "charge", 0.25, 1.4, 0.15 } } },
	{ "beacon", "Recall Beacon", 600, 1, "Press it and you'll be teleported straight to your hive.",
		{ home = true }, { kind = "device", c1 = C(50, 55, 65), c2 = C(80, 200, 255) },
		{ color = C(80, 200, 255), style = "teleport" }, { { "9118353221", 0.5, 1.3 }, { "whooshRise", 0.5, 1.2, 0.1 }, { "reveal", 0.35, 1.5, 0.35 } } },
	{ "stim", "Combat Stim", 1500, 2, "A shot in the shoulder: +5 stacks of Swarm Rage and +3 stacks of Aim.",
		{ buffs = { rage = 5, crit = 3 } }, { kind = "syringe", c1 = C(255, 70, 50), c2 = C(230, 235, 245) },
		{ color = C(255, 70, 50), style = "pulse" }, { { "9116328427", 0.7, 0.8 }, { "hit", 0.35, 1.3, 0.12 } } },
	{ "goldpaint", "Gold Paint", 2500, 2, "A can of gold spray: piles within 10 studs turn golden for 15 seconds (x5 scrap).",
		{ field = true, gold = { 10, 15 } }, { kind = "spray", c1 = C(255, 200, 40), c2 = C(40, 40, 45) },
		{ color = C(255, 205, 50), style = "spray" }, { { "9113046623", 0.7, 1 }, { "sparkle", 0.4, 1.2, 0.3 } } },
	{ "flare", "Signal Flare", 3500, 3, "Calls in an airdrop: 3 gathering buff orbs fall onto the field.",
		{ field = true, orbs = { 3, "gather" } }, { kind = "flare", c1 = C(230, 50, 40), c2 = C(255, 220, 120) },
		{ color = C(255, 90, 50), style = "flare" }, { { "113248727573901", 0.7, 1 }, { "whoosh", 0.4, 0.8, 0.2 } } },
	{ "microconv", "Mini Recycler", 4000, 3, "A pocket recycler: all the scrap in your backpack instantly turns into batteries.",
		{ convert = true }, { kind = "device", c1 = C(90, 95, 105), c2 = C(130, 255, 120) },
		{ color = C(130, 255, 120), style = "convert" }, { { "9118352429", 0.6, 1 }, { "coin", 0.5, 1.1, 0.3 }, { "chime", 0.35, 1.2, 0.5 } } },
	{ "scrapbomb", "Bomb Crate", 6000, 3, "Falls from the sky and explodes: collects piles within 12 studs (x3) and hits zombies for 400.",
		{ field = true, bomb = { 12, 3, 400 } }, { kind = "crate", c1 = C(120, 90, 55), c2 = C(255, 170, 40) },
		{ color = C(255, 160, 50), style = "bomb" }, { { "9116537007", 0.7, 0.9 }, { "boom", 0.6, 1.2, 0.55 } } },
	{ "luckycoin", "Lucky Nut", 8000, 3, "Flip it for luck: +10 stacks of the Luck buff.",
		{ buffs = { luck = 10 } }, { kind = "coin", c1 = C(255, 215, 70), c2 = C(110, 240, 90) },
		{ color = C(120, 240, 90), style = "sparkle" }, { { "7022812395", 0.7, 1 }, { "star", 0.35, 1.2, 0.4 } } },
	{ "candybars", "Snack Bar Pack", 9000, 3, "Scatters 5 random buff orbs around you.",
		{ field = true, orbs = { 5 } }, { kind = "box", c1 = C(255, 120, 200), c2 = C(120, 220, 255) },
		{ color = C(255, 140, 210), style = "confetti" }, { { "9117848029", 0.6, 1.1 }, { "bling", 0.4, 1, 0.2 } } },
	{ "botbox", "Box of Nano Bugs", 15000, 4, "Releases 8 mini drones for 45 seconds.",
		{ field = true, minis = { 8, 45 } }, { kind = "box", c1 = C(60, 70, 60), c2 = C(80, 255, 140) },
		{ color = C(80, 255, 140), style = "swarm" }, { { "9118327495", 0.6, 1.2 }, { "9118328814", 0.4, 1.5, 0.25 } } },
	{ "magglue", "Magnetic Glue", 20000, 4, "A sticky magnetic gel: +5 stacks of Swarm Grease (drone gathering).",
		{ buffs = { dgather = 5 } }, { kind = "tube", c1 = C(120, 160, 255), c2 = C(220, 230, 255) },
		{ color = C(120, 160, 255), style = "drip" }, { { "9117646243", 0.5, 1.3 }, { "glock", 0.25, 0.8, 0.3 } } },
	{ "rageextract", "Rage Extract", 25000, 4, "A red extract from a mutant heart: +3 Swarm Rage and +3 Aim.",
		{ buffs = { rage = 3, crit = 3 } }, { kind = "vial", c1 = C(255, 50, 60), c2 = C(80, 20, 20) },
		{ color = C(255, 60, 60), style = "pulse" }, { { "9114171955", 0.7, 0.9 }, { "riser", 0.3, 1.4, 0.2 } } },
	{ "gatherextract", "Gatherer's Extract", 25000, 4, "A blue extract from a radioactive crystal: +3 Rich Harvest and +3 Swarm Grease.",
		{ buffs = { scrap = 3, dgather = 3 } }, { kind = "vial", c1 = C(60, 140, 255), c2 = C(20, 40, 80) },
		{ color = C(70, 150, 255), style = "sparkle" }, { { "9114171955", 0.7, 1.15 }, { "chime", 0.35, 0.9, 0.2 } } },
	{ "enzymes", "Recycling Enzymes", 30000, 4, "Bacteria that eat scrap: +5 stacks of Fermentation and +2 Rich Harvest.",
		{ buffs = { convb = 5, scrap = 2 } }, { kind = "jar", c1 = C(150, 255, 90), c2 = C(60, 70, 50) },
		{ color = C(150, 255, 90), style = "bubbles" }, { { "9117642899", 0.5, 1.2 }, { "9117848644", 0.5, 0.9, 0.3 } } },
	{ "motoroil", "Motor Oil", 30000, 4, "Synthetic oil for rotors: +5 Swarm Turbo and +2 Swarm Grease.",
		{ buffs = { dspeed = 5, dgather = 2 } }, { kind = "can", c1 = C(30, 30, 35), c2 = C(255, 140, 30) },
		{ color = C(255, 150, 40), style = "drip" }, { { "9117646243", 0.6, 0.8 }, { "9118352946", 0.4, 1.1, 0.3 } } },
	{ "cocktail", "Survivor Cocktail", 45000, 4, "Full health, +5 Aim and +3 Speed Boost.",
		{ heal = "full", buffs = { crit = 5, speed = 3 } }, { kind = "cup", c1 = C(255, 170, 60), c2 = C(90, 230, 120) },
		{ color = C(255, 180, 70), style = "heal" }, { { "133988388434763", 0.7, 1 }, { "sparkle", 0.35, 1.3, 0.3 } } },
	{ "nanocloud", "Nano Cloud", 40000, 4, "A cloud of nanobots refills every pile on the field and gives +3 Rich Harvest.",
		{ field = true, refill = true, buffs = { scrap = 3 } }, { kind = "vial", c1 = C(220, 235, 255), c2 = C(140, 170, 210) },
		{ color = C(200, 225, 255), style = "cloud" }, { { "9113045686", 0.6, 0.7 }, { "reveal", 0.4, 1, 0.3 } } },
	{ "mutantseed", "Mutant Seed", 120000, 5, "Throw it into the ground and the whole field turns golden for 12 seconds.",
		{ field = true, goldAll = 12 }, { kind = "seed", c1 = C(150, 60, 200), c2 = C(255, 210, 60) },
		{ color = C(255, 210, 60), style = "goldfield" }, { { "thud", 0.6, 1.2 }, { "bigRiser", 0.35, 1.3, 0.1 }, { "fanfare", 0.4, 1, 0.9 } } },
	{ "mutagen", "Purple Mutagen", 250000, 5, "A purple serum: +5 stacks each of Swarm Rage, Aim, Luck and Swarm Grease.",
		{ buffs = { rage = 5, crit = 5, luck = 5, dgather = 5 } }, { kind = "vial", c1 = C(170, 60, 255), c2 = C(60, 20, 80) },
		{ color = C(180, 80, 255), style = "pulse" }, { { "9114171955", 0.7, 0.75 }, { "bigRiser", 0.35, 1.1, 0.15 }, { "boom", 0.3, 1.6, 0.9 } } },
	{ "supershake", "Apocalypse Super Cocktail", 1500000, 6, "Everything at once: max stacks of every swarm buff and full health.",
		{ heal = "full", buffs = { speed = 10, scrap = 10, rage = 10, luck = 10, dgather = 10, convb = 10, crit = 10, dspeed = 10 } },
		{ kind = "cup", c1 = C(255, 70, 110), c2 = C(70, 255, 230) },
		{ color = C(255, 120, 200), style = "rainbow" }, { { "133988388434763", 0.8, 0.9 }, { "bigRiser", 0.4, 1, 0.1 }, { "fanfare", 0.5, 1.05, 1 } } },
}
for _, c in ipairs(CONSUMABLES) do
	table.insert(S.Items, {
		id = c[1], slot = "consumable", name = c[2], price = c[3], grade = c[4], desc = c[5], icon = c[1], stack = true,
		stats = {}, use = c[6], model = c[7], fx = c[8], sfx = c[9], noShop = true,
	})
end

-- ===== КРАФТ: находки из куч лома, нужные помимо батарей =====
S.Mats = {
	-- инструменты
	shovel = { nut = 2 },
	pickaxe = { nut = 4, cog = 1 },
	magrake = { cog = 4, wire = 6, oldbattery = 3 },
	jackhammer = { cog = 8, chip = 3, keycard = 1 },
	vacuum = { chip = 6, dronecell = 3, slime = 3 },
	plasmacutter = { plutonium = 2, radcrystal = 6, blueprint = 1 },
	-- оружие
	pipe = { nut = 2, wire = 1 },
	bat = { nut = 4, tooth = 2, wire = 2 },
	machete = { cog = 3, dogtag = 2, nut = 6 },
	fireaxe = { cog = 5, chip = 3, oldbattery = 4 },
	sledge = { cog = 8, keycard = 1, slime = 2 },
	chainsaw = { chip = 6, dronecell = 3, radcrystal = 3 },
	baton = { dronecell = 5, radcrystal = 5, blueprint = 1, plutonium = 1 },
	scythe = { plutonium = 3, omegacore = 1, goldbar = 2, mutantheart = 2 },
	-- броня
	armor1 = { nut = 1, wire = 1 },
	armor2 = { dogtag = 1, nut = 5, wire = 4 },
	armor3 = { cog = 4, dogtag = 2, keycard = 1 },
	armor4 = { radcrystal = 3, slime = 3, cog = 6 },
	armor5 = { plutonium = 2, mutantheart = 1, radcrystal = 6 },
	-- шлемы
	helmet1 = { nut = 1 },
	helmet2 = { cog = 1, nut = 4 },
	helmet3 = { chip = 2, cog = 3 },
	helmet4 = { slime = 4, chip = 4 },
	helmet5 = { mutantheart = 1, blueprint = 1, slime = 6 },
	-- перчатки
	gloves1 = { wire = 1 },
	gloves2 = { wire = 5, bandage = 1 },
	gloves3 = { chip = 3, wire = 8 },
	gloves4 = { dronecell = 2, chip = 5 },
	gloves5 = { blueprint = 1, dronecell = 5, goldbar = 1 },
	-- ботинки
	boots1 = { nut = 1, wire = 1 },
	boots2 = { tooth = 4, nut = 3 },
	boots3 = { energydrink = 3, cog = 3 },
	boots4 = { dronecell = 2, energydrink = 4 },
	boots5 = { plutonium = 1, omegacore = 1, energydrink = 6 },
	-- новое оружие
	spear = { radcrystal = 4, keycard = 2, cog = 10 },
	katana = { plutonium = 2, goldbar = 1, chip = 8 },
	bonecleaver = { mutantheart = 2, tooth = 12, gemshard = 3 },
	lavaaxe = { plutonium = 3, radcrystal = 8, goldbar = 2 },
	thunderhammer = { dronecell = 10, blueprint = 2, goldbar = 3 },
	crystalblade = { radcrystal = 14, gemshard = 6, omegacore = 1 },
	dragonglaive = { mutantheart = 4, goldbar = 5, omegacore = 1 },
	obsidianscythe = { omegacore = 2, plutonium = 6, gemshard = 10 },
	gravhammer = { omegacore = 3, blueprint = 4, dronecell = 16 },
	omegasaber = { omegacore = 5, goldbar = 10, mutantheart = 6 },
	-- новые инструменты
	drillgun = { cog = 12, chip = 6, keycard = 1 },
	harvester = { cog = 16, dronecell = 4, blueprint = 1 },
	magnetcannon = { chip = 12, radcrystal = 6, dronecell = 6 },
	excavator = { cog = 24, keycard = 3, slime = 8 },
	laserdrill = { plutonium = 3, chip = 16, blueprint = 2 },
	cryoextractor = { radcrystal = 12, gemshard = 6, omegacore = 1 },
	gravitywell = { omegacore = 2, plutonium = 6, blueprint = 3 },
	lavaforge = { omegacore = 2, goldbar = 6, mutantheart = 3 },
	nanoswarm = { omegacore = 3, chip = 30, dronecell = 12 },
	singularity = { omegacore = 5, goldbar = 10, plutonium = 10 },
	-- рюкзаки
	bp_sack = { wire = 1 },
	bp_denim = { nut = 4, wire = 3 },
	bp_hiker = { cog = 2, wire = 5 },
	bp_scrapper = { cog = 4, oldbattery = 3 },
	bp_raid = { dogtag = 3, cog = 5 },
	bp_tactical = { keycard = 1, chip = 4 },
	bp_hazmat = { slime = 4, chip = 5 },
	bp_reactor = { dronecell = 4, radcrystal = 4 },
	bp_bone = { mutantheart = 1, tooth = 10 },
	bp_dragon = { mutantheart = 2, goldbar = 1 },
	bp_crystal = { radcrystal = 10, gemshard = 4 },
	bp_magma = { plutonium = 4, goldbar = 3 },
	bp_obsidian = { omegacore = 1, gemshard = 10 },
	bp_nano = { omegacore = 2, chip = 24 },
	bp_royal = { goldbar = 10, mutantheart = 4 },
	bp_omega = { omegacore = 5, goldbar = 10, plutonium = 8 },
}
-- материалы для снаряжения уровней 6–15
do
	local pool = {
		{ radcrystal = 4, keycard = 2 }, { mutantheart = 1, goldbar = 1 }, { plutonium = 2, gemshard = 4 },
		{ slime = 10, blueprint = 1 }, { radcrystal = 10, gemshard = 6 }, { plutonium = 4, goldbar = 3 },
		{ omegacore = 1, gemshard = 10 }, { omegacore = 2, dronecell = 12 }, { goldbar = 8, mutantheart = 4 },
		{ omegacore = 4, goldbar = 10, plutonium = 8 },
	}
	for _, slot in ipairs({ "armor", "helmet", "gloves", "boots" }) do
		for k = 1, 10 do
			S.Mats[slot .. (5 + k)] = pool[k]
		end
	end
end

S.ById = {}
S.BySlot = {}
for i, it in ipairs(S.Items) do
	it.index = i
	it.mats = S.Mats[it.id]
	S.ById[it.id] = it
	S.BySlot[it.slot] = S.BySlot[it.slot] or {}
	table.insert(S.BySlot[it.slot], it)
end

-- ===== ДОП. ХАРАКТЕРИСТИКИ В СТИЛЕ BSS =====
-- У каждого предмета снаряжения, кроме главной характеристики, есть 2–3 дополнительные.
-- Они растут с уровнем/грейдом и складываются со всех надетых вещей (в т.ч. оружия и инструмента).
S.StatDefs = {
	crit = { "🎯 Crit Chance", pct = true, desc = "Chance to land a critical hit (weapons and drones)." },
	critx = { "💥 Crit Power", pct = true, desc = "A crit hits for 1.5x + this bonus." },
	ddmg = { "🤖 Drone Damage", pct = true, desc = "Damage dealt by the drones in your swarm." },
	dgather = { "🛸 Drone Gathering", pct = true, desc = "How much scrap each drone collection brings." },
	tgather = { "⛏ Tool Gathering", pct = true, desc = "How much scrap each tool hit brings." },
	instconv = { "⚡ Instant Recycling", pct = true, desc = "The share of collected scrap that instantly becomes batteries." },
	luck = { "🍀 Luck", pct = true, desc = "Chance of finds and buff orbs." },
	regen = { "✚ Regeneration", suffix = " HP/s", desc = "Health restored every second." },
	energy = { "🔋 Drone Stamina", pct = true, desc = "Drones work longer on one charge." },
	dspeed = { "🚀 Drone Speed", pct = true, desc = "How fast drones fly and collect." },
	buffdur = { "⏳ Buff Duration", pct = true, desc = "Buffs last longer." },
}
S.StatOrder = { "crit", "critx", "ddmg", "dgather", "tgather", "instconv", "luck", "regen", "energy", "dspeed", "buffdur" }
S.StatCaps = { def = 0.8, speed = 32, crit = 0.6, instconv = 0.5 }

local function r2(v)
	return math.floor(v * 1000 + 0.5) / 1000
end
local EXTRA = {
	weapon = function(it, g)
		return { crit = r2(0.01 * g), critx = r2(0.1 * (g - 1)), ddmg = g >= 3 and r2(0.03 * (g - 2)) or nil }
	end,
	tool = function(it, g)
		return { dgather = r2(0.015 * g), instconv = g >= 4 and r2(0.02 * (g - 3)) or nil, luck = g >= 5 and r2(0.05 * (g - 4)) or nil }
	end,
	armor = function(it, t)
		return { regen = math.floor(it.stats.hp * 0.006 * 10 + 0.5) / 10, ddmg = r2(0.02 * t) }
	end,
	helmet = function(it, t)
		return { crit = r2(0.005 * t), luck = r2(0.03 * t), buffdur = t >= 3 and r2(0.02 * t) or nil }
	end,
	gloves = function(it, t)
		return { tgather = r2(0.04 * t), critx = r2(0.05 * t), instconv = t >= 6 and r2(0.01 * (t - 5)) or nil }
	end,
	boots = function(it, t)
		return { dspeed = r2(0.01 * t), energy = r2(0.015 * t) }
	end,
	backpack = function(it, t)
		return { dgather = t >= 2 and r2(0.01 * (t - 1)) or nil, instconv = t >= 10 and r2(0.02 * (t - 9)) or nil, energy = t >= 6 and r2(0.01 * (t - 5)) or nil }
	end,
}
do
	-- оружие и инструменты считаются по номеру в линейке (как уровень у брони)
	local n = { weapon = 0, tool = 0 }
	for _, it in ipairs(S.Items) do
		local f = EXTRA[it.slot]
		if f then
			local lvl = it.tier
			if it.slot == "weapon" or it.slot == "tool" then
				n[it.slot] += 1
				lvl = math.max(it.grade, math.ceil(n[it.slot] / 3))
			end
			for k, v in pairs(f(it, lvl or it.grade)) do
				if v and v > 0 and it.stats[k] == nil then
					it.stats[k] = v
				end
			end
		end
	end
end

-- суммарные характеристики по экипировке
local MAIN_ONLY = { dmg = true, radius = true, cd = true, gather = true, fx = true }
function S.Totals(gear)
	local t = { hp = 0, def = 0, scrap = 0, speed = 0, jump = 0, cap = 0, conv = 0, cspeed = 0 }
	for _, k in ipairs(S.StatOrder) do
		t[k] = 0
	end
	for _, slot in ipairs({ "armor", "helmet", "gloves", "boots", "backpack", "weapon", "tool" }) do
		local it = gear and gear[slot] and S.ById[gear[slot]]
		if it then
			for k, v in pairs(it.stats) do
				if not MAIN_ONLY[k] and type(v) == "number" then
					t[k] = (t[k] or 0) + v
				end
			end
		end
	end
	for k, cap in pairs(S.StatCaps) do
		t[k] = math.min(t[k] or 0, cap)
	end
	return t
end

return S
