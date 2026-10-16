-- Магазин: оружие (бить зомби), инструменты (добывать ресурсы) и снаряжение
local C = Color3.fromRGB
local S = {}

S.Slots = {
	{ key = "weapon", name = "Оружие", icon = "⚔" },
	{ key = "tool", name = "Инструменты", icon = "⛏" },
	{ key = "armor", name = "Броня", icon = "🛡" },
	{ key = "helmet", name = "Шлемы", icon = "⛑" },
	{ key = "gloves", name = "Перчатки", icon = "🧤" },
	{ key = "boots", name = "Ботинки", icon = "🥾" },
	{ key = "backpack", name = "Рюкзаки", icon = "🎒" },
	{ key = "consumable", name = "Расходники", icon = "🧪" },
}

-- хотбар: ячейка 1 — оружие, ячейка 2 — инструмент (с собой только по одному), дальше расходники
S.HotbarWeapons = 2
S.HotbarOrder = { "weapon", "tool" }
S.HotbarConsumables = { "medkit", "energycell", "grenade", "adrenaline" }

-- грейд предмета (цвет рамки)
S.Grades = {
	[1] = { name = "Обычный", color = C(200, 200, 200) },
	[2] = { name = "Надёжный", color = C(110, 220, 80) },
	[3] = { name = "Военный", color = C(60, 150, 255) },
	[4] = { name = "Элитный", color = C(180, 80, 255) },
	[5] = { name = "Прототип", color = C(255, 190, 30) },
	[6] = { name = "Реликт", color = C(255, 70, 110) },
	[7] = { name = "Абсолют", color = C(70, 255, 230) },
}

S.DefaultWeapon = "shiv"
S.DefaultTool = "scraper"
S.DefaultBackpack = "bp_old"

S.Items = {
	-- ===== ОРУЖИЕ (только урон по зомби) =====
	{ id = "shiv", slot = "weapon", name = "Заточка", price = 0, grade = 1,
		desc = "Самодельный нож из арматуры и изоленты. Лучше, чем ничего.",
		stats = { dmg = 7, radius = 4.5, cd = 0.4, fx = "none" } },
	{ id = "pipe", slot = "weapon", name = "Ржавая труба", price = 3000, grade = 1,
		desc = "Кусок водопровода с изолентой. Классика апокалипсиса.",
		stats = { dmg = 12, radius = 5, cd = 0.45, fx = "none" } },
	{ id = "bat", slot = "weapon", name = "Бита с гвоздями", price = 8200, grade = 2,
		desc = "Деревянная бита, утыканная гвоздями и колючкой.",
		stats = { dmg = 20, radius = 5.5, cd = 0.45, fx = "none" } },
	{ id = "machete", slot = "weapon", name = "Мачете", price = 23000, grade = 2,
		desc = "Широкий клинок для джунглей — и для зомби.",
		stats = { dmg = 32, radius = 6, cd = 0.4, fx = "none" } },
	{ id = "fireaxe", slot = "weapon", name = "Пожарный топор", price = 62000, grade = 3,
		desc = "Красный топор с пожарного щита. Поджигает зомби.",
		stats = { dmg = 52, radius = 6.5, cd = 0.45, fx = "fire" } },
	{ id = "sledge", slot = "weapon", name = "Кувалда", price = 170000, grade = 3,
		desc = "Тяжёлая кувалда. Каждый удар — ударная волна.",
		stats = { dmg = 90, radius = 8, cd = 0.6, fx = "shock" } },
	{ id = "chainsaw", slot = "weapon", name = "Бензопила", price = 470000, grade = 4,
		desc = "Ревущая бензопила. Очень быстрые удары.",
		stats = { dmg = 85, radius = 7, cd = 0.25, fx = "sparks" } },
	{ id = "baton", slot = "weapon", name = "Электродубина", price = 1300000, grade = 4,
		desc = "Шоковая дубина с катушкой. Бьёт молнией по всем рядом.",
		stats = { dmg = 180, radius = 9, cd = 0.4, fx = "zap" } },
	{ id = "scythe", slot = "weapon", name = "Плазменная коса", price = 3600000, grade = 5,
		desc = "Прототип с плазменным лезвием. Режет всё в большом радиусе.",
		stats = { dmg = 310, radius = 11, cd = 0.35, fx = "plasma" } },

	-- ===== ИНСТРУМЕНТЫ (только добыча ресурсов с полей) =====
	{ id = "scraper", slot = "tool", name = "Скребок", price = 0, grade = 1,
		desc = "Стартовая лопата-скребок. Гребёт всё, что лежит на поле.",
		stats = { gather = 2, radius = 4.5, cd = 0.45, fx = "none" } },
	{ id = "shovel", slot = "tool", name = "Сапёрная лопата", price = 1500, grade = 1,
		desc = "Короткая армейская лопата. Зачёрпывает в полтора раза больше.",
		stats = { gather = 3, radius = 4.75, cd = 0.45, fx = "none" } },
	{ id = "pickaxe", slot = "tool", name = "Кирка", price = 4400, grade = 2,
		desc = "Стальная кирка. Разбивает слёжавшиеся кучи.",
		stats = { gather = 4, radius = 5, cd = 0.44, fx = "none" } },
	{ id = "magrake", slot = "tool", name = "Магнитные грабли", price = 13000, grade = 3,
		desc = "Грабли с магнитами — мелкие детали липнут сами.",
		stats = { gather = 5, radius = 5.25, cd = 0.43, fx = "sparks" } },
	{ id = "jackhammer", slot = "tool", name = "Отбойный молоток", price = 37000, grade = 3,
		desc = "Раскалывает целые кучи. Каждый удар — ударная волна.",
		stats = { gather = 6, radius = 5.5, cd = 0.42, fx = "shock" } },
	{ id = "vacuum", slot = "tool", name = "Утилизатор-пылесос", price = 110000, grade = 4,
		desc = "Ранцевый пылесос с циклоном. Засасывает всё вокруг.",
		stats = { gather = 7, radius = 5.75, cd = 0.41, fx = "zap" } },
	{ id = "plasmacutter", slot = "tool", name = "Плазменный резак", price = 310000, grade = 5,
		desc = "Промышленный резак: плавит лом прямо в слитки.",
		stats = { gather = 8, radius = 6, cd = 0.4, fx = "plasma" } },

	-- ===== БРОНЯ =====
	{ id = "armor1", slot = "armor", name = "Куртка из мешковины", price = 1200, grade = 1, tier = 1,
		desc = "Сшита из старых мешков. Хоть какая-то защита.", stats = { hp = 20, def = 0.05 } },
	{ id = "armor2", slot = "armor", name = "Кожаный жилет", price = 3400, grade = 2, tier = 2,
		desc = "Плотная кожа с ремнями и заклёпками.", stats = { hp = 40, def = 0.1 } },
	{ id = "armor3", slot = "armor", name = "Бронежилет", price = 9400, grade = 3, tier = 3,
		desc = "Кевларовый бронежилет с пластинами и подсумками.", stats = { hp = 75, def = 0.18 } },
	{ id = "armor4", slot = "armor", name = "Тактическая броня", price = 26000, grade = 4, tier = 4,
		desc = "Армейский комплект с наплечниками в камуфляже.", stats = { hp = 120, def = 0.25 } },
	{ id = "armor5", slot = "armor", name = "Экзоскелет «Титан»", price = 74000, grade = 5, tier = 5,
		desc = "Силовой каркас с реактором на спине.", stats = { hp = 200, def = 0.35 } },

	-- ===== ШЛЕМЫ =====
	{ id = "helmet1", slot = "helmet", name = "Строительная каска", price = 1000, grade = 1, tier = 1,
		desc = "Жёлтая каска с фонариком.", stats = { hp = 10, def = 0.03 } },
	{ id = "helmet2", slot = "helmet", name = "Мотошлем", price = 2800, grade = 2, tier = 2,
		desc = "Закрытый шлем с тонированным визором.", stats = { hp = 20, def = 0.06 } },
	{ id = "helmet3", slot = "helmet", name = "Военная каска", price = 7800, grade = 3, tier = 3,
		desc = "Камуфляжная каска с прибором ночного видения.", stats = { hp = 35, def = 0.09 } },
	{ id = "helmet4", slot = "helmet", name = "Шлем-противогаз", price = 22000, grade = 4, tier = 4,
		desc = "Защита от радиации и токсинов. Два фильтра.", stats = { hp = 55, def = 0.12 } },
	{ id = "helmet5", slot = "helmet", name = "Шлем «Жнец»", price = 61000, grade = 5, tier = 5,
		desc = "Чёрный шлем с рогами и алым визором. Зомби боятся.", stats = { hp = 80, def = 0.16 } },

	-- ===== ПЕРЧАТКИ =====
	{ id = "gloves1", slot = "gloves", name = "Рабочие перчатки", price = 1100, grade = 1, tier = 1,
		desc = "Хлопковые перчатки. Лом собирать удобнее.", stats = { scrap = 0.10 } },
	{ id = "gloves2", slot = "gloves", name = "Кожаные перчатки", price = 3100, grade = 2, tier = 2,
		desc = "Прочная кожа, не рвётся об осколки.", stats = { scrap = 0.20 } },
	{ id = "gloves3", slot = "gloves", name = "Тактические перчатки", price = 8600, grade = 3, tier = 3,
		desc = "С защитными накладками на костяшках.", stats = { scrap = 0.35 } },
	{ id = "gloves4", slot = "gloves", name = "Перчатки-манипуляторы", price = 24000, grade = 4, tier = 4,
		desc = "Механические пальцы с сервоприводами.", stats = { scrap = 0.55 } },
	{ id = "gloves5", slot = "gloves", name = "Силовые перчатки «Тесла»", price = 68000, grade = 5, tier = 5,
		desc = "Электромагнитные перчатки — лом сам прилипает.", stats = { scrap = 0.80 } },

	-- ===== БОТИНКИ =====
	{ id = "boots1", slot = "boots", name = "Кеды", price = 800, grade = 1, tier = 1,
		desc = "Старые кеды. В них хотя бы можно бежать.", stats = { speed = 2, jump = 0 } },
	{ id = "boots2", slot = "boots", name = "Берцы", price = 2200, grade = 2, tier = 2,
		desc = "Кожаные армейские ботинки на шнурках.", stats = { speed = 4, jump = 0 } },
	{ id = "boots3", slot = "boots", name = "Кроссовки бегуна", price = 6300, grade = 3, tier = 3,
		desc = "Лёгкие и пружинистые. Убегать от зомби — самое то.", stats = { speed = 6, jump = 3 } },
	{ id = "boots4", slot = "boots", name = "Сапоги-скороходы", price = 18000, grade = 4, tier = 4,
		desc = "Бронированные сапоги с амортизаторами.", stats = { speed = 9, jump = 5 } },
	{ id = "boots5", slot = "boots", name = "Реактивные ботинки", price = 49000, grade = 5, tier = 5,
		desc = "Мини-двигатели в подошвах. Очень быстро и высоко.", stats = { speed = 13, jump = 9 } },

	-- ===== РАСХОДНИКИ (складываются, используются из хотбара) =====
	{ id = "medkit", slot = "consumable", name = "Аптечка", price = 500, grade = 2, icon = "medkit", stack = true,
		desc = "Мгновенно восстанавливает 60 здоровья.", stats = { heal = 60 } },
	{ id = "energycell", slot = "consumable", name = "Энергоячейка", price = 3000, grade = 3, icon = "energycell", stack = true,
		desc = "Подзаряжает весь рой на 50% прямо в поле.", stats = { energy = 0.5 } },
	{ id = "grenade", slot = "consumable", name = "Граната", price = 1000, grade = 3, icon = "grenade", stack = true,
		desc = "Взрыв в радиусе 14: 350 урона всем зомби.", stats = { dmg = 350, radius = 14 } },
	{ id = "adrenaline", slot = "consumable", name = "Адреналин", price = 800, grade = 3, icon = "adrenaline", stack = true,
		desc = "Укол адреналина: +4 ступени баффа «Ускорение» (до x1.5 скорости).", stats = { stacks = 4 } },

	-- ===== НОВОЕ ОРУЖИЕ (высокие уровни) =====
	{ id = "spear", slot = "weapon", name = "Копьё-гарпун", price = 9800000, grade = 5,
		desc = "Титановое древко и дамасский наконечник с зазубринами.", stats = { dmg = 380, radius = 12, cd = 0.38, fx = "none" } },
	{ id = "katana", slot = "weapon", name = "Катана «Ронин»", price = 27000000, grade = 5,
		desc = "Клинок из дамасской стали и золотая цуба. Очень быстрые удары.", stats = { dmg = 470, radius = 11, cd = 0.28, fx = "sparks" } },
	{ id = "bonecleaver", slot = "weapon", name = "Костяной тесак", price = 74000000, grade = 6,
		desc = "Вырезан из кости мутанта. Зубья по кромке рвут на части.", stats = { dmg = 600, radius = 11.5, cd = 0.4, fx = "none" } },
	{ id = "lavaaxe", slot = "weapon", name = "Магматический топор", price = 200000000, grade = 6,
		desc = "Лезвие из остывшей лавы — внутри всё ещё тлеет огонь.", stats = { dmg = 800, radius = 12, cd = 0.45, fx = "fire" } },
	{ id = "thunderhammer", slot = "weapon", name = "Молот «Громовержец»", price = 560000000, grade = 6,
		desc = "Титан и гравированное золото. Каждый удар — разряд молнии.", stats = { dmg = 1100, radius = 13, cd = 0.55, fx = "zap" } },
	{ id = "crystalblade", slot = "weapon", name = "Кристальный меч", price = 1500000000, grade = 6,
		desc = "Выращен из радиоактивного кристалла. Сияет и звенит.", stats = { dmg = 1400, radius = 12.5, cd = 0.35, fx = "sparks" } },
	{ id = "dragonglaive", slot = "weapon", name = "Драконья глефа", price = 4200000000, grade = 7,
		desc = "Древко в драконьей чешуе, изогнутое лезвие дышит огнём.", stats = { dmg = 2000, radius = 14, cd = 0.4, fx = "fire" } },
	{ id = "obsidianscythe", slot = "weapon", name = "Обсидиановая коса", price = 12000000000, grade = 7,
		desc = "Чёрное вулканическое стекло с фиолетовыми жилами энергии.", stats = { dmg = 2800, radius = 15, cd = 0.38, fx = "plasma" } },
	{ id = "gravhammer", slot = "weapon", name = "Гравитационный молот", price = 32000000000, grade = 7,
		desc = "Искривляет пространство вокруг удара. Зомби сплющивает.", stats = { dmg = 4000, radius = 16, cd = 0.5, fx = "shock" } },
	{ id = "omegasaber", slot = "weapon", name = "Омега-сабля", price = 88000000000, grade = 7,
		desc = "Лезвие из чистой энергии. Вершина оружейной науки.", stats = { dmg = 6000, radius = 16, cd = 0.25, fx = "plasma" } },

	-- ===== НОВЫЕ ИНСТРУМЕНТЫ =====
	{ id = "drillgun", slot = "tool", name = "Ручной бур", price = 890000, grade = 5,
		desc = "Аккумуляторный бур со спиральным сверлом из титана.", stats = { gather = 10, radius = 6.25, cd = 0.39, fx = "sparks" } },
	{ id = "harvester", slot = "tool", name = "Роторный жнец", price = 2600000, grade = 5,
		desc = "Вращающийся барабан с ножами перемалывает целые кучи.", stats = { gather = 12, radius = 6.5, cd = 0.38, fx = "none" } },
	{ id = "magnetcannon", slot = "tool", name = "Магнитная пушка", price = 7500000, grade = 6,
		desc = "Электромагнит тянет металл с десятка метров.", stats = { gather = 14, radius = 6.75, cd = 0.38, fx = "zap" } },
	{ id = "excavator", slot = "tool", name = "Гидроковш", price = 22000000, grade = 6,
		desc = "Ковш мини-экскаватора на гидравлике. Загребает тоннами.", stats = { gather = 16, radius = 7, cd = 0.37, fx = "shock" } },
	{ id = "laserdrill", slot = "tool", name = "Лазерный бур", price = 63000000, grade = 6,
		desc = "Режет кучи лучом и сразу спекает ресурсы в брикеты.", stats = { gather = 18, radius = 7.2, cd = 0.36, fx = "plasma" } },
	{ id = "cryoextractor", slot = "tool", name = "Крио-экстрактор", price = 180000000, grade = 6,
		desc = "Замораживает кучу и раскалывает её на чистые детали.", stats = { gather = 20, radius = 7.4, cd = 0.36, fx = "sparks" } },
	{ id = "gravitywell", slot = "tool", name = "Гравитационная воронка", price = 530000000, grade = 7,
		desc = "Миниатюрная чёрная дыра засасывает всё вокруг.", stats = { gather = 22, radius = 7.6, cd = 0.35, fx = "zap" } },
	{ id = "lavaforge", slot = "tool", name = "Магма-плавильня", price = 1500000000, grade = 7,
		desc = "Переплавляет лом прямо в руках. Горячо!", stats = { gather = 25, radius = 7.8, cd = 0.34, fx = "fire" } },
	{ id = "nanoswarm", slot = "tool", name = "Нано-сборщик", price = 4500000000, grade = 7,
		desc = "Рой наноботов разбирает лом по атомам.", stats = { gather = 27, radius = 7.9, cd = 0.34, fx = "zap" } },
	{ id = "singularity", slot = "tool", name = "Сингулярный коллектор", price = 13000000000, grade = 7,
		desc = "Золотые кольца удерживают сингулярность. Собирает всё.", stats = { gather = 30, radius = 8, cd = 0.33, fx = "plasma" } },
}

-- ===== НОВОЕ СНАРЯЖЕНИЕ: уровни 6–15 =====
local GEAR_NEW = {
	armor = {
		{ "Пластинчатый доспех «Бастион»", "Титановые пластины внахлёст и массивные наплечники." },
		{ "Чешуйчатая броня «Дракон»", "Красная чешуя с золотой окантовкой и шипами." },
		{ "Костяной панцирь", "Рёбра и череп мутанта на кожаных ремнях." },
		{ "Химзащита «Улей»", "Герметичный костюм с баллонами антидота." },
		{ "Кристаллический доспех", "Радиокристаллы проросли прямо сквозь броню." },
		{ "Магматическая броня", "Раскалённый камень с лавой в трещинах." },
		{ "Обсидиановый доспех", "Чёрное стекло и фиолетовые жилы энергии." },
		{ "Нано-костюм «Призрак»", "Схемы на броне светятся и перестраиваются." },
		{ "Королевская броня", "Гравированное золото, рубин и алый плащ." },
		{ "Экзоскелет «Омега»", "Реактор на груди и энергетические крылья." },
	},
	helmet = {
		{ "Шлем «Бастион»", "Закрытый титановый шлем с прорезью." },
		{ "Шлем «Дракон»", "Рога и чешуя, глаза горят огнём." },
		{ "Череп вождя", "Череп с клыками — зомби принимают за своего." },
		{ "Шлем химзащиты", "Панорамное стекло и двойной фильтр." },
		{ "Кристальная корона", "Сияющие кристаллы над лбом." },
		{ "Магматический шлем", "Тлеющий камень и огненная щель." },
		{ "Обсидиановая маска", "Гладкая чёрная маска с фиолетовыми глазами." },
		{ "Нано-шлем «Призрак»", "Цельный визор с дополненной реальностью." },
		{ "Корона пустоши", "Золотая корона с рубинами." },
		{ "Шлем «Омега»", "Силовое поле и нимб из чистой энергии." },
	},
	gloves = {
		{ "Титановые рукавицы", "Стальные пальцы гребут лом как ковш." },
		{ "Драконьи когти", "Чешуйчатые перчатки с золотыми когтями." },
		{ "Костяные наручи", "Фаланги мутанта на ремнях." },
		{ "Хим-перчатки", "Резина защищает от любой слизи." },
		{ "Кристальные перчатки", "Кристаллы притягивают ценные детали." },
		{ "Лавовые кулаки", "Плавят лом при касании." },
		{ "Обсидиановые латницы", "Тяжёлые и несокрушимые." },
		{ "Нано-перчатки", "Наноботы сортируют лом прямо в ладони." },
		{ "Королевские перчатки", "Золото и рубины — сами тянут ценности." },
		{ "Перчатки «Омега»", "Гравизахват для любого ресурса." },
	},
	boots = {
		{ "Титановые сабатоны", "Лёгкий титан и пружины в каблуке." },
		{ "Драконьи сапоги", "Чешуя и огненный след." },
		{ "Костяные поножи", "Ступают бесшумно, как хищник." },
		{ "Хим-боты", "Резина с амортизацией для длинных прыжков." },
		{ "Кристальные сапоги", "Отталкиваются от земли как пружины." },
		{ "Лавоходы", "Оставляют тлеющие следы." },
		{ "Обсидиановые сапоги", "Тёмная сила ускоряет каждый шаг." },
		{ "Нано-ботинки", "Подошва подстраивается под любую поверхность." },
		{ "Королевские сапоги", "Золотые шпоры и рубины." },
		{ "Грави-боты «Омега»", "Антигравитация: почти полёт." },
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
-- cap — бонус к вместимости (умножает вместимость уровня рюкзака), conv — больше батарей
-- за переработку, cspeed — быстрее работает Переработчик. Бонус переработки есть не у всех.
local BACKPACKS = {
	{ "bp_old", "Школьный рюкзак", 0, 1, { cap = 0 }, "Потёртый рюкзак с брелоком. Лучше, чем ничего." },
	{ "bp_sack", "Брезентовый вещмешок", 2500, 1, { cap = 0.1 }, "Мешок на верёвке. Влезает чуть больше лома." },
	{ "bp_denim", "Джинсовый рюкзак", 7200, 2, { cap = 0.15, conv = 0.05 }, "Сшит из старых джинсов, весь в нашивках. Счастливый: переработка выгоднее." },
	{ "bp_hiker", "Туристический рюкзак", 21000, 2, { cap = 0.3 }, "Каркасный рюкзак со спальником и флягой." },
	{ "bp_scrapper", "Сумка утилизатора", 61000, 3, { cap = 0.2, conv = 0.12, cspeed = 0.25 }, "Встроенный сортировщик: лом перерабатывается быстрее и выгоднее." },
	{ "bp_raid", "Армейский рейдовый рюкзак", 180000, 3, { cap = 0.5 }, "Камуфляж и куча подсумков — максимум места." },
	{ "bp_tactical", "Тактический MOLLE-рюкзак", 510000, 4, { cap = 0.75, cspeed = 0.15 }, "Стропы MOLLE, рация и быстрая разгрузка." },
	{ "bp_hazmat", "Хим-контейнер «Изотоп»", 1500000, 4, { cap = 0.6, conv = 0.2 }, "Бак с нейтрализатором растворяет лом в чистую энергию." },
	{ "bp_reactor", "Ранец с мини-реактором", 4300000, 5, { cap = 1.0, conv = 0.15, cspeed = 0.4 }, "Реактор подзаряжает батареи прямо на спине." },
	{ "bp_bone", "Костяной короб", 13000000, 5, { cap = 1.4 }, "Шкура мутанта на рёбрах чудовища. Огромный и жуткий." },
	{ "bp_dragon", "Драконий ранец", 36000000, 6, { cap = 1.8, conv = 0.3 }, "Чешуя, золото и сложенные крылья. Тлеет изнутри." },
	{ "bp_crystal", "Кристальный ранец", 110000000, 6, { cap = 2.2, cspeed = 0.6 }, "Радиокристаллы гудят и ускоряют переработку." },
	{ "bp_magma", "Магма-плавильня", 310000000, 6, { cap = 2.6, conv = 0.45, cspeed = 0.5 }, "Плавит лом на ходу. Из трубы валит огонь." },
	{ "bp_obsidian", "Обсидиановый сундук", 880000000, 7, { cap = 3.3 }, "Чёрное стекло с фиолетовыми рунами. Внутри больше, чем снаружи." },
	{ "bp_nano", "Нано-ранец «Призрак»", 2600000000, 7, { cap = 3.8, conv = 0.6, cspeed = 0.8 }, "Наноботы сортируют лом, голограмма считает батареи." },
	{ "bp_royal", "Королевский сундук", 7400000000, 7, { cap = 4.6 }, "Гравированное золото, рубины и бархат. Для короля пустоши." },
	{ "bp_omega", "Пространственный ранец «Омега»", 22000000000, 7, { cap = 6, conv = 0.8, cspeed = 1.2 }, "Портал в карманное измерение и энергетические крылья." },
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
local CONSUMABLES = {
	{ "lube", "Смазка для дронов", 400, 1, "Капля машинного масла в каждый привод. Бодрит рой.",
		{ energy = 0.15, buffs = { dgather = 1 } }, { kind = "can", c1 = C(70, 120, 60), c2 = C(240, 200, 70) },
		{ color = C(240, 200, 70), style = "drip" }, { { "9116328427", 0.6, 1.1 }, { "charge", 0.25, 1.4, 0.15 } } },
	{ "beacon", "Маячок возврата", 600, 1, "Жми — и тебя телепортирует прямо к твоему улью.",
		{ home = true }, { kind = "device", c1 = C(50, 55, 65), c2 = C(80, 200, 255) },
		{ color = C(80, 200, 255), style = "teleport" }, { { "9118353221", 0.5, 1.3 }, { "whooshRise", 0.5, 1.2, 0.1 }, { "reveal", 0.35, 1.5, 0.35 } } },
	{ "stim", "Боевой стимулятор", 1500, 2, "Укол в плечо: +5 ступеней «Ярости роя» и +3 ступени «Прицела».",
		{ buffs = { rage = 5, crit = 3 } }, { kind = "syringe", c1 = C(255, 70, 50), c2 = C(230, 235, 245) },
		{ color = C(255, 70, 50), style = "pulse" }, { { "9116328427", 0.7, 0.8 }, { "hit", 0.35, 1.3, 0.12 } } },
	{ "goldpaint", "Золотая краска", 2500, 2, "Баллончик с позолотой: кучи в радиусе 10 золотые 15 секунд (x5 лома).",
		{ field = true, gold = { 10, 15 } }, { kind = "spray", c1 = C(255, 200, 40), c2 = C(40, 40, 45) },
		{ color = C(255, 205, 50), style = "spray" }, { { "9113046623", 0.7, 1 }, { "sparkle", 0.4, 1.2, 0.3 } } },
	{ "flare", "Сигнальная ракета", 3500, 3, "Вызывает сброс с воздуха: на поле падают 3 сферы добывающих баффов.",
		{ field = true, orbs = { 3, "gather" } }, { kind = "flare", c1 = C(230, 50, 40), c2 = C(255, 220, 120) },
		{ color = C(255, 90, 50), style = "flare" }, { { "113248727573901", 0.7, 1 }, { "whoosh", 0.4, 0.8, 0.2 } } },
	{ "microconv", "Мини-переработчик", 4000, 3, "Карманный утилизатор: весь лом в рюкзаке сразу превращается в батареи.",
		{ convert = true }, { kind = "device", c1 = C(90, 95, 105), c2 = C(130, 255, 120) },
		{ color = C(130, 255, 120), style = "convert" }, { { "9118352429", 0.6, 1 }, { "coin", 0.5, 1.1, 0.3 }, { "chime", 0.35, 1.2, 0.5 } } },
	{ "scrapbomb", "Ящик-бомба", 6000, 3, "Падает с неба и взрывается: собирает кучи в радиусе 12 (x3) и бьёт зомби на 400.",
		{ field = true, bomb = { 12, 3, 400 } }, { kind = "crate", c1 = C(120, 90, 55), c2 = C(255, 170, 40) },
		{ color = C(255, 160, 50), style = "bomb" }, { { "9116537007", 0.7, 0.9 }, { "boom", 0.6, 1.2, 0.55 } } },
	{ "luckycoin", "Счастливая гайка", 8000, 3, "Подкинь на удачу: +10 ступеней баффа «Удача».",
		{ buffs = { luck = 10 } }, { kind = "coin", c1 = C(255, 215, 70), c2 = C(110, 240, 90) },
		{ color = C(120, 240, 90), style = "sparkle" }, { { "7022812395", 0.7, 1 }, { "star", 0.35, 1.2, 0.4 } } },
	{ "candybars", "Набор батончиков", 9000, 3, "Рассыпает 5 случайных сфер баффов вокруг тебя.",
		{ field = true, orbs = { 5 } }, { kind = "box", c1 = C(255, 120, 200), c2 = C(120, 220, 255) },
		{ color = C(255, 140, 210), style = "confetti" }, { { "9117848029", 0.6, 1.1 }, { "bling", 0.4, 1, 0.2 } } },
	{ "botbox", "Коробка нано-жуков", 15000, 4, "Выпускает 8 мини-дронов на 45 секунд.",
		{ field = true, minis = { 8, 45 } }, { kind = "box", c1 = C(60, 70, 60), c2 = C(80, 255, 140) },
		{ color = C(80, 255, 140), style = "swarm" }, { { "9118327495", 0.6, 1.2 }, { "9118328814", 0.4, 1.5, 0.25 } } },
	{ "magglue", "Магнитный клей", 20000, 4, "Липкий магнитный гель: +5 ступеней «Смазки роя» (сбор дронов).",
		{ buffs = { dgather = 5 } }, { kind = "tube", c1 = C(120, 160, 255), c2 = C(220, 230, 255) },
		{ color = C(120, 160, 255), style = "drip" }, { { "9117646243", 0.5, 1.3 }, { "glock", 0.25, 0.8, 0.3 } } },
	{ "rageextract", "Экстракт ярости", 25000, 4, "Красная вытяжка из сердца мутанта: +3 «Ярости роя» и +3 «Прицела».",
		{ buffs = { rage = 3, crit = 3 } }, { kind = "vial", c1 = C(255, 50, 60), c2 = C(80, 20, 20) },
		{ color = C(255, 60, 60), style = "pulse" }, { { "9114171955", 0.7, 0.9 }, { "riser", 0.3, 1.4, 0.2 } } },
	{ "gatherextract", "Экстракт сборщика", 25000, 4, "Синяя вытяжка из радиокристалла: +3 «Щедрого сбора» и +3 «Смазки роя».",
		{ buffs = { scrap = 3, dgather = 3 } }, { kind = "vial", c1 = C(60, 140, 255), c2 = C(20, 40, 80) },
		{ color = C(70, 150, 255), style = "sparkle" }, { { "9114171955", 0.7, 1.15 }, { "chime", 0.35, 0.9, 0.2 } } },
	{ "enzymes", "Ферменты переработки", 30000, 4, "Бактерии едят лом: +5 ступеней «Ферментации» и +2 «Щедрого сбора».",
		{ buffs = { convb = 5, scrap = 2 } }, { kind = "jar", c1 = C(150, 255, 90), c2 = C(60, 70, 50) },
		{ color = C(150, 255, 90), style = "bubbles" }, { { "9117642899", 0.5, 1.2 }, { "9117848644", 0.5, 0.9, 0.3 } } },
	{ "motoroil", "Моторное масло", 30000, 4, "Синтетика для винтов: +5 «Турбо роя» и +2 «Смазки роя».",
		{ buffs = { dspeed = 5, dgather = 2 } }, { kind = "can", c1 = C(30, 30, 35), c2 = C(255, 140, 30) },
		{ color = C(255, 150, 40), style = "drip" }, { { "9117646243", 0.6, 0.8 }, { "9118352946", 0.4, 1.1, 0.3 } } },
	{ "cocktail", "Коктейль выжившего", 45000, 4, "Полное здоровье, +5 «Прицела» и +3 «Ускорения».",
		{ heal = "full", buffs = { crit = 5, speed = 3 } }, { kind = "cup", c1 = C(255, 170, 60), c2 = C(90, 230, 120) },
		{ color = C(255, 180, 70), style = "heal" }, { { "133988388434763", 0.7, 1 }, { "sparkle", 0.35, 1.3, 0.3 } } },
	{ "nanocloud", "Нано-облако", 40000, 4, "Облако наноботов восстанавливает все кучи поля и даёт +3 «Щедрого сбора».",
		{ field = true, refill = true, buffs = { scrap = 3 } }, { kind = "vial", c1 = C(220, 235, 255), c2 = C(140, 170, 210) },
		{ color = C(200, 225, 255), style = "cloud" }, { { "9113045686", 0.6, 0.7 }, { "reveal", 0.4, 1, 0.3 } } },
	{ "mutantseed", "Семя-мутант", 120000, 5, "Бросаешь в землю — всё поле становится золотым на 12 секунд.",
		{ field = true, goldAll = 12 }, { kind = "seed", c1 = C(150, 60, 200), c2 = C(255, 210, 60) },
		{ color = C(255, 210, 60), style = "goldfield" }, { { "thud", 0.6, 1.2 }, { "bigRiser", 0.35, 1.3, 0.1 }, { "fanfare", 0.4, 1, 0.9 } } },
	{ "mutagen", "Мутаген «Пурпур»", 250000, 5, "Пурпурная сыворотка: по +5 ступеней «Ярости», «Прицела», «Удачи» и «Смазки роя».",
		{ buffs = { rage = 5, crit = 5, luck = 5, dgather = 5 } }, { kind = "vial", c1 = C(170, 60, 255), c2 = C(60, 20, 80) },
		{ color = C(180, 80, 255), style = "pulse" }, { { "9114171955", 0.7, 0.75 }, { "bigRiser", 0.35, 1.1, 0.15 }, { "boom", 0.3, 1.6, 0.9 } } },
	{ "supershake", "Суперкоктейль «Апокалипсис»", 1500000, 6, "Всё и сразу: максимум ступеней всех баффов роя и полное здоровье.",
		{ heal = "full", buffs = { speed = 10, scrap = 10, rage = 10, luck = 10, dgather = 10, convb = 10, crit = 10, dspeed = 10 } },
		{ kind = "cup", c1 = C(255, 70, 110), c2 = C(70, 255, 230) },
		{ color = C(255, 120, 200), style = "rainbow" }, { { "133988388434763", 0.8, 0.9 }, { "bigRiser", 0.4, 1, 0.1 }, { "fanfare", 0.5, 1.05, 1 } } },
}
for _, c in ipairs(CONSUMABLES) do
	table.insert(S.Items, {
		id = c[1], slot = "consumable", name = c[2], price = c[3], grade = c[4], desc = c[5], icon = c[1], stack = true,
		stats = {}, use = c[6], model = c[7], fx = c[8], sfx = c[9],
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
	crit = { "🎯 Шанс крита", pct = true, desc = "Шанс нанести критический удар (оружие и дроны)." },
	critx = { "💥 Сила крита", pct = true, desc = "Крит бьёт в 1.5x + этот бонус." },
	ddmg = { "🤖 Урон дронов", pct = true, desc = "Урон, который наносят дроны роя." },
	dgather = { "🛸 Сбор дронов", pct = true, desc = "Сколько лома приносит каждый сбор дрона." },
	tgather = { "⛏ Сбор инструментом", pct = true, desc = "Сколько лома приносит удар инструментом." },
	instconv = { "⚡ Мгновенная переработка", pct = true, desc = "Доля собранного лома, которая сразу становится батареями." },
	luck = { "🍀 Удача", pct = true, desc = "Шанс находок и сфер баффов." },
	regen = { "✚ Регенерация", suffix = " HP/с", desc = "Здоровье восстанавливается каждую секунду." },
	energy = { "🔋 Выносливость дронов", pct = true, desc = "Дроны дольше работают на одном заряде." },
	dspeed = { "🚀 Скорость дронов", pct = true, desc = "Как быстро дроны летают и собирают." },
	buffdur = { "⏳ Длительность баффов", pct = true, desc = "Баффы действуют дольше." },
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
