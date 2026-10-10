-- Выпадающие баффы: светящиеся сферы. Подобрал — действует сразу.
-- Появляются только от активности игрока: cat = "gather" — при добыче, cat = "combat" — в бою с зомби.
-- (Предметы — отдельно: падают ящичками-находками и идут в рюкзак, см. ItemsConfig.)
local C = Color3.fromRGB
local B = {}

-- Накопление как в Bee Swarm Simulator: каждый подобранный такой же бафф добавляет ступень (до MaxStacks)
-- и восстанавливает время до полного. Множитель = 1 + per * ступени.
-- time = длительность (сек), 0 = мгновенный; weight = частота появления
B.MaxStacks = 10
B.List = {
	{ id = "speed", name = "Ускорение", short = "СКОРОСТЬ", desc = "скорость бега", time = 10, per = 0.05, weight = 30, cat = "gather", color = C(80, 230, 255) },
	{ id = "scrap", name = "Щедрый сбор", short = "РЕСУРСЫ", desc = "добыча ресурсов", time = 15, per = 0.1, weight = 22, cat = "gather", color = C(255, 160, 60) },
	{ id = "rage", name = "Ярость роя", short = "УРОН", desc = "урон дронов и оружия", time = 15, per = 0.05, weight = 18, cat = "combat", color = C(255, 80, 50) },
	{ id = "luck", name = "Удача", short = "УДАЧА", desc = "шанс находок", time = 20, per = 0.2, weight = 12, cat = "gather", color = C(110, 240, 90) },
	{ id = "heal", name = "Аптечка", short = "ЛЕЧЕНИЕ", desc = "Сразу +50 здоровья", time = 0, value = 50, weight = 10, cat = "combat", color = C(255, 90, 100) },
	{ id = "charge", name = "Батарея роя", short = "ЗАРЯД +25%", desc = "Сразу +25% энергии всем дронам", time = 0, value = 0.25, weight = 8, cat = "gather", color = C(90, 170, 255) },
}
B.ById = {}
for i, b in ipairs(B.List) do
	b.index = i
	B.ById[b.id] = b
end

-- появление от активности (для каждого игрока отдельно)
B.Field = { perField = 4, lifetime = 30 } -- не больше 4 сфер на поле, живут 30 сек
B.Gather = { chance = 0.07, cooldown = 6 } -- шанс за удар инструментом/сбор дрона, пауза между сферами
B.Combat = { chance = 0.12, cooldown = 6 } -- шанс за удар по зомби
B.ZombieChance = 0.35 -- шанс, что из убитого зомби выпадет боевая сфера

-- находки (ящички с предметами)
B.Loot = { ownerTime = 20, lifetime = 120, magnet = 9 }

function B.Roll(rng, cat)
	local total = 0
	for _, b in ipairs(B.List) do
		if not cat or b.cat == cat then
			total += b.weight
		end
	end
	local r = rng:NextNumber() * total
	for _, b in ipairs(B.List) do
		if not cat or b.cat == cat then
			r -= b.weight
			if r <= 0 then
				return b
			end
		end
	end
	return B.List[1]
end

-- состояние хранится в атрибутах игрока (видно и серверу, и клиенту):
-- ZSS_Buff_<id> = до какого времени действует, ZSS_BuffN_<id> = ступени
function B.Left(player, id)
	return math.max(0, (player:GetAttribute("ZSS_Buff_" .. id) or 0) - workspace:GetServerTimeNow())
end

function B.Active(player, id)
	return B.Left(player, id) > 0
end

function B.Stacks(player, id)
	return B.Active(player, id) and (player:GetAttribute("ZSS_BuffN_" .. id) or 0) or 0
end

function B.Mult(player, id)
	local b = B.ById[id]
	return 1 + (b and b.per or 0) * B.Stacks(player, id)
end

-- текст множителя: x1.05, x1.5, x3
function B.MultText(mult)
	local s = ("%.2f"):format(mult):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. s
end

return B
