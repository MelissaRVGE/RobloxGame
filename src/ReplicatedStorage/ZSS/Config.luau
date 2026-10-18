-- Zombie Swarm Simulator: общий конфиг (сервер + клиент)
local C = Color3.fromRGB

local Config = {}

Config.GameName = "Zombie Swarm Simulator"

-- Тестовый бонус: в Roblox Studio игроку выдаётся минимум столько батарей (0 = выключить)
Config.StudioBonusBatteries = 0

-- ===== ГАЧА =====
Config.StudioBonusGems = 0

-- гача оплачивается ГЕМАМИ
Config.PullCost = 10
Config.Pull10Cost = 100 -- без скидки: ровно 10 одиночных круток
Config.StartGems = 0 -- новый игрок начинает без гемов
-- награда за время в игре (как ежечасные раздатчики в BSS): каждые interval секунд онлайн
Config.PlaytimeReward = { interval = 600, gems = 5 }
-- гемы нельзя купить за батареи: только квесты, босс и редкие находки
Config.GemPacks = {}

-- Игроков на сервере и ульев-зарядок (по одному на игрока, как в Bee Swarm Simulator)
Config.MaxPlayers = 6
Config.MaxSlots = 25
Config.StartBatteries = 300
Config.StartDrones = { "scout", "collector" }

Config.RarityOrder = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- weight в долях от 10000 (1% = 100)
Config.Rarities = {
	Uncommon = { order = 1, label = "UNCOMMON", ru = "White", color = C(235, 238, 245), weight = 7700 },
	Rare = { order = 2, label = "RARE", ru = "Blue", color = C(50, 140, 255), weight = 1700 },
	Epic = { order = 3, label = "EPIC", ru = "Purple", color = C(175, 70, 255), weight = 450 },
	Legendary = { order = 4, label = "LEGENDARY", ru = "Yellow", color = C(255, 205, 35), weight = 120 },
	Mythic = { order = 5, label = "MYTHIC", ru = "Rainbow", color = C(255, 120, 220), weight = 28, rainbow = true },
	Secret = { order = 6, label = "SECRET", ru = "Red", color = C(255, 30, 40), weight = 2 },
}
Config.WeightTotal = 10000

-- Гарант: если за N круток не выпала эта редкость (или выше) — N-я крутка гарантированно её даёт
Config.Pity = {
	{ rarity = "Secret", pulls = 3000 },
	{ rarity = "Mythic", pulls = 1000 },
	{ rarity = "Legendary", pulls = 250 },
}

function Config.ChanceText(rarity)
	local pct = Config.Rarities[rarity].weight / 100
	local s = string.format("%.2f", pct)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s .. "%"
end

function Config.Rainbow(t, offset)
	return Color3.fromHSV(((t or os.clock()) * 0.35 + (offset or 0)) % 1, 0.75, 1)
end

function Config.RarityColor(rarity, t)
	local r = Config.Rarities[rarity]
	if r.rainbow then
		return Config.Rainbow(t)
	end
	return r.color
end

do
	local kp = {}
	for i = 0, 6 do
		table.insert(kp, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 0.8, 1)))
	end
	Config.RainbowSequence = ColorSequence.new(kp)
end

-- радуга, плавно бегущая по оттенку: для фона мифических карточек (каждый кадр — новый сдвиг)
function Config.RainbowFlow(t, sat, val)
	local shift = ((t or os.clock()) * 0.12) % 1
	local kp = {}
	for i = 0, 6 do
		table.insert(kp, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6 * 0.85 + shift) % 1, sat or 0.8, val or 1)))
	end
	return ColorSequence.new(kp)
end

-- Базовые характеристики по редкости.
-- Рой — главный источник дохода (как пчёлы в BSS): дрон за сбор приносит намного больше, чем один
-- взмах инструмента, а каждая следующая редкость заметно сильнее предыдущей.
Config.RarityStats = {
	Uncommon = { gather = 25, damage = 4, speed = 24, gatherTime = 1.6 },
	Rare = { gather = 45, damage = 7, speed = 27, gatherTime = 1.5 },
	Epic = { gather = 75, damage = 11, speed = 30, gatherTime = 1.35 },
	Legendary = { gather = 120, damage = 17, speed = 33, gatherTime = 1.25 },
	Mythic = { gather = 180, damage = 26, speed = 36, gatherTime = 1.15 },
	Secret = { gather = 300, damage = 42, speed = 40, gatherTime = 1.0 },
}

-- ===== 24 ДРОНА =====
-- look: body (ball/box/cyl/disc/diamond/skull), size, c1 (корпус), c2 (акцент), mat, eye, rotors, extras
Config.Drones = {
	-- UNCOMMON (белые)
	{ id = "scout", name = "Scout", rarity = "Uncommon",
		desc = "A light scout drone with a night-vision camera.",
		ability = { id = "scan", name = "Scan", cd = 12, desc = "Scans the area and instantly collects scrap from 3 nearby tiles." },
		look = { body = "ball", size = 1, c1 = C(238, 240, 245), c2 = C(120, 125, 135), mat = "SmoothPlastic", eye = C(80, 230, 255), rotors = 2, extras = { "antenna", "camera" } } },
	{ id = "collector", name = "Collector", rarity = "Uncommon",
		desc = "The workhorse of the wastes: grabs anything that isn't nailed down.",
		ability = { id = "double", name = "Double Grab", passive = true, desc = "Passive: 25% chance to collect a double load of scrap." },
		look = { body = "box", size = 1, c1 = C(225, 228, 232), c2 = C(230, 120, 40), mat = "Metal", eye = C(255, 210, 60), rotors = 4, extras = { "claw" } },
		mods = { gather = 1.2 } },
	{ id = "spark", name = "Spark", rarity = "Uncommon",
		desc = "Small but feisty drone running on a homemade battery.",
		ability = { id = "zap", name = "Zap", cd = 6, desc = "Hits the nearest zombie with an electric zap (25 damage)." },
		look = { body = "ball", size = 0.9, c1 = C(245, 245, 235), c2 = C(255, 225, 90), mat = "SmoothPlastic", eye = C(255, 240, 90), rotors = 2, extras = { "coil", "sparks" } } },
	{ id = "buzzsaw", name = "Saw", rarity = "Uncommon",
		desc = "A drone with a circular saw. Zombies don't like it.",
		ability = { id = "blades", name = "Blade Whirl", cd = 8, desc = "Slices every zombie within 12 studs of you (18 damage)." },
		look = { body = "disc", size = 1, c1 = C(205, 208, 215), c2 = C(70, 72, 80), mat = "Metal", eye = C(255, 60, 60), rotors = 3, extras = { "saw" } },
		mods = { damage = 1.6 } },
	{ id = "medic", name = "Medic", rarity = "Uncommon",
		desc = "A field medical drone. Smells of alcohol and hope.",
		ability = { id = "heal", name = "Medkit", cd = 10, desc = "Heals its owner for 25 HP." },
		look = { body = "box", size = 1, c1 = C(250, 250, 250), c2 = C(200, 205, 210), mat = "SmoothPlastic", eye = C(90, 255, 120), rotors = 4, extras = { "cross" } } },

	-- RARE (синие)
	{ id = "cryo", name = "Cryo Drone", rarity = "Rare",
		desc = "A cooling unit turned into a weapon.",
		ability = { id = "frost", name = "Frost Wave", cd = 10, desc = "Freezes zombies within 22 studs: −60% speed for 5 s and 10 damage." },
		look = { body = "diamond", size = 1, c1 = C(120, 190, 255), c2 = C(225, 245, 255), mat = "Ice", eye = C(180, 240, 255), rotors = 4, extras = { "icicles", "snow" } } },
	{ id = "magnet", name = "Magnet", rarity = "Rare",
		desc = "A powerful electromagnet. Scrap flies right to it.",
		ability = { id = "magnet", name = "Magnetic Field", cd = 16, desc = "Pulls scrap from every tile within 7 studs of you." },
		look = { body = "ball", size = 1, c1 = C(40, 110, 230), c2 = C(150, 190, 255), mat = "Metal", eye = C(255, 255, 255), rotors = 4, extras = { "magnet" } } },
	{ id = "volt", name = "Volt", rarity = "Rare",
		desc = "A high-voltage drone with a Tesla coil.",
		ability = { id = "chain", name = "Chain Lightning", cd = 8, desc = "Lightning jumps between 4 zombies (30 damage each)." },
		look = { body = "cyl", size = 1, c1 = C(30, 70, 190), c2 = C(80, 220, 255), mat = "DiamondPlate", eye = C(80, 220, 255), rotors = 2, extras = { "coil", "lightning" } },
		mods = { damage = 1.3 } },
	{ id = "recycler", name = "Recycler", rarity = "Rare",
		desc = "A mini factory on propellers. Recycles scrap in mid-flight.",
		ability = { id = "recycle", name = "Recycling", cd = 20, desc = "Turns 20% of the scrap in your backpack straight into batteries (+10% bonus)." },
		look = { body = "box", size = 1, c1 = C(35, 60, 140), c2 = C(70, 230, 110), mat = "CorrodedMetal", eye = C(90, 255, 140), rotors = 4, extras = { "canister" } } },
	{ id = "turret", name = "Turret", rarity = "Rare",
		desc = "A flying gun nest with twin barrels.",
		ability = { id = "burst", name = "Burst Fire", cd = 7, desc = "Fires a 5-round burst at the nearest zombie (12 damage per bullet)." },
		look = { body = "box", size = 1, c1 = C(70, 120, 200), c2 = C(35, 38, 45), mat = "Metal", eye = C(255, 50, 50), rotors = 4, extras = { "guns" } },
		mods = { damage = 1.4 } },

	-- EPIC (фиолетовые)
	{ id = "plague", name = "Plague", rarity = "Epic",
		desc = "Sprays a toxin that eats through even dead flesh.",
		ability = { id = "cloud", name = "Toxic Cloud", cd = 22, desc = "A cloud for 8 s: poisons zombies (10 damage/s) and slowly collects scrap within 5 studs." },
		look = { body = "ball", size = 1, c1 = C(110, 40, 170), c2 = C(120, 255, 80), mat = "Slate", eye = C(140, 255, 90), rotors = 4, extras = { "canister", "toxic" } } },
	{ id = "phantom", name = "Phantom", rarity = "Epic",
		desc = "An experimental phase drone. Flies without rotors.",
		ability = { id = "phase", name = "Phase Shift", cd = 18, desc = "Teleports around the field and collects 6 random tiles with an x1.5 bonus." },
		look = { body = "diamond", size = 1, c1 = C(170, 90, 255), c2 = C(230, 200, 255), mat = "Glass", eye = C(240, 220, 255), rotors = 0, extras = { "ghost" } } },
	{ id = "inferno", name = "Inferno", rarity = "Epic",
		desc = "A flamethrower drone. Always burning inside.",
		ability = { id = "nova", name = "Firestorm", cd = 15, desc = "A wave of fire burns zombies within 22 studs (75 damage)." },
		look = { body = "box", size = 1, c1 = C(90, 30, 140), c2 = C(255, 120, 30), mat = "Basalt", eye = C(255, 150, 40), rotors = 4, extras = { "flame", "vents" } },
		mods = { damage = 1.3 } },
	{ id = "overclock", name = "Overclock", rarity = "Epic",
		desc = "A command drone with an overclocked CPU.",
		ability = { id = "overclock", name = "Overclock", cd = 30, desc = "Overclocks the whole swarm: gather and attack speed x1.35 for 8 s. Multiple Overclocks don't stack." },
		look = { body = "cyl", size = 1, c1 = C(140, 50, 220), c2 = C(255, 90, 255), mat = "Metal", eye = C(255, 120, 255), rotors = 4, extras = { "speedtrail" } } },
	{ id = "drill", name = "Driller", rarity = "Epic",
		desc = "A mining drone with a diamond drill. Digs scrap up from underground.",
		ability = { id = "quake", name = "Seismic Drill", cd = 16, desc = "Bores into the ground: collects tiles within 5 studs x1.6 and stuns zombies within 10 studs (−60% speed for 3 s, 20 damage)." },
		look = { body = "cyl", size = 1, c1 = C(120, 50, 190), c2 = C(255, 140, 30), mat = "Metal", eye = C(255, 160, 50), rotors = 4, extras = { "drilldust" } },
		mods = { gather = 1.1, speed = 0.9 } },

	-- LEGENDARY (жёлтые)
	{ id = "goliath", name = "Goliath", rarity = "Legendary",
		desc = "A heavy combat drone with an orbital strike targeter.",
		ability = { id = "orbital", name = "Orbital Strike", cd = 22, desc = "A strike from orbit: 400 damage within 20 studs and x2 scrap collection within 8 studs." },
		look = { body = "box", size = 1.3, c1 = C(255, 195, 30), c2 = C(40, 35, 30), mat = "DiamondPlate", eye = C(255, 80, 30), rotors = 6, extras = { "cannon", "antenna" } },
		mods = { damage = 1.3 } },
	{ id = "midas", name = "Midas", rarity = "Legendary",
		desc = "Everything it touches turns to gold.",
		ability = { id = "gold", name = "Golden Touch", cd = 24, desc = "12 nearby tiles turn golden for 18 s and give x5 scrap." },
		look = { body = "ball", size = 1.1, c1 = C(255, 205, 50), c2 = C(255, 245, 200), mat = "Foil", eye = C(255, 255, 255), rotors = 4, extras = { "sparkles" } },
		mods = { gather = 1.2 } },
	{ id = "queen", name = "Swarm Queen", rarity = "Legendary",
		desc = "A mother drone. Builds mini drones in mid-flight.",
		ability = { id = "swarm", name = "Swarm", cd = 30, desc = "Releases 6 mini drones for 18 s that collect scrap alongside the swarm." },
		look = { body = "diamond", size = 1.15, c1 = C(255, 180, 40), c2 = C(130, 70, 15), mat = "Metal", eye = C(255, 120, 0), rotors = 4, extras = { "crown", "wings", "orbit" } } },
	{ id = "tempest", name = "Stormbringer", rarity = "Legendary",
		desc = "A weather drone that learned to summon storms.",
		ability = { id = "storm", name = "Storm Front", cd = 30, desc = "A storm over the field for 10 s: every second, lightning hits 2 zombies (45 damage) and knocks scrap out of 2 nearby tiles x1.5." },
		look = { body = "disc", size = 1.1, c1 = C(255, 200, 40), c2 = C(30, 40, 80), mat = "Metal", eye = C(110, 210, 255), rotors = 4, extras = { "lightning", "storm" } },
		mods = { damage = 1.2, speed = 1.1 } },

	-- MYTHIC (радужные)
	{ id = "prism", name = "Prism", rarity = "Mythic",
		desc = "A crystal drone that refracts light into pure energy.",
		ability = { id = "prism", name = "Rainbow Resonance", cd = 40, desc = "All scrap collected x2 for 15 s. Multiple Prisms don't stack." },
		look = { body = "diamond", size = 1.15, c1 = C(255, 255, 255), c2 = C(255, 255, 255), mat = "Glass", eye = C(255, 255, 255), rotors = 4, extras = { "prism", "orbit", "sparkles" } } },
	{ id = "necro", name = "Necrodrone", rarity = "Mythic",
		desc = "Built from the skull of the first zombie. They say it can hear the dead.",
		ability = { id = "reap", name = "Soul Harvest", cd = 30, desc = "Takes 50% health from every zombie on the field (3000 to the boss), x2 reward for them." },
		look = { body = "skull", size = 1.15, c1 = C(30, 28, 34), c2 = C(255, 255, 255), mat = "Slate", eye = C(0, 255, 200), rotors = 4, extras = { "souls", "spikes" } },
		mods = { damage = 1.3 } },
	{ id = "chrono", name = "Chronos", rarity = "Mythic",
		desc = "Clockwork from the future. To it, time is just another resource.",
		ability = { id = "timewarp", name = "Time Loop", cd = 40, desc = "Rewinds time: tiles within 16 studs refill, zombies on the field are slowed for 6 s, and the swarm works x1.6 faster for 12 s." },
		look = { body = "disc", size = 1.15, c1 = C(230, 190, 110), c2 = C(90, 230, 255), mat = "Metal", eye = C(120, 240, 255), rotors = 4, extras = { "clock", "sparkles" } },
		mods = { speed = 1.25 } },

	-- SECRET (красный)
	{ id = "apocalypse", name = "Apocalypse", rarity = "Secret",
		desc = "The “Omega” prototype. It was never supposed to exist.",
		ability = { id = "doomsday", name = "Doomsday", cd = 45, desc = "Nuclear strike: takes 70% health from every zombie (8000 to the boss), collects scrap within 20 studs x3 and gives x3 gathering for 15 s." },
		look = { body = "box", size = 1.4, c1 = C(28, 14, 16), c2 = C(255, 25, 30), mat = "CorrodedMetal", eye = C(255, 0, 0), rotors = 6, extras = { "spikes", "flame", "cannon" } } },
	{ id = "singularity", name = "Singularity", rarity = "Secret",
		desc = "A tiny black hole is locked in its core. Better not look inside.",
		ability = { id = "blackhole", name = "Event Horizon", cd = 55, desc = "A black hole for 6 s: every second it takes 12% health from zombies within 25 studs (1500 to the boss) and sucks in scrap from tiles within 14 studs x1.5. x2 reward for kills." },
		look = { body = "ball", size = 1.35, c1 = C(14, 10, 18), c2 = C(255, 30, 50), mat = "Basalt", eye = C(255, 40, 60), rotors = 6, extras = { "void" } },
		mods = { gather = 1.1 } },
}

-- ===== ХЭЛЛОУИН: 8 ДРОНОВ ИЗ ХЭЛЛОУИНСКОЙ ГАЧИ =====
-- event = "halloween": такие дроны не выпадают в обычной гаче и капсулах, только в «Тыквенном котле»
local HALLOWEEN_DRONES = {
	{ id = "gourd", name = "Gourdling", rarity = "Uncommon", event = "halloween",
		desc = "A carved pumpkin that learned to fly. Still smells of pie.",
		ability = { id = "pumpkinbomb", name = "Pumpkin Bomb", cd = 8, desc = "Lobs a pumpkin at the nearest zombie: 22 damage to every zombie within 8 studs of the impact." },
		look = { body = "ball", size = 1, c1 = C(255, 140, 30), c2 = C(60, 120, 40), mat = "SmoothPlastic", eye = C(255, 220, 60), rotors = 4, extras = { "candle" } } },
	{ id = "batbot", name = "Bat Bot", rarity = "Uncommon", event = "halloween",
		desc = "Sleeps upside down on the charging station. Sees in the dark with sonar.",
		ability = { id = "echo", name = "Echo Swoop", cd = 10, desc = "Sonar finds 3 tiles within 14 studs and collects them x1.1." },
		look = { body = "ball", size = 0.95, c1 = C(70, 66, 80), c2 = C(150, 40, 60), mat = "Metal", eye = C(255, 50, 60), rotors = 2, extras = { "bats" } } },
	{ id = "candycorn", name = "Candy Corn", rarity = "Rare", event = "halloween",
		desc = "Pure sugar on propellers. Nobody knows who built it, or why.",
		ability = { id = "sugar", name = "Sugar Rush", cd = 18, desc = "Gives you 2 stacks of Speed Boost and collects tiles within 6 studs x0.8." },
		look = { body = "diamond", size = 1, c1 = C(255, 170, 40), c2 = C(255, 250, 235), mat = "SmoothPlastic", eye = C(255, 255, 255), rotors = 4, extras = { "sparkles" } } },
	{ id = "spider", name = "Widow", rarity = "Rare", event = "halloween",
		desc = "Eight legs, eight eyes, one goal: keep zombies stuck in place.",
		ability = { id = "web", name = "Web Trap", cd = 10, desc = "Webs every zombie within 20 studs: −60% speed for 6 s and 15 damage." },
		look = { body = "ball", size = 1, c1 = C(40, 70, 160), c2 = C(220, 225, 235), mat = "Metal", eye = C(90, 230, 255), rotors = 4, extras = { "web" } },
		mods = { damage = 1.2 } },
	{ id = "wraith", name = "Wraith", rarity = "Epic", event = "halloween",
		desc = "A restless spirit bound to a drone core. It never stops wandering the fields.",
		ability = { id = "haunt", name = "Haunting", cd = 16, desc = "Haunts the field: hits up to 5 zombies within 26 studs for 50 damage and collects 5 random tiles nearby x1.3." },
		look = { body = "diamond", size = 1.05, c1 = C(120, 60, 190), c2 = C(200, 160, 255), mat = "Glass", eye = C(220, 180, 255), rotors = 4, extras = { "ghost", "wisps" } } },
	{ id = "jackodrone", name = "Jack-o'-Drone", rarity = "Legendary", event = "halloween",
		desc = "The king of the pumpkin patch. Its candle has been burning for a hundred years.",
		ability = { id = "lantern", name = "Lantern Blaze", cd = 24, desc = "A blast of lantern fire: 260 damage within 18 studs and tiles within 10 studs collected x2." },
		look = { body = "ball", size = 1.2, c1 = C(255, 150, 30), c2 = C(40, 30, 20), mat = "SmoothPlastic", eye = C(255, 200, 40), rotors = 4, extras = { "candle", "flame", "sparkles" } },
		mods = { damage = 1.2 } },
	{ id = "reaper", name = "Reaper", rarity = "Mythic", event = "halloween",
		desc = "It comes for every zombie in the end. With a drone-sized scythe.",
		ability = { id = "harvest", name = "Harvest Moon", cd = 38, desc = "One swing of the scythe takes 40% health from every zombie on the field (2500 to the boss, x2 reward) and collects tiles within 12 studs x1.5." },
		look = { body = "skull", size = 1.2, c1 = C(25, 22, 30), c2 = C(170, 255, 120), mat = "Slate", eye = C(150, 255, 110), rotors = 4, extras = { "souls", "wisps" } },
		mods = { damage = 1.3 } },
	{ id = "pumpkinking", name = "Pumpkin King", rarity = "Secret", event = "halloween",
		desc = "Ruler of Halloween night. When it rises, the whole field burns orange.",
		ability = { id = "terror", name = "Night of Terror", cd = 50, desc = "Halloween night falls on the field: takes 70% health from every zombie (8000 to the boss, x2 reward), collects tiles within 18 studs x3, gives x2.5 gathering for 15 s and +3 🎃." },
		look = { body = "ball", size = 1.4, c1 = C(255, 110, 20), c2 = C(30, 10, 40), mat = "SmoothPlastic", eye = C(255, 60, 20), rotors = 6, extras = { "flame", "candle", "wisps" } } },
}
for _, d in ipairs(HALLOWEEN_DRONES) do
	table.insert(Config.Drones, d)
end

-- Мини-дрон (призывается Королевой роя, в гаче не выпадает)
Config.MiniDrone = { id = "mini", name = "Mini Drone", rarity = "Legendary",
	look = { body = "ball", size = 0.6, c1 = C(255, 200, 60), c2 = C(90, 55, 10), mat = "Metal", eye = C(255, 120, 0), rotors = 2, extras = {} },
	mods = { gather = 0.5, damage = 0 } }

Config.DroneById = {}
Config.DronesByRarity = {} -- пул обычной гачи и капсул (без дронов событий)
Config.EventPool = {} -- event -> rarity -> { дроны }
for i, d in ipairs(Config.Drones) do
	d.index = i
	Config.DroneById[d.id] = d
	if d.event then
		Config.EventPool[d.event] = Config.EventPool[d.event] or {}
		local pool = Config.EventPool[d.event]
		pool[d.rarity] = pool[d.rarity] or {}
		table.insert(pool[d.rarity], d)
	else
		Config.DronesByRarity[d.rarity] = Config.DronesByRarity[d.rarity] or {}
		table.insert(Config.DronesByRarity[d.rarity], d)
	end
end

-- ===== ХЭЛЛОУИН (событие) =====
-- enabled = false выключает всё событие разом: тыквы на полях, ночь с призраками, тыквенного Колосса,
-- ведьму с квестами и обменом, хэллоуинскую гачу и декор. Дроны и тыквы у игроков остаются.
Config.Halloween = {
	enabled = true,
	-- котёл-гача стоит у каменных столбов за северо-восточным углом базы (ведьма осталась в роще за южной стеной);
	-- tp — куда ставит телепорт (карта и кнопка в HUD): сразу за аркой-входом, лицом к котлу
	zone = { center = Vector3.new(50, 0, 84), radius = 22, tp = Vector3.new(34, 4, 84) },
	-- тыквы на полях: столько светящихся тыкв на поле одновременно, сколько тыкв даёт сбор (по номеру поля)
	pumpkins = { perField = 4, value = { 1, 2, 3, 4, 6 }, respawn = { 40, 80 } },
	-- Призрачная ночь: ночь длиннее, часть зомби — призраки в костюмах
	night = 900,
	ghosts = { chance = 0.4, hp = 1.3, pumpkins = { 1, 3 }, consumMult = 2 },
	-- Тыквенный Колосс: тыквы и трофей за победу
	boss = { pumpkins = { 40, 90 }, name = "Pumpkin Colossus" },
	-- гача «Тыквенный котёл»: крутки за тыквы; шансы и гарант те же, что у обычной гачи (ниже)
	gacha = {
		pullCost = 30,
		pull10Cost = 300,
	},
}
do
	local w = {}
	for key, r in pairs(Config.Rarities) do
		w[key] = r.weight
	end
	Config.Halloween.gacha.weights = w
	Config.Halloween.gacha.pity = Config.Pity
end

function Config.HalloweenOn()
	return Config.Halloween.enabled == true
end

function Config.HalloweenChanceText(rarity)
	local pct = Config.Halloween.gacha.weights[rarity] / 100
	local s = string.format("%.2f", pct)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s .. "%"
end

-- ===== ПОЛЯ =====
-- Поле — сетка плиток 4x4 (как цветы в BSS). На каждой плитке лежит один из ресурсов поля:
-- у поля 1–3 вида ресурсов, первый — главный (его больше всего). Собранная плитка
-- проседает и плавно поднимается обратно по мере восстановления.
Config.TileSize = 4
Config.TileDepth = 1.2 -- насколько опускается пустая плитка
Config.TileRegen = 0.025 -- восстановление полноты плитки в секунду
Config.TileTake = 0.08 -- сколько полноты забирает один сбор

-- Ресурсы: все лежат в общем рюкзаке и перерабатываются в батареи одновременно.
Config.Resources = {
	{ id = "rust", name = "Scrap Metal", color = C(255, 160, 90), field = "wasteland" },
	{ id = "chips", name = "Microchips", color = C(90, 220, 140), field = "deadcity" },
	{ id = "bio", name = "Biomass", color = C(170, 255, 90), field = "swamp" },
	{ id = "uranium", name = "Uranium", color = C(200, 255, 70), field = "radzone" },
	{ id = "brass", name = "Shell Casings", color = C(255, 210, 110), field = "military" },
}
Config.ResourceById, Config.ResourceByField = {}, {}
for i, r in ipairs(Config.Resources) do
	r.index = i
	Config.ResourceById[r.id] = r
	Config.ResourceByField[r.field] = r
end

-- Карта «лестницей» (как в BSS): база внизу, главная дорога идёт на север,
-- каждый следующий ярус выше на 12 и открывается при большем числе дронов.
-- tier = номер яруса (0 — у базы)
-- res = ресурсы поля {id, доля %} (первый — главный); tileMult — средний множитель сбора плиток
Config.Fields = {
	{ id = "wasteland", name = "Wasteland", req = 0, mult = 1, center = Vector3.new(-58, 0, 100), size = 48, gate = "east", tier = 0,
		res = { { "rust", 75 }, { "chips", 25 } }, tileMult = 1.09, ground = { mat = "SmoothPlastic", color = C(222, 178, 106) },
		zombies = { max = 5, hp = 150, damage = 4, reward = 30, speed = 7, name = "Walker" } },
	{ id = "deadcity", name = "Dead City", req = 5, mult = 2.5, center = Vector3.new(58, 12, 180), size = 48, gate = "west", tier = 1,
		res = { { "chips", 65 }, { "rust", 25 }, { "brass", 10 } }, tileMult = 1.17, ground = { mat = "SmoothPlastic", color = C(150, 160, 178) },
		zombies = { max = 6, hp = 400, damage = 9, reward = 90, speed = 8, name = "Townie" } },
	-- низина на 2-м ярусе: поле ниже уровня яруса, вокруг топь и вода
	{ id = "swamp", name = "Rotten Swamp", req = 10, mult = 5, center = Vector3.new(-58, 20, 260), size = 48, gate = "east", tier = 2,
		res = { { "bio", 100 } }, tileMult = 1.37, ground = { mat = "SmoothPlastic", color = C(92, 178, 74) },
		zombies = { max = 7, hp = 900, damage = 14, reward = 200, speed = 7, name = "Drowner" } },
	{ id = "radzone", name = "Radioactive Zone", req = 15, mult = 9, center = Vector3.new(58, 36, 340), size = 48, gate = "west", tier = 3,
		res = { { "uranium", 65 }, { "bio", 25 }, { "chips", 10 } }, tileMult = 1.34, ground = { mat = "SmoothPlastic", color = C(132, 204, 62) },
		zombies = { max = 8, hp = 2000, damage = 20, reward = 400, speed = 9, name = "Mutant" } },
	-- вершина: последний ярус, главная дорога упирается прямо в ворота
	{ id = "military", name = "Military Base", req = 25, mult = 16, center = Vector3.new(0, 60, 530), size = 48, gate = "south", tier = 5,
		res = { { "brass", 70 }, { "rust", 30 } }, tileMult = 1.18, ground = { mat = "SmoothPlastic", color = C(190, 178, 112) },
		zombies = { max = 9, hp = 12000, damage = 30, reward = 1500, speed = 10, name = "Soldier" } },
	-- логово босса: без лома, один гигантский зомби на 500 000 HP (рассчитан на группу)
	{ id = "boss", name = "Colossus Lair", req = 20, mult = 0, center = Vector3.new(-70, 48, 430), size = 84, gate = "east", tier = 4, boss = true,
		zombies = { max = 0, hp = 500000, damage = 40, reward = 0, speed = 9, name = "Colossus" } },
}

-- Босс: если рядом никого нет 3 минуты — здоровье восстанавливается до максимума
Config.Boss = {
	resetTime = 180,
	respawnTime = 120,
	slamDamage = 30,
	slamRadius = 16,
	slamCd = 6,
	meleeCd = 2,
	-- награда каждому, кто нанёс хотя бы 0.5% урона
	minShare = 0.005,
	gems = { 25, 60 },
	batteries = 2000000,
	items = { 3, 6 },
}

-- Смена дня и ночи (секунды). Ночью зомби бьют x2, но награда тоже x2
Config.DayNight = { day = 1800, night = 600, damageMult = 2, rewardMult = 2 }
if Config.Halloween.enabled then
	Config.DayNight.night = Config.Halloween.night -- Призрачная ночь длиннее
end

-- Границы карты: невидимые стены по подножию гор (X/Z) и потолок (Y)
Config.MapBounds = { minX = -158, maxX = 148, minZ = -92, maxZ = 596, yMin = -40, yMax = 260 }

-- Ускорение, которое появляется на полях
Config.SpeedPickup = { perField = 2, minDelay = 15, maxDelay = 45, bonus = 10, duration = 20, lifetime = 60 }

-- Магазин стоит справа от базы (вход смотрит на запад, к восточному выходу базы)
Config.ShopZone = { center = Vector3.new(98, 0, 0), radius = 48 }

-- гача стоит слева от базы (арка смотрит на восток, к западным воротам базы)
Config.GachaZone = { center = Vector3.new(-100, 0, 0), radius = 40 }
Config.BasePos = Vector3.new(0, 4, -6)

-- ===== ЭНЕРГИЯ ДРОНОВ =====
-- workTime: сколько секунд активной работы хватает полного заряда (+5 минут к прежним 150–270 сек)
-- chargeTime: сколько секунд заряжается с 0 до 100% на станции (максимум 90 сек у SECRET)
Config.Energy = {
	workTime = { Uncommon = 450, Rare = 470, Epic = 490, Legendary = 515, Mythic = 540, Secret = 570 },
	chargeTime = { Uncommon = 30, Rare = 42, Epic = 54, Legendary = 66, Mythic = 78, Secret = 90 },
}
-- ===== УЛЬИ-ЗАРЯДКИ (соты на стене) =====
-- 6 ульев на южной стене базы, у каждого 50 сот (5 столбцов x 10 рядов)
Config.Hive = { count = 6, maxCells = 50, startCells = 3, cols = 5, dx = 1.6, dy = 1.6 }
Config.HiveFrames = {}
for i, x in ipairs({ -38, -27, -16, 16, 27, 38 }) do
	-- центр панели сот, лицом на север (к спавну)
	Config.HiveFrames[i] = CFrame.lookAt(Vector3.new(x, 12.4, -38), Vector3.new(x, 12.4, -30))
end
-- смещение соты №i от центра панели (заполняются снизу вверх)
function Config.CellOffset(i, forward)
	local H = Config.Hive
	local col = (i - 1) % H.cols
	local row = math.floor((i - 1) / H.cols)
	local x = (col - (H.cols - 1) / 2) * H.dx
	local y = -7.2 + row * H.dy
	return CFrame.new(x, y, -(forward or 0))
end
-- цена n-го гнезда (первые 3 бесплатны). Гнёзда = размер роя, поэтому это главный долгий
-- «гейт» прогрессии, как ячейки улья в BSS: каждое следующее заметно дороже предыдущего.
-- Числа подобраны моделью прогрессии (balance/tune.py в файлах проекта).
-- @tune CellCost
function Config.CellCost(n)
	return math.floor(4000 * 1.53 ^ (math.min(n, 25) - 4) * 1.1 ^ math.max(0, n - 25) / 10 + 0.5) * 10
end
-- Мастерская ячеек (покупка новых сот)
Config.CellShop = { center = Vector3.new(-28, 1, -18), radius = 13 }
-- оставлено для совместимости (телепорт «станция» ведёт к своему улью)
Config.ChargeStation = { center = Vector3.new(0, 1, -30), radius = 14 }

-- ===== ПЕРЕРАБОТЧИК (как делание мёда в BSS: перерабатывает постепенно) =====
-- скорость в секунду = baseRate + вместимость * capRate  (первый рюкзак ~5 сек, дальше ~10–20 сек)
Config.Converter = { pad = Vector3.new(25, 1, 22), radius = 8, baseRate = 48, capRate = 0.05 }

-- Быстрое перемещение (вкладка «Карта»)
Config.Locations = {
	{ id = "base", name = "Survivor Base", desc = "Recycler and charging stations" },
	{ id = "gacha", name = "Drone Lab", desc = "Gacha: new drones" },
	{ id = "shop", name = "Shop", desc = "Weapons, tools, gear" },
	{ id = "halloween", name = "Pumpkin Cauldron", desc = "Halloween drone gacha", event = "halloween" },
	{ id = "wasteland", field = true },
	{ id = "deadcity", field = true },
	{ id = "swamp", field = true },
	{ id = "radzone", field = true },
	{ id = "military", field = true },
	{ id = "boss", field = true },
}

-- ===== РЮКЗАК =====
Config.MaxBagLevel = 20
-- @tune BagCapacity
function Config.BagCapacity(level)
	return math.floor(300 * 1.6 ^ (level - 1))
end
-- @tune BagCost
function Config.BagCost(level)
	if level >= Config.MaxBagLevel then
		return nil
	end
	return math.floor(400 * 2.7 ^ (level - 1) / 10 + 0.5) * 10
end
-- материалы для улучшения рюкзака с уровня N на N+1 (находки из куч лома)
Config.BagMats = {
	{ nut = 1 },
	{ nut = 2, wire = 1 },
	{ wire = 3, oldbattery = 1 },
	{ tooth = 3, cans = 1 },
	{ cog = 2, nut = 6 },
	{ cog = 3, chip = 2 },
	{ chip = 3, dogtag = 2 },
	{ bandage = 3, energydrink = 2, cog = 4 },
	{ dronecell = 1, chip = 5 },
	{ slime = 2, keycard = 1 },
	{ radcrystal = 2, dronecell = 2 },
	{ keycard = 2, slime = 3 },
	{ gemshard = 2, radcrystal = 3 },
	{ blueprint = 1, dronecell = 4 },
	{ plutonium = 1, chip = 10 },
	{ mutantheart = 1, radcrystal = 5 },
	{ goldbar = 1, blueprint = 1 },
	{ plutonium = 2, slime = 6 },
	{ omegacore = 1, goldbar = 1 },
}

return Config
