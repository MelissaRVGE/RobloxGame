-- Серверная проверка ярусов: на ярус N можно попасть, только если в рое хватает дронов.
-- Стены ворот и барьеры полей стоят на клиенте, их можно обойти (деревья, лаги, читы),
-- поэтому сервер сам следит, на каком ярусе игрок, и возвращает его к воротам, если пройти было нельзя.
-- Кто зашёл честно и потом снял дронов, остаётся (как с барьерами полей на клиенте).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes

local TierGuard = {}
local Data
local CHECK = 0.3

-- требование яруса N (берём из конфига полей)
local REQ = {}
local TOP = 0
for _, f in ipairs(Config.Fields) do
	if f.tier then
		REQ[f.tier] = math.max(REQ[f.tier] or 0, f.req or 0)
		TOP = math.max(TOP, f.tier)
	end
end
-- требование с учётом всех нижних ярусов (чтобы пройти на 3-й, нужны и ворота 1 и 2)
local NEED = { [0] = 0 }
for n = 1, TOP do
	NEED[n] = math.max(NEED[n - 1], REQ[n] or 0)
end

local gateZ = {} -- [N] = Z стены ворот на ярус N
local gateY = {}
local reached = {} -- [player] = самый высокий ярус, куда игрок прошёл честно (сбрасывается при спуске)
local lastWarn = {}

local function tierAt(z)
	local t = 0
	for n = 1, TOP do
		if gateZ[n] and z > gateZ[n] then
			t = n
		end
	end
	return t
end

local function openTier(have)
	local t = 0
	for n = 1, TOP do
		if have >= NEED[n] then
			t = n
		end
	end
	return t
end

-- точка на главной дороге прямо перед воротами на ярус target+1
local function backPos(char, target)
	local z = gateZ[target + 1] and (gateZ[target + 1] - 8) or Config.BasePos.Z
	local top = (gateY[target + 1] or 0) + 80
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { char }
	for _, name in ipairs({ "ZSS_FieldBarriers", "ZSS_MapBounds", "ZSS_Swarms", "ZSS_WornBackpacks" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(0, top, z), Vector3.new(0, -top - 60, 0), params)
	local y = hit and (hit.Position.Y + 4) or (target * 12 + 4)
	return Vector3.new(0, y, z)
end

local function kickBack(player, char, hrp, target, tier)
	local pos = backPos(char, target)
	hrp.AssemblyLinearVelocity = Vector3.zero
	char:PivotTo(CFrame.lookAt(pos, pos - Vector3.new(0, 0, 10)))
	local now = os.clock()
	if not lastWarn[player] or now - lastWarn[player] > 3 then
		lastWarn[player] = now
		local p = Data.Get(player)
		local have = p and #p.equipped or 0
		Remotes.Notify:FireClient(player, ("🔒 This location unlocks when your swarm has %d drones (now %d)"):format(NEED[tier], have), "bad")
	end
end

local function check(player)
	local p = Data.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not p or not hrp or not hum or hum.Health <= 0 then
		return
	end
	local tier = tierAt(hrp.Position.Z)
	local have = #p.equipped
	local last = reached[player]
	if last == nil then
		-- после появления: где стоит — туда и можно, если хватает дронов
		last = math.min(tier, openTier(have))
	end
	if tier > last and have < NEED[tier] then
		local target = math.max(last, math.min(tier - 1, openTier(have)))
		reached[player] = target
		kickBack(player, char, hrp, target, tier)
		return
	end
	reached[player] = tier
end

function TierGuard.OnSpawn(player)
	reached[player] = nil
end

function TierGuard.Remove(player)
	reached[player] = nil
	lastWarn[player] = nil
end

function TierGuard.Init(dataModule)
	Data = dataModule
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local gates = map:WaitForChild("TierGates", 30)
		for _, gate in ipairs(gates and gates:GetChildren() or {}) do
			local n = tonumber(gate.Name:match("^Gate_(%d+)$"))
			local wall = gate:FindFirstChild("Wall")
			if n and wall then
				gateZ[n] = wall.Position.Z
				gateY[n] = wall.Position.Y
			end
		end
		while true do
			task.wait(CHECK)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(check, player)
			end
		end
	end)
end

return TierGuard
