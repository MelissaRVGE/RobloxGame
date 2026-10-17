-- Ворота между ярусами (как «5 Bee Zone» в BSS).
-- Вдоль каждого обрыва стоит невидимая стена: если дронов меньше нужного — не пройти наверх.
-- Спускаться можно всегда (стена выключается, если игрок уже выше неё).
-- Здесь же невидимые барьеры вокруг закрытых полей (ниже).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("ZSS"):WaitForChild("Config"))
local player = Players.LocalPlayer

-- ворота Gate_N ведут на ярус N: сколько дронов нужно, берём из конфига (а не из карты)
local REQ_BY_TIER = {}
for _, f in ipairs(Config.Fields) do
	if f.tier then
		REQ_BY_TIER[f.tier] = f.req
	end
end
local function gateReq(gate)
	local n = tonumber(gate.Name:match("^Gate_(%d+)$"))
	return (n and REQ_BY_TIER[n]) or gate:GetAttribute("Req") or 0
end

local TierGates = {}
local State, UI
local RED, GREEN = Color3.fromRGB(255, 60, 50), Color3.fromRGB(80, 255, 110)
local shown = {}

local function update()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("TierGates")
	if not folder then
		return
	end
	local d = State.data
	local have = d and d.equippedTotal or 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, gate in ipairs(folder:GetChildren()) do
		local req = gateReq(gate)
		local open = d ~= nil and have >= req
		local wall = gate:FindFirstChild("Wall")
		if wall then
			local above = hrp and hrp.Position.Z > (wall.Position.Z + 1)
			wall.CanCollide = not open and not above
		end
		if shown[gate] ~= open then
			shown[gate] = open
			local door = gate:FindFirstChild("Door")
			-- ворота открываются плавно: дверь тает, лампы перетекают в зелёный
			local ti = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			if door then
				TweenService:Create(door, ti, { Transparency = open and 1 or 0.35 }):Play()
			end
			for _, p in ipairs(gate:GetChildren()) do
				if p.Name == "Lamp" then
					TweenService:Create(p, ti, { Color = open and GREEN or RED }):Play()
					local l = p:FindFirstChildOfClass("PointLight")
					if l then
						TweenService:Create(l, ti, { Color = open and GREEN or RED }):Play()
					end
				end
			end
			local beam = gate:FindFirstChild("Beam")
			if beam then
				for _, t in ipairs(beam:GetDescendants()) do
					if t:IsA("TextLabel") and t.Name == "Title" then
						t.Text = (open and "✔ " or "🔒 ") .. req .. " DRONES"
					end
				end
			end
		end
	end
end

-- ===== БАРЬЕРЫ ПОЛЕЙ =====
-- Вокруг каждого закрытого поля стоит невидимая стена, своя у каждого игрока (создаётся на клиенте).
-- Пока в рое мало дронов — внутрь не пройти; подойдёшь вплотную — стена мягко проступает красным
-- силовым полем и всплывает подсказка. Если игрок уже внутри (например, снял дронов), стена его не держит.
local BAR_H = 44 -- высота стены над полом поля
local GLOW_DIST = 9 -- с какого расстояния стена начинает проступать
local GLOW_MAX = 0.45 -- самая видимая прозрачность (1 = невидима)
local HINT_DIST = 2.5
local HINT_CD = 4
local barriers = {} -- { cfg, walls = {part}, inside = fn(pos) }
local glow = {} -- [part] = текущая прозрачность
local lastHint = 0

local function wallPart(folder, cf, size)
	local p = Instance.new("Part")
	p.Name = "Barrier"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.ForceField
	p.Color = Color3.fromRGB(255, 70, 55)
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	glow[p] = 1
	return p
end

local function buildBarriers()
	local folder = Instance.new("Folder")
	folder.Name = "ZSS_FieldBarriers"
	for _, f in ipairs(Config.Fields) do
		if (f.req or 0) > 0 then
			local c = f.center
			local y0 = c.Y - 8
			local midY = y0 + (BAR_H + 8) / 2
			local h = BAR_H + 8
			local b = { cfg = f, walls = {} }
			if f.boss then
				-- арена Колосса круглая: стена-многоугольник чуть снаружи башен ворот
				local R, N = 50, 28
				local seg = 2 * R * math.tan(math.pi / N) + 0.4
				for i = 0, N - 1 do
					local a = (i + 0.5) / N * math.pi * 2
					local pos = Vector3.new(c.X + math.cos(a) * R, midY, c.Z + math.sin(a) * R)
					local cf = CFrame.lookAt(pos, Vector3.new(c.X, midY, c.Z))
					table.insert(b.walls, wallPart(folder, cf, Vector3.new(seg, h, 1)))
				end
				b.inside = function(pos, m)
					local dx, dz = pos.X - c.X, pos.Z - c.Z
					return dx * dx + dz * dz < (R + m) ^ 2
				end
			else
				-- квадратное поле: забор стоит на 3 стада дальше плиток; стена сразу за ним, ворота тоже перекрыты
				local half = f.size / 2 + 4
				local len = half * 2 + 1
				table.insert(b.walls, wallPart(folder, CFrame.new(c.X, midY, c.Z - half), Vector3.new(len, h, 1)))
				table.insert(b.walls, wallPart(folder, CFrame.new(c.X, midY, c.Z + half), Vector3.new(len, h, 1)))
				table.insert(b.walls, wallPart(folder, CFrame.new(c.X - half, midY, c.Z), Vector3.new(1, h, len)))
				table.insert(b.walls, wallPart(folder, CFrame.new(c.X + half, midY, c.Z), Vector3.new(1, h, len)))
				b.inside = function(pos, m)
					return math.abs(pos.X - c.X) < half + m and math.abs(pos.Z - c.Z) < half + m
				end
			end
			b.yMin, b.yMax = y0 - 4, y0 + h + 6
			table.insert(barriers, b)
		end
	end
	folder.Parent = workspace
end

-- расстояние от точки до ближайшей точки стены (стена — тонкий брусок)
local function distToPart(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local hs = part.Size / 2
	local q = Vector3.new(math.clamp(lp.X, -hs.X, hs.X), math.clamp(lp.Y, -hs.Y, hs.Y), math.clamp(lp.Z, -hs.Z, hs.Z))
	return (lp - q).Magnitude
end

local function barrierLocked(b)
	local d = State.data
	return d == nil or (d.equippedTotal or 0) < b.cfg.req
end

-- коллизия: закрыто и игрок снаружи → стена твёрдая
local function updateBarriers()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, b in ipairs(barriers) do
		local locked = barrierLocked(b)
		if hrp then
			local p = hrp.Position
			local inBand = p.Y > b.yMin and p.Y < b.yMax
			if locked and inBand and b.inside(p, -0.5) and not b.solid then
				-- уже внутри: выпускаем, а обратно не пустим, когда отойдёт от стены
				b.letOut = true
			elseif b.letOut and not (inBand and b.inside(p, 3)) then
				b.letOut = false
			end
		end
		local solid = locked and not b.letOut
		if b.solid ~= solid then
			b.solid = solid
			for _, w in ipairs(b.walls) do
				w.CanCollide = solid
				w.CanQuery = false
			end
		end
	end
end

-- плавное проявление стены рядом с игроком + подсказка, почему не пройти
local function glowStep(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and hrp.Position
	local k = math.min(1, dt * 7)
	for _, b in ipairs(barriers) do
		for _, w in ipairs(b.walls) do
			local target = 1
			if b.solid and pos then
				local dist = distToPart(w, pos)
				if dist < GLOW_DIST then
					local a = 1 - dist / GLOW_DIST
					a = a * a * (3 - 2 * a) -- smoothstep
					target = 1 - (1 - GLOW_MAX) * a
				end
				if dist < HINT_DIST and os.clock() - lastHint > HINT_CD and UI and UI.Toast then
					lastHint = os.clock()
					local have = State.data and State.data.equippedTotal or 0
					UI.Toast(("🔒 “%s” unlocks when your swarm has %d drones (now %d)"):format(b.cfg.name, b.cfg.req, have), "bad")
				end
			end
			local cur = glow[w]
			if math.abs(cur - target) > 0.002 then
				cur += (target - cur) * k
				glow[w] = cur
				w.Transparency = cur
			elseif cur ~= target then
				glow[w] = target
				w.Transparency = target
			end
		end
	end
end

function TierGates.Init(state, ui)
	State, UI = state, ui
	buildBarriers()
	State.Changed:Connect(function()
		update()
		updateBarriers()
	end)
	task.spawn(function()
		while true do
			pcall(update)
			pcall(updateBarriers)
			task.wait(0.2)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		pcall(glowStep, dt)
	end)
end

return TierGates
