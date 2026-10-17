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
		name = "Доктор Лиза",
		role = "Врач лазарета",
		color = C(255, 110, 110),
		greet = "Держись подальше от их зубов. Я ищу вакцину — и мне нужен кто-то смелый.",
		migrate = { 1, 3, 4, 7, 9, 11, 13, 14 },
		quests = {
			{ title = "Первая помощь", text = "Зомби подходят к лазарету слишком близко. Отгони их от Пустоши и натаскай лома на баррикады.",
				goals = { { t = "kill", field = "wasteland", n = 12 }, { t = "scrap", n = 800 } },
				reward = { batteries = 1500, gems = 5, items = { nut = 2, wire = 2 }, consum = { medkit = 2 } } },
			{ title = "Консервы для лазарета", text = "Раненым нечего есть. В кучах лома иногда попадаются консервы — принеси мне пару банок.",
				goals = { { t = "deliver", id = "cans", n = 2 }, { t = "kill", n = 30 } },
				reward = { batteries = 3000, gems = 8, items = { tooth = 2, wire = 2, bandage = 1 } } },
			{ title = "Образцы ткани", text = "Чтобы понять вирус, мне нужны образцы. Зубы зомби сохраняют вирус лучше всего. Да, это мерзко.",
				goals = { { t = "deliver", id = "tooth", n = 3 }, { t = "kill", field = "deadcity", n = 40 } },
				reward = { batteries = 6000, gems = 10, items = { dogtag = 1, nut = 4 } } },
			{ title = "Стерильность", text = "Мне нужны бинты для перевязок и доказательство, что ты умеешь себя лечить. На задании мёртвый герой никому не нужен.",
				goals = { { t = "deliver", id = "bandage", n = 3 }, { t = "use", id = "medkit", n = 3 }, { t = "kill", field = "deadcity", n = 80 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 2, energydrink = 2 }, consum = { lube = 2 } } },
			{ title = "Ночной обход", text = "Ночью вирус просыпается. Пройдись по полям после заката и принеси энергетики — мои санитары засыпают на ходу.",
				goals = { { t = "kill", night = true, n = 30 }, { t = "deliver", id = "energydrink", n = 2 }, { t = "scrap", res = "chips", n = 40000 } },
				reward = { batteries = 25000, gems = 15, items = { chip = 2, bandage = 2 }, consum = { stim = 1 } } },
			{ title = "Болотная лихорадка", text = "С Гнилого болота пришла новая зараза. Зачисти утопленников и привези биомассу — я сделаю из неё культуру.",
				goals = { { t = "kill", field = "swamp", n = 120 }, { t = "deliver", id = "tooth", n = 8 }, { t = "scrap", res = "bio", n = 150000 } },
				reward = { batteries = 70000, gems = 20, items = { slime = 2, cog = 3 } } },
			{ title = "Заражённая кровь", text = "Ночью вирус активизируется. Мне нужны данные именно с ночных зомби — и с болотных утопленников.",
				goals = { { t = "kill", night = true, n = 80 }, { t = "kill", field = "swamp", n = 220 }, { t = "deliver", id = "energydrink", n = 4 } },
				reward = { batteries = 150000, gems = 25, items = { slime = 3, dronecell = 2 } } },
			{ title = "Карантин", text = "Лазарет переполнен. Мне нужны бинты, слизь для антисептика и люди, которые не боятся подходить к больным.",
				goals = { { t = "deliver", id = "bandage", n = 6 }, { t = "deliver", id = "slime", n = 3 }, { t = "use", id = "cocktail", n = 2 }, { t = "kill", field = "swamp", n = 350 } },
				reward = { batteries = 350000, gems = 30, items = { radcrystal = 2, slime = 3 }, consum = { cocktail = 1 } } },
			{ title = "Слизь мутанта", text = "Слизь мутантов — катализатор мутации. Если я права, из неё можно сделать антидот.",
				goals = { { t = "deliver", id = "slime", n = 6 }, { t = "kill", field = "radzone", n = 300 }, { t = "scrap", res = "uranium", n = 4000000 } },
				reward = { batteries = 1200000, gems = 40, items = { mutantheart = 1, radcrystal = 3 } } },
			{ title = "Сыворотка", text = "Первая сыворотка готова, но ей нужен стабилизатор. Радиокристаллы, сердце мутанта и испытания на ночных тварях.",
				goals = { { t = "deliver", id = "radcrystal", n = 6 }, { t = "deliver", id = "mutantheart", n = 1 }, { t = "kill", night = true, n = 250 } },
				reward = { batteries = 3000000, gems = 50, items = { mutantheart = 1, plutonium = 1, capsule = 1 } } },
			{ title = "Сердце болезни", text = "Сердце мутанта всё ещё бьётся — вирус держит его живым. Добудь мне ещё сердец и проверь сыворотку на самом Колоссе.",
				goals = { { t = "deliver", id = "mutantheart", n = 3 }, { t = "bossDamage", n = 500000 }, { t = "kill", field = "radzone", n = 800 } },
				reward = { batteries = 4500000, gems = 60, items = { plutonium = 2, slime = 5 }, consum = { rageextract = 2 } } },
			{ title = "Полевой госпиталь", text = "Солдаты на Военной базе — тоже чьи-то сыновья. Разверни там госпиталь: бинты, коктейли и зачистка периметра.",
				goals = { { t = "kill", field = "military", n = 400 }, { t = "deliver", id = "bandage", n = 15 }, { t = "use", id = "cocktail", n = 8 } },
				reward = { batteries = 8000000, gems = 80, items = { mutantheart = 2, blueprint = 1 } } },
			{ title = "Вакцина «Рассвет»", text = "Последний ингредиент — кровь Колосса. Он первый заражённый. Сделаешь это — и мы спасём тех, кто ещё жив.",
				goals = { { t = "bossKill", n = 4 }, { t = "deliver", id = "mutantheart", n = 4 }, { t = "kill", field = "military", n = 2000 } },
				reward = { batteries = 15000000, gems = 120, items = { goldbar = 1, mutantheart = 2 }, perk = { hp = 50 } }, perkText = "Навсегда +50 к максимальному здоровью" },
			{ title = "Эпидемия", text = "Вирус мутировал. Новый штамм приходит только ночью. Мне нужны тонны образцов, пока он не добрался до базы.",
				goals = { { t = "kill", night = true, n = 2000 }, { t = "deliver", id = "slime", n = 25 }, { t = "deliver", id = "radcrystal", n = 25 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, plutonium = 2 }, consum = { supershake = 1 } } },
			{ title = "Лекарство от апокалипсиса", text = "Это оно. Финальная формула. Двенадцать побед над Колоссом, сердца мутантов и золото на оборудование. Человечество в твоих руках.",
				goals = { { t = "bossKill", n = 12 }, { t = "deliver", id = "mutantheart", n = 12 }, { t = "deliver", id = "goldbar", n = 4 }, { t = "kill", field = "military", n = 6000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 1, goldbar = 2, mutantheart = 2 }, perk = { hp = 100 } }, perkText = "Навсегда +100 к максимальному здоровью" },
		},
	},
	{
		id = "sergeant",
		name = "Сержант Громов",
		role = "Командир заставы",
		color = C(150, 200, 90),
		greet = "Смирно, боец! На этой базе выживают только те, кто умеет стрелять. Или бить трубой.",
		migrate = { 1, 3, 4, 5, 9, 10, 13, 14 },
		quests = {
			{ title = "Боевое крещение", text = "Покажи, что ты не обуза. Положи пару десятков ходоков — и я выдам тебе гранаты.",
				goals = { { t = "kill", n = 20 } },
				reward = { batteries = 1500, gems = 5, items = { nut = 3, wire = 1 }, consum = { grenade = 2 } } },
			{ title = "Первая вылазка", text = "Пустошь — наш задний двор. Прочеши её как следует и подбирай всё, что ускоряет, — пригодится.",
				goals = { { t = "kill", field = "wasteland", n = 50 }, { t = "pickup", n = 3 } },
				reward = { batteries = 3000, gems = 8, items = { tooth = 3, nut = 2 } } },
			{ title = "Огневая мощь", text = "Скребком мир не спасёшь. Скрафти себе настоящее оружие и научись бросать гранаты.",
				goals = { { t = "craft", slot = "weapon", n = 1 }, { t = "use", id = "grenade", n = 2 }, { t = "kill", n = 80 } },
				reward = { batteries = 6000, gems = 10, items = { dogtag = 2, wire = 2 } } },
			{ title = "Патруль города", text = "В Мёртвом городе пропал мой отряд. Найди их жетоны и отомсти за ребят.",
				goals = { { t = "kill", field = "deadcity", n = 120 }, { t = "deliver", id = "dogtag", n = 2 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 3, dogtag = 1 } } },
			{ title = "Ночная смена", text = "Ночью они вдвое злее. Именно поэтому настоящий солдат выходит в патруль ночью. Двигайся быстро.",
				goals = { { t = "kill", night = true, n = 40 }, { t = "pickup", n = 10 } },
				reward = { batteries = 25000, gems = 15, items = { keycard = 1, cog = 3 }, consum = { medkit = 5 } } },
			{ title = "Зачистка болота", text = "Утопленники лезут из топи прямо к дороге. Закидай их гранатами и найди жетоны тех, кто не вернулся.",
				goals = { { t = "kill", field = "swamp", n = 150 }, { t = "use", id = "grenade", n = 10 }, { t = "deliver", id = "dogtag", n = 4 } },
				reward = { batteries = 70000, gems = 20, items = { chip = 3, oldbattery = 3 } } },
			{ title = "Отряд «Сапсан»", text = "Собираю ударный отряд. Тебе нужна броня получше и опыт ночных боёв на болоте.",
				goals = { { t = "kill", field = "swamp", n = 300 }, { t = "kill", night = true, n = 100 }, { t = "craft", n = 3 } },
				reward = { batteries = 150000, gems = 25, items = { keycard = 1, radcrystal = 2 }, consum = { stim = 3 } } },
			{ title = "Позывной «Гром»", text = "Две с половиной тысячи на твоём счету — и позывной твой. Плюс ключ-карты от складов и полная выкладка на бегу.",
				goals = { { t = "killTotal", n = 2500 }, { t = "deliver", id = "keycard", n = 2 }, { t = "pickup", n = 40 } },
				reward = { batteries = 350000, gems = 30, items = { dronecell = 2, radcrystal = 3 }, consum = { grenade = 10 } } },
			{ title = "Радиоактивный рубеж", text = "Мутанты прорвали рубеж у Радзоны. Держи линию, коли стимуляторы и собирай жетоны павших.",
				goals = { { t = "kill", field = "radzone", n = 400 }, { t = "use", id = "stim", n = 5 }, { t = "deliver", id = "dogtag", n = 8 } },
				reward = { batteries = 1200000, gems = 40, items = { plutonium = 1, keycard = 2 } } },
			{ title = "Операция «Колосс»", text = "Разведка доложила: на 4-м ярусе, выше по дороге, обитает гигант. Собери отряд и свали его. Это приказ.",
				goals = { { t = "bossKill", n = 1 }, { t = "kill", field = "radzone", n = 600 } },
				reward = { batteries = 3000000, gems = 60, items = { radcrystal = 5, blueprint = 2 } } },
			{ title = "Охота на гиганта", text = "Одна победа — случайность. Три — тактика. Свали Колосса ещё трижды и добудь ключ-карты от его логова.",
				goals = { { t = "bossKill", n = 3 }, { t = "kill", night = true, n = 400 }, { t = "deliver", id = "keycard", n = 5 } },
				reward = { batteries = 4500000, gems = 70, items = { goldbar = 1, plutonium = 1 } } },
			{ title = "Плацдарм", text = "Военная база на плато — наш билет к оружейному складу. Зачисти её и добудь ключ-карты.",
				goals = { { t = "kill", field = "military", n = 400 }, { t = "deliver", id = "keycard", n = 6 } },
				reward = { batteries = 8000000, gems = 80, items = { plutonium = 2, radcrystal = 6 }, consum = { scrapbomb = 5 } } },
			{ title = "Ветеран апокалипсиса", text = "Пятнадцать тысяч побед и шесть поверженных гигантов — вот что значит быть легендой. Докажи, что ты ей стал.",
				goals = { { t = "killTotal", n = 15000 }, { t = "bossKill", n = 6 }, { t = "kill", field = "military", n = 1500 } },
				reward = { batteries = 15000000, gems = 150, items = { goldbar = 2, mutantheart = 1 }, perk = { dmg = 0.15 } }, perkText = "Навсегда +15% к урону по зомби" },
			{ title = "Генеральная зачистка", text = "Штаб требует очистить базу полностью. Днём и ночью, с экстрактом ярости в крови. Ни шагу назад.",
				goals = { { t = "kill", field = "military", n = 3000 }, { t = "kill", night = true, n = 1500 }, { t = "use", id = "rageextract", n = 10 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, goldbar = 2 }, consum = { mutagen = 2 } } },
			{ title = "Легенда пустошей", text = "О тебе уже поют у костров. Тридцать тысяч зомби, двенадцать Колоссов. Сделай это — и я отдам тебе свой старый орден.",
				goals = { { t = "killTotal", n = 30000 }, { t = "bossKill", n = 12 }, { t = "kill", field = "military", n = 5000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, plutonium = 3 }, perk = { dmg = 0.25 } }, perkText = "Навсегда +25% к урону по зомби" },
		},
	},
	{
		id = "mechanic",
		name = "Механик Кузьмич",
		role = "Инженер дронов",
		color = C(255, 170, 60),
		greet = "А, новенький! Дроны — это тебе не игрушки. Каждый винтик на счету. Работы — вагон.",
		migrate = { 1, 3, 4, 6, 8, 10, 13, 14 },
		quests = {
			{ title = "Металлолом", text = "Переработчик стоит без дела. Натаскай лома и переработай его — посмотрим, как он тянет.",
				goals = { { t = "scrap", n = 1000 }, { t = "convert", n = 800 } },
				reward = { batteries = 1500, gems = 5, items = { wire = 2, nut = 3 } } },
			{ title = "Ржавые запасы", text = "Мне нужна ржавчина — да, именно ржавчина, для грунтовки. В Пустоши её полно. И пару гаек сверху.",
				goals = { { t = "scrap", res = "rust", n = 5000 }, { t = "deliver", id = "nut", n = 3 } },
				reward = { batteries = 3000, gems = 8, items = { nut = 3, oldbattery = 2 } } },
			{ title = "Запчасти", text = "Рюкзак у тебя крошечный. Принеси проволоку — и улучши его, не позорься.",
				goals = { { t = "deliver", id = "wire", n = 3 }, { t = "bagUp", n = 2 } },
				reward = { batteries = 6000, gems = 10, items = { wire = 4, cog = 2 } } },
			{ title = "Расширение роя", text = "Рой из трёх дронов — это не рой. Собери побольше и докупи гнёзд на станцию, чтобы заряжать их.",
				goals = { { t = "swarm", n = 6 }, { t = "cells", n = 6 }, { t = "charged", n = 25 } },
				reward = { batteries = 12000, gems = 12, items = { cog = 3, chip = 2 } } },
			{ title = "Электроника города", text = "В Мёртвом городе валяются целые платы. Набери микросхем, принеси шестерёнки и прогони всё через переработчик.",
				goals = { { t = "scrap", res = "chips", n = 50000 }, { t = "deliver", id = "cog", n = 3 }, { t = "convert", n = 60000 } },
				reward = { batteries = 25000, gems = 15, items = { oldbattery = 3, cog = 3, chip = 2 } } },
			{ title = "Производство", text = "Батареи — это жизнь базы. Переработай гору лома и принеси старые батарейки на запчасти.",
				goals = { { t = "convert", n = 300000 }, { t = "deliver", id = "oldbattery", n = 6 }, { t = "swarm", n = 10 } },
				reward = { batteries = 70000, gems = 20, items = { dronecell = 1, chip = 4 } } },
			{ title = "Биотопливо", text = "Генератор на биомассе! Привези её с болота, добавь шестерёнок — и смажь своих дронов как следует.",
				goals = { { t = "scrap", res = "bio", n = 1200000 }, { t = "deliver", id = "cog", n = 6 }, { t = "use", id = "lube", n = 5 } },
				reward = { batteries = 150000, gems = 25, items = { dronecell = 2, cog = 6 }, consum = { lube = 5 } } },
			{ title = "Микросхемы", text = "Мне нужны целые микросхемы, чтобы перепрошить зарядные гнёзда. И скрафти себе нормальное снаряжение.",
				goals = { { t = "deliver", id = "chip", n = 8 }, { t = "craft", n = 6 }, { t = "cells", n = 14 } },
				reward = { batteries = 350000, gems = 30, items = { keycard = 1, chip = 6 } } },
			{ title = "Урановый реактор", text = "Уран из Радзоны — топливо для нового реактора. Аккумуляторы для запуска и сотни зарядок, чтобы обкатать гнёзда.",
				goals = { { t = "scrap", res = "uranium", n = 6000000 }, { t = "deliver", id = "dronecell", n = 4 }, { t = "charged", n = 600 } },
				reward = { batteries = 1200000, gems = 40, items = { dronecell = 3, blueprint = 1 } } },
			{ title = "Большой рой", text = "Вот теперь поговорим по-взрослому. Двадцать дронов, двадцать гнёзд и гора переработанного лома.",
				goals = { { t = "swarm", n = 20 }, { t = "cells", n = 20 }, { t = "convert", n = 40000000 } },
				reward = { batteries = 3000000, gems = 50, items = { dronecell = 4, plutonium = 1, blueprint = 1 } } },
			{ title = "Тюнинг", text = "Каждому дрону — по аккумулятору. И весь твой арсенал пора пересобрать из нормальных деталей.",
				goals = { { t = "deliver", id = "dronecell", n = 8 }, { t = "craft", n = 12 }, { t = "scrap", n = 100000000 } },
				reward = { batteries = 4500000, gems = 60, items = { blueprint = 1, chip = 8 }, consum = { motoroil = 3 } } },
			{ title = "Склад боеприпасов", text = "Гильзы с Военной базы — лучшая латунь в округе. Натаскай мне их горой и подкинь шестерёнок.",
				goals = { { t = "scrap", res = "brass", n = 200000000 }, { t = "deliver", id = "cog", n = 30 } },
				reward = { batteries = 8000000, gems = 80, items = { plutonium = 2, dronecell = 5 }, consum = { microconv = 5 } } },
			{ title = "Шедевр инженерии", text = "Говорят, в ядре «Омега» столько энергии, что хватит на весь город. Принеси его — и я разгоню твои перчатки.",
				goals = { { t = "deliver", id = "omegacore", n = 1 }, { t = "cells", n = 35 }, { t = "convert", n = 1500000000 } },
				reward = { batteries = 15000000, gems = 120, items = { goldbar = 1, blueprint = 2 }, perk = { scrap = 0.2 } }, perkText = "Навсегда +20% к сбору лома" },
			{ title = "Фабрика", text = "Строим настоящую фабрику. Миллиарды лома, сорок микросхем и все гнёзда станции под завязку.",
				goals = { { t = "convert", n = 3000000000 }, { t = "deliver", id = "chip", n = 40 }, { t = "cells", n = 45 } },
				reward = { batteries = 30000000, gems = 150, items = { omegacore = 1, dronecell = 8 }, consum = { enzymes = 5 } } },
			{ title = "Сердце базы", text = "Три ядра «Омега» в одном реакторе — и база будет жить вечно. Это работа всей моей жизни. Не подведи.",
				goals = { { t = "deliver", id = "omegacore", n = 3 }, { t = "cells", n = 50 }, { t = "convert", n = 5000000000 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, blueprint = 3 }, perk = { scrap = 0.3 } }, perkText = "Навсегда +30% к сбору лома" },
		},
	},
	{
		id = "professor",
		name = "Профессор Вольт",
		role = "Учёный-аномалист",
		color = C(150, 120, 255),
		greet = "Фасцинирующе! Радиация, аномалии, дроны из капсулы… Этот мир стал одной большой лабораторией!",
		migrate = { 1, 3, 4, 8, 10, 11, 13, 14 },
		quests = {
			{ title = "Первый образец", text = "Дрон-капсула в лаборатории — загадка. Открой её пару раз и принеси мне всё, что найдёшь в кучах лома.",
				goals = { { t = "pull", n = 2 }, { t = "find", n = 2 } },
				reward = { batteries = 1500, gems = 10, items = { nut = 2, oldbattery = 2 } } },
			{ title = "Капсульная лихорадка", text = "Ещё! Мне нужна статистика. Пять круток и побольше находок — наука любит большие выборки.",
				goals = { { t = "pull", n = 5 }, { t = "find", n = 8 } },
				reward = { batteries = 3000, gems = 10, items = { wire = 3, tooth = 1 } } },
			{ title = "Энергия из ничего", text = "Моя теория: старые батарейки под радиацией сами себя заряжают. Нужны образцы и замеры зарядки дронов.",
				goals = { { t = "deliver", id = "oldbattery", n = 3 }, { t = "charged", n = 20 } },
				reward = { batteries = 6000, gems = 15, items = { cog = 2, oldbattery = 2 } } },
			{ title = "Редкий экземпляр", text = "Редкие дроны излучают странные волны. Добудь такого — и продолжай копаться в ломе.",
				goals = { { t = "own", rarity = "Rare", n = 1 }, { t = "find", n = 25 }, { t = "pull", n = 10 } },
				reward = { batteries = 12000, gems = 20, items = { chip = 2, gemshard = 1 } } },
			{ title = "Химия города", text = "Микросхемы и энергетики — идеальная пара для моего опыта с проводимостью. И образцы микросхем с полей города.",
				goals = { { t = "deliver", id = "chip", n = 2 }, { t = "deliver", id = "energydrink", n = 2 }, { t = "scrap", res = "chips", n = 40000 } },
				reward = { batteries = 25000, gems = 20, items = { slime = 1, dogtag = 2 } } },
			{ title = "Эпическая волна", text = "Эпический дрон! Мне нужен эпический дрон! И находки, много находок — для сравнения.",
				goals = { { t = "own", rarity = "Epic", n = 1 }, { t = "pull", n = 25 }, { t = "find", n = 80 } },
				reward = { batteries = 70000, gems = 25, items = { radcrystal = 1, gemshard = 3 } } },
			{ title = "Биомасса", text = "Биомасса с болота шевелится сама по себе. Я хочу знать почему. Привези её — и немного слизи для контроля.",
				goals = { { t = "scrap", res = "bio", n = 1000000 }, { t = "deliver", id = "slime", n = 2 }, { t = "find", n = 150 } },
				reward = { batteries = 150000, gems = 30, items = { radcrystal = 3, gemshard = 2 } } },
			{ title = "Радиационный фон", text = "Кристаллы из Радиоактивной зоны — чистая энергия мутации. Добудь их, только не носи в кармане. И подкинь гайку на удачу.",
				goals = { { t = "deliver", id = "radcrystal", n = 4 }, { t = "use", id = "luckycoin", n = 3 }, { t = "pull", n = 40 } },
				reward = { batteries = 350000, gems = 35, items = { slime = 3, keycard = 1 } } },
			{ title = "Урановая аномалия", text = "Уран здесь ведёт себя неправильно. Мне нужны тонны урана, кристаллы и сотни находок для статистики.",
				goals = { { t = "scrap", res = "uranium", n = 8000000 }, { t = "deliver", id = "radcrystal", n = 8 }, { t = "find", n = 400 } },
				reward = { batteries = 1200000, gems = 45, items = { radcrystal = 4, gemshard = 3 } } },
			{ title = "Чертежи древних", text = "Кто-то проектировал этих дронов ДО катастрофы. Чертежи и легендарный дрон докажут мою теорию!",
				goals = { { t = "deliver", id = "blueprint", n = 2 }, { t = "own", rarity = "Legendary", n = 1 }, { t = "pull", n = 80 } },
				reward = { batteries = 3000000, gems = 60, items = { plutonium = 1, radcrystal = 4, capsule = 1 } } },
			{ title = "Золотая аномалия", text = "Золото и плутоний в одной реакции… Да, это опасно. Нет, я не буду объяснять.",
				goals = { { t = "deliver", id = "plutonium", n = 3 }, { t = "deliver", id = "goldbar", n = 1 }, { t = "find", n = 1200 } },
				reward = { batteries = 4500000, gems = 70, items = { gemshard = 5, blueprint = 1 } } },
			{ title = "Капсульная теория", text = "Капсулы прошивки — ключ к коду дронов. Открой их сам, сделай сотни круток и принеси осколки гемов.",
				goals = { { t = "use", id = "capsule", n = 2 }, { t = "pull", n = 120 }, { t = "deliver", id = "gemshard", n = 10 } },
				reward = { batteries = 8000000, gems = 90, items = { goldbar = 1, radcrystal = 6, goldcapsule = 1 } } },
			{ title = "Теория всего", text = "Последний опыт. Мне нужен мифический дрон и ядро «Омега». Если всё получится — ты станешь самым везучим человеком на свете.",
				goals = { { t = "own", rarity = "Mythic", n = 1 }, { t = "pull", n = 60 }, { t = "deliver", id = "omegacore", n = 1 }, { t = "deliver", id = "mutantheart", n = 2 } },
				reward = { batteries = 15000000, gems = 150, items = { omegacore = 1, gemshard = 5 }, perk = { luck = 0.5 } }, perkText = "Навсегда +50% к шансу находок" },
			{ title = "Квантовый скачок", text = "Теория всего оказалась теорией почти всего. Нужно больше данных: крутки, находки, плутоний. Гораздо больше.",
				goals = { { t = "pull", n = 400 }, { t = "find", n = 4000 }, { t = "deliver", id = "plutonium", n = 10 } },
				reward = { batteries = 30000000, gems = 150, items = { goldbar = 2, plutonium = 2, goldcapsule = 2 } } },
			{ title = "Секрет дронов", text = "Я наконец понял, откуда взялись дроны. Помоги собрать последнюю установку — и ты узнаешь секрет первым.",
				goals = { { t = "pull", n = 500 }, { t = "deliver", id = "omegacore", n = 3 }, { t = "deliver", id = "goldbar", n = 5 }, { t = "own", rarity = "Mythic", n = 1 } },
				reward = { batteries = 60000000, gems = 300, items = { omegacore = 2, goldbar = 3, starcapsule = 1 }, perk = { luck = 0.5 } }, perkText = "Навсегда ещё +50% к шансу находок" },
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

local function big(n)
	if n >= 1e9 then
		return (("%.1f"):format(n / 1e9):gsub("%.0$", "")) .. " млрд"
	elseif n >= 1e6 then
		return (("%.1f"):format(n / 1e6):gsub("%.0$", "")) .. " млн"
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
		return ("Убей %s зомби%s%s"):format(big(g.n), g.field and (" " .. FIELD_NAMES[g.field]) or "", g.night and " ночью" or "")
	elseif t == "scrap" then
		if g.res then
			return ("Собери %s: %s"):format(resName(g.res), big(g.n))
		end
		return ("Собери %s лома%s"):format(big(g.n), g.field and (" " .. FIELD_NAMES[g.field]) or "")
	elseif t == "convert" then
		return ("Переработай %s лома"):format(big(g.n))
	elseif t == "find" then
		return ("Найди %d предметов"):format(g.n)
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
		return ("Убей %s зомби за всё время"):format(big(g.n))
	elseif t == "use" then
		if not g.id then
			return ("Используй любые расходники x%d"):format(g.n)
		end
		return ("Используй: %s x%d"):format(consumName(g.id) or itemName or g.id, g.n)
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
		return ("Нанеси Колоссу %s урона"):format(big(g.n))
	end
	return t
end

return Q
