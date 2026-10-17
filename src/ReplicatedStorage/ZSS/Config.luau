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
Config.StartGems = 50
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
	Uncommon = { order = 1, label = "UNCOMMON", ru = "Белый", color = C(235, 238, 245), weight = 7700 },
	Rare = { order = 2, label = "RARE", ru = "Синий", color = C(50, 140, 255), weight = 1700 },
	Epic = { order = 3, label = "EPIC", ru = "Фиолетовый", color = C(175, 70, 255), weight = 450 },
	Legendary = { order = 4, label = "LEGENDARY", ru = "Жёлтый", color = C(255, 205, 35), weight = 120 },
	Mythic = { order = 5, label = "MYTHIC", ru = "Радужный", color = C(255, 120, 220), weight = 28, rainbow = true },
	Secret = { order = 6, label = "SECRET", ru = "Красный", color = C(255, 30, 40), weight = 2 },
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

-- ===== 20 ДРОНОВ =====
-- look: body (ball/box/cyl/disc/diamond/skull), size, c1 (корпус), c2 (акцент), mat, eye, rotors, extras
Config.Drones = {
	-- UNCOMMON (белые)
	{ id = "scout", name = "Разведчик", rarity = "Uncommon",
		desc = "Лёгкий дрон-разведчик с камерой ночного видения.",
		ability = { id = "scan", name = "Сканирование", cd = 12, desc = "Сканирует местность и мгновенно собирает лом с 3 плит рядом." },
		look = { body = "ball", size = 1, c1 = C(238, 240, 245), c2 = C(120, 125, 135), mat = "SmoothPlastic", eye = C(80, 230, 255), rotors = 2, extras = { "antenna", "camera" } } },
	{ id = "collector", name = "Сборщик", rarity = "Uncommon",
		desc = "Рабочая лошадка пустошей: хватает всё, что плохо лежит.",
		ability = { id = "double", name = "Двойной захват", passive = true, desc = "Пассивно: 25% шанс собрать двойную порцию лома." },
		look = { body = "box", size = 1, c1 = C(225, 228, 232), c2 = C(230, 120, 40), mat = "Metal", eye = C(255, 210, 60), rotors = 4, extras = { "claw" } },
		mods = { gather = 1.2 } },
	{ id = "spark", name = "Искра", rarity = "Uncommon",
		desc = "Маленький, но кусачий дрон на самодельном аккумуляторе.",
		ability = { id = "zap", name = "Разряд", cd = 6, desc = "Бьёт ближайшего зомби электрическим разрядом (25 урона)." },
		look = { body = "ball", size = 0.9, c1 = C(245, 245, 235), c2 = C(255, 225, 90), mat = "SmoothPlastic", eye = C(255, 240, 90), rotors = 2, extras = { "coil", "sparks" } } },
	{ id = "buzzsaw", name = "Пила", rarity = "Uncommon",
		desc = "Дрон с циркулярной пилой. Зомби его не любят.",
		ability = { id = "blades", name = "Вихрь лезвий", cd = 8, desc = "Режет всех зомби в радиусе 12 вокруг тебя (18 урона)." },
		look = { body = "disc", size = 1, c1 = C(205, 208, 215), c2 = C(70, 72, 80), mat = "Metal", eye = C(255, 60, 60), rotors = 3, extras = { "saw" } },
		mods = { damage = 1.6 } },
	{ id = "medic", name = "Медик", rarity = "Uncommon",
		desc = "Полевой медицинский дрон. Пахнет спиртом и надеждой.",
		ability = { id = "heal", name = "Аптечка", cd = 10, desc = "Лечит владельца на 25 HP." },
		look = { body = "box", size = 1, c1 = C(250, 250, 250), c2 = C(200, 205, 210), mat = "SmoothPlastic", eye = C(90, 255, 120), rotors = 4, extras = { "cross" } } },

	-- RARE (синие)
	{ id = "cryo", name = "Криодрон", rarity = "Rare",
		desc = "Охлаждающая установка, превращённая в оружие.",
		ability = { id = "frost", name = "Ледяная волна", cd = 10, desc = "Замораживает зомби в радиусе 22: −60% скорости на 5 сек и 10 урона." },
		look = { body = "diamond", size = 1, c1 = C(120, 190, 255), c2 = C(225, 245, 255), mat = "Ice", eye = C(180, 240, 255), rotors = 4, extras = { "icicles", "snow" } } },
	{ id = "magnet", name = "Магнит", rarity = "Rare",
		desc = "Мощный электромагнит. Лом сам летит к нему.",
		ability = { id = "magnet", name = "Магнитное поле", cd = 14, desc = "Притягивает лом со всех плит в радиусе 9 вокруг тебя." },
		look = { body = "ball", size = 1, c1 = C(40, 110, 230), c2 = C(150, 190, 255), mat = "Metal", eye = C(255, 255, 255), rotors = 4, extras = { "magnet" } } },
	{ id = "volt", name = "Вольт", rarity = "Rare",
		desc = "Высоковольтный дрон с катушкой Теслы.",
		ability = { id = "chain", name = "Цепная молния", cd = 8, desc = "Молния перескакивает между 4 зомби (30 урона каждому)." },
		look = { body = "cyl", size = 1, c1 = C(30, 70, 190), c2 = C(80, 220, 255), mat = "DiamondPlate", eye = C(80, 220, 255), rotors = 2, extras = { "coil", "lightning" } },
		mods = { damage = 1.3 } },
	{ id = "recycler", name = "Переработчик", rarity = "Rare",
		desc = "Мини-завод на пропеллерах. Перерабатывает лом прямо в полёте.",
		ability = { id = "recycle", name = "Переработка", cd = 20, desc = "Перерабатывает 20% лома из рюкзака прямо в батареи (+10% бонус)." },
		look = { body = "box", size = 1, c1 = C(35, 60, 140), c2 = C(70, 230, 110), mat = "CorrodedMetal", eye = C(90, 255, 140), rotors = 4, extras = { "canister" } } },
	{ id = "turret", name = "Турель", rarity = "Rare",
		desc = "Летающая огневая точка с двумя стволами.",
		ability = { id = "burst", name = "Очередь", cd = 7, desc = "Выпускает очередь из 5 пуль по ближайшему зомби (12 урона за пулю)." },
		look = { body = "box", size = 1, c1 = C(70, 120, 200), c2 = C(35, 38, 45), mat = "Metal", eye = C(255, 50, 50), rotors = 4, extras = { "guns" } },
		mods = { damage = 1.4 } },

	-- EPIC (фиолетовые)
	{ id = "plague", name = "Чумной", rarity = "Epic",
		desc = "Распыляет токсин, который разъедает даже мёртвую плоть.",
		ability = { id = "cloud", name = "Токсичное облако", cd = 18, desc = "Облако на 8 сек: травит зомби (10 урона/сек) и собирает лом в радиусе 6." },
		look = { body = "ball", size = 1, c1 = C(110, 40, 170), c2 = C(120, 255, 80), mat = "Slate", eye = C(140, 255, 90), rotors = 4, extras = { "canister", "toxic" } } },
	{ id = "phantom", name = "Фантом", rarity = "Epic",
		desc = "Экспериментальный фазовый дрон. Летает без винтов.",
		ability = { id = "phase", name = "Фазовый сдвиг", cd = 15, desc = "Телепортируется по полю и собирает 8 случайных плит с бонусом x2." },
		look = { body = "diamond", size = 1, c1 = C(170, 90, 255), c2 = C(230, 200, 255), mat = "Glass", eye = C(240, 220, 255), rotors = 0, extras = { "ghost", "halo" } } },
	{ id = "inferno", name = "Инферно", rarity = "Epic",
		desc = "Огнемётный дрон. Внутри всегда горит.",
		ability = { id = "nova", name = "Огненный шторм", cd = 14, desc = "Огненная волна сжигает зомби в радиусе 25 (90 урона)." },
		look = { body = "box", size = 1, c1 = C(90, 30, 140), c2 = C(255, 120, 30), mat = "Basalt", eye = C(255, 150, 40), rotors = 4, extras = { "flame", "vents" } },
		mods = { damage = 1.3 } },
	{ id = "overclock", name = "Разгон", rarity = "Epic",
		desc = "Командный дрон с разогнанным процессором.",
		ability = { id = "overclock", name = "Разгон", cd = 25, desc = "Разгоняет весь рой: скорость сбора и атаки x2 на 10 сек." },
		look = { body = "cyl", size = 1, c1 = C(140, 50, 220), c2 = C(255, 90, 255), mat = "Metal", eye = C(255, 120, 255), rotors = 4, extras = { "halo", "speedtrail" } } },

	-- LEGENDARY (жёлтые)
	{ id = "goliath", name = "Голиаф", rarity = "Legendary",
		desc = "Тяжёлый боевой дрон с наводчиком орбитального удара.",
		ability = { id = "orbital", name = "Орбитальный удар", cd = 20, desc = "Удар со спутника: 400 урона в радиусе 20 и сбор лома x3 в центре." },
		look = { body = "box", size = 1.3, c1 = C(255, 195, 30), c2 = C(40, 35, 30), mat = "DiamondPlate", eye = C(255, 80, 30), rotors = 6, extras = { "cannon", "antenna" } },
		mods = { damage = 1.3 } },
	{ id = "midas", name = "Мидас", rarity = "Legendary",
		desc = "Всё, к чему он прикасается, становится золотом.",
		ability = { id = "gold", name = "Золотое касание", cd = 25, desc = "10 плит рядом становятся золотыми на 15 сек — они дают x5 лома." },
		look = { body = "ball", size = 1.1, c1 = C(255, 205, 50), c2 = C(255, 245, 200), mat = "Foil", eye = C(255, 255, 255), rotors = 4, extras = { "halo", "sparkles" } },
		mods = { gather = 1.2 } },
	{ id = "queen", name = "Королева роя", rarity = "Legendary",
		desc = "Матка-дрон. Собирает мини-дронов прямо в полёте.",
		ability = { id = "swarm", name = "Рой", cd = 30, desc = "Выпускает 5 мини-дронов на 15 сек, которые собирают лом вместе с роем." },
		look = { body = "diamond", size = 1.15, c1 = C(255, 180, 40), c2 = C(130, 70, 15), mat = "Metal", eye = C(255, 120, 0), rotors = 4, extras = { "crown", "wings", "orbit" } } },

	-- MYTHIC (радужные)
	{ id = "prism", name = "Призма", rarity = "Mythic",
		desc = "Кристаллический дрон, преломляющий свет в чистую энергию.",
		ability = { id = "prism", name = "Радужный резонанс", cd = 35, desc = "Весь собираемый лом x3 на 15 сек." },
		look = { body = "diamond", size = 1.15, c1 = C(255, 255, 255), c2 = C(255, 255, 255), mat = "Glass", eye = C(255, 255, 255), rotors = 4, extras = { "prism", "orbit", "sparkles" } } },
	{ id = "necro", name = "Некродрон", rarity = "Mythic",
		desc = "Собран из черепа первого зомби. Говорят, он слышит мёртвых.",
		ability = { id = "reap", name = "Жатва душ", cd = 30, desc = "Забирает 50% здоровья у всех зомби на поле (боссу — 3000), награда за них x2." },
		look = { body = "skull", size = 1.15, c1 = C(30, 28, 34), c2 = C(255, 255, 255), mat = "Slate", eye = C(0, 255, 200), rotors = 4, extras = { "souls", "spikes" } },
		mods = { damage = 1.3 } },

	-- SECRET (красный)
	{ id = "apocalypse", name = "Апокалипсис", rarity = "Secret",
		desc = "Прототип «Омега». Его не должно было существовать.",
		ability = { id = "doomsday", name = "Судный день", cd = 45, desc = "Ядерный удар: забирает 70% здоровья у всех зомби (боссу — 8000), собирает лом в радиусе 30 x5 и даёт x5 к сбору на 20 сек." },
		look = { body = "box", size = 1.4, c1 = C(28, 14, 16), c2 = C(255, 25, 30), mat = "CorrodedMetal", eye = C(255, 0, 0), rotors = 6, extras = { "spikes", "flame", "halo", "cannon" } } },
}

-- Мини-дрон (призывается Королевой роя, в гаче не выпадает)
Config.MiniDrone = { id = "mini", name = "Мини-дрон", rarity = "Legendary",
	look = { body = "ball", size = 0.6, c1 = C(255, 200, 60), c2 = C(90, 55, 10), mat = "Metal", eye = C(255, 120, 0), rotors = 2, extras = {} },
	mods = { gather = 0.4, damage = 0 } }

Config.DroneById = {}
Config.DronesByRarity = {}
for i, d in ipairs(Config.Drones) do
	d.index = i
	Config.DroneById[d.id] = d
	Config.DronesByRarity[d.rarity] = Config.DronesByRarity[d.rarity] or {}
	table.insert(Config.DronesByRarity[d.rarity], d)
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
	{ id = "rust", name = "Металлолом", color = C(255, 160, 90), field = "wasteland" },
	{ id = "chips", name = "Микросхемы", color = C(90, 220, 140), field = "deadcity" },
	{ id = "bio", name = "Биомасса", color = C(170, 255, 90), field = "swamp" },
	{ id = "uranium", name = "Уран", color = C(200, 255, 70), field = "radzone" },
	{ id = "brass", name = "Гильзы", color = C(255, 210, 110), field = "military" },
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
	{ id = "wasteland", name = "Пустошь", req = 0, mult = 1, center = Vector3.new(-58, 0, 100), size = 48, gate = "east", tier = 0,
		res = { { "rust", 75 }, { "chips", 25 } }, tileMult = 1.09, ground = { mat = "SmoothPlastic", color = C(222, 178, 106) },
		zombies = { max = 5, hp = 150, damage = 4, reward = 30, speed = 7, name = "Ходок" } },
	{ id = "deadcity", name = "Мёртвый город", req = 5, mult = 2.5, center = Vector3.new(58, 12, 180), size = 48, gate = "west", tier = 1,
		res = { { "chips", 65 }, { "rust", 25 }, { "brass", 10 } }, tileMult = 1.17, ground = { mat = "SmoothPlastic", color = C(150, 160, 178) },
		zombies = { max = 6, hp = 400, damage = 9, reward = 90, speed = 8, name = "Горожанин" } },
	-- низина на 2-м ярусе: поле ниже уровня яруса, вокруг топь и вода
	{ id = "swamp", name = "Гнилое болото", req = 10, mult = 5, center = Vector3.new(-58, 20, 260), size = 48, gate = "east", tier = 2,
		res = { { "bio", 100 } }, tileMult = 1.37, ground = { mat = "SmoothPlastic", color = C(92, 178, 74) },
		zombies = { max = 7, hp = 900, damage = 14, reward = 200, speed = 7, name = "Утопленник" } },
	{ id = "radzone", name = "Радиоактивная зона", req = 15, mult = 9, center = Vector3.new(58, 36, 340), size = 48, gate = "west", tier = 3,
		res = { { "uranium", 65 }, { "bio", 25 }, { "chips", 10 } }, tileMult = 1.34, ground = { mat = "SmoothPlastic", color = C(132, 204, 62) },
		zombies = { max = 8, hp = 2000, damage = 20, reward = 400, speed = 9, name = "Мутант" } },
	-- вершина: последний ярус, главная дорога упирается прямо в ворота
	{ id = "military", name = "Военная база", req = 25, mult = 16, center = Vector3.new(0, 60, 530), size = 48, gate = "south", tier = 5,
		res = { { "brass", 70 }, { "rust", 30 } }, tileMult = 1.18, ground = { mat = "SmoothPlastic", color = C(190, 178, 112) },
		zombies = { max = 9, hp = 12000, damage = 30, reward = 1500, speed = 10, name = "Солдат" } },
	-- логово босса: без лома, один гигантский зомби на 500 000 HP (рассчитан на группу)
	{ id = "boss", name = "Логово Колосса", req = 20, mult = 0, center = Vector3.new(-70, 48, 430), size = 84, gate = "east", tier = 4, boss = true,
		zombies = { max = 0, hp = 500000, damage = 40, reward = 0, speed = 9, name = "Колосс" } },
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
	{ id = "base", name = "База выживших", desc = "Переработчик и зарядная станция" },
	{ id = "gacha", name = "Лаборатория дронов", desc = "Гача: новые дроны" },
	{ id = "shop", name = "Магазин", desc = "Оружие, инструменты, снаряжение" },
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
