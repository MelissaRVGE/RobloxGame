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
make("RemoteFunction", "DonateBuy")
make("RemoteEvent", "DonateDone")
make("RemoteFunction", "Halloween")
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
local Donate = require(Modules.Donate)
local TierGuard = require(Modules.TierGuard)
local Halloween = require(Modules.Halloween)
local DonateCfg = require(Shared.DonateConfig)

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
Donate.Init(Data, Equipment)
TierGuard.Init(Data)
Halloween.Init(Data, Fields, Drones)
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
-- игроки проходят друг сквозь друга, но сталкиваются с миром и зомби
local PhysicsService = game:GetService("PhysicsService")
local PLAYER_GROUP = "ZSS_Players"
pcall(function()
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

local function setPlayerGroup(inst)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = PLAYER_GROUP
	end
end

local function onPlayerAdded(player)
	local p = Data.Load(player)
	Equipment.Reconcile(p)
	Donate.CheckPasses(player)
	task.spawn(Donate.CheckPolicy, player)
	Drones.Add(player)
	Data.Sync(player)
	-- как в BSS: дроны ждут в улье, пока игрок не займёт станцию
	task.delay(4, function()
		if player.Parent and not Hives.Index(player) then
			notify(player, "🤖 Your swarm is waiting at the base: go to a free charging station and press E", "info")
		end
	end)
	local function onChar(char)
		-- вся экипировка, надетая позже, тоже попадает в группу
		for _, d in ipairs(char:GetDescendants()) do
			setPlayerGroup(d)
		end
		char.DescendantAdded:Connect(setPlayerGroup)
		-- смерть: ресурсы с полей в рюкзаке пропадают (вместимость остаётся)
		local hum = char and char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				local p = Data.Get(player)
				if p and (p.scrap or 0) > 0 then
					Data.TakeScrap(p, p.scrap)
					p.scrap = 0
					p.res = {}
					Data.MarkDirty(player)
					Data.Sync(player)
					notify(player, "💀 You died. The resources in your backpack are lost", "bad")
				end
			end)
		end
		TierGuard.OnSpawn(player)
		task.wait(0.3)
		Equipment.Apply(player)
		Halloween.ApplyHat(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	Drones.Remove(player)
	TierGuard.Remove(player)
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
					-- пропуск «Гем-магнит» умножает награду
					local gems = PR.gems * math.max(1, DonateCfg.Perk(p.passes, "playGems"))
					Data.AddGems(player, gems)
					notify(player, ("💎 +%d for playtime! Next ones in %d min"):format(gems, math.floor(PR.interval / 60)), "good")
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
	return { ok = false, err = "Gems can't be bought with batteries. Complete quests and defeat the boss" }
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
	keys = "table",
}
-- переназначенные горячие клавиши: { [действие] = "ИмяKeyCode" }, только существующие клавиши
local function cleanKeys(t)
	local out, n = {}, 0
	for id, name in pairs(t) do
		if typeof(id) == "string" and #id <= 16 and typeof(name) == "string" and #name <= 24 then
			local ok, kc = pcall(function()
				return Enum.KeyCode[name]
			end)
			if ok and kc then
				out[id] = name
				n += 1
				if n >= 32 then
					break
				end
			end
		end
	end
	return out
end
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
			elseif kind == "table" then
				v = cleanKeys(v)
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
		return { ok = false, err = "Request error" }
	end
	local now = os.clock()
	if lastRedeem[player] and now - lastRedeem[player] < 2 then
		return { ok = false, err = "Wait a couple of seconds" }
	end
	lastRedeem[player] = now
	local code = raw:upper():gsub("%s", ""):sub(1, 32)
	if code == "" then
		return { ok = false, err = "Enter a promo code" }
	end
	local list = require(game:GetService("ServerStorage"):WaitForChild("ZSS_PromoCodes"))
	local reward
	for k, v in pairs(list) do
		if k:upper() == code then
			reward = v
		end
	end
	if not reward or reward.active == false or (reward.expires and os.time() > reward.expires) then
		return { ok = false, err = "❌ This code doesn't exist or has expired" }
	end
	p.codes = p.codes or {}
	if p.codes[code] then
		return { ok = false, err = "You've already redeemed this code" }
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
		table.insert(got, "drone “" .. Config.DroneById[reward.drone].name .. "”")
	end
	Data.MarkDirty(player)
	task.spawn(Data.Save, player) -- сразу сохранить, чтобы код нельзя было активировать повторно
	Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
	return { ok = true, msg = "🎁 Code redeemed: " .. table.concat(got, ", "), desc = reward.desc }
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
		return { ok = false, err = "Unknown item" }
	end
	p.bag = p.bag or {}
	local have = p.bag[id] or 0
	if have <= 0 then
		return { ok = false, err = "No such item" }
	end
	local function take(n)
		p.bag[id] = have - n
		if p.bag[id] <= 0 then
			p.bag[id] = nil
		end
		Data.MarkDirty(player)
	end
	-- продажи нет: находки только используются или идут на крафт
	if action == "use" then
		local u = item.use
		if not u then
			return { ok = false, err = "This item is a crafting material" }
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if u.heal then
			if not hum or hum.Health <= 0 then
				return { ok = false, err = "Not right now" }
			end
			if hum.Health >= hum.MaxHealth - 0.5 then
				return { ok = false, err = "❤ Health is already full" }
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
				return { ok = false, err = "Not right now" }
			end
			take(1)
			Quests.Event(player, "use", { id = id, find = true })
			local rar = Config.Rarities[rarity]
			return { ok = true, msg = ("🧬 %s: %s drone “%s”%s"):format(item.name, rar.label, def.name, isNew and " (NEW!)" or "") }
		end
		take(1)
		Quests.Event(player, "use", { id = id, find = true })
		return { ok = true, msg = "✔ Used: " .. item.name .. (u.gems and (" (+" .. u.gems .. " 💎)") or "") }
	end
	return { ok = false, err = "bad action" }
end

-- Хэллоуин: гача «Тыквенный котёл», обмен у ведьмы, шляпа
Remotes.Halloween.OnServerInvoke = function(player, action, arg)
	if action == "pull" and typeof(arg) == "number" then
		return Halloween.Pull(player, arg)
	elseif action == "trade" and typeof(arg) == "string" then
		return Halloween.Trade(player, arg)
	elseif action == "hat" then
		return Halloween.SetHat(player, arg == true)
	end
	return { ok = false, err = "bad request" }
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
			notify(player, ("Your swarm already has %d/%d drones. For more slots, buy cells at the Workshop by the charging stations"):format(#p.equipped, max), "bad")
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
	notify(player, "All drones removed from the swarm", "info")
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
	notify(player, "⚡ Best drones added to the swarm!", "good")
end)

Remotes.UpgradeBag.OnServerEvent:Connect(function(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	local cost = Config.BagCost(p.bagLevel)
	if not cost then
		notify(player, "🎒 Your backpack is already max level!", "info")
		return
	end
	if p.batteries < cost then
		notify(player, ("🔋 You need %d batteries to upgrade the backpack"):format(cost), "bad")
		return
	end
	-- рюкзак крафтится из находок
	local mats = Config.BagMats[p.bagLevel]
	local ok, missing = Data.HasMats(p, mats)
	if not ok then
		notify(player, "🎒 Not enough materials: " .. missing, "bad")
		return
	end
	Data.TakeMats(p, mats)
	p.batteries -= cost
	p.bagLevel += 1
	Data.MarkDirty(player)
	Quests.Event(player, "bagUp")
	Quests.Event(player, "craft", { slot = "bag" })
	notify(player, ("🎒 Backpack upgraded! Capacity: %d"):format(Data.Capacity(p)), "good")
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
		for _, z in ipairs(Zombies.InRadius(field, hrp.Position, st.radius + 2, player)) do
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
		notify(player, "⚡ First claim a free charging station by the south wall of the base", "bad")
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Hives.FrontPos(hive)).Magnitude > 22 then
		notify(player, "⚡ Go to your station #" .. hive .. " at the base", "bad")
		return
	end
	if Drones.DockedCount(player) > 0 then
		local n = Drones.Recall(player)
		notify(player, ("🤖 Taken from the station: %d drones"):format(n), "info")
	else
		local n, waiting = Drones.Dock(player)
		if n == 0 then
			notify(player, "⚡ All drones are already charged", "good")
		elseif waiting > 0 then
			notify(player, ("⚡ In cells: %d, in queue: %d. Buy more cells at the Workshop!"):format(n, waiting), "good")
		else
			notify(player, ("⚡ Charging: %d drones. They'll come back on their own when charged"):format(n), "good")
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
	elseif dest == "halloween" and Config.HalloweenOn() then
		-- перед котлом-гачей, лицом к нему
		pos = Config.Halloween.zone.tp or Config.Halloween.zone.center + Vector3.new(0, 4, 22)
		fieldCenter = Config.Halloween.zone.center
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
				-- карта не пускает в закрытую локацию: нужен рой не меньше требования поля
				local p = Data.Get(player)
				local have = p and #p.equipped or 0
				if have < (f.cfg.req or 0) then
					notify(player, ("🔒 “%s” unlocks when your swarm has %d drones (now %d)"):format(f.cfg.name, f.cfg.req, have), "bad")
					return
				end
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
		warn("[ZSS] ConvertPrompt not found")
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
				elseif cmd == "pumpkins" then
					p.pumpkins = a
				elseif cmd == "scrap" then
					Data.TakeScrap(p, p.scrap)
					Data.AddScrap(player, math.min(a, Data.Capacity(p)), b or "rust")
				elseif cmd == "donate" then
					-- выдать предложение доната без оплаты (проверка анимаций и выдачи)
					Donate.DebugGrant(player, a)
				elseif cmd == "unpass" then
					p.passes = {}
					p.donateOnce = {}
					for _, o in ipairs(DonateCfg.List) do
						player:SetAttribute("ZSS_Pass_" .. o.key, nil)
					end
					Equipment.Apply(player)
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

print("[ZSS] Zombie Swarm Simulator started")
