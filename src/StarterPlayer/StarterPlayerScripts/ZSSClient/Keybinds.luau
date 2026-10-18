-- Назначение горячих клавиш: список действий, клавиши по умолчанию и переназначения игрока.
-- Переназначения хранятся в настройках профиля (settings.keys = { [действие] = "ИмяKeyCode" }),
-- в профиль попадают только клавиши, отличные от стандартных.
local K = {}

-- scope: клавиши проверяются на конфликт только внутри своей группы
-- (пропуск гачи работает лишь во время анимации, поэтому может совпадать с клавишами мира)
K.Actions = {
	{ id = "drones", label = "Drone inventory", default = "Y", scope = "world" },
	{ id = "gacha", label = "Gacha (Drone Lab)", default = "G", scope = "world" },
	{ id = "shop", label = "Shop", default = "N", scope = "world" },
	{ id = "bag", label = "Inventory (gear and items)", default = "B", scope = "world" },
	{ id = "map", label = "Map and teleport", default = "M", scope = "world" },
	{ id = "convert", label = "Teleport to the Recycler", default = "R", scope = "world" },
	{ id = "quests", label = "Quest book", default = "Q", scope = "world" },
	{ id = "donate", label = "Donation shop", default = "H", scope = "world" },
	{ id = "settings", label = "Settings", default = "P", scope = "world" },
	{ id = "halloween", label = "Teleport to the Pumpkin Cauldron", default = "J", scope = "world", event = "halloween" },
	{ id = "slot1", label = "Slot 1: weapon", default = "One", scope = "world", slot = 1 },
	{ id = "slot2", label = "Slot 2: gathering tool", default = "Two", scope = "world", slot = 2 },
	{ id = "slot3", label = "Slot 3: item", default = "Three", scope = "world", slot = 3 },
	{ id = "slot4", label = "Slot 4: item", default = "Four", scope = "world", slot = 4 },
	{ id = "slot5", label = "Slot 5: item", default = "Five", scope = "world", slot = 5 },
	{ id = "slot6", label = "Slot 6: item", default = "Six", scope = "world", slot = 6 },
	{ id = "gachaSkip", label = "Gacha: skip / claim (and Enter)", default = "Space", scope = "gacha" },
}
-- действия события есть только пока оно идёт (выключили Хэллоуин — пропадают и из настроек)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("ZSS"):WaitForChild("Config"))
for i = #K.Actions, 1, -1 do
	local ev = K.Actions[i].event
	if ev == "halloween" and not Config.HalloweenOn() then
		table.remove(K.Actions, i)
	end
end
K.ById = {}
for _, a in ipairs(K.Actions) do
	K.ById[a.id] = a
end

-- клавиши, которые заняты управлением Roblox или самой игры
local RESERVED = {
	world = {
		W = "movement", A = "movement", S = "movement", D = "movement",
		Up = "movement", Down = "movement", Left = "camera", Right = "camera",
		Space = "jump", E = "interact", Escape = "Roblox menu", Tab = "player list",
		Slash = "chat", LeftShift = "Shift Lock", RightShift = "Shift Lock", I = "camera zoom in", O = "camera zoom out",
		F9 = "Roblox console", F11 = "fullscreen", LeftSuper = "system", RightSuper = "system",
	},
	gacha = { Escape = "Roblox menu", Return = "already skips the gacha", KeypadEnter = "already skips the gacha" },
}

local PRETTY = {
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	KeypadOne = "Num1", KeypadTwo = "Num2", KeypadThree = "Num3", KeypadFour = "Num4", KeypadFive = "Num5",
	KeypadSix = "Num6", KeypadSeven = "Num7", KeypadEight = "Num8", KeypadNine = "Num9", KeypadZero = "Num0",
	Space = "Space", Return = "Enter", Backspace = "⌫", LeftControl = "Ctrl", RightControl = "RCtrl",
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
