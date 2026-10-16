-- Донат-магазин (как в Bee Swarm Simulator): пропуска навсегда и товары за Robux.
-- Бонусы подобраны так, чтобы не ломать баланс: пропуска дают удобство и умеренные проценты,
-- товары — гемы и расходники, которые и так добываются в игре.
--
-- КАК ПОДКЛЮЧИТЬ: на create.roblox.com → игра → Monetization создать пропуска (Passes) и
-- товары разработчика (Developer Products) с ценами из этого файла и вписать их номера в поле id.
-- Пока id = 0, кнопка покупки показывает «скоро в продаже» и ничего не списывает.
local C = Color3.fromRGB

local D = {}

D.Tabs = {
	{ key = "passes", name = "Passes", icon = "⭐", color = C(255, 200, 60), hint = "Buy once, keep forever" },
	{ key = "gems", name = "Gems", icon = "💎", color = C(90, 200, 255), hint = "Gems for the drone gacha" },
	{ key = "packs", name = "Bundles", icon = "🎁", color = C(255, 110, 200), hint = "Boosts and consumables for your swarm" },
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
		key = "turbo", kind = "pass", id = 2040722493, price = 149, tab = "passes",
		name = "Turbo Recycler", short = "Recycling 2x faster",
		desc = "The Recycler eats scrap twice as fast. Less waiting at the pad, more time in the fields.",
		perk = { cspeed = 1 }, color = C(130, 255, 110), anim = "spin",
	},
	{
		key = "lucky", kind = "pass", id = 2040044750, price = 199, tab = "passes",
		name = "Lucky Scanner", short = "+25% find chance",
		desc = "The scanner highlights stashes in scrap piles: finds and crates drop more often.",
		perk = { luck = 0.25 }, color = C(120, 240, 90), anim = "orbit",
	},
	{
		key = "vip", kind = "pass", id = 2036955012, price = 399, tab = "passes", badge = "VIP",
		name = "Survivor VIP", short = "+10% swarm gathering, +10% batteries",
		desc = "Golden status: drones gather 10% more scrap and the Recycler gives 10% more batteries.",
		perk = { dgather = 0.1, conv = 0.1 }, color = C(255, 210, 60), anim = "crown",
	},

	-- ===== ГЕМЫ =====
	{
		key = "gems1", kind = "product", id = 0, price = 199, tab = "gems",
		name = "Handful of Gems", short = "120 💎  •  12 rolls",
		desc = "A small handful of gems for the drone gacha.",
		grant = { gems = 120 }, color = C(110, 210, 255), anim = "gems", level = 1,
	},
	{
		key = "gems2", kind = "product", id = 0, price = 899, tab = "gems", badge = "+20%",
		name = "Bag of Gems", short = "650 💎  •  65 rolls",
		desc = "A bag of gems: 20% better value than handfuls.",
		grant = { gems = 650 }, color = C(80, 180, 255), anim = "gems", level = 2,
	},
	{
		key = "gems3", kind = "product", id = 0, price = 1799, tab = "gems", badge = "+33%",
		name = "Chest of Gems", short = "1,450 💎  •  145 rolls",
		desc = "A chest of gems: a third better value than handfuls. The most popular choice.",
		grant = { gems = 1450 }, color = C(150, 120, 255), anim = "gems", level = 3,
	},
	{
		key = "gems4", kind = "product", id = 0, price = 3599, tab = "gems", badge = "+40%",
		name = "Gem Vault", short = "3,050 💎  •  305 rolls",
		desc = "A whole vault of gems: the best deal, 40% more gems per Robux.",
		grant = { gems = 3050 }, color = C(255, 120, 220), anim = "gems", level = 4,
	},

	-- ===== НАБОРЫ =====
	{
		key = "starter", kind = "product", id = 0, price = 199, tab = "packs", once = true, badge = "ONCE",
		name = "Starter Pack", short = "200 💎 + 8 boosts",
		desc = "One time only: 200 gems, 3 Mini Recyclers, 3 Lucky Nuts and 2 Gatherer Extracts.",
		grant = { gems = 200, consum = { microconv = 3, luckycoin = 3, gatherextract = 2 } },
		color = C(255, 120, 90), anim = "gift",
	},
	{
		key = "boosts", kind = "product", id = 0, price = 199, tab = "packs",
		name = "Boost Crate", short = "13 swarm boosts",
		desc = "3 Lucky Nuts, 3 Gatherer Extracts, 3 Rage Extracts, 2 Enzymes and 2 Motor Oils.",
		grant = { consum = { luckycoin = 3, gatherextract = 3, rageextract = 3, enzymes = 2, motoroil = 2 } },
		color = C(255, 150, 50), anim = "shake",
	},
	{
		key = "microconv", kind = "product", id = 0, price = 49, tab = "packs",
		name = "5 Mini Recyclers", short = "Backpack → batteries right in the field",
		desc = "5 pocket recyclers: all scrap in your backpack instantly turns into batteries, wherever you are.",
		grant = { consum = { microconv = 5 } }, color = C(130, 255, 120), anim = "recycle",
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
