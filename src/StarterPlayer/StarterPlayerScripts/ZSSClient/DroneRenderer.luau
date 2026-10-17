-- Отрисовка роёв всех игроков на клиенте (плавно, 60 FPS, BulkMoveTo)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Builder = require(Shared.DroneBuilder)
local Remotes = Shared:WaitForChild("Remotes")

local Renderer = {}
local FX
local folder
local swarms = {} -- [userId] = { player, drones = {[key]=vis}, order = {vis} }
local WORLD_SCALE = 0.46

local function makeVis(def, key)
	local model = Builder.Build(def, WORLD_SCALE)
	local core = model.PrimaryPart
	local entries, tints = {}, {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(entries, {
				part = p,
				offset = core.CFrame:ToObjectSpace(p.CFrame),
				spin = p:GetAttribute("Spin"),
				axis = p:GetAttribute("SpinAxis"),
				orbit = p:GetAttribute("Orbit"),
			})
			if p:GetAttribute("Tint") then
				table.insert(tints, p)
			end
		end
	end
	model.Parent = folder
	local stats = Config.RarityStats[def.rarity]
	return {
		key = key,
		def = def,
		model = model,
		entries = entries,
		tints = tints,
		rainbow = model:GetAttribute("Rainbow") == true,
		secret = model:GetAttribute("Secret") == true,
		mode = "idle",
		phase = math.random() * 10,
		speed = stats.speed * 1.35,
		lastShot = 0,
		color = Config.Rarities[def.rarity].color,
	}
end

local function destroyVis(v, burst)
	if burst and FX and v.pos then
		FX.Burst(v.pos, v.color, 10, 0.4, 6)
	end
	v.model:Destroy()
end

local function syncSwarm(plr)
	local raw = plr:GetAttribute("Swarm")
	local list = {}
	if raw then
		local ok, res = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(res) == "table" then
			list = res
		end
	end
	local sw = swarms[plr.UserId]
	if not sw then
		sw = { player = plr, drones = {}, order = {} }
		swarms[plr.UserId] = sw
	end
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local keep, order = {}, {}
	local hive = plr:GetAttribute("ZSS_Hive")
	local frame = hive and Config.HiveFrames[hive]
	local now = os.clock()
	for idx, e in ipairs(list) do
		keep[e.k] = true
		local v = sw.drones[e.k]
		if v and v.def.id ~= e.id then
			destroyVis(v)
			v = nil
		end
		if not v then
			local def = e.id == "mini" and Config.MiniDrone or Config.DroneById[e.id]
			if def then
				v = makeVis(def, e.k)
				if e.l and frame then
					-- вылет из улья: дрон стоит в своей соте и по очереди срывается к игроку
					local cell = (idx - 1) % Config.Hive.maxCells + 1
					local home = (frame * Config.CellOffset(cell, 0.9)).Position
					v.pos = home
					v.home = home
					v.homeLook = home + frame.LookVector * 10
					v.launchAt = now + 0.35 + (idx - 1) * 0.12
				elseif hrp then
					v.pos = hrp.Position + Vector3.new(math.random(-3, 3), 3, math.random(-3, 3))
					if FX then
						FX.Burst(v.pos, v.color, 12, 0.5, 6)
					end
				end
				sw.drones[e.k] = v
			end
		end
		if v then
			table.insert(order, v)
		end
	end
	for k, v in pairs(sw.drones) do
		if not keep[k] then
			destroyVis(v, true)
			sw.drones[k] = nil
		end
	end
	sw.order = order
end

local function removePlayer(plr)
	local sw = swarms[plr.UserId]
	if sw then
		for _, v in pairs(sw.drones) do
			destroyVis(v)
		end
		swarms[plr.UserId] = nil
	end
end

function Renderer.GetPos(userId, key)
	local sw = swarms[userId]
	local v = sw and sw.drones[key]
	return v and v.pos
end

local UP = Vector3.new(0, 1, 0)

local function updateVis(v, i, n, hrp, t, dt)
	local owner = hrp.Position
	if not v.pos then
		v.pos = owner + Vector3.new(0, 4, 0)
	end
	local mode = v.mode
	local desired
	if v.launchAt then
		if t < v.launchAt then
			-- ждёт в соте: лёгкое покачивание, лицом наружу
			v.pos = v.home + Vector3.new(0, math.sin(t * 3 + v.phase) * 0.05, 0)
			v.cf = CFrame.lookAt(v.pos, v.homeLook, UP)
			v.look = (v.homeLook - v.pos).Unit
			return
		end
		if not v.launched then
			v.launched = true
			v.flyFrom = v.pos
			v.flyT0 = t
			if FX then
				FX.Burst(v.pos, v.color, 8, 0.35, 5)
			end
		end
		-- плавный вылет по дуге: ease-in-out к точке у игрока
		local k = math.clamp((t - v.flyT0) / 1.4, 0, 1)
		if k >= 1 then
			v.launchAt = nil
		else
			local e = k < 0.5 and 4 * k * k * k or 1 - (-2 * k + 2) ^ 3 / 2
			local goal = owner + Vector3.new(math.cos(v.phase) * 3.6, 2.6, math.sin(v.phase) * 3.6)
			local mid = v.flyFrom:Lerp(goal, 0.5) + Vector3.new(0, 6, 0)
			local a = v.flyFrom:Lerp(mid, e)
			local b = mid:Lerp(goal, e)
			local prevPos = v.pos
			v.pos = a:Lerp(b, e)
			local dir = v.pos - prevPos
			local flat = Vector3.new(dir.X, 0, dir.Z)
			local look = flat.Magnitude > 1e-3 and flat.Unit or (v.look or Vector3.new(0, 0, -1))
			if v.look then
				local bl = v.look:Lerp(look, 1 - math.exp(-dt * 8))
				if bl.Magnitude > 0.05 then
					look = bl.Unit
				end
			end
			v.look = look
			v.cf = CFrame.lookAt(v.pos, v.pos + look, UP) * CFrame.Angles(-math.clamp(dir.Magnitude / math.max(dt, 1e-3) / 45, 0, 0.45), 0, 0)
			return
		end
	end
	if mode == "travel" and v.target then
		desired = v.target + Vector3.new(0, 1.4, 0)
		if (desired - v.pos).Magnitude < 0.5 then
			v.mode = "gather"
			mode = "gather"
		end
	end
	if mode == "gather" and v.target then
		desired = v.target + Vector3.new(math.sin(t * 9 + v.phase) * 0.3, 1.1 + math.abs(math.sin(t * 7 + v.phase)) * 0.5, math.cos(t * 8 + v.phase) * 0.3)
	elseif mode == "attack" then
		local inst = v.targetInst
		local zr = inst and inst.Parent and inst:FindFirstChild("HumanoidRootPart")
		if zr then
			local zp = zr.Position
			local a = t * 1.6 + v.phase
			desired = zp + Vector3.new(math.cos(a) * 4, 3.5 + math.sin(t * 3 + v.phase) * 0.6, math.sin(a) * 4)
			v.lookAt = zp
			if (v.pos - zp).Magnitude < 9 and t - v.lastShot > 0.9 then
				v.lastShot = t
				FX.Laser(v.pos, zp + Vector3.new(0, 0.5, 0), v.color)
			end
		else
			v.mode = "idle"
		end
	elseif mode == "dock" and v.target then
		-- в соте улья: лицом наружу (на север, к спавну)
		desired = v.target + Vector3.new(0, math.sin(t * 2 + v.phase) * 0.06, 0)
		v.lookAt = v.target + Vector3.new(0, 0, 10)
		if (v.pos - v.target).Magnitude < 1.2 and t - (v.lastSpark or 0) > 1.4 then
			v.lastSpark = t + math.random() * 0.6
			FX.Burst(v.pos + Vector3.new(0, 0, 0.6), Color3.fromRGB(255, 190, 70), 4, 0.25, 3)
		end
	elseif mode == "tired" then
		-- разряжен: плетётся позади игрока низко над землёй
		local cf = hrp.CFrame
		desired = owner - cf.LookVector * (3 + (i % 5) * 1.3) + cf.RightVector * (((i % 3) - 1) * 2.2) + Vector3.new(0, -1.3 + math.abs(math.sin(t * 1.4 + v.phase)) * 0.35, 0)
	end
	if not desired then
		local ring = (i - 1) % 3
		local a = (i / math.max(n, 1)) * math.pi * 2 + t * (0.55 + ring * 0.12)
		local r = 3.6 + ring * 1.7
		desired = owner + Vector3.new(math.cos(a) * r, 2.2 + ring * 0.9 + math.sin(t * 2 + v.phase) * 0.45, math.sin(a) * r)
	end

	local delta = desired - v.pos
	local dist = delta.Magnitude
	local prev = v.pos
	if dist > 150 then
		v.pos = desired
	elseif mode == "travel" then
		if dist > 0.001 then
			v.pos = v.pos + delta.Unit * math.min(dist, v.speed * dt)
		end
	else
		v.pos = v.pos:Lerp(desired, 1 - math.exp(-dt * (mode == "tired" and 1.8 or (mode == "dock" and 2.5 or 5))))
	end

	-- ориентация: лицом по движению / на цель, наклон по скорости
	local vel = (v.pos - prev) / math.max(dt, 1e-3)
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local look
	if v.lookAt then
		look = Vector3.new(v.lookAt.X - v.pos.X, 0, v.lookAt.Z - v.pos.Z)
		v.lookAt = nil
	elseif flat.Magnitude > 1 then
		look = flat
	else
		look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if look.Magnitude < 1e-3 then
		look = v.look or Vector3.new(0, 0, -1)
	end
	look = look.Unit
	if v.look then
		local blended = v.look:Lerp(look, 1 - math.exp(-dt * 8))
		if blended.Magnitude > 0.05 then
			look = blended.Unit
		end
	end
	v.look = look
	local tilt = math.clamp(flat.Magnitude / 45, 0, 0.45)
	if mode == "tired" then
		tilt = 0.45
	end
	v.cf = CFrame.lookAt(v.pos, v.pos + look, UP) * CFrame.Angles(-tilt, 0, math.sin(t * 2 + v.phase) * (mode == "tired" and 0.25 or 0.06))
end

local function onRender(dt)
	local t = os.clock()
	local parts, cfs = {}, {}
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, sw in pairs(swarms) do
		local char = sw.player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local n = #sw.order
			for i, v in ipairs(sw.order) do
				updateVis(v, i, n, hrp, t, dt)
				if (v.pos - camPos).Magnitude < 400 then
					local base = v.cf
					for _, e in ipairs(v.entries) do
						local cf
						if e.orbit then
							cf = base * CFrame.Angles(0, t * e.orbit, 0) * e.offset
						else
							cf = base * e.offset
							if e.spin then
								local a = t * e.spin
								if e.axis == "X" then
									cf = cf * CFrame.Angles(a, 0, 0)
								else
									cf = cf * CFrame.Angles(0, a, 0)
								end
							end
						end
						parts[#parts + 1] = e.part
						cfs[#cfs + 1] = cf
					end
					if v.rainbow then
						for k, p in ipairs(v.tints) do
							p.Color = Config.Rainbow(t, k * 0.06)
						end
					elseif v.secret then
						local pulse = 0.55 + 0.45 * math.abs(math.sin(t * 3 + v.phase))
						for _, p in ipairs(v.tints) do
							p.Color = Color3.new(pulse, 0.05 * pulse, 0.06 * pulse)
						end
					end
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Renderer.Init(fx)
	FX = fx
	folder = Instance.new("Folder")
	folder.Name = "ZSS_Drones"
	folder.Parent = workspace

	local function watch(plr)
		plr:GetAttributeChangedSignal("Swarm"):Connect(function()
			syncSwarm(plr)
		end)
		syncSwarm(plr)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(removePlayer)

	Remotes.DroneState.OnClientEvent:Connect(function(userId, key, mode, target)
		local sw = swarms[userId]
		local v = sw and sw.drones[key]
		if not v then
			return
		end
		v.mode = mode
		if typeof(target) == "Vector3" then
			v.target = target
			v.targetInst = nil
		elseif typeof(target) == "Instance" then
			v.targetInst = target
			v.target = nil
		else
			v.target = nil
			v.targetInst = nil
		end
	end)

	RunService.RenderStepped:Connect(onRender)

	-- дроны, чей меш у этого игрока не загрузился, пересобираем процедурно (иначе виден только их свет)
	task.spawn(function()
		local failed = Builder.CheckMeshes()
		if #failed == 0 then
			return
		end
		warn("[ZSS] Меши дронов не загрузились, рисуем процедурно:", table.concat(failed, ", "))
		local set = {}
		for _, id in ipairs(failed) do
			set[id] = true
		end
		for _, sw in pairs(swarms) do
			for i, v in ipairs(sw.order) do
				if set[v.def.id] then
					local nv = makeVis(v.def, v.key)
					nv.pos, nv.look, nv.mode, nv.target, nv.targetInst = v.pos, v.look, v.mode, v.target, v.targetInst
					nv.home, nv.homeLook, nv.launchAt, nv.launched, nv.flyFrom, nv.flyT0 = v.home, v.homeLook, v.launchAt, v.launched, v.flyFrom, v.flyT0
					v.model:Destroy()
					sw.drones[v.key] = nv
					sw.order[i] = nv
				end
			end
		end
	end)
end

return Renderer
