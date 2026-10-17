-- Назначение горячих клавиш: список действий, клавиши по умолчанию и переназначения игрока.
-- Переназначения хранятся в настройках профиля (settings.keys = { [действие] = "ИмяKeyCode" }),
-- в профиль попадают только клавиши, отличные от стандартных.
local K = {}

-- scope: клавиши проверяются на конфликт только внутри своей группы
-- (пропуск гачи работает лишь во время анимации, поэтому может совпадать с клавишами мира)
K.Actions = {
	{ id = "drones", label = "Инвентарь дронов", default = "Y", scope = "world" },
	{ id = "gacha", label = "Гача (Лаборатория дронов)", default = "G", scope = "world" },
	{ id = "shop", label = "Магазин", default = "N", scope = "world" },
	{ id = "bag", label = "Инвентарь (снаряжение и предметы)", default = "B", scope = "world" },
	{ id = "map", label = "Карта и телепорт", default = "M", scope = "world" },
	{ id = "convert", label = "Телепорт к Переработчику", default = "R", scope = "world" },
	{ id = "quests", label = "Книга заданий", default = "Q", scope = "world" },
	{ id = "donate", label = "Донат-магазин", default = "H", scope = "world" },
	{ id = "settings", label = "Настройки", default = "P", scope = "world" },
	{ id = "slot1", label = "Ячейка 1: оружие", default = "One", scope = "world", slot = 1 },
	{ id = "slot2", label = "Ячейка 2: инструмент добычи", default = "Two", scope = "world", slot = 2 },
	{ id = "slot3", label = "Ячейка 3: предмет", default = "Three", scope = "world", slot = 3 },
	{ id = "slot4", label = "Ячейка 4: предмет", default = "Four", scope = "world", slot = 4 },
	{ id = "slot5", label = "Ячейка 5: предмет", default = "Five", scope = "world", slot = 5 },
	{ id = "slot6", label = "Ячейка 6: предмет", default = "Six", scope = "world", slot = 6 },
	{ id = "gachaSkip", label = "Гача: пропустить / забрать (и Enter)", default = "Space", scope = "gacha" },
}
K.ById = {}
for _, a in ipairs(K.Actions) do
	K.ById[a.id] = a
end

-- клавиши, которые заняты управлением Roblox или самой игры
local RESERVED = {
	world = {
		W = "движение", A = "движение", S = "движение", D = "движение",
		Up = "движение", Down = "движение", Left = "камера", Right = "камера",
		Space = "прыжок", E = "взаимодействие", Escape = "меню Roblox", Tab = "список игроков",
		Slash = "чат", LeftShift = "Shift Lock", RightShift = "Shift Lock", I = "приближение камеры", O = "отдаление камеры",
		F9 = "консоль Roblox", F11 = "полный экран", LeftSuper = "система", RightSuper = "система",
	},
	gacha = { Escape = "меню Roblox", Return = "уже пропускает гачу", KeypadEnter = "уже пропускает гачу" },
}

local PRETTY = {
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	KeypadOne = "Num1", KeypadTwo = "Num2", KeypadThree = "Num3", KeypadFour = "Num4", KeypadFive = "Num5",
	KeypadSix = "Num6", KeypadSeven = "Num7", KeypadEight = "Num8", KeypadNine = "Num9", KeypadZero = "Num0",
	Space = "Пробел", Return = "Enter", Backspace = "⌫", LeftControl = "Ctrl", RightControl = "RCtrl",
	LeftAlt = "Alt", RightAlt = "RAlt", CapsLock = "Caps", Minus = "-", Equals = "=", LeftBracket = "[",
	RightBracket = "]", BackSlash = "\\", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Backquote = "`",
	Delete = "Del", Insert = "Ins", PageUp = "PgUp", PageDown = "PgDn",
}
local SHORT = { Space = "␣", Backspace = "⌫", LeftControl = "Ctrl", CapsLock = "Caps" }

K.Overrides = {}
K.Capturing = false -- пока в настройках ждём новую клавишу, игровые клавиши молчат
local changed = Instance.new("BindableEvent")
K.Changed = changed.Event

local keyOf = {} -- id -> Enum.KeyCode
local actionOf = { world = {}, gacha = {} } -- scope -> KeyCode -> id

local function toKey(name)
	if typeof(name) ~= "string" then
		return nil
	end
	local ok, kc = pcall(function()
		return Enum.KeyCode[name]
	end)
	return ok and kc or nil
end

local function rebuild()
	table.clear(keyOf)
	actionOf.world, actionOf.gacha = {}, {}
	for _, a in ipairs(K.Actions) do
		local kc = toKey(K.Overrides[a.id]) or toKey(a.default)
		keyOf[a.id] = kc
		actionOf[a.scope][kc] = a.id
	end
	changed:Fire()
end

-- стоят ли две клавиши на одном действии / одна клавиша на двух действиях
local function consistent(over)
	local used = { world = {}, gacha = {} }
	for _, a in ipairs(K.Actions) do
		local name = over[a.id] or a.default
		if used[a.scope][name] or RESERVED[a.scope][name] then
			return false
		end
		used[a.scope][name] = true
	end
	return true
end

-- загрузка из профиля; кривые или конфликтующие назначения — возврат к стандартным
function K.Load(t)
	local over = {}
	if typeof(t) == "table" then
		for id, name in pairs(t) do
			local a = K.ById[id]
			if a and toKey(name) and name ~= a.default then
				over[id] = name
			end
		end
	end
	K.Overrides = consistent(over) and over or {}
	rebuild()
end

function K.Export()
	return table.clone(K.Overrides)
end

function K.Get(id)
	return keyOf[id]
end

function K.Action(kc, scope)
	return actionOf[scope or "world"][kc]
end

function K.IsReserved(scope, kc)
	return RESERVED[scope][kc.Name]
end

-- назначить клавишу; если она уже у другого действия той же группы — меняем их местами
-- возвращает ok, ошибка или id действия, с которым поменялись
function K.Assign(id, kc)
	local a = K.ById[id]
	if not a then
		return false, "?"
	end
	local why = RESERVED[a.scope][kc.Name]
	if why then
		return false, why
	end
	local old = keyOf[id]
	if old == kc then
		return true
	end
	local other = actionOf[a.scope][kc]
	local function put(aid, key)
		local def = K.ById[aid].default
		K.Overrides[aid] = key.Name ~= def and key.Name or nil
	end
	put(id, kc)
	if other then
		put(other, old)
	end
	rebuild()
	return true, other
end

function K.Reset()
	K.Overrides = {}
	rebuild()
end

function K.IsDefault()
	return next(K.Overrides) == nil
end

-- подпись для настроек
function K.Name(kc)
	if not kc then
		return "—"
	end
	return PRETTY[kc.Name] or kc.Name
end

-- короткая подпись для значков на кнопках (2–4 символа)
function K.Short(kc)
	if not kc then
		return ""
	end
	local s = SHORT[kc.Name] or PRETTY[kc.Name] or kc.Name
	return utf8.len(s) and utf8.len(s) > 4 and s:sub(1, 3) or s
end

rebuild()
return K
