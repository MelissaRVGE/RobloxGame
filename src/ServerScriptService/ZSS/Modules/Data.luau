-- Профили игроков: загрузка/сохранение (DataStore), валюты, синхронизация с клиентом.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local Shop = require(RS.ZSS.ShopConfig)
local Donate = require(RS.ZSS.DonateConfig)
local Remotes = RS.ZSS.Remotes

local Data = {}
Data.Profiles = {}

local store = nil
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore("ZSS_Profiles_v1")
	end)
	if ok then
		store = res
	end
end

local canSave = {}
local dirty = {}

local function defaultProfile()
	return {
		batteries = Config.StartBatteries,
		gems = Config.StartGems,
		bag = {}, -- найденные предметы: id -> количество
		scrap = 0, -- всего ресурсов в рюкзаке
		res = {}, -- по видам: rust / chips / bio / uranium / brass
		bagLevel = 1,
		drones = {}, -- uid -> droneId
		nextUid = 1,
		equipped = {}, -- список uid
		pity = { Legendary = 0, Mythic = 0, Secret = 0 },
		totalPulls = 0,
		seen = {},
		kills = 0,
		dockSlots = Config.Hive.startCells, -- соты зарядки в улье
		quests = {}, -- npcId -> { stage, active, prog = {} }
		perks = {}, -- постоянные бонусы за финалы квестов
		bossKills = 0,
		totalBatteries = 0, -- сколько батарей заработано за всё время (для лидерборда)
		settings = {}, -- настройки игрока из меню
		playAcc = 0, -- секунды онлайн до следующей награды за время в игре
		hotbar = { "", "", "", "" }, -- свободные ячейки хотбара 3–6 (ZSS/Hotbar)
		passes = {}, -- купленные пропуска доната: key -> true
		donateOnce = {}, -- купленные разовые наборы доната
		receipts = {}, -- PurchaseId последних покупок за Robux (чтобы не выдать дважды)
		-- Хэллоуин: тыквы, гарант и крутки «Тыквенного котла», трофеи Тыквенного Колосса, косметика
		pumpkins = 0,
		totalPumpkins = 0,
		hpity = { Legendary = 0, Mythic = 0, Secret = 0 },
		hpulls = 0,
		trophies = 0,
		cosmetics = {},
	}
end

-- хватает ли находок для крафта; возвращает (ok, текст чего не хватает)
function Data.HasMats(p, mats)
	if not mats then
		return true
	end
	local Items = require(RS.ZSS.ItemsConfig)
	local missing = {}
	for id, n in pairs(mats) do
		local have = p.bag and p.bag[id] or 0
		if have < n then
			table.insert(missing, ("%s %d/%d"):format(Items.ById[id] and Items.ById[id].name or id, have, n))
		end
	end
	return #missing == 0, table.concat(missing, ", ")
end

function Data.TakeMats(p, mats)
	for id, n in pairs(mats or {}) do
		p.bag[id] = (p.bag[id] or 0) - n
		if p.bag[id] <= 0 then
			p.bag[id] = nil
		end
	end
end

-- сколько дронов можно поставить в рой: по числу купленных гнёзд станции (старт — 3)
function Data.MaxEquip(p)
	return math.min(Config.MaxSlots, p.dockSlots or Config.Hive.startCells)
end

local function reconcile(p)
	-- старые профили: в ячейках 3–6 лежало то же, что раньше было к ним привязано (если есть в запасе)
	if p.hotbar == nil then
		local Hotbar = require(RS.ZSS.Hotbar)
		p.hotbar = {}
		for i, id in ipairs(Hotbar.Legacy) do
			p.hotbar[i] = (p.consum and (p.consum[id] or 0) > 0) and id or ""
		end
	end
	local d = defaultProfile()
	for k, v in pairs(d) do
		if p[k] == nil then
			p[k] = v
		end
	end
	for k, v in pairs(d.pity) do
		if p.pity[k] == nil then
			p.pity[k] = v
		end
	end
	for uid, id in pairs(p.drones) do
		if not Config.DroneById[id] then
			p.drones[uid] = nil
		end
	end
	-- старые профили: весь накопленный «лом» становится металлоломом
	p.res = p.res or {}
	local sum = 0
	for id, n in pairs(p.res) do
		if Config.ResourceById[id] and typeof(n) == "number" and n > 0 then
			sum += n
		else
			p.res[id] = nil
		end
	end
	if (p.scrap or 0) > sum then
		p.res.rust = (p.res.rust or 0) + (p.scrap - sum)
		sum = p.scrap
	end
	p.scrap = sum
	local eq, used = {}, {}
	for _, uid in ipairs(p.equipped) do
		if p.drones[uid] and not used[uid] and #eq < Data.MaxEquip(p) then
			table.insert(eq, uid)
			used[uid] = true
		end
	end
	p.equipped = eq
	return p
end

function Data.Get(player)
	return Data.Profiles[player]
end

-- вместимость = уровень рюкзака × бонус надетой модели рюкзака
function Data.Capacity(p)
	local bp = p.gear and Shop.ById[p.gear.backpack or ""]
	local cap = (bp and bp.stats.cap or 0) + Donate.Perk(p.passes, "cap")
	return math.floor(Config.BagCapacity(p.bagLevel) * (1 + cap))
end

function Data.MarkDirty(player)
	dirty[player] = true
end

function Data.AddDrone(p, id)
	local uid = "d" .. p.nextUid
	p.nextUid += 1
	p.drones[uid] = id
	p.seen[id] = true
	if #p.equipped < Data.MaxEquip(p) then
		table.insert(p.equipped, uid)
	end
	return uid
end

-- возвращает (добавлено, рюкзак_полон); resId — вид ресурса (по локации)
function Data.AddScrap(player, amount, resId)
	local p = Data.Profiles[player]
	if not p then
		return 0, false
	end
	local cap = Data.Capacity(p)
	local add = math.max(0, math.min(math.floor(amount), cap - p.scrap))
	p.scrap += add
	if add > 0 then
		resId = Config.ResourceById[resId or ""] and resId or "rust"
		p.res = p.res or {}
		p.res[resId] = (p.res[resId] or 0) + add
	end
	if add > 0 then
		dirty[player] = true
	end
	return add, p.scrap >= cap
end

-- найденный предмет в рюкзак (места не ограничены); false только для неизвестного предмета
function Data.AddItem(player, id, n)
	local p = Data.Profiles[player]
	local Items = require(RS.ZSS.ItemsConfig)
	if not p or not Items.ById[id] then
		return false
	end
	p.bag = p.bag or {}
	p.bag[id] = (p.bag[id] or 0) + (n or 1)
	dirty[player] = true
	return true
end

-- списать n ресурсов из рюкзака — со всех видов одновременно, пропорционально их доле.
-- Возвращает, сколько списано всего, и таблицу {resId = сколько}.
function Data.TakeScrap(p, n)
	n = math.min(math.floor(n), p.scrap)
	p.res = p.res or {}
	local taken = {}
	if n <= 0 then
		return 0, taken
	end
	local total = 0
	for _, r in ipairs(Config.Resources) do
		total += p.res[r.id] or 0
	end
	local left = n
	if total > 0 then
		-- целая часть доли каждому виду, остаток — по самым большим дробным частям
		local fr = {}
		for _, r in ipairs(Config.Resources) do
			local have = p.res[r.id] or 0
			if have > 0 then
				local exact = n * have / total
				local whole = math.min(have, math.floor(exact))
				taken[r.id] = whole
				left -= whole
				table.insert(fr, { id = r.id, f = exact - whole, have = have })
			end
		end
		table.sort(fr, function(a, b)
			return a.f > b.f
		end)
		while left > 0 do
			local moved = false
			for _, e in ipairs(fr) do
				if left > 0 and taken[e.id] < e.have then
					taken[e.id] += 1
					left -= 1
					moved = true
				end
			end
			if not moved then
				break
			end
		end
		for id, k in pairs(taken) do
			local rest = (p.res[id] or 0) - k
			p.res[id] = rest > 0 and rest or nil
			if k <= 0 then
				taken[id] = nil
			end
		end
	end
	p.scrap -= n
	return n, taken
end

function Data.AddGems(player, amount)
	local p = Data.Profiles[player]
	if not p then
		return
	end
	p.gems = (p.gems or 0) + math.floor(amount)
	dirty[player] = true
end

function Data.AddBatteries(player, amount)
	local p = Data.Profiles[player]
	if not p then
		return
	end
	amount = math.floor(amount)
	p.batteries += amount
	if amount > 0 then
		p.totalBatteries = (p.totalBatteries or 0) + amount
	end
	dirty[player] = true
end

function Data.Snapshot(p)
	local owned, eqc, eqList = {}, {}, {}
	for _, id in pairs(p.drones) do
		owned[id] = (owned[id] or 0) + 1
	end
	for _, uid in ipairs(p.equipped) do
		local id = p.drones[uid]
		if id then
			eqc[id] = (eqc[id] or 0) + 1
			table.insert(eqList, { uid = uid, id = id })
		end
	end
	return {
		batteries = p.batteries,
		gems = p.gems or 0,
		bag = p.bag or {},
		scrap = p.scrap,
		res = p.res or {},
		capacity = Data.Capacity(p),
		bagLevel = p.bagLevel,
		bagCost = Config.BagCost(p.bagLevel),
		owned = owned,
		equippedCount = eqc,
		equippedTotal = #p.equipped,
		equippedList = eqList,
		items = p.items or {},
		consum = p.consum or {},
		hotbar = require(RS.ZSS.Hotbar).Normalize(p.hotbar),
		passes = p.passes or {},
		donateOnce = p.donateOnce or {},
		gear = p.gear or {},
		maxSlots = Data.MaxEquip(p),
		pity = p.pity,
		totalPulls = p.totalPulls,
		kills = p.kills,
		dockSlots = p.dockSlots or Config.Hive.startCells,
		nextCellCost = (p.dockSlots or 3) < Config.Hive.maxCells and Config.CellCost((p.dockSlots or 3) + 1) or nil,
		perks = p.perks or {},
		settings = p.settings or {},
		totalBatteries = p.totalBatteries or 0,
		quests = Data.QuestView and Data.QuestView(p) or {},
		pumpkins = p.pumpkins or 0,
		hpity = p.hpity or { Legendary = 0, Mythic = 0, Secret = 0 },
		hpulls = p.hpulls or 0,
		trophies = p.trophies or 0,
		cosmetics = p.cosmetics or {},
	}
end

local function updateLeaderstats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	ls["Batteries"].Value = p.batteries
	local count = 0
	for _ in pairs(p.drones) do
		count += 1
	end
	ls["Drones"].Value = count
end

function Data.Sync(player)
	local p = Data.Profiles[player]
	if not p then
		return
	end
	dirty[player] = nil
	updateLeaderstats(player, p)
	Remotes.DataSync:FireClient(player, Data.Snapshot(p))
end

-- копия профиля только из того, что умеет хранить DataStore (строки, числа, bool, таблицы)
local function sanitize(v, depth, path, bad)
	local t = typeof(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			table.insert(bad, path)
			return 0
		end
		return v
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "table" then
		if depth > 12 then
			table.insert(bad, path)
			return nil
		end
		local out = {}
		local n = #v
		local isArray = n > 0
		if isArray then
			for k in pairs(v) do
				if typeof(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
					isArray = false
					break
				end
			end
		end
		for k, x in pairs(v) do
			local key = k
			if not isArray then
				key = tostring(k) -- смешанные/числовые ключи → строки
			end
			local c = sanitize(x, depth + 1, path .. "." .. tostring(k), bad)
			if c ~= nil then
				out[key] = c
			end
		end
		return out
	end
	table.insert(bad, path .. "(" .. t .. ")")
	return nil
end
Data.Sanitize = sanitize

local function withRetry(what, fn)
	local last
	for attempt = 1, 4 do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		last = res
		if tostring(res):find("StudioAccessToApisNotAllowed") or tostring(res):find("Studio access to APIs") then
			break -- в Studio без доступа к API повторять бессмысленно
		end
		task.wait(attempt * 1.5)
	end
	warn(("[ZSS] %s: failed after retries: %s"):format(what, tostring(last)))
	return false, last
end

function Data.Load(player)
	local p, ok = nil, true
	if store then
		local success, res = withRetry("loading profile " .. player.UserId, function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if success then
			p = res
		else
			-- если профиль не загрузился, НЕ сохраняем поверх (иначе сотрём старый прогресс)
			ok = false
			if player.Parent then
				Remotes.Notify:FireClient(player, "⚠ Couldn't load your progress. Rejoin, or this session won't be saved.", "bad")
			end
		end
	else
		ok = false
	end
	local isNew = type(p) ~= "table"
	p = reconcile(isNew and defaultProfile() or p)
	if isNew then
		for _, id in ipairs(Config.StartDrones) do
			Data.AddDrone(p, id)
		end
	end
	if RunService:IsStudio() and Config.StudioBonusBatteries > 0 then
		p.batteries = math.max(p.batteries, Config.StudioBonusBatteries)
		p.gems = math.max(p.gems or 0, Config.StudioBonusGems or 0)
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local b = Instance.new("IntValue")
	b.Name = "Batteries"
	b.Parent = ls
	local d = Instance.new("IntValue")
	d.Name = "Drones"
	d.Parent = ls
	ls.Parent = player

	Data.Profiles[player] = p
	canSave[player] = ok
	dirty[player] = true
	return p
end

local saving = {}
function Data.Save(player)
	if Data.BeforeSave then
		pcall(Data.BeforeSave, player)
	end
	local p = Data.Profiles[player]
	if not p or not store or not canSave[player] then
		return false
	end
	if saving[player] then
		return false
	end
	saving[player] = true
	local bad = {}
	local clean = sanitize(p, 0, "p", bad)
	if #bad > 0 then
		warn("[ZSS] Profile had unsavable data (skipped):", table.concat(bad, ", "))
	end
	clean.savedAt = os.time()
	clean.version = 2
	local ok = withRetry("saving profile " .. player.UserId, function()
		store:UpdateAsync("u" .. player.UserId, function()
			return clean
		end)
	end)
	saving[player] = nil
	return ok
end

-- можно ли сохранять профиль (false, если он не загрузился)
function Data.CanSave(player)
	return store ~= nil and canSave[player] == true
end

-- сохранить прямо сейчас: дождаться идущего автосохранения и записать свежее состояние
function Data.SaveNow(player)
	local t0 = os.clock()
	while saving[player] and os.clock() - t0 < 15 do
		task.wait(0.2)
	end
	return Data.Save(player)
end

function Data.Release(player)
	-- дождаться идущего автосохранения и сохранить финальное состояние
	local t0 = os.clock()
	while saving[player] and os.clock() - t0 < 15 do
		task.wait(0.2)
	end
	Data.Save(player)
	Data.Profiles[player] = nil
	canSave[player] = nil
	dirty[player] = nil
end

function Data.Init()
	-- рассылка изменений не чаще 5 раз в секунду
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in pairs(dirty) do
				if player.Parent then
					Data.Sync(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)
	-- автосохранение раз в минуту
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(Data.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		-- сохраняем всех параллельно и ждём (до ~25 сек)
		local left = 0
		for _, player in ipairs(Players:GetPlayers()) do
			left += 1
			task.spawn(function()
				saving[player] = nil
				Data.Save(player)
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return Data
