-- Логика роя: сбор лома, атака зомби, уникальные способности.
-- Сервер считает логику, клиенты рисуют дронов (атрибут Swarm + событие DroneState).
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes

local Drones = {}
local Data, Fields, Zombies

local swarms = {}
Drones.Swarms = swarms

local function statsFor(def)
	local base = Config.RarityStats[def.rarity]
	local m = def.mods or {}
	return {
		gather = base.gather * (m.gather or 1),
		damage = base.damage * (m.damage or 1),
		speed = base.speed * (m.speed or 1),
		gatherTime = base.gatherTime,
	}
end

local function newDrone(key, id, isMini)
	local def = isMini and Config.MiniDrone or Config.DroneById[id]
	local now = os.clock()
	local ab = def.ability
	return {
		key = key,
		id = id,
		def = def,
		stats = statsFor(def),
		state = "idle",
		t = 0,
		waitUntil = now + math.random() * 1.5,
		abilityReady = now + ((ab and ab.cd) and math.random(30, 100) / 100 * ab.cd or 0),
		mini = isMini,
		energy = 1,
		-- у каждого дрона свой «аккумулятор»: редкость + разброс ±20%
		workTime = isMini and 1e9 or Config.Energy.workTime[def.rarity] * (0.8 + math.random() * 0.4),
		chargeTime = Config.Energy.chargeTime[def.rarity],
	}
end

local function fx(kind, data)
	Remotes.FX:FireAllClients(kind, data)
end

local function send(player, d, mode, target)
	Remotes.DroneState:FireAllClients(player.UserId, d.key, mode, target)
end

local function addBuff(s, name, mult, duration)
	table.insert(s.buffs, { name = name, mult = mult, untilT = os.clock() + duration })
end

local function buffMult(s, name, now)
	local m = 1
	for i = #s.buffs, 1, -1 do
		local b = s.buffs[i]
		if now > b.untilT then
			table.remove(s.buffs, i)
		elseif b.name == name then
			m = math.max(m, b.mult)
		end
	end
	return m
end

local function collect(c, d, tile, mult)
	return Fields.Collect(c.player, tile, d.stats.gather, (mult or 1) * buffMult(c.s, "scrap", c.now))
end

local function travelTime(d, pos, speedMult)
	local from = d.pos or pos
	return math.clamp((pos - from).Magnitude / (d.stats.speed * speedMult), 0.25, 3)
end

-- ===== СПОСОБНОСТИ =====
-- каждая функция возвращает true, если способность сработала (тогда уходит на перезарядку)
local A = {}

A.scan = function(c)
	if not c.field then
		return false
	end
	local tiles = Fields.TilesNear(c.field, c.hrp.Position, 16)
	if #tiles == 0 then
		return false
	end
	local targets = {}
	for _ = 1, 3 do
		local t = tiles[math.random(#tiles)]
		collect(c, c.d, t, 1)
		table.insert(targets, Fields.TopPos(t))
	end
	fx("beams", { owner = c.player.UserId, key = c.d.key, targets = targets, color = Color3.fromRGB(80, 230, 255) })
	return true
end

A.zap = function(c)
	if not c.field then
		return false
	end
	local z = Zombies.Nearest(c.field, c.hrp.Position, 30)
	if not z then
		return false
	end
	fx("zap", { owner = c.player.UserId, key = c.d.key, to = z.root.Position, color = Color3.fromRGB(255, 240, 90) })
	Zombies.Damage(z, 25, c.player)
	return true
end

A.blades = function(c)
	if not c.field then
		return false
	end
	local zs = Zombies.InRadius(c.field, c.hrp.Position, 12)
	if #zs == 0 then
		return false
	end
	fx("ring", { pos = c.hrp.Position, radius = 12, color = Color3.fromRGB(220, 220, 230), style = "blades" })
	for _, z in ipairs(zs) do
		Zombies.Damage(z, 18, c.player)
	end
	return true
end

A.heal = function(c)
	if c.hum.Health >= c.hum.MaxHealth - 1 then
		return false
	end
	c.hum.Health = math.min(c.hum.MaxHealth, c.hum.Health + 25)
	fx("heal", { owner = c.player.UserId, key = c.d.key })
	return true
end

A.frost = function(c)
	if not c.field then
		return false
	end
	local zs = Zombies.InRadius(c.field, c.hrp.Position, 22)
	if #zs == 0 then
		return false
	end
	fx("ring", { pos = c.hrp.Position, radius = 22, color = Color3.fromRGB(150, 220, 255), style = "frost" })
	for _, z in ipairs(zs) do
		Zombies.Slow(z, 5)
		Zombies.Damage(z, 10, c.player)
	end
	return true
end

A.magnet = function(c)
	if not c.field then
		return false
	end
	local tiles = Fields.TilesNear(c.field, c.hrp.Position, 9)
	if #tiles == 0 then
		return false
	end
	local targets = {}
	for _, t in ipairs(tiles) do
		collect(c, c.d, t, 0.8)
		table.insert(targets, Fields.TopPos(t))
	end
	fx("magnet", { owner = c.player.UserId, pos = c.hrp.Position, radius = 9, targets = targets })
	return true
end

A.chain = function(c)
	if not c.field then
		return false
	end
	local zs = Zombies.InRadius(c.field, c.hrp.Position, 30)
	if #zs == 0 then
		return false
	end
	local points = {}
	for i = 1, math.min(4, #zs) do
		table.insert(points, zs[i].root.Position)
	end
	fx("chain", { owner = c.player.UserId, key = c.d.key, points = points })
	for i = 1, math.min(4, #zs) do
		Zombies.Damage(zs[i], 30, c.player)
	end
	return true
end

A.recycle = function(c)
	local p = Data.Get(c.player)
	if not p or p.scrap < 10 then
		return false
	end
	local amount = Data.TakeScrap(p, p.scrap * 0.2)
	local gain = math.floor(amount * 1.1)
	Data.AddBatteries(c.player, gain)
	Remotes.Popup:FireClient(c.player, c.hrp.Position + Vector3.new(0, 5, 0), "🔋 +" .. gain, "battery")
	fx("recycle", { owner = c.player.UserId, key = c.d.key })
	return true
end

A.burst = function(c)
	if not c.field then
		return false
	end
	local z = Zombies.Nearest(c.field, c.hrp.Position, 35)
	if not z then
		return false
	end
	local player, key = c.player, c.d.key
	task.spawn(function()
		for _ = 1, 5 do
			if z.dead then
				break
			end
			fx("shot", { owner = player.UserId, key = key, to = z.root.Position, color = Color3.fromRGB(255, 120, 40) })
			Zombies.Damage(z, 12, player)
			task.wait(0.15)
		end
	end)
	return true
end

A.cloud = function(c)
	if not c.field then
		return false
	end
	local pos, field, player, s, d = c.hrp.Position, c.field, c.player, c.s, c.d
	fx("cloud", { pos = pos, radius = 12, duration = 8, color = Color3.fromRGB(120, 255, 80) })
	task.spawn(function()
		for _ = 1, 8 do
			if not player.Parent then
				break
			end
			for _, z in ipairs(Zombies.InRadius(field, pos, 12)) do
				Zombies.Damage(z, 10, player)
			end
			for _, t in ipairs(Fields.TilesNear(field, pos, 6)) do
				Fields.Collect(player, t, d.stats.gather, 0.5 * buffMult(s, "scrap", os.clock()))
			end
			task.wait(1)
		end
	end)
	return true
end

A.phase = function(c)
	if not c.field or #c.field.tiles == 0 then
		return false
	end
	local targets = {}
	for _ = 1, 8 do
		local t = c.field.tiles[math.random(#c.field.tiles)]
		collect(c, c.d, t, 2)
		table.insert(targets, Fields.TopPos(t))
	end
	fx("phase", { owner = c.player.UserId, key = c.d.key, targets = targets })
	return true
end

A.nova = function(c)
	if not c.field then
		return false
	end
	local zs = Zombies.InRadius(c.field, c.hrp.Position, 25)
	if #zs == 0 then
		return false
	end
	fx("ring", { pos = c.hrp.Position, radius = 25, color = Color3.fromRGB(255, 120, 30), style = "fire" })
	for _, z in ipairs(zs) do
		Zombies.Damage(z, 90, c.player)
	end
	return true
end

A.overclock = function(c)
	if not c.field then
		return false
	end
	addBuff(c.s, "speed", 2, 10)
	fx("aura", { owner = c.player.UserId, color = Color3.fromRGB(220, 90, 255), duration = 10 })
	return true
end

A.orbital = function(c)
	if not c.field then
		return false
	end
	local z = Zombies.Nearest(c.field, c.hrp.Position, 40)
	local pos = z and z.root.Position or c.hrp.Position
	pos = Vector3.new(pos.X, c.field.cfg.center.Y + 1, pos.Z)
	local field, player, s, d = c.field, c.player, c.s, c.d
	fx("orbital", { pos = pos, radius = 20, color = Color3.fromRGB(255, 200, 40) })
	task.delay(1.1, function()
		if not player.Parent then
			return
		end
		for _, zz in ipairs(Zombies.InRadius(field, pos, 20)) do
			Zombies.Damage(zz, 400, player)
		end
		for _, t in ipairs(Fields.TilesNear(field, pos, 10)) do
			Fields.Collect(player, t, d.stats.gather, 3 * buffMult(s, "scrap", os.clock()))
		end
	end)
	return true
end

A.gold = function(c)
	if not c.field then
		return false
	end
	local tiles = Fields.TilesNear(c.field, c.hrp.Position, 18)
	if #tiles == 0 then
		return false
	end
	for _ = 1, 10 do
		Fields.SetGold(tiles[math.random(#tiles)], 15)
	end
	fx("ring", { pos = c.hrp.Position, radius = 18, color = Color3.fromRGB(255, 210, 50), style = "gold" })
	return true
end

A.swarm = function(c)
	if not c.field then
		return false
	end
	local s = c.s
	for _ = 1, 5 do
		s.miniCounter += 1
		local key = "m" .. s.miniCounter
		local d = newDrone(key, "mini", true)
		d.expires = c.now + 15
		d.pos = c.hrp.Position
		s.drones[key] = d
		table.insert(s.order, key)
	end
	Drones.Publish(c.player)
	fx("summon", { owner = c.player.UserId, key = c.d.key })
	return true
end

A.prism = function(c)
	if not c.field then
		return false
	end
	addBuff(c.s, "scrap", 3, 15)
	fx("aura", { owner = c.player.UserId, rainbow = true, duration = 15 })
	return true
end

A.reap = function(c)
	if not c.field then
		return false
	end
	local zs = Zombies.InField(c.field)
	if #zs == 0 then
		return false
	end
	local points = {}
	for _, z in ipairs(zs) do
		table.insert(points, z.root.Position)
	end
	fx("reap", { owner = c.player.UserId, key = c.d.key, points = points })
	-- не мгновенное убийство: забирает половину здоровья (боссу — фиксированный урон)
	for _, z in ipairs(zs) do
		if z.boss then
			Zombies.Damage(z, 3000, c.player)
		else
			z.rewardMult = 2
			Zombies.Damage(z, z.hum.MaxHealth * 0.5, c.player)
		end
	end
	return true
end

A.doomsday = function(c)
	if not c.field then
		return false
	end
	local pos = c.hrp.Position
	local field, player, s, d = c.field, c.player, c.s, c.d
	fx("doomsday", { pos = pos, radius = 40 })
	task.delay(1.6, function()
		if not player.Parent then
			return
		end
		for _, z in ipairs(Zombies.InField(field)) do
			if z.boss then
				Zombies.Damage(z, 8000, player)
			else
				z.rewardMult = 2
				Zombies.Damage(z, z.hum.MaxHealth * 0.7, player)
			end
		end
		for _, t in ipairs(Fields.TilesNear(field, pos, 30)) do
			Fields.Collect(player, t, d.stats.gather, 5)
		end
		addBuff(s, "scrap", 5, 20)
		addBuff(s, "speed", 1.5, 20)
	end)
	return true
end

-- ===== УПРАВЛЕНИЕ РОЕМ =====
-- как в BSS: рой появляется только после того, как игрок занял станцию (улей)
local function hasHive(player)
	return Drones.HiveIndex ~= nil and Drones.HiveIndex(player) ~= nil
end

function Drones.Publish(player, launch)
	local s = swarms[player]
	if not s then
		return
	end
	local list = {}
	if hasHive(player) then
		for _, key in ipairs(s.order) do
			local d = s.drones[key]
			if d then
				-- l = true: дрон только что вылетает из соты (клиент рисует вылет из улья)
				table.insert(list, { k = key, id = d.mini and "mini" or d.id, l = launch or nil })
			end
		end
	end
	player:SetAttribute("Swarm", HttpService:JSONEncode(list))
end

function Drones.Rebuild(player)
	local s = swarms[player]
	local p = Data.Get(player)
	if not s or not p then
		return
	end
	local newList, order = {}, {}
	-- запоминаем заряд текущих дронов (снять/надеть не заряжает)
	p.energy = p.energy or {}
	for key, d in pairs(s.drones) do
		if not d.mini then
			p.energy[key] = d.energy
		end
	end
	for _, uid in ipairs(p.equipped) do
		local id = p.drones[uid]
		if id then
			local d = s.drones[uid]
			if not d or d.id ~= id then
				d = newDrone(uid, id, false)
				-- заряд сохраняется по каждому дрону; новый/только что надетый — полный
				if p.energy and p.energy[uid] then
					d.energy = math.clamp(p.energy[uid], 0, 1)
					if d.energy <= 0 then
						d.state = "tired"
					end
				end
			end
			newList[uid] = d
			table.insert(order, uid)
		end
	end
	for _, key in ipairs(s.order) do
		local d = s.drones[key]
		if d and d.mini then
			newList[key] = d
			table.insert(order, key)
		end
	end
	s.drones = newList
	s.order = order
	Drones.Publish(player)
end

function Drones.Add(player)
	swarms[player] = { drones = {}, order = {}, buffs = {}, miniCounter = 0, lastGateWarn = 0 }
	Drones.Rebuild(player)
end

-- сохранить заряд дронов в профиль
function Drones.SaveEnergy(player)
	local s = swarms[player]
	local p = Data.Get(player)
	if not s or not p then
		return
	end
	p.energy = p.energy or {}
	for key, d in pairs(s.drones) do
		if not d.mini then
			p.energy[key] = math.floor(d.energy * 1000) / 1000
		end
	end
	-- удалённые дроны чистим
	for uid in pairs(p.energy) do
		if not p.drones[uid] then
			p.energy[uid] = nil
		end
	end
end

-- игрок занял станцию: рой вылетает из сот и летит к нему
function Drones.Launch(player)
	local s = swarms[player]
	local hive = Drones.HiveIndex and Drones.HiveIndex(player)
	if not s or not hive then
		return
	end
	local now = os.clock()
	for i, key in ipairs(s.order) do
		local d = s.drones[key]
		if d then
			d.pos = Drones.CellPos(hive, (i - 1) % Config.Hive.maxCells + 1)
			d.tile = nil
			d.zombie = nil
			if d.state ~= "tired" then
				d.state = "idle"
			end
			-- не начинать работу, пока дрон ещё летит от улья
			d.waitUntil = now + 1.6 + i * 0.12
		end
	end
	Drones.Publish(player, true)
	-- снять флаг вылета, чтобы позже зашедшие игроки не видели повторный вылет
	task.delay(3, Drones.Publish, player)
end

function Drones.Remove(player)
	Drones.SaveEnergy(player)
	swarms[player] = nil
end

local function stepDrone(c, d)
	local now = c.now
	local st = d.state
	if st == "dock" then
		return
	end
	if st == "tired" then
		if d.energy > 0.02 then
			d.state = "idle"
			d.waitUntil = now
			send(c.player, d, "idle")
		end
		return
	end
	if st == "idle" then
		if now < d.waitUntil or not c.field then
			d.pos = c.hrp.Position
			return
		end
		if d.stats.damage > 0 and math.random() < 0.45 then
			local z = Zombies.Nearest(c.field, c.hrp.Position, 28)
			if z then
				d.state = "attack"
				d.zombie = z
				d.hits = 0
				d.t = now + travelTime(d, z.root.Position, c.speedMult)
				send(c.player, d, "attack", z.model)
				return
			end
		end
		local tile = Fields.RandomTileNear(c.field, c.hrp.Position, 14)
		if tile then
			d.state = "travel"
			d.tile = tile
			local top = Fields.TopPos(tile)
			d.t = now + travelTime(d, top, c.speedMult)
			send(c.player, d, "travel", top)
		end
	elseif st == "travel" then
		if now >= d.t then
			d.state = "gather"
			d.t = now + d.stats.gatherTime / c.speedMult
		end
	elseif st == "gather" then
		if now >= d.t then
			local mult = 1
			if d.def.ability and d.def.ability.id == "double" and math.random() < 0.25 then
				mult = 2
			end
			collect(c, d, d.tile, mult)
			d.pos = Fields.TopPos(d.tile)
			d.tile = nil
			d.state = "idle"
			d.waitUntil = now + 0.3 / c.speedMult
			if not c.field then
				send(c.player, d, "idle")
			end
		end
	elseif st == "attack" then
		local z = d.zombie
		if not z or z.dead or not c.field or (z.root.Position - c.hrp.Position).Magnitude > 45 then
			d.state = "idle"
			d.zombie = nil
			d.waitUntil = now + 0.2
			send(c.player, d, "idle")
			return
		end
		if now >= d.t then
			Zombies.Damage(z, d.stats.damage, c.player)
			d.hits += 1
			d.t = now + 0.9 / c.speedMult
			if d.hits >= 4 then
				d.state = "idle"
				d.zombie = nil
				d.pos = z.root.Position
				d.waitUntil = now + 0.2
				send(c.player, d, "idle")
			end
		end
	end
end

function Drones.Step(now)
	for player, s in pairs(swarms) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local p = Data.Get(player)
		if hrp and hum and hum.Health > 0 and p then
			local field = Fields.At(hrp.Position)
			if field and #p.equipped < field.cfg.req then
				if now - s.lastGateWarn > 1 then
					s.lastGateWarn = now
					Remotes.Notify:FireClient(player, ("⛔ Для зоны «%s» нужно %d дронов в рое!"):format(field.cfg.name, field.cfg.req), "bad")
					char:PivotTo(CFrame.new(Fields.Entrance(field) + Fields.GateDir(field) * 4))
				end
				field = nil
			end
			-- рой ещё сидит в улье, пока игрок не занял станцию
			if not hasHive(player) then
				continue
			end

			-- истекшие мини-дроны
			local changed = false
			for i = #s.order, 1, -1 do
				local key = s.order[i]
				local d = s.drones[key]
				if d and d.mini and now > d.expires then
					s.drones[key] = nil
					table.remove(s.order, i)
					changed = true
				end
			end
			if changed then
				Drones.Publish(player)
			end

			local c = { player = player, s = s, field = field, hrp = hrp, hum = hum, now = now, speedMult = buffMult(s, "speed", now) }
			local dt = math.clamp(now - (s.lastStep or now), 0, 0.5)
			s.lastStep = now
			local freed = false
			for _, key in ipairs(table.clone(s.order)) do
				local d = s.drones[key]
				if d and d.state == "dock" then
					-- зарядка в соте улья
					if now >= d.t then
						d.energy = math.min(1, d.energy + dt / d.chargeTime)
						if d.energy >= 1 then
							d.state = "idle"
							d.cell = nil
							d.waitUntil = now + 0.5
							send(player, d, "idle")
							freed = true
							if Drones.OnCharged then
								Drones.OnCharged(player)
							end
						end
					end
				elseif d then
					if d.state == "travel" or d.state == "gather" or d.state == "attack" then
						d.energy = math.max(0, d.energy - dt / d.workTime)
						if d.energy <= 0 then
							d.state = "tired"
							d.tile = nil
							d.zombie = nil
							send(player, d, "tired")
						end
					end
					stepDrone(c, d)
					local ab = d.def.ability
					if ab and ab.cd and now >= d.abilityReady and d.state ~= "tired" and d.state ~= "dock" then
						c.d = d
						local ok, used = pcall(A[ab.id], c)
						if not ok then
							warn("[ZSS] Способность", ab.id, used)
							d.abilityReady = now + 5
						elseif used then
							d.abilityReady = now + ab.cd
							d.energy = math.max(0, d.energy - 0.03) -- способность тратит заряд
							fx("ability", { owner = player.UserId, key = d.key, name = ab.name, rarity = d.def.rarity })
						else
							d.abilityReady = now + 0.5
						end
					end
				end
			end
			if freed then
				-- в освободившуюся соту — следующего разряженного дрона
				if s.charging then
					Drones.FillDock(player)
				end
				if Drones.DockedCount(player) == 0 then
					s.charging = false
				end
				if Drones.OnDockChanged then
					Drones.OnDockChanged(player)
				end
			end
		end
	end
end

-- ===== ЗАРЯДКА В УЛЬЕ (соты на стене) =====
-- соты занимают самые разряженные дроны; остальные ждут свободной соты
function Drones.FillDock(player)
	local s = swarms[player]
	local p = Data.Get(player)
	local hive = Drones.HiveIndex and Drones.HiveIndex(player)
	if not s or not p or not hive then
		return 0
	end
	local slots = p.dockSlots or Config.Hive.startCells
	local used = {}
	for _, d in pairs(s.drones) do
		if d.state == "dock" and d.cell then
			used[d.cell] = true
		end
	end
	local cand = {}
	for _, d in pairs(s.drones) do
		if not d.mini and d.state ~= "dock" and d.energy < 0.995 then
			table.insert(cand, d)
		end
	end
	table.sort(cand, function(a, b)
		return a.energy < b.energy
	end)
	local now = os.clock()
	local n, k = 0, 1
	for cell = 1, slots do
		if not used[cell] then
			local d = cand[k]
			if not d then
				break
			end
			k += 1
			local pos = Drones.CellPos(hive, cell)
			d.state = "dock"
			d.cell = cell
			d.tile = nil
			d.zombie = nil
			d.t = now + travelTime(d, pos, 1)
			d.pos = pos
			send(player, d, "dock", pos)
			n += 1
		end
	end
	if n > 0 and Drones.OnDockChanged then
		Drones.OnDockChanged(player)
	end
	return n, #cand - n
end

function Drones.Dock(player)
	local s = swarms[player]
	if not s then
		return 0, 0
	end
	s.charging = true
	local n, waiting = Drones.FillDock(player)
	if Drones.DockedCount(player) == 0 then
		s.charging = false
	end
	return n, waiting or 0
end

function Drones.Recall(player)
	local s = swarms[player]
	if not s then
		return 0
	end
	s.charging = false
	local n = 0
	for _, d in pairs(s.drones) do
		if d.state == "dock" then
			n += 1
			d.cell = nil
			d.state = d.energy > 0.02 and "idle" or "tired"
			d.waitUntil = os.clock() + 0.3
			send(player, d, d.state)
		end
	end
	if Drones.OnDockChanged then
		Drones.OnDockChanged(player)
	end
	return n
end

-- занятые соты: номер -> цвет редкости дрона
function Drones.DockedCells(player)
	local s = swarms[player]
	local out = {}
	if s then
		for _, d in pairs(s.drones) do
			if d.state == "dock" and d.cell then
				out[d.cell] = Config.Rarities[d.def.rarity] and Config.Rarities[d.def.rarity].color or Color3.new(1, 1, 1)
			end
		end
	end
	return out
end

function Drones.DockedCount(player)
	local s = swarms[player]
	local n = 0
	if s then
		for _, d in pairs(s.drones) do
			if d.state == "dock" then
				n += 1
			end
		end
	end
	return n
end

function Drones.AddEnergy(player, amount)
	local s = swarms[player]
	if not s then
		return
	end
	for _, d in pairs(s.drones) do
		if not d.mini then
			d.energy = math.min(1, d.energy + amount)
		end
	end
end

function Drones.Init(dataModule, fieldsModule, zombiesModule)
	Data, Fields, Zombies = dataModule, fieldsModule, zombiesModule
	-- синхронизация энергии с владельцем (для HUD и инвентаря)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, s in pairs(swarms) do
				local t = {}
				for key, d in pairs(s.drones) do
					if not d.mini then
						t[key] = { e = math.floor(d.energy * 100 + 0.5), s = d.state == "dock" and 1 or 0 }
					end
				end
				local json = HttpService:JSONEncode(t)
				if json ~= s.lastEnergyJson then
					s.lastEnergyJson = json
					Remotes.Energy:FireClient(player, t)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(Drones.Step, os.clock())
			if not ok then
				warn("[ZSS] Drones.Step:", err)
			end
		end
	end)
end

return Drones
