-- Донат-магазин (как в Bee Swarm Simulator): пропуска навсегда и товары за Robux.
-- Бонусы подобраны так, чтобы не ломать баланс: пропуска дают удобство и умеренные проценты,
-- товары — гемы, капсулы и расходники, которые и так добываются в игре.
--
-- КАК ПОДКЛЮЧИТЬ: на create.roblox.com → игра → Monetization создать пропуска (Passes) и
-- товары разработчика (Developer Products) с ценами из этого файла и вписать их номера в поле id.
-- Пока id = 0, кнопка покупки показывает «скоро в продаже» и ничего не списывает.
local C = Color3.fromRGB

local D = {}

D.Tabs = {
	{ key = "passes", name = "Пропуска", icon = "⭐", color = C(255, 200, 60), hint = "Покупаются один раз и действуют навсегда" },
	{ key = "gems", name = "Гемы", icon = "💎", color = C(90, 200, 255), hint = "Гемы для гачи дронов" },
	{ key = "packs", name = "Наборы", icon = "🎁", color = C(255, 110, 200), hint = "Капсулы дронов и расходники" },
}

-- kind: "pass" — Game Pass (навсегда), "product" — Developer Product (можно покупать много раз)
-- perk (только у пропусков): прибавки к характеристикам игрока
--   cspeed — скорость переработки, cap — вместимость рюкзака, luck — шанс находок,
--   speed — скорость бега (ед.), dgather — сбор лома дронами, conv — батареи с переработки,
--   playGems — множитель гемов за время в игре
-- grant (у товаров): gems, items = { id = n } (находки в рюкзак), consum = { id = n } (расходники)
-- anim — вид анимации иконки в карточке; badge — ленточка в углу
D.List = {
	-- ===== ПРОПУСКА =====
	{
		key = "turbo", kind = "pass", id = 0, price = 149, tab = "passes",
		name = "Турбо-переработка", short = "Переработка в 2 раза быстрее",
		desc = "Переработчик съедает лом вдвое быстрее. Меньше ждать на площадке — больше времени на полях.",
		perk = { cspeed = 1 }, color = C(130, 255, 110), anim = "spin",
	},
	{
		key = "bigbag", kind = "pass", id = 0, price = 199, tab = "passes",
		name = "Большой рюкзак", short = "+25% вместимости рюкзака",
		desc = "Усиленные лямки и лишний карман: в рюкзак влезает на четверть больше лома.",
		perk = { cap = 0.25 }, color = C(255, 170, 60), anim = "bounce",
	},
	{
		key = "lucky", kind = "pass", id = 0, price = 199, tab = "passes",
		name = "Счастливый сканер", short = "+25% к шансу находок",
		desc = "Сканер подсвечивает тайники в кучах лома: находки и ящички падают чаще.",
		perk = { luck = 0.25 }, color = C(120, 240, 90), anim = "orbit",
	},
	{
		key = "sprint", kind = "pass", id = 0, price = 99, tab = "passes",
		name = "Кроссовки бегуна", short = "+3 к скорости бега",
		desc = "Лёгкие кроссовки с амортизацией: быстрее бегаешь между полями и базой.",
		perk = { speed = 3 }, color = C(80, 210, 255), anim = "dash",
	},
	{
		key = "gemtime", kind = "pass", id = 0, price = 299, tab = "passes", badge = "×2",
		name = "Гем-магнит", short = "×2 гемов за время в игре",
		desc = "Каждые 10 минут в игре — не 2, а 4 гема. Накопленное время не сгорает при выходе.",
		perk = { playGems = 2 }, color = C(90, 200, 255), anim = "swing",
	},
	{
		key = "vip", kind = "pass", id = 0, price = 499, tab = "passes", badge = "VIP",
		name = "VIP выжившего", short = "+10% сбор роя и +10% батарей",
		desc = "Золотой статус: дроны собирают на 10% больше лома, Переработчик даёт на 10% больше батарей.",
		perk = { dgather = 0.1, conv = 0.1 }, color = C(255, 210, 60), anim = "crown",
	},

	-- ===== ГЕМЫ =====
	{
		key = "gems1", kind = "product", id = 0, price = 99, tab = "gems",
		name = "Горсть гемов", short = "120 💎  •  12 круток",
		desc = "Небольшая горсть гемов для гачи дронов.",
		grant = { gems = 120 }, color = C(110, 210, 255), anim = "gems", level = 1,
	},
	{
		key = "gems2", kind = "product", id = 0, price = 449, tab = "gems", badge = "+20%",
		name = "Мешок гемов", short = "650 💎  •  65 круток",
		desc = "Мешок гемов: выгоднее горстей на 20%.",
		grant = { gems = 650 }, color = C(80, 180, 255), anim = "gems", level = 2,
	},
	{
		key = "gems3", kind = "product", id = 0, price = 899, tab = "gems", badge = "+33%",
		name = "Сундук гемов", short = "1 450 💎  •  145 круток",
		desc = "Сундук с гемами: на треть выгоднее горстей. Самый популярный выбор.",
		grant = { gems = 1450 }, color = C(150, 120, 255), anim = "gems", level = 3,
	},
	{
		key = "gems4", kind = "product", id = 0, price = 1799, tab = "gems", badge = "+40%",
		name = "Хранилище гемов", short = "3 050 💎  •  305 круток",
		desc = "Целое хранилище гемов: самое выгодное предложение, на 40% больше гемов за Robux.",
		grant = { gems = 3050 }, color = C(255, 120, 220), anim = "gems", level = 4,
	},

	-- ===== НАБОРЫ =====
	{
		key = "starter", kind = "product", id = 0, price = 149, tab = "packs", once = true, badge = "1 РАЗ",
		name = "Набор новичка", short = "300 💎, Золотая капсула и бусты",
		desc = "Только один раз: 300 гемов, Золотая капсула (эпический дрон или лучше), 3 Мини-переработчика и 3 Счастливые гайки.",
		grant = { gems = 300, items = { goldcapsule = 1 }, consum = { microconv = 3, luckycoin = 3 } },
		color = C(255, 120, 90), anim = "gift",
	},
	{
		key = "goldcap", kind = "product", id = 0, price = 129, tab = "packs",
		name = "Золотая капсула", short = "Эпический дрон или лучше",
		desc = "Капсула прошивки с гарантией: дрон из гачи редкости «Эпический» или выше. Ложится в рюкзак.",
		grant = { items = { goldcapsule = 1 } }, color = C(255, 200, 50), anim = "capsule",
	},
	{
		key = "starcap", kind = "product", id = 0, price = 499, tab = "packs", badge = "ЛЕГЕНДА",
		name = "Звёздная капсула", short = "Легендарный дрон или лучше",
		desc = "Самая редкая капсула: дрон редкости «Легендарный» или выше (бывают и Мифические!). Ложится в рюкзак.",
		grant = { items = { starcapsule = 1 } }, color = C(255, 120, 230), anim = "capsule",
	},
	{
		key = "boosts", kind = "product", id = 0, price = 199, tab = "packs",
		name = "Ящик бустов", short = "13 усилителей для роя",
		desc = "3 Счастливые гайки, 3 Экстракта сборщика, 3 Экстракта ярости, 2 Ферментов и 2 Моторных масла.",
		grant = { consum = { luckycoin = 3, gatherextract = 3, rageextract = 3, enzymes = 2, motoroil = 2 } },
		color = C(255, 150, 50), anim = "shake",
	},
	{
		key = "microconv", kind = "product", id = 0, price = 49, tab = "packs",
		name = "5 Мини-переработчиков", short = "Рюкзак → батареи прямо на поле",
		desc = "5 карманных утилизаторов: весь лом в рюкзаке сразу превращается в батареи, где бы ты ни был.",
		grant = { consum = { microconv = 5 } }, color = C(130, 255, 120), anim = "recycle",
	},
	{
		key = "supershake", kind = "product", id = 0, price = 149, tab = "packs",
		name = "Суперкоктейль", short = "Все баффы роя на максимум",
		desc = "Суперкоктейль «Апокалипсис»: максимум ступеней всех баффов роя и полное здоровье.",
		grant = { consum = { supershake = 1 } }, color = C(255, 110, 190), anim = "rainbow",
	},
}

D.ByKey = {}
D.ByPass = {} -- id пропуска → предложение
D.ByProduct = {} -- id товара → предложение
for i, o in ipairs(D.List) do
	o.index = i
	D.ByKey[o.key] = o
	if o.id and o.id > 0 then
		if o.kind == "pass" then
			D.ByPass[o.id] = o
		else
			D.ByProduct[o.id] = o
		end
	end
end

-- сумма бонуса stat по всем пропускам игрока (passes = { key = true })
function D.Perk(passes, stat)
	local sum = 0
	for key, on in pairs(passes or {}) do
		local o = on and D.ByKey[key]
		if o and o.perk and o.perk[stat] then
			sum += o.perk[stat]
		end
	end
	return sum
end

return D
