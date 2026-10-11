-- Процедурная анимация зомби: руки вперёд, шаркающая походка, заморозка
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ZA = {}
local cache = {}

local function ease(t)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- удар зомби (0.6 с): замах → удар → возврат. Возвращает углы рук и наклон корпуса
local function attackPose(t)
	if t < 0.55 then
		local k = ease(t / 0.55)
		return lerp(1.45, 2.9, k), lerp(0, -0.25, k)
	elseif t < 0.72 then
		local k = (t - 0.55) / 0.17
		return lerp(2.9, 0.5, k), lerp(-0.25, 0.45, k)
	else
		local k = ease((t - 0.72) / 0.28)
		return lerp(0.5, 1.45, k), lerp(0.45, 0, k)
	end
end

-- ударная волна босса (1.1 с): обе руки вверх → удар о землю
local function slamPose(t)
	if t < 0.7 then
		local k = ease(t / 0.7)
		return lerp(1.45, 3.15, k), lerp(0, -0.35, k)
	elseif t < 0.8 then
		local k = (t - 0.7) / 0.1
		return lerp(3.15, 0.2, k), lerp(-0.35, 0.7, k)
	elseif t < 0.9 then
		return 0.2, 0.7
	else
		local k = ease((t - 0.9) / 0.1)
		return lerp(0.2, 1.45, k), lerp(0.7, 0, k)
	end
end

local function getRig(m)
	local c = cache[m]
	if c then
		return c
	end
	local torso = m:FindFirstChild("Torso")
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if not torso or not hrp then
		return nil
	end
	c = {
		rj = hrp:FindFirstChild("RootJoint"),
		atk = m:GetAttribute("Atk") or 0,
		slam = m:GetAttribute("Slam") or 0,
		atkStart = -10,
		slamStart = -10,
		atkSide = 1,
		boss = m:GetAttribute("Boss") == true,
		rs = torso:FindFirstChild("Right Shoulder"),
		ls = torso:FindFirstChild("Left Shoulder"),
		rh = torso:FindFirstChild("Right Hip"),
		lh = torso:FindFirstChild("Left Hip"),
		neck = torso:FindFirstChild("Neck"),
		root = hrp,
		hum = m:FindFirstChildOfClass("Humanoid"),
		phase = math.random() * 6,
	}
	if not (c.rs and c.ls and c.rh and c.lh and c.neck) then
		return nil
	end
	cache[m] = c
	return c
end

function ZA.Init()
	local lastClean = 0
	RunService.Stepped:Connect(function()
		local folder = workspace:FindFirstChild("Zombies")
		if not folder then
			return
		end
		local now = os.clock()
		for _, m in ipairs(folder:GetChildren()) do
			local c = getRig(m)
			if c then
				local vel = c.root.AssemblyLinearVelocity
				local sp = Vector3.new(vel.X, 0, vel.Z).Magnitude
				local walk = math.clamp(sp / (c.boss and 8 or 7), 0, 1)
				local frozen = m:GetAttribute("Frozen") == true
				local speed = frozen and 2.5 or (c.boss and 4 or 7)
				local ph = now * speed + c.phase
				local swing = math.sin(ph) * 0.65 * walk
				local dead = c.hum and c.hum.Health <= 0
				local up = dead and 0.2 or 1.45
				local swayR = math.sin(now * 2.1 + c.phase) * 0.15
				local swayL = math.sin(now * 1.7 + c.phase + 1) * 0.15

				-- новая атака / ударная волна (счётчики с сервера)
				local a = m:GetAttribute("Atk") or 0
				if a ~= c.atk then
					c.atk = a
					c.atkStart = now
					c.atkSide = math.random() < 0.5 and 1 or -1
				end
				local s = m:GetAttribute("Slam") or 0
				if s ~= c.slam then
					c.slam = s
					c.slamStart = now
				end
				local rUp, lUp, lean = up + swayR - swing * 0.25, up + swayL + swing * 0.25, 0.12
				local atkDur = c.boss and 0.9 or 0.6
				if not dead and now - c.slamStart < 1.1 then
					local arm, l = slamPose((now - c.slamStart) / 1.1)
					rUp, lUp, lean = arm, arm, l
				elseif not dead and now - c.atkStart < atkDur then
					local arm, l = attackPose((now - c.atkStart) / atkDur)
					if c.boss or c.atkSide > 0 then
						rUp = arm
					end
					if not c.boss and c.atkSide < 0 then
						lUp = arm
					end
					lean = 0.12 + l
				end
				c.rs.Transform = CFrame.Angles(0, 0, rUp)
				c.ls.Transform = CFrame.Angles(0, 0, -lUp)
				c.rh.Transform = CFrame.Angles(0, 0, swing)
				c.lh.Transform = CFrame.Angles(0, 0, swing)
				if c.rj then
					-- сутулость + наклон при ударе
					c.rj.Transform = CFrame.Angles(-lean, 0, math.sin(ph * 0.5) * 0.06 * walk)
				end
				c.neck.Transform = CFrame.Angles(math.sin(now * 1.3 + c.phase) * 0.2, 0, math.sin(now * 0.9 + c.phase) * 0.25)

				local hl = m:FindFirstChild("FrostHL")
				if frozen and not hl then
					hl = Instance.new("Highlight")
					hl.Name = "FrostHL"
					hl.FillColor = Color3.fromRGB(140, 210, 255)
					hl.OutlineColor = Color3.fromRGB(220, 245, 255)
					-- иней плавно нарастает и так же плавно сходит
					hl.FillTransparency = 1
					hl.OutlineTransparency = 1
					hl.Parent = m
					TweenService:Create(hl, TweenInfo.new(0.25), { FillTransparency = 0.45, OutlineTransparency = 0 }):Play()
				elseif not frozen and hl then
					hl.Name = "FrostHL_Out"
					TweenService:Create(hl, TweenInfo.new(0.3), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
					Debris:AddItem(hl, 0.32)
				end
			end
		end
		if now - lastClean > 5 then
			lastClean = now
			for m in pairs(cache) do
				if not m.Parent then
					cache[m] = nil
				end
			end
		end
	end)
end

return ZA
