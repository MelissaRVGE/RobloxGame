-- Предметы, которые случайно выпадают с мест добычи, зомби и босса. Хранятся в рюкзаке.
local C = Color3.fromRGB
local I = {}

I.Tiers = {
	Common = { order = 1, name = "Обычный", color = C(200, 200, 200), weight = 600 },
	Uncommon = { order = 2, name = "Необычный", color = C(110, 220, 80), weight = 250 },
	Rare = { order = 3, name = "Редкий", color = C(60, 150, 255), weight = 110 },
	Epic = { order = 4, name = "Эпический", color = C(180, 80, 255), weight = 34 },
	Legendary = { order = 5, name = "Легендарный", color = C(255, 190, 30), weight = 6 },
}
I.TierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- use: heal / speed / energy / gems (что делает при использовании); value — цена продажи в батареях
I.List = {
	{ id = "nut", name = "Ржавая гайка", tier = "Common", value = 40, desc = "Когда-то держала мост. Теперь держит только ржавчину." },
	{ id = "wire", name = "Медная проволока", tier = "Common", value = 60, desc = "Моток меди — ценная вещь для пайки дронов." },
	{ id = "oldbattery", name = "Старая батарейка", tier = "Common", value = 50, desc = "Почти села. Почти." },
	{ id = "cans", name = "Консервы", tier = "Common", value = 70, use = { heal = 30 }, desc = "Тушёнка 2019 года. Восстанавливает 30 здоровья." },
	{ id = "tooth", name = "Зуб зомби", tier = "Common", value = 55, desc = "Трофей. Не спрашивай, откуда." },
	{ id = "cog", name = "Шестерёнка", tier = "Uncommon", value = 150, desc = "Идеально подойдёт для ремонта винтов." },
	{ id = "chip", name = "Микросхема", tier = "Uncommon", value = 220, desc = "Мозг старого робота-пылесоса." },
	{ id = "energydrink", name = "Энергетик", tier = "Uncommon", value = 180, use = { speed = 8, time = 30 }, desc = "+8 к скорости на 30 секунд." },
	{ id = "bandage", name = "Бинты", tier = "Uncommon", value = 160, use = { heal = 70 }, desc = "Восстанавливают 70 здоровья." },
	{ id = "dogtag", name = "Жетон выжившего", tier = "Uncommon", value = 260, desc = "Имя стёрто. Он сражался до конца." },
	{ id = "dronecell", name = "Аккумулятор дрона", tier = "Rare", value = 600, use = { energy = 0.35 }, desc = "Подзаряжает весь рой на 35%." },
	{ id = "slime", name = "Слизь мутанта", tier = "Rare", value = 700, desc = "Светится и немного шевелится. Учёные заплатят." },
	{ id = "radcrystal", name = "Радиоактивный кристалл", tier = "Rare", value = 900, desc = "Тёплый на ощупь. Лучше не держать в кармане." },
	{ id = "keycard", name = "Ключ-карта", tier = "Rare", value = 1000, desc = "Доступ уровня А. От какой двери — загадка." },
	{ id = "gemshard", name = "Осколок гема", tier = "Rare", value = 400, use = { gems = 1 }, desc = "Используй, чтобы получить 1 гем. Десять осколков — одна крутка." },
	{ id = "blueprint", name = "Чертёж дрона", tier = "Epic", value = 2500, use = { gems = 2 }, desc = "Используй, чтобы получить 2 гема." },
	{ id = "plutonium", name = "Плутониевый стержень", tier = "Epic", value = 4000, use = { energy = 1 }, desc = "Полностью заряжает весь рой." },
	{ id = "mutantheart", name = "Сердце мутанта", tier = "Epic", value = 5000, use = { heal = 9999 }, desc = "Всё ещё бьётся. Полностью восстанавливает здоровье." },
	{ id = "goldbar", name = "Золотой слиток", tier = "Legendary", value = 15000, desc = "Из хранилища падшего банка. Дорого продаётся." },
	-- капсулы дронов (аналог Королевского желе и яиц): бесплатная крутка гачи где угодно
	{ id = "capsule", name = "Капсула прошивки", tier = "Epic", value = 3000, w = 0.2, use = { pull = true }, desc = "Перепрошивает случайного дрона из гачи. Считается как обычная крутка (с гарантом)." },
	{ id = "goldcapsule", name = "Золотая капсула", tier = "Legendary", value = 12000, w = 0.15, use = { pull = "Epic" }, desc = "Дрон из гачи редкости «Эпический» или выше." },
	{ id = "starcapsule", name = "Звёздная капсула", tier = "Legendary", value = 25000, w = 0.03, use = { pull = "Legendary" }, desc = "Дрон из гачи редкости «Легендарный» или выше. Сияет даже днём." },
	{ id = "omegacore", name = "Ядро «Омега»", tier = "Legendary", value = 30000, use = { gems = 5 }, desc = "Источник силы секретного дрона. Даёт 5 гемов — но лучшие вещи крафтятся именно из него." },
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
I.BagSlots = 20 -- сколько разных предметов помещается (стаки до 99)
I.StackMax = 99

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
