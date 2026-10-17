-- Цепочки квестов четырёх NPC на базе (по 15 заданий, как длинные цепочки медведей в BSS).
-- Цепочки идут параллельно. Первые задания — минуты, середина — часы, финалы — десятки часов
-- активной игры (подобрано симуляцией zombie-swarm/balance/questsim.luau).
-- Типы целей:
--   kill (field?, night?) — убить зомби            scrap (field?, res?) — собрать лом (ресурс поля)
--   convert — переработать лом                 find — найти предметы
--   deliver (id) — принести предмет (забирается при сдаче)
--   pull — крутки гачи        own (rarity) — иметь дрона редкости или выше
--   swarm — дронов в рое        cells — ячеек зарядки       killTotal — убийств за всё время
--   use (id?) — использовать расходник или находку (без id — любой расходник)
--   craft (slot?) — скрафтить   bagUp — улучшить рюкзак
--   pickup — подобрать ускорение   charged — зарядить дрона до 100%
--   bossKill — победить Колосса   bossDamage — урон по Колоссу
-- Награда: batteries, gems, items={id=n}, consum={id=n}, perk={hp|dmg|scrap|luck = значение}
-- В каждой награде есть находки для крафта (items): ранние задания дают гайки и проволоку,
-- поздние — плутоний, золото и ядра «Омега» под лучшее снаряжение.
-- Награда батареями ≈ 20–40 минут дохода игрока на этом этапе.
local C = Color3.fromRGB
local Q = {}

-- Версия цепочек. При смене старый номер задания игрока переводится по npc.migrate
-- (индекс — старый номер, значение — новый; последний элемент — «цепочка была пройдена»).
Q.Version = 2

Q.NPCs = {
	{
		id = "doctor",
		name = "Doctor Liza",
		role = "Infirmary Doctor",
		color = C(255, 110, 110),
		greet = "Stay away from their teeth. I'm working on a vaccine, and I need someone brave.",
		migrate = { 1, 3, 4, 7, 9, 11, 13, 14 },
		quests = {
			{ title = "First Aid", text = "Zombies are getting too close to the infirmary. Drive them back from the Wasteland and haul some scrap for the barricades.",
				goals = { { t = "kill", field = "wasteland", n = 12 }, { t = "scrap", n = 800 } },
				reward = { batteries = 1500, gems = 5, items = { nut = 2, wire = 2 }, consum = { medkit = 2 } } },
			{ title = "Food for the Infirmary", text = "The wounded have nothing to eat. Scrap piles sometimes hide canned food, so bring me a couple of cans.",
				goals = { { t = "deliver", id = "cans", n = 2 }, { t = "kill", n = 30 } },
				reward = { batteries = 3000, gems = 8, items = { tooth = 2, wire = 2, bandage = 1 } } },
			{ title = "Tissue Samples", text = "To understand the virus I need samples. Zombie teeth preserve it best. Yes, it's gross.",
				goals = { { t = "deliver", id = "tooth", n = 3 }, { t = "kill", field = "deadcity", n = 40 } },
				reward = { batteries = 6000, gems = 10, items = { dogtag = 1, nut = 4 } } },
			{ title = "Sterile Conditions", text = "I need bandages for dressings and proof that you can heal yourself. A dead hero is no use to anyone on a mission.",
				goals = { { t = "deliver", id = "bandage", n = 3 }, { t = "use", id = "medkit", n = 3 }, { t = "kill", field = "deadcity", n = 80 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 2, energydrink = 2 }, consum = { lube = 2 } } },
			{ title = "Night Rounds", text = "The virus wakes up at night. Patrol the fields after sunset and bring energy drinks. My orderlies are falling asleep on their feet.",
				goals = { { t = "kill", night = true, n = 30 }, { t = "deliver", id = "energydrink", n = 2 }, { t = "scrap", res = "chips", n = 40000 } },
				reward = { batteries = 25000, gems = 15, items = { chip = 2, bandage = 2 }, consum = { stim = 1 } } },
			{ title = "Swamp Fever", text = "A new infection came from the Rotten Swamp. Clear out the Drowners and bring back biomass so I can grow a culture.",
				goals = { { t = "kill", field = "swamp", n = 120 }, { t = "deliver", id = "tooth", n = 8 }, { t = "scrap", res = "bio", n = 150000 } },
				reward = { batteries = 70000, gems = 20, items = { slime = 2, cog = 3 } } },
			{ title = "Infected Blood", text = "The virus gets active at night. I need data from night zombies specifically, and from the swamp Drowners.",
				goals = { { t = "kill", night = true, n = 80 }, { t = "kill", field = "swamp", n = 220 }, { t = "deliver", id = "energydrink", n = 4 } },
				reward = { batteries = 150000, gems = 25, items = { slime = 3, dronecell = 2 } } },
			{ title = "Quarantine", text = "The infirmary is overflowing. I need bandages, slime for antiseptic, and people who aren't afraid to go near the sick.",
				goals = { { t = "deliver", id = "bandage", n = 6 }, { t = "deliver", id = "slime", n = 3 }, { t = "use", id = "cocktail", n = 2 }, { t = "kill", field = "swamp", n = 350 } },
				reward = { batteries = 350000, gems = 30, items = { radcrystal = 2, slime = 3 }, consum = { cocktail = 1 } } },
			{ title = "Mutant Slime", text = "Mutant slime is the catalyst of the mutation. If I'm right, it can be turned into an antidote.",
				goals = { { t = "deliver", id = "slime", n = 6 }, { t = "kill", field = "radzone", n = 300 }, { t = "scrap", res = "uranium", n = 4000000 } },
				reward = { batteries = 1200000, gems = 40, items = { mutantheart = 1, radcrystal = 3 } } },
			{ title = "Serum", text = "The first serum is ready, but it needs a stabilizer. Radioactive crystals, a mutant heart, and field tests on night creatures.",
				goals = { { t = "deliver", id = "radcrystal", n = 6 }, { t = "deliver", id = "mutantheart", n = 1 }, { t = "kill", night = true, n = 250 } },
				reward = { batteries = 3000000, gems = 50, items = { mutantheart = 1, plutonium = 1, capsule = 1 } } },
			{ title = "Heart of the Disease", text = "The mutant heart is still beating because the virus keeps it alive. Get me more hearts and test the serum on the Colossus itself.",
				goals = { { t = "deliver", id = "mutantheart", n = 3 }, { t = "bossDamage", n = 500000 }, { t = "kill", field = "radzone", n = 800 } },
				reward = { batteries = 4500000, gems = 60, items = { plutonium = 2, slime = 5 }, consum = { rageextract = 2 } } },
			{ title = "Field Hospital", text = "The soldiers at the Military Base are somebody's children too. Set up a hospital there: bandages, cocktails, and a cleared perimeter.",
				goals = { { t = "kill", field = "military", n = 400 }, { t = "deliver", id = "bandage", n = 15 }, { t = "use", id = "cocktail", n = 8 } },
				reward = { batteries = 8000000, gems = 80, items = { mutantheart = 2, blueprint = 1 } } },
			{ title = "Dawn Vaccine", text = "The last ingredient is the Colossus's blood. It was the first one infected. Do this, and we'll save everyone who's still alive.",
				goals = { { t = "bossKill", n = 4 }, { t = "deliver", id = "mutantheart", n = 4 }, { t = "kill", field = "military", n = 2000 } },
				reward = { batteries = 15000000, gems = 120, items = { goldbar = 1, mutantheart = 2 }, perk = { hp = 50 } }, perkText = "Permanent +50 max health" },
			{ title = "Epidemic", text = "The virus has mutated. The new strain only comes out at night. I need tons of samples before it reaches the base.",
				goals = { { t = "kill", night = true, n = 2000 }, { t = "deliver", id = "slime", n = 25 }, { t = "deliver", id = "radcrystal", n = 25 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, plutonium = 2 }, consum = { supershake = 1 } } },
			{ title = "Cure for the Apocalypse", text = "This is it. The final formula. Twelve victories over the Colossus, mutant hearts, and gold for the equipment. Humanity is in your hands.",
				goals = { { t = "bossKill", n = 12 }, { t = "deliver", id = "mutantheart", n = 12 }, { t = "deliver", id = "goldbar", n = 4 }, { t = "kill", field = "military", n = 6000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 1, goldbar = 2, mutantheart = 2 }, perk = { hp = 100 } }, perkText = "Permanent +100 max health" },
		},
	},
	{
		id = "sergeant",
		name = "Sergeant Gromov",
		role = "Outpost Commander",
		color = C(150, 200, 90),
		greet = "Attention, soldier! On this base only those who can shoot survive. Or swing a pipe.",
		migrate = { 1, 3, 4, 5, 9, 10, 13, 14 },
		quests = {
			{ title = "Baptism of Fire", text = "Show me you're not dead weight. Take down a couple dozen Walkers and I'll issue you grenades.",
				goals = { { t = "kill", n = 20 } },
				reward = { batteries = 1500, gems = 5, items = { nut = 3, wire = 1 }, consum = { grenade = 2 } } },
			{ title = "First Sortie", text = "The Wasteland is our backyard. Sweep it properly and grab every speed boost you find. You'll need them.",
				goals = { { t = "kill", field = "wasteland", n = 50 }, { t = "pickup", n = 3 } },
				reward = { batteries = 3000, gems = 8, items = { tooth = 3, nut = 2 } } },
			{ title = "Firepower", text = "You won't save the world with a scraper. Craft yourself a real weapon and learn to throw grenades.",
				goals = { { t = "craft", slot = "weapon", n = 1 }, { t = "use", id = "grenade", n = 2 }, { t = "kill", n = 80 } },
				reward = { batteries = 6000, gems = 10, items = { dogtag = 2, wire = 2 } } },
			{ title = "City Patrol", text = "My squad went missing in the Dead City. Find their tags and avenge them.",
				goals = { { t = "kill", field = "deadcity", n = 120 }, { t = "deliver", id = "dogtag", n = 2 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 3, dogtag = 1 } } },
			{ title = "Night Shift", text = "They're twice as vicious at night. That's exactly why a real soldier patrols at night. Move fast.",
				goals = { { t = "kill", night = true, n = 40 }, { t = "pickup", n = 10 } },
				reward = { batteries = 25000, gems = 15, items = { keycard = 1, cog = 3 }, consum = { medkit = 5 } } },
			{ title = "Swamp Sweep", text = "Drowners are crawling out of the bog right onto the road. Hit them with grenades and find the tags of those who never came back.",
				goals = { { t = "kill", field = "swamp", n = 150 }, { t = "use", id = "grenade", n = 10 }, { t = "deliver", id = "dogtag", n = 4 } },
				reward = { batteries = 70000, gems = 20, items = { chip = 3, oldbattery = 3 } } },
			{ title = "Peregrine Squad", text = "I'm putting together a strike team. You need better armor and night combat experience in the swamp.",
				goals = { { t = "kill", field = "swamp", n = 300 }, { t = "kill", night = true, n = 100 }, { t = "craft", n = 3 } },
				reward = { batteries = 150000, gems = 25, items = { keycard = 1, radcrystal = 2 }, consum = { stim = 3 } } },
			{ title = "Call Sign: Thunder", text = "Two and a half thousand kills to your name and the call sign is yours. Plus keycards to the depots and a full sprint loadout.",
				goals = { { t = "killTotal", n = 2500 }, { t = "deliver", id = "keycard", n = 2 }, { t = "pickup", n = 40 } },
				reward = { batteries = 350000, gems = 30, items = { dronecell = 2, radcrystal = 3 }, consum = { grenade = 10 } } },
			{ title = "Radioactive Frontier", text = "Mutants broke through the line at the Rad Zone. Hold the line, use your stims, and collect the tags of the fallen.",
				goals = { { t = "kill", field = "radzone", n = 400 }, { t = "use", id = "stim", n = 5 }, { t = "deliver", id = "dogtag", n = 8 } },
				reward = { batteries = 1200000, gems = 40, items = { plutonium = 1, keycard = 2 } } },
			{ title = "Operation Colossus", text = "Recon reports a giant on tier 4, further up the road. Gather a squad and bring it down. That's an order.",
				goals = { { t = "bossKill", n = 1 }, { t = "kill", field = "radzone", n = 600 } },
				reward = { batteries = 3000000, gems = 60, items = { radcrystal = 5, blueprint = 2 } } },
			{ title = "Giant Hunt", text = "One win is luck. Three is tactics. Bring down the Colossus three more times and get the keycards to its lair.",
				goals = { { t = "bossKill", n = 3 }, { t = "kill", night = true, n = 400 }, { t = "deliver", id = "keycard", n = 5 } },
				reward = { batteries = 4500000, gems = 70, items = { goldbar = 1, plutonium = 1 } } },
			{ title = "Beachhead", text = "The Military Base on the plateau is our ticket to the armory. Clear it out and get the keycards.",
				goals = { { t = "kill", field = "military", n = 400 }, { t = "deliver", id = "keycard", n = 6 } },
				reward = { batteries = 8000000, gems = 80, items = { plutonium = 2, radcrystal = 6 }, consum = { scrapbomb = 5 } } },
			{ title = "Apocalypse Veteran", text = "Fifteen thousand kills and six fallen giants: that's what it takes to be a legend. Prove you've become one.",
				goals = { { t = "killTotal", n = 15000 }, { t = "bossKill", n = 6 }, { t = "kill", field = "military", n = 1500 } },
				reward = { batteries = 15000000, gems = 150, items = { goldbar = 2, mutantheart = 1 }, perk = { dmg = 0.15 } }, perkText = "Permanent +15% damage to zombies" },
			{ title = "Total Sweep", text = "HQ wants the base cleared completely. Day and night, with rage extract in your veins. Not one step back.",
				goals = { { t = "kill", field = "military", n = 3000 }, { t = "kill", night = true, n = 1500 }, { t = "use", id = "rageextract", n = 10 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, goldbar = 2 }, consum = { mutagen = 2 } } },
			{ title = "Legend of the Wastes", text = "They already sing about you around the campfires. Thirty thousand zombies, twelve Colossi. Do it and I'll give you my old medal.",
				goals = { { t = "killTotal", n = 30000 }, { t = "bossKill", n = 12 }, { t = "kill", field = "military", n = 5000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, plutonium = 3 }, perk = { dmg = 0.25 } }, perkText = "Permanent +25% damage to zombies" },
		},
	},
	{
		id = "mechanic",
		name = "Mechanic Kuzmich",
		role = "Drone Engineer",
		color = C(255, 170, 60),
		greet = "Ah, a new face! Drones aren't toys. Every screw counts. There's a mountain of work.",
		migrate = { 1, 3, 4, 6, 8, 10, 13, 14 },
		quests = {
			{ title = "Scrap Metal", text = "The Recycler is sitting idle. Haul in some scrap and recycle it. Let's see how it runs.",
				goals = { { t = "scrap", n = 1000 }, { t = "convert", n = 800 } },
				reward = { batteries = 1500, gems = 5, items = { wire = 2, nut = 3 } } },
			{ title = "Rusty Stockpile", text = "I need rust. Yes, actual rust, for primer. The Wasteland is full of it. And a couple of nuts on top.",
				goals = { { t = "scrap", res = "rust", n = 5000 }, { t = "deliver", id = "nut", n = 3 } },
				reward = { batteries = 3000, gems = 8, items = { nut = 3, oldbattery = 2 } } },
			{ title = "Spare Parts", text = "Your backpack is tiny. Bring me some wire and upgrade it. Don't embarrass yourself.",
				goals = { { t = "deliver", id = "wire", n = 3 }, { t = "bagUp", n = 2 } },
				reward = { batteries = 6000, gems = 10, items = { wire = 4, cog = 2 } } },
			{ title = "Swarm Expansion", text = "Three drones aren't a swarm. Get more of them and buy extra cells for your station to charge them.",
				goals = { { t = "swarm", n = 6 }, { t = "cells", n = 6 }, { t = "charged", n = 25 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 3, chip = 2 } } },
			{ title = "City Electronics", text = "There are intact circuit boards lying around the Dead City. Gather microchips, bring gear wheels, and run it all through the Recycler.",
				goals = { { t = "scrap", res = "chips", n = 50000 }, { t = "deliver", id = "cog", n = 3 }, { t = "convert", n = 60000 } },
				reward = { batteries = 25000, gems = 15, items = { oldbattery = 3, cog = 3, chip = 2 } } },
			{ title = "Production", text = "Batteries are the lifeblood of the base. Recycle a mountain of scrap and bring old batteries for parts.",
				goals = { { t = "convert", n = 300000 }, { t = "deliver", id = "oldbattery", n = 6 }, { t = "swarm", n = 10 } },
				reward = { batteries = 70000, gems = 20, items = { dronecell = 1, chip = 4 } } },
			{ title = "Biofuel", text = "A biomass generator! Bring biomass from the swamp, add some gear wheels, and grease your drones properly.",
				goals = { { t = "scrap", res = "bio", n = 1200000 }, { t = "deliver", id = "cog", n = 6 }, { t = "use", id = "lube", n = 5 } },
				reward = { batteries = 150000, gems = 25, items = { dronecell = 2, cog = 6 }, consum = { lube = 5 } } },
			{ title = "Microchips", text = "I need intact microchips to reflash the charging cells. And craft yourself some decent gear.",
				goals = { { t = "deliver", id = "chip", n = 8 }, { t = "craft", n = 6 }, { t = "cells", n = 14 } },
				reward = { batteries = 350000, gems = 30, items = { keycard = 1, chip = 6 } } },
			{ title = "Uranium Reactor", text = "Uranium from the Rad Zone will fuel the new reactor. Battery packs to start it up, and hundreds of charges to break in the cells.",
				goals = { { t = "scrap", res = "uranium", n = 6000000 }, { t = "deliver", id = "dronecell", n = 4 }, { t = "charged", n = 600 } },
				reward = { batteries = 1200000, gems = 40, items = { dronecell = 3, blueprint = 1 } } },
			{ title = "Big Swarm", text = "Now we're talking business. Twenty drones, twenty cells, and a mountain of recycled scrap.",
				goals = { { t = "swarm", n = 20 }, { t = "cells", n = 20 }, { t = "convert", n = 40000000 } },
				reward = { batteries = 3000000, gems = 50, items = { dronecell = 4, plutonium = 1, blueprint = 1 } } },
			{ title = "Tuning", text = "A battery pack for every drone. And it's time to rebuild your whole arsenal from proper parts.",
				goals = { { t = "deliver", id = "dronecell", n = 8 }, { t = "craft", n = 12 }, { t = "scrap", n = 100000000 } },
				reward = { batteries = 4500000, gems = 60, items = { blueprint = 1, chip = 8 }, consum = { motoroil = 3 } } },
			{ title = "Ammo Depot", text = "Shell casings from the Military Base are the best brass around. Bring me a mountain of them and toss in some gear wheels.",
				goals = { { t = "scrap", res = "brass", n = 200000000 }, { t = "deliver", id = "cog", n = 30 } },
				reward = { batteries = 8000000, gems = 80, items = { plutonium = 2, dronecell = 5 }, consum = { microconv = 5 } } },
			{ title = "Engineering Masterpiece", text = "They say an Omega Core holds enough energy for a whole city. Bring me one and I'll overclock your gloves.",
				goals = { { t = "deliver", id = "omegacore", n = 1 }, { t = "cells", n = 35 }, { t = "convert", n = 1500000000 } },
				reward = { batteries = 15000000, gems = 120, items = { goldbar = 1, blueprint = 2 }, perk = { scrap = 0.2 } }, perkText = "Permanent +20% scrap gathering" },
			{ title = "Factory", text = "We're building a real factory. Billions of scrap, forty microchips, and every station cell filled up.",
				goals = { { t = "convert", n = 3000000000 }, { t = "deliver", id = "chip", n = 40 }, { t = "cells", n = 45 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, dronecell = 8 }, consum = { enzymes = 5 } } },
			{ title = "Heart of the Base", text = "Three Omega Cores in one reactor and the base will live forever. This is my life's work. Don't let me down.",
				goals = { { t = "deliver", id = "omegacore", n = 3 }, { t = "cells", n = 50 }, { t = "convert", n = 5000000000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, blueprint = 3 }, perk = { scrap = 0.3 } }, perkText = "Permanent +30% scrap gathering" },
		},
	},
	{
		id = "professor",
		name = "Professor Volt",
		role = "Anomaly Scientist",
		color = C(150, 120, 255),
		greet = "Fascinating! Radiation, anomalies, drones from a capsule… This world has become one big laboratory!",
		migrate = { 1, 3, 4, 8, 10, 11, 13, 14 },
		quests = {
			{ title = "First Sample", text = "The Drone Capsule in the lab is a mystery. Open it a couple of times and bring me whatever you find in the scrap piles.",
				goals = { { t = "pull", n = 2 }, { t = "find", n = 2 } },
				reward = { batteries = 1500, gems = 10, items = { nut = 2, oldbattery = 2 } } },
			{ title = "Capsule Fever", text = "More! I need statistics. Five pulls and plenty of finds. Science loves big samples.",
				goals = { { t = "pull", n = 5 }, { t = "find", n = 8 } },
				reward = { batteries = 3000, gems = 10, items = { wire = 3, tooth = 1 } } },
			{ title = "Energy from Nothing", text = "My theory: old batteries recharge themselves under radiation. I need samples and drone charging measurements.",
				goals = { { t = "deliver", id = "oldbattery", n = 3 }, { t = "charged", n = 20 } },
				reward = { batteries = 6000, gems = 15, items = { cog = 2, oldbattery = 2 } } },
			{ title = "Rare Specimen", text = "Rare drones give off strange waves. Get one, and keep digging through the scrap.",
				goals = { { t = "own", rarity = "Rare", n = 1 }, { t = "find", n = 25 }, { t = "pull", n = 10 } },
				reward = { batteries = 12000, gems = 20, items = { chip = 2, gemshard = 1 } } },
			{ title = "City Chemistry", text = "Microchips and energy drinks are the perfect pair for my conductivity experiment. And microchip samples from the city fields.",
				goals = { { t = "deliver", id = "chip", n = 2 }, { t = "deliver", id = "energydrink", n = 2 }, { t = "scrap", res = "chips", n = 40000 } },
				reward = { batteries = 25000, gems = 20, items = { slime = 1, dogtag = 2 } } },
			{ title = "Epic Wave", text = "An Epic drone! I need an Epic drone! And finds, lots of finds, for comparison.",
				goals = { { t = "own", rarity = "Epic", n = 1 }, { t = "pull", n = 25 }, { t = "find", n = 80 } },
				reward = { batteries = 70000, gems = 25, items = { radcrystal = 1, gemshard = 3 } } },
			{ title = "Biomass", text = "The swamp biomass moves on its own. I want to know why. Bring some, plus a little slime as a control.",
				goals = { { t = "scrap", res = "bio", n = 1000000 }, { t = "deliver", id = "slime", n = 2 }, { t = "find", n = 150 } },
				reward = { batteries = 150000, gems = 30, items = { radcrystal = 3, gemshard = 2 } } },
			{ title = "Background Radiation", text = "Crystals from the Radioactive Zone are pure mutation energy. Get some, just don't carry them in your pocket. And toss in a nut for luck.",
				goals = { { t = "deliver", id = "radcrystal", n = 4 }, { t = "use", id = "luckycoin", n = 3 }, { t = "pull", n = 40 } },
				reward = { batteries = 350000, gems = 35, items = { slime = 3, keycard = 1 } } },
			{ title = "Uranium Anomaly", text = "The uranium here behaves wrong. I need tons of uranium, crystals, and hundreds of finds for statistics.",
				goals = { { t = "scrap", res = "uranium", n = 8000000 }, { t = "deliver", id = "radcrystal", n = 8 }, { t = "find", n = 400 } },
				reward = { batteries = 1200000, gems = 45, items = { radcrystal = 4, gemshard = 3 } } },
			{ title = "Ancient Blueprints", text = "Someone designed these drones BEFORE the catastrophe. Blueprints and a Legendary drone will prove my theory!",
				goals = { { t = "deliver", id = "blueprint", n = 2 }, { t = "own", rarity = "Legendary", n = 1 }, { t = "pull", n = 80 } },
				reward = { batteries = 3000000, gems = 60, items = { plutonium = 1, radcrystal = 4, capsule = 1 } } },
			{ title = "Golden Anomaly", text = "Gold and plutonium in one reaction… Yes, it's dangerous. No, I won't explain.",
				goals = { { t = "deliver", id = "plutonium", n = 3 }, { t = "deliver", id = "goldbar", n = 1 }, { t = "find", n = 1200 } },
				reward = { batteries = 4500000, gems = 70, items = { gemshard = 5, blueprint = 1 } } },
			{ title = "Capsule Theory", text = "Firmware capsules are the key to drone code. Open them yourself, make hundreds of pulls, and bring gem shards.",
				goals = { { t = "use", id = "capsule", n = 2 }, { t = "pull", n = 120 }, { t = "deliver", id = "gemshard", n = 10 } },
				reward = { batteries = 8000000, gems = 90, items = { goldbar = 1, radcrystal = 6, goldcapsule = 1 } } },
			{ title = "Theory of Everything", text = "The last experiment. I need a Mythic drone and an Omega Core. If it works, you'll be the luckiest person alive.",
				goals = { { t = "own", rarity = "Mythic", n = 1 }, { t = "pull", n = 60 }, { t = "deliver", id = "omegacore", n = 1 }, { t = "deliver", id = "mutantheart", n = 2 } },
				reward = { batteries = 15000000, gems = 150, items = { omegacore = 1, gemshard = 5 }, perk = { luck = 0.5 } }, perkText = "Permanent +50% find chance" },
			{ title = "Quantum Leap", text = "The theory of everything turned out to be a theory of almost everything. I need more data: pulls, finds, plutonium. Much more.",
				goals = { { t = "pull", n = 400 }, { t = "find", n = 4000 }, { t = "deliver", id = "plutonium", n = 10 } },
				reward = { batteries = 30000000, gems = 150, items = { goldbar = 2, plutonium = 2, goldcapsule = 2 } } },
			{ title = "Secret of the Drones", text = "I finally figured out where the drones came from. Help me build the last device and you'll be the first to know the secret.",
				goals = { { t = "pull", n = 500 }, { t = "deliver", id = "omegacore", n = 3 }, { t = "deliver", id = "goldbar", n = 5 }, { t = "own", rarity = "Mythic", n = 1 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, goldbar = 3, starcapsule = 1 }, perk = { luck = 0.5 } }, perkText = "Another permanent +50% find chance" },
		},
	},
}

Q.ById = {}
for _, n in ipairs(Q.NPCs) do
	Q.ById[n.id] = n
end

-- текст цели для интерфейса
local FIELD_NAMES = { wasteland = "in the Wasteland", deadcity = "in the Dead City", swamp = "in the Rotten Swamp", radzone = "in the Radioactive Zone", military = "at the Military Base" }
local RAR = { Uncommon = "Uncommon", Rare = "Rare", Epic = "Epic", Legendary = "Legendary", Mythic = "Mythic", Secret = "Secret" }

local function big(n)
	if n >= 1e9 then
		return (("%.1f"):format(n / 1e9):gsub("%.0$", "")) .. "B"
	elseif n >= 1e6 then
		return (("%.1f"):format(n / 1e6):gsub("%.0$", "")) .. "M"
	end
	return tostring(n)
end

-- названия ресурсов и расходников берём из конфигов (лениво: этот модуль грузится и вне игры)
local function resName(id)
	local ok, Config = pcall(require, script.Parent.Config)
	local r = ok and Config.ResourceById and Config.ResourceById[id]
	return r and r.name or id
end
local function consumName(id)
	local ok, Shop = pcall(require, script.Parent.ShopConfig)
	local it = ok and Shop.ById and Shop.ById[id]
	return it and it.name
end

function Q.GoalText(g, itemName)
	local t = g.t
	if t == "kill" then
		return ("Kill %s zombies%s%s"):format(big(g.n), g.field and (" " .. FIELD_NAMES[g.field]) or "", g.night and " at night" or "")
	elseif t == "scrap" then
		if g.res then
			return ("Collect %s: %s"):format(resName(g.res), big(g.n))
		end
		return ("Collect %s scrap%s"):format(big(g.n), g.field and (" " .. FIELD_NAMES[g.field]) or "")
	elseif t == "convert" then
		return ("Recycle %s scrap"):format(big(g.n))
	elseif t == "find" then
		return ("Find %d items"):format(g.n)
	elseif t == "deliver" then
		return ("Bring: %s x%d"):format(itemName or g.id, g.n)
	elseif t == "pull" then
		return ("Make %d gacha pulls"):format(g.n)
	elseif t == "own" then
		return ("Own a drone of %s rarity or higher"):format(RAR[g.rarity] or g.rarity)
	elseif t == "swarm" then
		return ("Have %d drones in your swarm"):format(g.n)
	elseif t == "cells" then
		return ("Have %d cells at your charging station"):format(g.n)
	elseif t == "killTotal" then
		return ("Kill %s zombies in total"):format(big(g.n))
	elseif t == "use" then
		if not g.id then
			return ("Use any consumables x%d"):format(g.n)
		end
		return ("Use: %s x%d"):format(consumName(g.id) or itemName or g.id, g.n)
	elseif t == "craft" then
		return g.slot == "weapon" and ("Craft weapons x%d"):format(g.n) or ("Craft items x%d"):format(g.n)
	elseif t == "bagUp" then
		return ("Upgrade your backpack %d time(s)"):format(g.n)
	elseif t == "pickup" then
		return ("Pick up %d boosts in the fields"):format(g.n)
	elseif t == "charged" then
		return ("Charge drones to 100%% at the station x%d"):format(g.n)
	elseif t == "bossKill" then
		return ("Defeat the Colossus x%d"):format(g.n)
	elseif t == "bossDamage" then
		return ("Deal %s damage to the Colossus"):format(big(g.n))
	end
	return t
end

return Q
