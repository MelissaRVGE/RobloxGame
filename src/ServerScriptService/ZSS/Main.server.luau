-- Zombie Swarm Simulator — серверная точка входа
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)

-- ===== REMOTES =====
local remotes = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = Shared
local function make(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
for _, n in ipairs({ "DataSync", "DroneState", "FX", "Notify", "Popup", "Equip", "AutoEquip", "Unequip", "UnequipAll", "Scoop", "UpgradeBag", "Teleport" }) do
	make("RemoteEvent", n)
end
make("RemoteFunction", "Pull")
make("RemoteFunction", "ShopBuy")
make("RemoteFunction", "BuyGems")
make("RemoteFunction", "BagAction")
make("RemoteEvent", "ShopEquip")
make("RemoteEvent", "UseItem")
make("RemoteEvent", "SetHotbar")
make("RemoteEvent", "Energy")
make("RemoteEvent", "ChargeToggle")
make("RemoteFunction", "GetData")
make("RemoteFunction", "QuestAction")
make("RemoteFunction", "BuyCell")
make("RemoteEvent", "SaveSettings")
make("RemoteFunction", "RedeemCode")
local Remotes = remotes

local Modules = script.Parent.Modules
local Data = require(Modules.Data)
local Fields = require(Modules.Fields)
local Zombies = require(Modules.Zombies)
local Drones = require(Modules.Drones)
local Gacha = require(Modules.Gacha)
local Equipment = require(Modules.Equipment)
local World = require(Modules.World)
local Boss = require(Modules.Boss)
local Items = require(Shared.ItemsConfig)
local Quests = require(Modules.Quests)
local Hives = require(Modules.Hives)
local Converter = require(Modules.Converter)
local Leaderboard = require(Modules.Leaderboard)
local Drops = require(Modules.Drops)

-- максимум игроков на сервере задаётся в настройках игры (Game Settings → Places → Server Size = 6)
Quests.Init()
Data.Init()
Fields.Init(Data)
Zombies.Init(Data, Fields)
Drones.Init(Data, Fields, Zombies)
Gacha.Init(Data, Drones)
Equipment.Init(Data, Drones, Fields, Zombies)
Data.BeforeSave = Drones.SaveEnergy
World.Init(Fields, Equipment)
Drops.Init(Data, Fields, Equipment, Drones)
Boss.Init(Data, Fields, Zombies)
Converter.Init(Data)
Leaderboard.Init(Data)
Drones.OnCharged = function(player)
	Quests.Event(player, "charged")
end
Quests.OnPerk = function(player)
	Equipment.Apply(player)
end

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

-- ===== ИГРОКИ =====
local function onPlayerAdded(player)
	local p = Data.Load(player)
	Equipment.Reconcile(p)
	Drones.Add(player)
	Data.Sync(player)
	-- как в BSS: дроны ждут в улье, пока игрок не займёт станцию
	task.delay(4, function()
		if player.Parent and not Hives.Index(player) then
			notify(player, "🤖 Твой рой ждёт на базе: подойди к свободной станции зарядки и нажми E", "info")
		end
	end)
	local function onChar()
		task.wait(0.3)
		Equipment.Apply(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	Drones.Remove(player)
	Data.Release(player)
end)

-- ===== НАГРАДА ЗА ВРЕМЯ В ИГРЕ =====
-- как раздатчики в BSS: каждые PlaytimeReward.interval секунд онлайн — немного гемов.
-- Накопленное время хранится в профиле, поэтому неполный интервал не сгорает при выходе.
task.spawn(function()
	local PR = Config.PlaytimeReward
	if not PR then
		return
	end
	local STEP = 10
	while true do
		task.wait(STEP)
		for _, player in ipairs(Players:GetPlayers()) do
			local p = Data.Get(player)
			if p then
				p.playAcc = (p.playAcc or 0) + STEP
				if p.playAcc >= PR.interval then
					p.playAcc -= PR.interval
					Data.AddGems(player, PR.gems)
					notify(player, ("💎 +%d за время в игре! Следующие — через %d мин"):format(PR.gems, math.floor(PR.interval / 60)), "good")
				end
			end
		end
	end
end)

-- ===== УДАЛЁННЫЕ ВЫЗОВЫ =====
Remotes.GetData.OnServerInvoke = function(player)
	local t0 = os.clock()
	while not Data.Get(player) and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	local p = Data.Get(player)
	return p and Data.Snapshot(p) or nil
end

-- обмен батарей на гемы убран: гемы дают квесты, босс и редкие находки
Remotes.BuyGems.OnServerInvoke = function()
	return { ok = false, err = "Гемы нельзя купить за батареи — выполняй квесты и побеждай босса" }
end

-- ===== КВЕСТЫ =====
Remotes.QuestAction.OnServerInvoke = function(player, npcId, action)
	if typeof(npcId) ~= "string" or typeof(action) ~= "string" then
		return { ok = false }
	end
	return Quests.Action(player, npcId, action)
end

-- ===== НАСТРОЙКИ ИГРОКА (сохраняются в профиль) =====
local SETTING_KEYS = {
	preset = "string", shadows = "boolean", effects = "boolean", particles = "boolean", fov = "number",
	sensitivity = "number", shake = "boolean", master = "number", sfx = "number", ui = "number",
	uiScale = "number", showQuests = "boolean", showDamage = "boolean", toasts = "boolean",
}
Remotes.SaveSettings.OnServerEvent:Connect(function(player, t)
	local p = Data.Get(player)
	if not p or typeof(t) ~= "table" then
		return
	end
	local clean = {}
	for k, kind in pairs(SETTING_KEYS) do
		local v = t[k]
		if typeof(v) == kind then
			if kind == "number" then
				v = math.clamp(v, 0, 200)
			elseif kind == "string" then
				v = v:sub(1, 12)
			end
			clean[k] = v
		end
	end
	p.settings = clean
end)

-- ===== ПРОМОКОДЫ (список — ServerStorage.ZSS_PromoCodes) =====
local lastRedeem = {}
Remotes.RedeemCode.OnServerInvoke = function(player, raw)
	local p = Data.Get(player)
	if not p or typeof(raw) ~= "string" then
		return { ok = false, err = "Ошибка запроса" }
	end
	local now = os.clock()
	if lastRedeem[player] and now - lastRedeem[player] < 2 then
		return { ok = false, err = "Подожди пару секунд" }
	end
	lastRedeem[player] = now
	local code = raw:upper():gsub("%s", ""):sub(1, 32)
	if code == "" then
		return { ok = false, err = "Введи промокод" }
	end
	local list = require(game:GetService("ServerStorage"):WaitForChild("ZSS_PromoCodes"))
	local reward
	for k, v in pairs(list) do
		if k:upper() == code then
			reward = v
		end
	end
	if not reward or reward.active == false or (reward.expires and os.time() > reward.expires) then
		return { ok = false, err = "❌ Такого кода нет или он истёк" }
	end
	p.codes = p.codes or {}
	if p.codes[code] then
		return { ok = false, err = "Ты уже активировал этот код" }
	end
	p.codes[code] = os.time()
	local got = {}
	if reward.gems then
		Data.AddGems(player, reward.gems)
		table.insert(got, "💎 " .. reward.gems)
	end
	if reward.batteries then
		Data.AddBatteries(player, reward.batteries)
		table.insert(got, "🔋 " .. reward.batteries)
	end
	for id, n in pairs(reward.items or {}) do
		if Items.ById[id] then
			Data.AddItem(player, id, n)
			table.insert(got, Items.ById[id].name .. " ×" .. n)
		end
	end
	local Shop = require(Shared.ShopConfig)
	for id, n in pairs(reward.consum or {}) do
		if Shop.ById[id] then
			p.consum = p.consum or {}
			p.consum[id] = (p.consum[id] or 0) + n
			table.insert(got, Shop.ById[id].name .. " ×" .. n)
		end
	end
	if reward.drone and Config.DroneById[reward.drone] then
		Data.AddDrone(p, reward.drone)
		Drones.Rebuild(player)
		table.insert(got, "дрон «" .. Config.DroneById[reward.drone].name .. "»")
	end
	Data.MarkDirty(player)
	task.spawn(Data.Save, player) -- сразу сохранить, чтобы код нельзя было активировать повторно
	Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
	return { ok = true, msg = "🎁 Код активирован: " .. table.concat(got, ", "), desc = reward.desc }
end

-- ===== УЛЬИ: покупка сот =====
Remotes.BuyCell.OnServerInvoke = function(player, qty)
	return Hives.BuyCell(player, qty)
end

-- ===== РЮКЗАК: найденные предметы =====
Remotes.BagAction.OnServerInvoke = function(player, action, id)
	local p = Data.Get(player)
	local item = typeof(id) == "string" and Items.ById[id]
	if not p or not item then
		return { ok = false, err = "Неизвестный предмет" }
	end
	p.bag = p.bag or {}
	local have = p.bag[id] or 0
	if have <= 0 then
		return { ok = false, err = "Нет такого предмета" }
	end
	local function take(n)
		p.bag[id] = have - n
		if p.bag[id] <= 0 then
			p.bag[id] = nil
		end
		Data.MarkDirty(player)
	end
	if action == "sell" or action == "sellall" then
		local n = action == "sellall" and have or 1
		local gain = item.value * n
		take(n)
		Data.AddBatteries(player, gain)
		return { ok = true, msg = ("🔋 +%d за «%s» x%d"):format(gain, item.name, n) }
	elseif action == "use" then
		local u = item.use
		if not u then
			return { ok = false, err = "Этот предмет можно только продать" }
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if u.heal then
			if not hum or hum.Health <= 0 then
				return { ok = false, err = "Нельзя сейчас" }
			end
			if hum.Health >= hum.MaxHealth - 0.5 then
				return { ok = false, err = "❤ Здоровье уже полное" }
			end
			hum.Health = math.min(hum.MaxHealth, hum.Health + u.heal)
			Remotes.FX:FireAllClients("heal", { owner = player.UserId })
		end
		if u.speed then
			Equipment.AddSpeedBuff(player, u.speed, u.time or 20)
			Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = Color3.fromRGB(80, 255, 120), duration = 2 })
		end
		if u.energy then
			Drones.AddEnergy(player, u.energy)
			Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = Color3.fromRGB(80, 220, 255), duration = 2 })
		end
		if u.gems then
			Data.AddGems(player, u.gems)
		end
		if u.pull then
			local def, rarity, isNew = Gacha.Capsule(player, u.pull ~= true and u.pull or nil)
			if not def then
				return { ok = false, err = "Нельзя сейчас" }
			end
			take(1)
			Quests.Event(player, "use", { id = id })
			local rar = Config.Rarities[rarity]
			return { ok = true, msg = ("🧬 %s: %s дрон «%s»%s"):format(item.name, rar.label, def.name, isNew and " (НОВЫЙ!)" or "") }
		end
		take(1)
		Quests.Event(player, "use", { id = id })
		return { ok = true, msg = "✔ Использовано: " .. item.name .. (u.gems and (" (+" .. u.gems .. " 💎)") or "") }
	end
	return { ok = false, err = "bad action" }
end

Remotes.Pull.OnServerInvoke = function(player, count)
	if typeof(count) ~= "number" then
		return { ok = false, err = "bad request" }
	end
	local res = Gacha.Pull(player, count)
	if res and res.ok and res.results then
		Quests.Event(player, "pull", nil, #res.results)
	end
	return res
end

local RARITY_RANK = {}
for _, key in ipairs(Config.RarityOrder) do
	RARITY_RANK[key] = Config.Rarities[key].order
end

Remotes.Equip.OnServerEvent:Connect(function(player, id, delta)
	local p = Data.Get(player)
	if not p or typeof(id) ~= "string" or not Config.DroneById[id] then
		return
	end
	local equippedSet = {}
	for _, uid in ipairs(p.equipped) do
		equippedSet[uid] = true
	end
	if delta == 1 then
		local max = Data.MaxEquip(p)
		if #p.equipped >= max then
			notify(player, ("В рое уже %d/%d дронов. Больше мест — покупай гнёзда в Мастерской у станций зарядки"):format(#p.equipped, max), "bad")
			return
		end
		for uid, did in pairs(p.drones) do
			if did == id and not equippedSet[uid] then
				table.insert(p.equipped, uid)
				break
			end
		end
	elseif delta == -1 then
		for i = #p.equipped, 1, -1 do
			if p.drones[p.equipped[i]] == id then
				table.remove(p.equipped, i)
				break
			end
		end
	end
	Drones.Rebuild(player)
	Data.MarkDirty(player)
end)

-- снять конкретного дрона из слота роя
Remotes.Unequip.OnServerEvent:Connect(function(player, uid)
	local p = Data.Get(player)
	if not p or typeof(uid) ~= "string" then
		return
	end
	local i = table.find(p.equipped, uid)
	if i then
		table.remove(p.equipped, i)
		Drones.Rebuild(player)
		Data.MarkDirty(player)
	end
end)

Remotes.UnequipAll.OnServerEvent:Connect(function(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	p.equipped = {}
	Drones.Rebuild(player)
	Data.MarkDirty(player)
	notify(player, "Все дроны сняты с роя", "info")
end)

Remotes.AutoEquip.OnServerEvent:Connect(function(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	local all = {}
	for uid, id in pairs(p.drones) do
		local def = Config.DroneById[id]
		table.insert(all, { uid = uid, rank = RARITY_RANK[def.rarity], index = def.index })
	end
	table.sort(all, function(a, b)
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.index < b.index
	end)
	local eq = {}
	for i = 1, math.min(Data.MaxEquip(p), #all) do
		table.insert(eq, all[i].uid)
	end
	p.equipped = eq
	Drones.Rebuild(player)
	Data.MarkDirty(player)
	notify(player, "⚡ В рой поставлены лучшие дроны!", "good")
end)

Remotes.UpgradeBag.OnServerEvent:Connect(function(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	local cost = Config.BagCost(p.bagLevel)
	if not cost then
		notify(player, "🎒 Рюкзак уже максимального уровня!", "info")
		return
	end
	if p.batteries < cost then
		notify(player, ("🔋 Нужно %d батарей для улучшения рюкзака"):format(cost), "bad")
		return
	end
	-- рюкзак крафтится из находок
	local mats = Config.BagMats[p.bagLevel]
	local ok, missing = Data.HasMats(p, mats)
	if not ok then
		notify(player, "🎒 Не хватает материалов: " .. missing, "bad")
		return
	end
	Data.TakeMats(p, mats)
	p.batteries -= cost
	p.bagLevel += 1
	Data.MarkDirty(player)
	Quests.Event(player, "bagUp")
	Quests.Event(player, "craft", { slot = "bag" })
	notify(player, ("🎒 Рюкзак улучшен! Вместимость: %d"):format(Data.Capacity(p)), "good")
end)

-- удар: оружие бьёт зомби, инструмент добывает ресурсы с поля
local lastScoop = {}
Remotes.Scoop.OnServerEvent:Connect(function(player)
	local st, item = Equipment.WeaponStats(player)
	local now = os.clock()
	if lastScoop[player] and now - lastScoop[player] < st.cd * 0.85 then
		return
	end
	lastScoop[player] = now
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("ZSSWeapon") ~= item.id then
		return
	end
	local field = Fields.At(hrp.Position)
	-- анимация удара (своя для каждого оружия) — для всех клиентов, кроме самого игрока (он играет её сразу)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Remotes.FX:FireClient(other, "swing", { owner = player.UserId, w = item.id })
		end
	end
	if st.fx ~= "none" then
		Remotes.FX:FireAllClients("weapon", { owner = player.UserId, fx = st.fx, pos = hrp.Position + hrp.CFrame.LookVector * 2, radius = st.radius })
	end
	if not field then
		return
	end
	if item.slot == "tool" then
		for _, t in ipairs(Fields.TilesNear(field, hrp.Position + hrp.CFrame.LookVector * 2, st.radius * 0.8)) do
			Fields.Collect(player, t, st.gather or 1, player:GetAttribute("ZSS_ToolGather") or 1)
		end
	else
		for _, z in ipairs(Zombies.InRadius(field, hrp.Position, st.radius + 2)) do
			Zombies.Damage(z, st.dmg or 1, player)
		end
	end
end)

-- ===== МАГАЗИН =====
Remotes.ShopBuy.OnServerInvoke = function(player, id, qty)
	if typeof(id) ~= "string" then
		return { ok = false, err = "bad request" }
	end
	return Equipment.Buy(player, id, typeof(qty) == "number" and qty or 1)
end

Remotes.UseItem.OnServerEvent:Connect(function(player, id)
	if typeof(id) == "string" then
		Equipment.Use(player, id)
	end
end)

-- свободные ячейки хотбара: положить предмет / поменять местами / очистить
local Hotbar = require(Shared.Hotbar)
Remotes.SetHotbar.OnServerEvent:Connect(function(player, slot, key)
	local p = Data.Get(player)
	if not p or typeof(slot) ~= "number" or (key ~= "" and not Hotbar.Valid(key)) then
		return
	end
	p.hotbar = Hotbar.Place(p.hotbar, slot, key)
	Data.MarkDirty(player)
end)

-- ===== УЛЕЙ-ЗАРЯДКА (свой у каждого игрока) =====
local function chargeToggle(player)
	local hive = Hives.Index(player)
	if not hive then
		notify(player, "⚡ Сначала займи свободную станцию зарядки у южной стены базы", "bad")
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Hives.FrontPos(hive)).Magnitude > 22 then
		notify(player, "⚡ Подойди к своей станции №" .. hive .. " на базе", "bad")
		return
	end
	if Drones.DockedCount(player) > 0 then
		local n = Drones.Recall(player)
		notify(player, ("🤖 Забрано со станции: %d дронов"):format(n), "info")
	else
		local n, waiting = Drones.Dock(player)
		if n == 0 then
			notify(player, "⚡ Все дроны уже заряжены", "good")
		elseif waiting > 0 then
			notify(player, ("⚡ В сотах: %d, в очереди: %d. Купи больше гнёзд в Мастерской!"):format(n, waiting), "good")
		else
			notify(player, ("⚡ На зарядке: %d дронов. Вернутся сами, когда зарядятся"):format(n), "good")
		end
	end
end
Remotes.ChargeToggle.OnServerEvent:Connect(chargeToggle)
Hives.Init(Data, Drones, chargeToggle)

Remotes.ShopEquip.OnServerEvent:Connect(function(player, id)
	if typeof(id) == "string" then
		Equipment.Equip(player, id)
	end
end)

local lastTp = {}
Remotes.Teleport.OnServerEvent:Connect(function(player, dest)
	local now = os.clock()
	if lastTp[player] and now - lastTp[player] < 2 then
		return
	end
	lastTp[player] = now
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local pos, fieldCenter
	if dest == "base" then
		pos = Config.BasePos
	elseif dest == "gacha" then
		pos = Config.GachaZone.center + Vector3.new(22, 4, 0)
	elseif dest == "shop" then
		pos = Config.ShopZone.center + Vector3.new(-30, 4, 0)
	elseif dest == "converter" then
		-- прямо на площадку Переработчика, лицом к машине
		pos = Config.Converter.pad + Vector3.new(0, 3.5, 0)
		fieldCenter = Config.Converter.pad + Vector3.new(10, 0, 0)
	elseif dest == "station" then
		local hive = Hives.Index(player)
		pos = hive and Hives.FrontPos(hive) or Vector3.new(0, 4, -20)
		fieldCenter = hive and Config.HiveFrames[hive].Position or Vector3.new(0, 4, -40)
	else
		for _, f in ipairs(Fields.List) do
			if f.cfg.id == dest then
				pos = Fields.Entrance(f)
				fieldCenter = f.cfg.center
			end
		end
	end
	if pos then
		local look = fieldCenter or (dest == "gacha" and Config.GachaZone.center) or (dest == "shop" and Config.ShopZone.center) or (pos + Vector3.new(0, 0, 10))
		char:PivotTo(CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)))
	end
end)

-- ===== ПЕРЕРАБОТЧИК (постепенно, как мёд в BSS) =====
task.spawn(function()
	local map = workspace:WaitForChild("Map")
	local conv = map:WaitForChild("Base"):WaitForChild("Converter", 30)
	local prompt = conv and conv:FindFirstChild("ConvertPrompt", true)
	if not prompt then
		warn("[ZSS] ConvertPrompt не найден")
		return
	end
	prompt.Triggered:Connect(Converter.Start)
end)

-- ===== РЕГЕНЕРАЦИЯ ЗДОРОВЬЯ (характеристика брони) =====
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local regen = player:GetAttribute("ZSS_Regen") or 0
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if regen > 0 and hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
				hum.Health = math.min(hum.MaxHealth, hum.Health + regen)
			end
		end
	end
end)

-- ===== ОТЛАДКА (только в Studio) =====
-- Пример из командной строки сервера: game.ServerStorage.ZSS_Debug:Invoke("pity", "Secret", 1999)
if game:GetService("RunService"):IsStudio() then
	local dbg = Instance.new("BindableFunction")
	dbg.Name = "ZSS_Debug"
	dbg.OnInvoke = function(cmd, a, b)
		-- мировые команды
		if cmd == "night" then
			-- перемотать цикл: a = true (ночь) / false (день)
			local DN = Config.DayNight
			local target = a and (DN.day + 5) or 5
			workspace:SetAttribute("ZSS_CycleStart", workspace:GetServerTimeNow() - target)
			return "ok"
		elseif cmd == "bosshp" then
			for _, z in pairs(Zombies.Active) do
				if z.boss then
					z.hum.Health = a
				end
			end
			return "ok"
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local p = Data.Get(player)
			if p then
				if cmd == "pity" then
					p.pity[a] = b
				elseif cmd == "claim" then
					-- занять станцию a (как нажатие E у свободной станции)
					Hives.Claim(player, a or 1)
				elseif cmd == "give" then
					Data.AddDrone(p, a)
					Drones.Rebuild(player)
				elseif cmd == "batteries" then
					p.batteries = a
				elseif cmd == "gems" then
					p.gems = a
				elseif cmd == "scrap" then
					Data.TakeScrap(p, p.scrap)
					Data.AddScrap(player, math.min(a, Data.Capacity(p)), b or "rust")
				elseif cmd == "item" then
					Data.AddItem(player, a, b or 1)
				elseif cmd == "allitems" then
					for _, it in ipairs(Items.List) do
						Data.AddItem(player, it.id, math.random(1, 5))
					end
				elseif cmd == "energy" then
					local s = Drones.Swarms[player]
					if s then
						for _, d in pairs(s.drones) do
							d.energy = a
							if a <= 0 and not d.mini then
								d.state = "tired"
								Remotes.DroneState:FireAllClients(player.UserId, d.key, "tired")
							end
						end
					end
				end
				Data.MarkDirty(player)
			end
		end
		return "ok"
	end
	dbg.Parent = game:GetService("ServerStorage")
end

print("[ZSS] Zombie Swarm Simulator запущен")
