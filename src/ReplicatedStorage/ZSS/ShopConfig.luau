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
	{ id = "pipe", slot = "weapon", name = "Ржавая труба", price = 2000, grade = 1,
		desc = "Кусок водопровода с изолентой. Классика апокалипсиса.",
		stats = { dmg = 12, radius = 5, cd = 0.45, fx = "none" } },
	{ id = "bat", slot = "weapon", name = "Бита с гвоздями", price = 8000, grade = 2,
		desc = "Деревянная бита, утыканная гвоздями и колючкой.",
		stats = { dmg = 20, radius = 5.5, cd = 0.45, fx = "none" } },
	{ id = "machete", slot = "weapon", name = "Мачете", price = 25000, grade = 2,
		desc = "Широкий клинок для джунглей — и для зомби.",
		stats = { dmg = 32, radius = 6, cd = 0.4, fx = "none" } },
	{ id = "fireaxe", slot = "weapon", name = "Пожарный топор", price = 75000, grade = 3,
		desc = "Красный топор с пожарного щита. Поджигает зомби.",
		stats = { dmg = 52, radius = 6.5, cd = 0.45, fx = "fire" } },
	{ id = "sledge", slot = "weapon", name = "Кувалда", price = 200000, grade = 3,
		desc = "Тяжёлая кувалда. Каждый удар — ударная волна.",
		stats = { dmg = 90, radius = 8, cd = 0.6, fx = "shock" } },
	{ id = "chainsaw", slot = "weapon", name = "Бензопила", price = 600000, grade = 4,
		desc = "Ревущая бензопила. Очень быстрые удары.",
		stats = { dmg = 85, radius = 7, cd = 0.25, fx = "sparks" } },
	{ id = "baton", slot = "weapon", name = "Электродубина", price = 1500000, grade = 4,
		desc = "Шоковая дубина с катушкой. Бьёт молнией по всем рядом.",
		stats = { dmg = 180, radius = 9, cd = 0.4, fx = "zap" } },
	{ id = "scythe", slot = "weapon", name = "Плазменная коса", price = 5000000, grade = 5,
		desc = "Прототип с плазменным лезвием. Режет всё в большом радиусе.",
		stats = { dmg = 310, radius = 11, cd = 0.35, fx = "plasma" } },

	-- ===== ИНСТРУМЕНТЫ (только добыча ресурсов с полей) =====
	{ id = "scraper", slot = "tool", name = "Скребок", price = 0, grade = 1,
		desc = "Стартовая лопата-скребок. Гребёт всё, что лежит на поле.",
		stats = { gather = 2, radius = 4.5, cd = 0.45, fx = "none" } },
	{ id = "shovel", slot = "tool", name = "Сапёрная лопата", price = 3000, grade = 1,
		desc = "Короткая армейская лопата. Зачёрпывает вдвое больше.",
		stats = { gather = 4, radius = 5, cd = 0.45, fx = "none" } },
	{ id = "pickaxe", slot = "tool", name = "Кирка", price = 15000, grade = 2,
		desc = "Стальная кирка. Разбивает слёжавшиеся кучи.",
		stats = { gather = 8, radius = 5.5, cd = 0.45, fx = "none" } },
	{ id = "magrake", slot = "tool", name = "Магнитные грабли", price = 60000, grade = 3,
		desc = "Грабли с магнитами — мелкие детали липнут сами.",
		stats = { gather = 14, radius = 6.5, cd = 0.4, fx = "sparks" } },
	{ id = "jackhammer", slot = "tool", name = "Отбойный молоток", price = 250000, grade = 3,
		desc = "Раскалывает целые кучи. Каждый удар — ударная волна.",
		stats = { gather = 24, radius = 7, cd = 0.3, fx = "shock" } },
	{ id = "vacuum", slot = "tool", name = "Утилизатор-пылесос", price = 900000, grade = 4,
		desc = "Ранцевый пылесос с циклоном. Засасывает всё вокруг.",
		stats = { gather = 40, radius = 8.5, cd = 0.35, fx = "zap" } },
	{ id = "plasmacutter", slot = "tool", name = "Плазменный резак", price = 3000000, grade = 5,
		desc = "Промышленный резак: плавит лом прямо в слитки.",
		stats = { gather = 70, radius = 10, cd = 0.3, fx = "plasma" } },

	-- ===== БРОНЯ =====
	{ id = "armor1", slot = "armor", name = "Куртка из мешковины", price = 1500, grade = 1, tier = 1,
		desc = "Сшита из старых мешков. Хоть какая-то защита.", stats = { hp = 20, def = 0.05 } },
	{ id = "armor2", slot = "armor", name = "Кожаный жилет", price = 10000, grade = 2, tier = 2,
		desc = "Плотная кожа с ремнями и заклёпками.", stats = { hp = 40, def = 0.1 } },
	{ id = "armor3", slot = "armor", name = "Бронежилет", price = 50000, grade = 3, tier = 3,
		desc = "Кевларовый бронежилет с пластинами и подсумками.", stats = { hp = 75, def = 0.18 } },
	{ id = "armor4", slot = "armor", name = "Тактическая броня", price = 250000, grade = 4, tier = 4,
		desc = "Армейский комплект с наплечниками в камуфляже.", stats = { hp = 120, def = 0.25 } },
	{ id = "armor5", slot = "armor", name = "Экзоскелет «Титан»", price = 1500000, grade = 5, tier = 5,
		desc = "Силовой каркас с реактором на спине.", stats = { hp = 200, def = 0.35 } },

	-- ===== ШЛЕМЫ =====
	{ id = "helmet1", slot = "helmet", name = "Строительная каска", price = 1000, grade = 1, tier = 1,
		desc = "Жёлтая каска с фонариком.", stats = { hp = 10, def = 0.03 } },
	{ id = "helmet2", slot = "helmet", name = "Мотошлем", price = 8000, grade = 2, tier = 2,
		desc = "Закрытый шлем с тонированным визором.", stats = { hp = 20, def = 0.06 } },
	{ id = "helmet3", slot = "helmet", name = "Военная каска", price = 40000, grade = 3, tier = 3,
		desc = "Камуфляжная каска с прибором ночного видения.", stats = { hp = 35, def = 0.09 } },
	{ id = "helmet4", slot = "helmet", name = "Шлем-противогаз", price = 200000, grade = 4, tier = 4,
		desc = "Защита от радиации и токсинов. Два фильтра.", stats = { hp = 55, def = 0.12 } },
	{ id = "helmet5", slot = "helmet", name = "Шлем «Жнец»", price = 1200000, grade = 5, tier = 5,
		desc = "Чёрный шлем с рогами и алым визором. Зомби боятся.", stats = { hp = 80, def = 0.16 } },

	-- ===== ПЕРЧАТКИ =====
	{ id = "gloves1", slot = "gloves", name = "Рабочие перчатки", price = 1200, grade = 1, tier = 1,
		desc = "Хлопковые перчатки. Лом собирать удобнее.", stats = { scrap = 0.10 } },
	{ id = "gloves2", slot = "gloves", name = "Кожаные перчатки", price = 9000, grade = 2, tier = 2,
		desc = "Прочная кожа, не рвётся об осколки.", stats = { scrap = 0.20 } },
	{ id = "gloves3", slot = "gloves", name = "Тактические перчатки", price = 45000, grade = 3, tier = 3,
		desc = "С защитными накладками на костяшках.", stats = { scrap = 0.35 } },
	{ id = "gloves4", slot = "gloves", name = "Перчатки-манипуляторы", price = 220000, grade = 4, tier = 4,
		desc = "Механические пальцы с сервоприводами.", stats = { scrap = 0.55 } },
	{ id = "gloves5", slot = "gloves", name = "Силовые перчатки «Тесла»", price = 1300000, grade = 5, tier = 5,
		desc = "Электромагнитные перчатки — лом сам прилипает.", stats = { scrap = 0.80 } },

	-- ===== БОТИНКИ =====
	{ id = "boots1", slot = "boots", name = "Кеды", price = 800, grade = 1, tier = 1,
		desc = "Старые кеды. В них хотя бы можно бежать.", stats = { speed = 2, jump = 0 } },
	{ id = "boots2", slot = "boots", name = "Берцы", price = 7000, grade = 2, tier = 2,
		desc = "Кожаные армейские ботинки на шнурках.", stats = { speed = 4, jump = 0 } },
	{ id = "boots3", slot = "boots", name = "Кроссовки бегуна", price = 35000, grade = 3, tier = 3,
		desc = "Лёгкие и пружинистые. Убегать от зомби — самое то.", stats = { speed = 6, jump = 3 } },
	{ id = "boots4", slot = "boots", name = "Сапоги-скороходы", price = 180000, grade = 4, tier = 4,
		desc = "Бронированные сапоги с амортизаторами.", stats = { speed = 9, jump = 5 } },
	{ id = "boots5", slot = "boots", name = "Реактивные ботинки", price = 1000000, grade = 5, tier = 5,
		desc = "Мини-двигатели в подошвах. Очень быстро и высоко.", stats = { speed = 13, jump = 9 } },

	-- ===== РАСХОДНИКИ (складываются, используются из хотбара) =====
	{ id = "medkit", slot = "consumable", name = "Аптечка", price = 500, grade = 2, icon = "medkit", stack = true,
		desc = "Мгновенно восстанавливает 60 здоровья.", stats = { heal = 60 } },
	{ id = "energycell", slot = "consumable", name = "Энергоячейка", price = 1500, grade = 3, icon = "energycell", stack = true,
		desc = "Подзаряжает весь рой на 50% прямо в поле.", stats = { energy = 0.5 } },
	{ id = "grenade", slot = "consumable", name = "Граната", price = 1000, grade = 3, icon = "grenade", stack = true,
		desc = "Взрыв в радиусе 14: 350 урона всем зомби.", stats = { dmg = 350, radius = 14 } },
	{ id = "adrenaline", slot = "consumable", name = "Адреналин", price = 800, grade = 3, icon = "adrenaline", stack = true,
		desc = "Укол адреналина: +4 ступени баффа «Ускорение» (до x1.5 скорости).", stats = { stacks = 4 } },

	-- ===== НОВОЕ ОРУЖИЕ (высокие уровни) =====
	{ id = "spear", slot = "weapon", name = "Копьё-гарпун", price = 8000000, grade = 5,
		desc = "Титановое древко и дамасский наконечник с зазубринами.", stats = { dmg = 380, radius = 12, cd = 0.38, fx = "none" } },
	{ id = "katana", slot = "weapon", name = "Катана «Ронин»", price = 15000000, grade = 5,
		desc = "Клинок из дамасской стали и золотая цуба. Очень быстрые удары.", stats = { dmg = 470, radius = 11, cd = 0.28, fx = "sparks" } },
	{ id = "bonecleaver", slot = "weapon", name = "Костяной тесак", price = 25000000, grade = 6,
		desc = "Вырезан из кости мутанта. Зубья по кромке рвут на части.", stats = { dmg = 600, radius = 11.5, cd = 0.4, fx = "none" } },
	{ id = "lavaaxe", slot = "weapon", name = "Магматический топор", price = 45000000, grade = 6,
		desc = "Лезвие из остывшей лавы — внутри всё ещё тлеет огонь.", stats = { dmg = 800, radius = 12, cd = 0.45, fx = "fire" } },
	{ id = "thunderhammer", slot = "weapon", name = "Молот «Громовержец»", price = 80000000, grade = 6,
		desc = "Титан и гравированное золото. Каждый удар — разряд молнии.", stats = { dmg = 1100, radius = 13, cd = 0.55, fx = "zap" } },
	{ id = "crystalblade", slot = "weapon", name = "Кристальный меч", price = 140000000, grade = 6,
		desc = "Выращен из радиоактивного кристалла. Сияет и звенит.", stats = { dmg = 1400, radius = 12.5, cd = 0.35, fx = "sparks" } },
	{ id = "dragonglaive", slot = "weapon", name = "Драконья глефа", price = 250000000, grade = 7,
		desc = "Древко в драконьей чешуе, изогнутое лезвие дышит огнём.", stats = { dmg = 2000, radius = 14, cd = 0.4, fx = "fire" } },
	{ id = "obsidianscythe", slot = "weapon", name = "Обсидиановая коса", price = 450000000, grade = 7,
		desc = "Чёрное вулканическое стекло с фиолетовыми жилами энергии.", stats = { dmg = 2800, radius = 15, cd = 0.38, fx = "plasma" } },
	{ id = "gravhammer", slot = "weapon", name = "Гравитационный молот", price = 800000000, grade = 7,
		desc = "Искривляет пространство вокруг удара. Зомби сплющивает.", stats = { dmg = 4000, radius = 16, cd = 0.5, fx = "shock" } },
	{ id = "omegasaber", slot = "weapon", name = "Омега-сабля", price = 1500000000, grade = 7,
		desc = "Лезвие из чистой энергии. Вершина оружейной науки.", stats = { dmg = 6000, radius = 16, cd = 0.25, fx = "plasma" } },

	-- ===== НОВЫЕ ИНСТРУМЕНТЫ =====
	{ id = "drillgun", slot = "tool", name = "Ручной бур", price = 6000000, grade = 5,
		desc = "Аккумуляторный бур со спиральным сверлом из титана.", stats = { gather = 100, radius = 10.5, cd = 0.3, fx = "sparks" } },
	{ id = "harvester", slot = "tool", name = "Роторный жнец", price = 12000000, grade = 5,
		desc = "Вращающийся барабан с ножами перемалывает целые кучи.", stats = { gather = 140, radius = 11, cd = 0.3, fx = "none" } },
	{ id = "magnetcannon", slot = "tool", name = "Магнитная пушка", price = 22000000, grade = 6,
		desc = "Электромагнит тянет металл с десятка метров.", stats = { gather = 190, radius = 12, cd = 0.35, fx = "zap" } },
	{ id = "excavator", slot = "tool", name = "Гидроковш", price = 40000000, grade = 6,
		desc = "Ковш мини-экскаватора на гидравлике. Загребает тоннами.", stats = { gather = 260, radius = 12.5, cd = 0.4, fx = "shock" } },
	{ id = "laserdrill", slot = "tool", name = "Лазерный бур", price = 75000000, grade = 6,
		desc = "Режет кучи лучом и сразу спекает ресурсы в брикеты.", stats = { gather = 350, radius = 13, cd = 0.3, fx = "plasma" } },
	{ id = "cryoextractor", slot = "tool", name = "Крио-экстрактор", price = 130000000, grade = 6,
		desc = "Замораживает кучу и раскалывает её на чистые детали.", stats = { gather = 470, radius = 13.5, cd = 0.3, fx = "sparks" } },
	{ id = "gravitywell", slot = "tool", name = "Гравитационная воронка", price = 230000000, grade = 7,
		desc = "Миниатюрная чёрная дыра засасывает всё вокруг.", stats = { gather = 640, radius = 14.5, cd = 0.35, fx = "zap" } },
	{ id = "lavaforge", slot = "tool", name = "Магма-плавильня", price = 420000000, grade = 7,
		desc = "Переплавляет лом прямо в руках. Горячо!", stats = { gather = 860, radius = 15, cd = 0.3, fx = "fire" } },
	{ id = "nanoswarm", slot = "tool", name = "Нано-сборщик", price = 750000000, grade = 7,
		desc = "Рой наноботов разбирает лом по атомам.", stats = { gather = 1150, radius = 16, cd = 0.28, fx = "zap" } },
	{ id = "singularity", slot = "tool", name = "Сингулярный коллектор", price = 1400000000, grade = 7,
		desc = "Золотые кольца удерживают сингулярность. Собирает всё.", stats = { gather = 1600, radius = 17, cd = 0.25, fx = "plasma" } },
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
local GEAR_PRICE = { 3000000, 7000000, 15000000, 32000000, 70000000, 150000000, 320000000, 650000000, 1300000000, 2500000000 }
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
			price = math.floor(GEAR_PRICE[k] * (slot == "armor" and 1.2 or slot == "boots" and 0.8 or 1)),
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
	{ "bp_denim", "Джинсовый рюкзак", 12000, 2, { cap = 0.15, conv = 0.05 }, "Сшит из старых джинсов, весь в нашивках. Счастливый: переработка выгоднее." },
	{ "bp_hiker", "Туристический рюкзак", 40000, 2, { cap = 0.3 }, "Каркасный рюкзак со спальником и флягой." },
	{ "bp_scrapper", "Сумка утилизатора", 90000, 3, { cap = 0.2, conv = 0.12, cspeed = 0.25 }, "Встроенный сортировщик: лом перерабатывается быстрее и выгоднее." },
	{ "bp_raid", "Армейский рейдовый рюкзак", 250000, 3, { cap = 0.5 }, "Камуфляж и куча подсумков — максимум места." },
	{ "bp_tactical", "Тактический MOLLE-рюкзак", 700000, 4, { cap = 0.75, cspeed = 0.15 }, "Стропы MOLLE, рация и быстрая разгрузка." },
	{ "bp_hazmat", "Хим-контейнер «Изотоп»", 1800000, 4, { cap = 0.6, conv = 0.2 }, "Бак с нейтрализатором растворяет лом в чистую энергию." },
	{ "bp_reactor", "Ранец с мини-реактором", 5000000, 5, { cap = 1.0, conv = 0.15, cspeed = 0.4 }, "Реактор подзаряжает батареи прямо на спине." },
	{ "bp_bone", "Костяной короб", 12000000, 5, { cap = 1.4 }, "Шкура мутанта на рёбрах чудовища. Огромный и жуткий." },
	{ "bp_dragon", "Драконий ранец", 30000000, 6, { cap = 1.8, conv = 0.3 }, "Чешуя, золото и сложенные крылья. Тлеет изнутри." },
	{ "bp_crystal", "Кристальный ранец", 70000000, 6, { cap = 2.2, cspeed = 0.6 }, "Радиокристаллы гудят и ускоряют переработку." },
	{ "bp_magma", "Магма-плавильня", 150000000, 6, { cap = 2.6, conv = 0.45, cspeed = 0.5 }, "Плавит лом на ходу. Из трубы валит огонь." },
	{ "bp_obsidian", "Обсидиановый сундук", 350000000, 7, { cap = 3.3 }, "Чёрное стекло с фиолетовыми рунами. Внутри больше, чем снаружи." },
	{ "bp_nano", "Нано-ранец «Призрак»", 800000000, 7, { cap = 3.8, conv = 0.6, cspeed = 0.8 }, "Наноботы сортируют лом, голограмма считает батареи." },
	{ "bp_royal", "Королевский сундук", 1600000000, 7, { cap = 4.6 }, "Гравированное золото, рубины и бархат. Для короля пустоши." },
	{ "bp_omega", "Пространственный ранец «Омега»", 3000000000, 7, { cap = 6, conv = 0.8, cspeed = 1.2 }, "Портал в карманное измерение и энергетические крылья." },
}
for k, b in ipairs(BACKPACKS) do
	table.insert(S.Items, { id = b[1], slot = "backpack", name = b[2], price = b[3], grade = b[4], stats = b[5], desc = b[6], tier = k })
end

-- ===== КРАФТ: находки из куч лома, нужные помимо батарей =====
S.Mats = {
	-- инструменты
	shovel = { nut = 3, wire = 1 },
	pickaxe = { nut = 5, cog = 2 },
	magrake = { cog = 4, wire = 6, oldbattery = 3 },
	jackhammer = { cog = 8, chip = 3, keycard = 1 },
	vacuum = { chip = 6, dronecell = 3, slime = 3 },
	plasmacutter = { plutonium = 2, radcrystal = 6, blueprint = 1 },
	-- оружие
	pipe = { nut = 3, wire = 2 },
	bat = { nut = 5, tooth = 3, wire = 3 },
	machete = { cog = 3, dogtag = 2, nut = 6 },
	fireaxe = { cog = 5, chip = 3, oldbattery = 4 },
	sledge = { cog = 8, keycard = 1, slime = 2 },
	chainsaw = { chip = 6, dronecell = 3, radcrystal = 3 },
	baton = { dronecell = 5, radcrystal = 5, blueprint = 1, plutonium = 1 },
	scythe = { plutonium = 3, omegacore = 1, goldbar = 2, mutantheart = 2 },
	-- броня
	armor1 = { nut = 2, wire = 2 },
	armor2 = { dogtag = 1, nut = 5, wire = 4 },
	armor3 = { cog = 4, dogtag = 2, keycard = 1 },
	armor4 = { radcrystal = 3, slime = 3, cog = 6 },
	armor5 = { plutonium = 2, mutantheart = 1, radcrystal = 6 },
	-- шлемы
	helmet1 = { nut = 2 },
	helmet2 = { cog = 1, nut = 4 },
	helmet3 = { chip = 2, cog = 3 },
	helmet4 = { slime = 4, chip = 4 },
	helmet5 = { mutantheart = 1, blueprint = 1, slime = 6 },
	-- перчатки
	gloves1 = { wire = 2 },
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
	bp_sack = { wire = 2 },
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

-- суммарные характеристики по экипировке
function S.Totals(gear)
	local t = { hp = 0, def = 0, scrap = 0, speed = 0, jump = 0, cap = 0, conv = 0, cspeed = 0 }
	for _, slot in ipairs({ "armor", "helmet", "gloves", "boots", "backpack" }) do
		local it = gear and gear[slot] and S.ById[gear[slot]]
		if it then
			for k, v in pairs(it.stats) do
				t[k] = (t[k] or 0) + v
			end
		end
	end
	t.def = math.min(t.def, 0.8)
	t.speed = math.min(t.speed, 32)
	return t
end

return S
