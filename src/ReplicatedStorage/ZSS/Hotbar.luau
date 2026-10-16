-- Свободные ячейки хотбара (3–6): игрок сам кладёт в них любой используемый предмет.
-- Ключ ячейки: id расходника из Магазина ("medkit") или "f:<id>" для находки из рюкзака
-- с действием use ("f:cans"). Пустая ячейка — "". Общая логика для сервера и клиента.
local Shop = require(script.Parent.ShopConfig)
local Items = require(script.Parent.ItemsConfig)

local H = {}
H.Free = 4 -- сколько свободных ячеек
H.First = Shop.HotbarWeapons + 1 -- номер первой свободной ячейки на экране
-- что лежало в ячейках раньше, когда они были привязаны к предметам (для старых профилей)
H.Legacy = { "medkit", "energycell", "grenade", "adrenaline" }

-- разбирает ключ: kind ("shop" | "find"), id, описание предмета
function H.Parse(key)
	if typeof(key) ~= "string" or key == "" then
		return nil
	end
	if key:sub(1, 2) == "f:" then
		local it = Items.ById[key:sub(3)]
		if it and it.use then
			return "find", it.id, it
		end
		return nil
	end
	local it = Shop.ById[key]
	if it and it.stack then
		return "shop", it.id, it
	end
	return nil
end

function H.Valid(key)
	return H.Parse(key) ~= nil
end

-- сколько штук у игрока (по снимку профиля или самому профилю)
function H.Count(key, d)
	local kind, id = H.Parse(key)
	if not kind or not d then
		return 0
	end
	if kind == "shop" then
		return d.consum and d.consum[id] or 0
	end
	return d.bag and d.bag[id] or 0
end

-- ровно H.Free строк, неизвестные предметы и повторы убираются
function H.Normalize(list)
	local out, seen = {}, {}
	for i = 1, H.Free do
		local k = typeof(list) == "table" and list[i] or ""
		if not H.Valid(k) or seen[k] then
			k = ""
		end
		seen[k] = k ~= "" or nil
		out[i] = k
	end
	return out
end

-- кладёт key в ячейку slot (1..Free). Если предмет уже лежит в другой ячейке,
-- ячейки меняются местами; пустой key очищает ячейку. Возвращает новую таблицу.
function H.Place(list, slot, key)
	local out = H.Normalize(list)
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > H.Free then
		return out
	end
	key = H.Valid(key) and key or ""
	if key ~= "" then
		for j = 1, H.Free do
			if j ~= slot and out[j] == key then
				out[j] = out[slot]
				break
			end
		end
	end
	out[slot] = key
	return out
end

-- первая пустая ячейка или nil
function H.FirstEmpty(list)
	for i = 1, H.Free do
		if (list[i] or "") == "" then
			return i
		end
	end
	return nil
end

function H.IndexOf(list, key)
	for i = 1, H.Free do
		if list[i] == key then
			return i
		end
	end
	return nil
end

return H
