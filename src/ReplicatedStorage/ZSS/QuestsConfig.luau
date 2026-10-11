-- Цепочки квестов четырёх NPC на базе.
-- Типы целей:
--   kill (field?, night?) — убить зомби            scrap — собрать лом
--   convert — переработать лом                 find — найти предметы
--   deliver (id) — принести предмет (забирается при сдаче)
--   pull — крутки гачи        own (rarity) — иметь дрона редкости или выше
--   swarm — дронов в рое        cells — ячеек зарядки       killTotal — убийств за всё время
--   use (id) — использовать расходник  craft (slot?) — скрафтить   bagUp — улучшить рюкзак
--   pickup — подобрать ускорение   charged — зарядить дрона до 100%
--   bossKill — победить Колосса   bossDamage — урон по Колоссу
-- Награда: batteries, gems, items={id=n}, consum={id=n}, perk={hp|dmg|scrap|luck = значение}
local C = Color3.fromRGB
local Q = {}

Q.NPCs = {
	{
		id = "doctor",
		name = "Доктор Лиза",
		role = "Врач лазарета",
		color = C(255, 110, 110),
		greet = "Держись подальше от их зубов. Я ищу вакцину — и мне нужен кто-то смелый.",
		quests = {
			{ title = "Первая помощь", text = "В лазарете кончилась еда. Раненые слабеют. Принеси консервы и очисти Пустошь — зомби подходят слишком близко.",
				goals = { { t = "deliver", id = "cans", n = 2 }, { t = "kill", field = "wasteland", n = 15 } },
				reward = { batteries = 5000, gems = 10 } },
			{ title = "Образцы ткани", text = "Чтобы понять вирус, мне нужны образцы. Зубы зомби сохраняют вирус лучше всего. Да, это мерзко.",
				goals = { { t = "deliver", id = "tooth", n = 3 }, { t = "kill", n = 40 } },
				reward = { batteries = 10000, gems = 15, items = { bandage = 2 } } },
			{ title = "Стерильность", text = "Мне нужны бинты для перевязок и доказательство, что ты умеешь себя лечить. На задании мёртвый герой никому не нужен.",
				goals = { { t = "deliver", id = "bandage", n = 4 }, { t = "use", id = "medkit", n = 3 }, { t = "kill", field = "deadcity", n = 30 } },
				reward = { batteries = 25000, gems = 20 } },
			{ title = "Заражённая кровь", text = "Ночью вирус активизируется. Мне нужны данные именно с ночных зомби — и с болотных утопленников.",
				goals = { { t = "kill", night = true, n = 40 }, { t = "kill", field = "swamp", n = 40 }, { t = "deliver", id = "energydrink", n = 2 } },
				reward = { batteries = 80000, gems = 30, items = { dronecell = 1 } } },
			{ title = "Слизь мутанта", text = "Слизь мутантов — катализатор мутации. Если я права, из неё можно сделать антидот.",
				goals = { { t = "deliver", id = "slime", n = 4 }, { t = "kill", field = "radzone", n = 60 }, { t = "deliver", id = "bandage", n = 5 } },
				reward = { batteries = 300000, gems = 45 } },
			{ title = "Сердце болезни", text = "Сердце мутанта всё ещё бьётся — вирус держит его живым. Добудь мне его и проверь новую сыворотку в бою с солдатами.",
				goals = { { t = "deliver", id = "mutantheart", n = 1 }, { t = "kill", field = "military", n = 80 }, { t = "deliver", id = "radcrystal", n = 3 } },
				reward = { batteries = 1500000, gems = 70, items = { dronecell = 2 } } },
			{ title = "Вакцина «Рассвет»", text = "Последний ингредиент — кровь Колосса. Он первый заражённый. Сделаешь это — и мы спасём тех, кто ещё жив.",
				goals = { { t = "bossDamage", n = 100000 }, { t = "bossKill", n = 1 }, { t = "deliver", id = "mutantheart", n = 2 } },
				reward = { batteries = 8000000, gems = 150, perk = { hp = 50 } }, perkText = "Навсегда +50 к максимальному здоровью" },
		},
	},
	{
		id = "sergeant",
		name = "Сержант Громов",
		role = "Командир заставы",
		color = C(150, 200, 90),
		greet = "Смирно, боец! На этой базе выживают только те, кто умеет стрелять. Или бить трубой.",
		quests = {
			{ title = "Боевое крещение", text = "Покажи, что ты не обуза. Зачисти Пустошь и притащи лом — нам нужны укрепления.",
				goals = { { t = "kill", n = 20 }, { t = "scrap", n = 600 } },
				reward = { batteries = 5000, gems = 10, consum = { grenade = 2 } } },
			{ title = "Огневая мощь", text = "Скребком мир не спасёшь. Скрафти себе настоящее оружие и научись бросать гранаты.",
				goals = { { t = "craft", slot = "weapon", n = 1 }, { t = "use", id = "grenade", n = 2 }, { t = "kill", n = 50 } },
				reward = { batteries = 10000, gems = 15 } },
			{ title = "Патруль города", text = "В Мёртвом городе пропал мой отряд. Найди их жетоны и отомсти за ребят.",
				goals = { { t = "kill", field = "deadcity", n = 70 }, { t = "deliver", id = "dogtag", n = 3 } },
				reward = { batteries = 25000, gems = 20 } },
			{ title = "Ночная смена", text = "Ночью они вдвое злее. Именно поэтому настоящий солдат выходит в патруль ночью. Двигайся быстро.",
				goals = { { t = "kill", night = true, n = 60 }, { t = "pickup", n = 6 } },
				reward = { batteries = 80000, gems = 30, consum = { medkit = 5 } } },
			{ title = "Плацдарм", text = "Военная база на плато — наш билет к оружейному складу. Зачисти её и добудь ключ-карты.",
				goals = { { t = "kill", field = "military", n = 100 }, { t = "deliver", id = "keycard", n = 2 } },
				reward = { batteries = 300000, gems = 45, consum = { grenade = 5 } } },
			{ title = "Операция «Колосс»", text = "Разведка доложила: на 5-м ярусе, выше по дороге, обитает гигант. Собери отряд и свали его. Это приказ.",
				goals = { { t = "bossDamage", n = 60000 }, { t = "bossKill", n = 1 } },
				reward = { batteries = 1500000, gems = 100, items = { blueprint = 1 } } },
			{ title = "Ветеран апокалипсиса", text = "Тысяча побед и три поверженных гиганта — вот что значит быть легендой. Докажи, что ты ей стал.",
				goals = { { t = "killTotal", n = 1500 }, { t = "bossKill", n = 3 } },
				reward = { batteries = 8000000, gems = 220, perk = { dmg = 0.15 } }, perkText = "Навсегда +15% к урону по зомби" },
		},
	},
	{
		id = "mechanic",
		name = "Механик Кузьмич",
		role = "Инженер дронов",
		color = C(255, 170, 60),
		greet = "А, новенький! Дроны — это тебе не игрушки. Каждый винтик на счету. Работы — вагон.",
		quests = {
			{ title = "Металлолом", text = "Переработчик стоит без дела. Натаскай лома и переработай его — посмотрим, как он тянет.",
				goals = { { t = "scrap", n = 1500 }, { t = "convert", n = 1000 } },
				reward = { batteries = 5000, gems = 10, items = { nut = 5 } } },
			{ title = "Запчасти", text = "Рюкзак у тебя крошечный. Принеси гайки с проволокой — и улучши его, не позорься.",
				goals = { { t = "deliver", id = "nut", n = 6 }, { t = "deliver", id = "wire", n = 4 }, { t = "bagUp", n = 2 } },
				reward = { batteries = 10000, gems = 15, items = { cog = 2 } } },
			{ title = "Расширение роя", text = "Рой из двух дронов — это не рой. Собери побольше и докупи гнёзд на станцию, чтобы заряжать их.",
				goals = { { t = "swarm", n = 8 }, { t = "cells", n = 6 }, { t = "charged", n = 15 } },
				reward = { batteries = 25000, gems = 20, items = { chip = 2 } } },
			{ title = "Производство", text = "Батареи — это жизнь базы. Переработай гору лома и принеси шестерёнки для станка.",
				goals = { { t = "convert", n = 150000 }, { t = "deliver", id = "cog", n = 5 }, { t = "deliver", id = "oldbattery", n = 4 } },
				reward = { batteries = 80000, gems = 30, items = { dronecell = 2 } } },
			{ title = "Микросхемы", text = "Мне нужны целые микросхемы, чтобы перепрошить зарядные гнёзда. И скрафти себе нормальное снаряжение.",
				goals = { { t = "deliver", id = "chip", n = 6 }, { t = "craft", n = 6 }, { t = "scrap", n = 2000000 } },
				reward = { batteries = 300000, gems = 45 } },
			{ title = "Большой рой", text = "Вот теперь поговорим по-взрослому. Двадцать дронов, гнёзд на полстанции и два аккумулятора для резерва.",
				goals = { { t = "swarm", n = 20 }, { t = "cells", n = 20 }, { t = "deliver", id = "dronecell", n = 3 } },
				reward = { batteries = 1500000, gems = 90, items = { blueprint = 1 } } },
			{ title = "Шедевр инженерии", text = "Говорят, в ядре «Омега» столько энергии, что хватит на весь город. Принеси его — и я разгоню твои перчатки.",
				goals = { { t = "deliver", id = "omegacore", n = 1 }, { t = "cells", n = 35 }, { t = "convert", n = 80000000 } },
				reward = { batteries = 8000000, gems = 220, perk = { scrap = 0.2 } }, perkText = "Навсегда +20% к сбору лома" },
		},
	},
	{
		id = "professor",
		name = "Профессор Вольт",
		role = "Учёный-аномалист",
		color = C(150, 120, 255),
		greet = "Фасцинирующе! Радиация, аномалии, дроны из капсулы… Этот мир стал одной большой лабораторией!",
		quests = {
			{ title = "Первый образец", text = "Дрон-капсула в лаборатории — загадка. Открой её пару раз и принеси мне всё, что найдёшь в кучах лома.",
				goals = { { t = "pull", n = 3 }, { t = "find", n = 3 } },
				reward = { batteries = 5000, gems = 20 } },
			{ title = "Энергия из ничего", text = "Моя теория: старые батарейки под радиацией сами себя заряжают. Нужны образцы и кофеин. Много кофеина.",
				goals = { { t = "deliver", id = "oldbattery", n = 4 }, { t = "deliver", id = "energydrink", n = 2 }, { t = "charged", n = 10 } },
				reward = { batteries = 10000, gems = 25 } },
			{ title = "Редкий экземпляр", text = "Эпические дроны излучают странные волны. Добудь такого — и продолжай копаться в ломе.",
				goals = { { t = "own", rarity = "Epic", n = 1 }, { t = "find", n = 15 }, { t = "pull", n = 10 } },
				reward = { batteries = 25000, gems = 35, items = { chip = 3 } } },
			{ title = "Радиационный фон", text = "Кристаллы из Радиоактивной зоны — чистая энергия мутации. Добудь их, только не носи в кармане.",
				goals = { { t = "deliver", id = "radcrystal", n = 4 }, { t = "kill", field = "radzone", n = 50 }, { t = "deliver", id = "slime", n = 2 } },
				reward = { batteries = 80000, gems = 45 } },
			{ title = "Чертежи древних", text = "Кто-то проектировал этих дронов ДО катастрофы. Чертежи докажут мою теорию!",
				goals = { { t = "deliver", id = "blueprint", n = 2 }, { t = "pull", n = 40 }, { t = "own", rarity = "Legendary", n = 1 } },
				reward = { batteries = 300000, gems = 70, items = { gemshard = 3 } } },
			{ title = "Золотая аномалия", text = "Золото и плутоний в одной реакции… Да, это опасно. Нет, я не буду объяснять.",
				goals = { { t = "deliver", id = "plutonium", n = 2 }, { t = "deliver", id = "goldbar", n = 1 }, { t = "find", n = 80 } },
				reward = { batteries = 1500000, gems = 120 } },
			{ title = "Теория всего", text = "Последний опыт. Мне нужен мифический дрон и ядро «Омега». Если всё получится — ты станешь самым везучим человеком на свете.",
				goals = { { t = "own", rarity = "Mythic", n = 1 }, { t = "deliver", id = "omegacore", n = 1 }, { t = "deliver", id = "mutantheart", n = 1 } },
				reward = { batteries = 8000000, gems = 300, perk = { luck = 0.5 } }, perkText = "Навсегда +50% к шансу находок" },
		},
	},
}

Q.ById = {}
for _, n in ipairs(Q.NPCs) do
	Q.ById[n.id] = n
end

-- текст цели для интерфейса
local FIELD_NAMES = { wasteland = "в Пустоши", deadcity = "в Мёртвом городе", swamp = "на Гнилом болоте", radzone = "в Радиоактивной зоне", military = "на Военной базе" }
local RAR = { Uncommon = "Uncommon", Rare = "Rare", Epic = "Epic", Legendary = "Legendary", Mythic = "Mythic", Secret = "Secret" }
function Q.GoalText(g, itemName)
	local t = g.t
	if t == "kill" then
		return ("Убей %d зомби%s%s"):format(g.n, g.field and (" " .. FIELD_NAMES[g.field]) or "", g.night and " ночью" or "")
	elseif t == "scrap" then
		return ("Собери %s лома"):format(tostring(g.n))
	elseif t == "convert" then
		return ("Переработай %s лома"):format(tostring(g.n))
	elseif t == "find" then
		return ("Найди %d предметов в кучах лома"):format(g.n)
	elseif t == "deliver" then
		return ("Принеси: %s x%d"):format(itemName or g.id, g.n)
	elseif t == "pull" then
		return ("Сделай %d круток гачи"):format(g.n)
	elseif t == "own" then
		return ("Имей дрона редкости %s или выше"):format(RAR[g.rarity] or g.rarity)
	elseif t == "swarm" then
		return ("Имей %d дронов в рое"):format(g.n)
	elseif t == "cells" then
		return ("Имей %d гнёзд на станции зарядки"):format(g.n)
	elseif t == "killTotal" then
		return ("Убей %d зомби за всё время"):format(g.n)
	elseif t == "use" then
		local names = { medkit = "Аптечку", grenade = "Гранату", energycell = "Энергоячейку" }
		return ("Используй %s x%d"):format(names[g.id] or g.id, g.n)
	elseif t == "craft" then
		return g.slot == "weapon" and ("Скрафти оружие x%d"):format(g.n) or ("Скрафти предметы x%d"):format(g.n)
	elseif t == "bagUp" then
		return ("Улучши рюкзак %d раз(а)"):format(g.n)
	elseif t == "pickup" then
		return ("Подбери %d ускорений на полях"):format(g.n)
	elseif t == "charged" then
		return ("Заряди дронов на станции до 100%% x%d"):format(g.n)
	elseif t == "bossKill" then
		return ("Победи Колосса x%d"):format(g.n)
	elseif t == "bossDamage" then
		return ("Нанеси Колоссу %s урона"):format(tostring(g.n))
	end
	return t
end

return Q
