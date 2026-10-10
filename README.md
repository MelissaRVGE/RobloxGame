# Zombie Swarm Simulator

Roblox-игра в духе Bee Swarm Simulator, только вместо пчёл боевые дроны, а вместо цветов поля с ломом и толпы зомби. Весь текст в игре на русском.

## Как работать с кодом (Rojo)

В репозитории лежит только код: 44 скрипта игры. Список промокодов (`ServerStorage.ZSS_PromoCodes`) намеренно не выложен, потому что репозиторий публичный; он живёт только в Studio, и Rojo его не трогает. Карта, модели, меши и освещение хранятся в place-файле Roblox (placeId **86115868987100**). Rojo синхронизирует код из этой папки в Studio.

**Один раз:**

1. Установи Rojo: через [Rokit](https://github.com/rojo-rbx/rokit) командой `rokit install` в папке репозитория или скачай `rojo` 7.4.4 со [страницы релизов](https://github.com/rojo-rbx/rojo/releases).
2. Поставь плагин Rojo в Studio: `rojo plugin install` или найди «Rojo» в Creator Store.
3. Склонируй репозиторий: `git clone https://github.com/MelissaRVGE/RobloxGame`.

**Каждый раз:**

1. В папке репозитория запусти `rojo serve`.
2. Открой место в Studio и нажми **Connect** в плагине Rojo.
3. Меняй код в файлах `src/`, Studio подхватит изменения сам.
4. Сохраняй место в Studio (File → Save to Roblox) и коммить изменения в git.

**Важно:** при подключении Rojo перезаписывает в Studio скрипты, которые описаны в `default.project.json`, версией из файлов. Если менял скрипт прямо в Studio, сначала перенеси правку в файл, иначе она пропадёт. Папки с мешами (`ReplicatedStorage.ZSS.DroneMeshes`, `HelmetMeshes`), `Remotes` и всё, чего нет в `src/`, Rojo не трогает.

## Концепция и основной цикл

1. Игрок бьёт кучи лома оружием или инструментом добычи. Рой дронов летает рядом, собирает ресурсы и атакует зомби.
2. Лом сдаётся в Переработчик (converter pad) и постепенно превращается в **батарейки**.
3. На батарейки покупаются снаряжение, расходники, ячейки улья и улучшения рюкзака.
4. **Гемы** тратятся на гачу дронов. Их дают квесты, босс, редкие находки и промокоды; за батарейки гемы не продаются.
5. Чем больше дронов в рое, тем выше ярусы карты, тем ценнее поля и сильнее зомби.

## Системы

| Система | Как устроено |
|---|---|
| Сервер | 6 игроков. DataStore `ZSS_Profiles_v1`, лидерборды через OrderedDataStore |
| Дроны | 20 дронов в 6 редкостях: Uncommon, Rare, Epic, Legendary, Mythic, Secret. У каждого своя способность; у Королевы есть мини-дроны |
| Гача | 1 крутка стоит 10 гемов, 10 круток стоят 100. На старте 50 гемов. Гарант: Legendary на 500, Mythic на 1500, Secret на 2000 |
| Поля | 5 полей на ярусной карте, открываются по размеру роя: wasteland 0, deadcity 5, swamp 8, radzone 12, military 18. Ресурсы полей: rust, chips, bio, uranium, brass |
| Ворота ярусов | Невидимая стена у обрыва, пока дронов меньше нужного (как «5 Bee Zone») |
| Босс «Колосс» | 1 000 000 HP, логово открывается при 15 дронах. Сбрасывается через 180 с без игроков, возрождается через 120 с. Награда делится по доле урона |
| День и ночь | 1800 с день, 600 с ночь. Ночью урон зомби ×2 и награды ×2 |
| Энергия роя | Дроны разряжаются и заряжаются в личных ульях. 6 ульев по 3–50 ячеек, цена по CellCost. Максимум дронов в рое равен числу ячеек, не больше 25 |
| Рюкзак | Уровни 1–20, улучшаются материалами-находками |
| Находки | 20 предметов в 5 тирах. Ящики падают на землю, магнит их притягивает |
| Баффы | speed, scrap, rage, luck, heal, charge, стакаются до 10 (как в BSS) |
| Магазин «Последний шанс» | Оружие (грейды 1–7), инструменты, броня, шлем, перчатки и ботинки (тиры 1–15). Крафт требует материалов. Есть расходники |
| Квесты | 4 NPC: доктор, сержант, механик, профессор. У каждого цепочка из 7 квестов, последний даёт постоянный перк |
| Промокоды | Список кодов в `ServerStorage.ZSS_PromoCodes`. Он хранится только в Studio и в публичный репозиторий не попадает, чтобы игроки не нашли коды |
| Настройки | Графика, управление, звук, интерфейс, ввод промокодов. Сохраняются в профиль |

Горячие клавиши: Y дроны, G гача, N магазин, B рюкзак, M карта, R телепорт к Переработчику, P настройки, E взаимодействие, 1/2 оружие и инструмент, 3–5 расходники.

## Структура кода (`src/`)

Раскладку описывает `default.project.json`.

- `ServerScriptService/ZSS/Main.server.luau` — точка входа сервера, создаёт Remotes, дебаг-команды.
- `ServerScriptService/ZSS/Modules/` — серверные системы: Data, Fields, Zombies, Drones, Gacha, Equipment, Loot, World, Boss, Quests, Hives, Converter, Leaderboard, Drops.
- `ReplicatedStorage/ZSS/` — общие конфиги и сборщики моделей: Config, Icons, ItemsConfig, BuffsConfig, QuestsConfig, ShopConfig, DroneBuilder, ItemBuilder.
- `StarterPlayer/StarterPlayerScripts/ZSSClient/` — клиент: `init.client.luau` (LocalScript), State, U (UI-утилиты и звуки), UI, ShopUI, BagUI, QuestUI, SettingsUI, GachaAnim, FX, WorldFX, DroneRenderer (BulkMoveTo), ZombieAnim и PlayerAnim (процедурно через Motor6D.Transform), DayNight, TierGates.
- `ServerStorage/` — студийные утилиты для построения карты: ZSS_Placer, ZSS_DroneNorm, ZSS_FlowerKit, ZSS_MannequinKit.
- `ReplicatedStorage/Shared/Hello.luau` — заготовка, в игре не используется.

В репозиторий не входят: модели, карта, меши и бэкапы в ServerStorage (`ZSS_MapBackup_Old`, `ZSS_Removed` и другие), а также стандартные заглушки `ServerScriptService.Server` и `StarterPlayerScripts.Client` с «Hello world». Они остаются только в place-файле, и Rojo их не трогает.

## Remotes (`ReplicatedStorage.ZSS.Remotes`)

- RemoteEvent: DataSync, DroneState, FX, Notify, Popup, Equip, AutoEquip, Unequip, UnequipAll, Scoop, UpgradeBag, Teleport, ShopEquip, UseItem, Energy, ChargeToggle, SaveSettings.
- RemoteFunction: Pull, ShopBuy, BuyGems, BagAction, GetData, QuestAction, BuyCell, RedeemCode.

## Дебаг (только в Studio)

`ServerStorage.ZSS_Debug` — BindableFunction. Пример из командной строки сервера:

```lua
game.ServerStorage.ZSS_Debug:Invoke("pity", "Secret", 1999)
```

Команды: night, gems, batteries, scrap, energy, give, item, allitems, pity, bosshp.
