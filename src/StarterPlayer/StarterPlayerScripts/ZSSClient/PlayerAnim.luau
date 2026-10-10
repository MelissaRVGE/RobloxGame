-- Анимации удара игрока: у каждого оружия свой стиль.
-- Накладываются поверх стандартных анимаций (Motor6D.Transform в Stepped), работают для R15 и R6.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shop = require(RS:WaitForChild("ZSS"):WaitForChild("ShopConfig"))

local PA = {}
local active = {} -- char -> { style, start, dur }

local STYLE = {
	scraper = "scoop",
	pipe = "chop",
	bat = "swing",
	machete = "slash",
	fireaxe = "chop",
	sledge = "slam",
	chainsaw = "saw",
	baton = "jab",
	scythe = "spin",
	shiv = "slash",
	shovel = "scoop",
	pickaxe = "chop",
	magrake = "scoop",
	jackhammer = "saw",
	vacuum = "saw",
	plasmacutter = "jab",
	-- новое оружие
	spear = "jab",
	katana = "slash",
	bonecleaver = "chop",
	lavaaxe = "chop",
	thunderhammer = "slam",
	crystalblade = "slash",
	dragonglaive = "spin",
	obsidianscythe = "spin",
	gravhammer = "slam",
	omegasaber = "slash",
	-- новые инструменты
	drillgun = "saw",
	harvester = "scoop",
	magnetcannon = "jab",
	excavator = "scoop",
	laserdrill = "saw",
	cryoextractor = "jab",
	gravitywell = "scoop",
	lavaforge = "scoop",
	nanoswarm = "jab",
	singularity = "spin",
}
local DUR = { scoop = 0.36, chop = 0.45, swing = 0.4, slash = 0.34, slam = 0.6, saw = 0.25, jab = 0.3, spin = 0.5 }

local function ease(t)
	return t * t * (3 - 2 * t)
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
-- кусочно-линейная анимация по ключам {t, value}
local function keys(t, list)
	for i = 1, #list - 1 do
		local a, b = list[i], list[i + 1]
		if t <= b[1] then
			return lerp(a[2], b[2], ease((t - a[1]) / math.max(1e-3, b[1] - a[1])))
		end
	end
	return list[#list][2]
end

-- поза: rArm (подъём вперёд, рад), rRoll (отвод в сторону), lArm, twist (поворот корпуса), bend (наклон), elbow
local POSE = {}
POSE.scoop = function(t)
	return keys(t, { { 0, 0 }, { 0.35, 0.3 }, { 0.7, 1.4 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.7, 1.0 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.4, 0.35 }, { 1, 0 } }), 0
end
POSE.chop = function(t)
	return keys(t, { { 0, 0 }, { 0.42, 2.9 }, { 0.62, 0.7 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.42, 1.0 }, { 0.62, 0.4 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.42, -0.2 }, { 0.62, 0.35 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.42, 0.9 }, { 0.62, 0 }, { 1, 0 } })
end
POSE.swing = function(t)
	return keys(t, { { 0, 0 }, { 0.3, 1.5 }, { 0.7, 1.5 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.3, 1.2 }, { 0.65, -0.9 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.3, 1.3 }, { 0.7, 1.3 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.3, 0.9 }, { 0.65, -1.0 }, { 1, 0 } }), 0, 0
end
POSE.slash = function(t)
	return keys(t, { { 0, 0 }, { 0.35, 2.6 }, { 0.65, 0.5 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.35, 0.8 }, { 0.65, -0.7 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.35, 0.5 }, { 0.65, -0.7 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.65, 0.2 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.35, 0.6 }, { 0.65, 0 }, { 1, 0 } })
end
POSE.slam = function(t)
	return keys(t, { { 0, 0 }, { 0.5, 3.0 }, { 0.66, 0.35 }, { 0.82, 0.35 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.5, 3.0 }, { 0.66, 0.35 }, { 0.82, 0.35 }, { 1, 0 } }), 0, keys(t, { { 0, 0 }, { 0.5, -0.3 }, { 0.66, 0.55 }, { 0.82, 0.55 }, { 1, 0 } }), 0
end
POSE.saw = function(t)
	local j = math.sin(t * 60) * 0.08
	return keys(t, { { 0, 0.9 }, { 0.5, 1.45 }, { 1, 0.9 } }) + j, j, keys(t, { { 0, 0.8 }, { 0.5, 1.3 }, { 1, 0.8 } }) - j, 0, keys(t, { { 0, 0 }, { 0.5, 0.25 }, { 1, 0 } }), 0
end
POSE.jab = function(t)
	return keys(t, { { 0, 0.4 }, { 0.3, 1.0 }, { 0.5, 1.6 }, { 1, 0 } }), 0, 0, keys(t, { { 0, 0 }, { 0.3, 0.5 }, { 0.5, -0.3 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.5, 0.2 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.3, 1.6 }, { 0.5, 0 }, { 1, 0 } })
end
POSE.spin = function(t)
	return keys(t, { { 0, 0 }, { 0.15, 1.5 }, { 0.85, 1.5 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.15, 0.9 }, { 0.85, 0.9 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.15, 1.3 }, { 0.85, 1.3 }, { 1, 0 } }), keys(t, { { 0, 0 }, { 0.15, 0.6 }, { 0.85, 0.6 - math.pi * 2 }, { 1, -math.pi * 2 } }), 0, 0
end

local function rig(char)
	local ut = char:FindFirstChild("UpperTorso")
	if ut then
		local ra = char:FindFirstChild("RightUpperArm")
		local la = char:FindFirstChild("LeftUpperArm")
		local rl = char:FindFirstChild("RightLowerArm")
		return {
			r15 = true,
			rs = ra and ra:FindFirstChild("RightShoulder"),
			ls = la and la:FindFirstChild("LeftShoulder"),
			elbow = rl and rl:FindFirstChild("RightElbow"),
			waist = ut:FindFirstChild("Waist"),
		}
	end
	local torso = char:FindFirstChild("Torso")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if torso and hrp then
		return {
			r15 = false,
			rs = torso:FindFirstChild("Right Shoulder"),
			ls = torso:FindFirstChild("Left Shoulder"),
			waist = hrp:FindFirstChild("RootJoint"),
		}
	end
	return nil
end

-- аккуратное наложение: если аниматор не перезаписал сустав, сначала снимаем наше прошлое смещение
local function apply(a, motor, off)
	if not motor then
		return
	end
	a.last = a.last or {}
	local prev = a.last[motor]
	local base = motor.Transform
	if prev and base == prev.set then
		base = prev.set * prev.off:Inverse()
	end
	local set = base * off
	motor.Transform = set
	a.last[motor] = { set = set, off = off }
end

local function restore(a)
	for motor, prev in pairs(a.last or {}) do
		if motor.Parent and motor.Transform == prev.set then
			motor.Transform = prev.set * prev.off:Inverse()
		end
	end
end

function PA.Play(char, weaponId)
	if not char then
		return
	end
	local style = STYLE[weaponId] or "scoop"
	local item = Shop.ById[weaponId]
	local cd = item and item.stats and item.stats.cd or 0.45
	local dur = math.min(DUR[style], math.max(0.22, cd * 1.15))
	if active[char] then
		restore(active[char])
	end
	active[char] = { style = style, start = os.clock(), dur = dur, rig = rig(char) }
end

function PA.Init()
	RunService.Stepped:Connect(function()
		local now = os.clock()
		for char, a in pairs(active) do
			local t = (now - a.start) / a.dur
			local r = a.rig
			if t >= 1 or not char.Parent or not r then
				restore(a)
				active[char] = nil
			else
				local rArm, rRoll, lArm, twist, bend, elbow = POSE[a.style](t)
				if r.r15 then
					apply(a, r.rs, CFrame.Angles(rArm, 0, rRoll))
					apply(a, r.ls, CFrame.Angles(lArm, 0, -rRoll * 0.6))
					apply(a, r.elbow, CFrame.Angles(elbow, 0, 0))
					apply(a, r.waist, CFrame.Angles(-bend, twist, 0))
				else
					apply(a, r.rs, CFrame.Angles(-rRoll, 0, rArm))
					apply(a, r.ls, CFrame.Angles(rRoll * 0.6, 0, -lArm))
					apply(a, r.waist, CFrame.Angles(-bend, 0, twist))
				end
			end
		end
	end)
end

return PA
