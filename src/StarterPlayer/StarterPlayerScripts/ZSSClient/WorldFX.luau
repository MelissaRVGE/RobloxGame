-- Анимации окружения: вращение, радуга, мерцание света, голограмма дронов в гача-зоне
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Builder = require(Shared.DroneBuilder)
local U = require(script.Parent.U)

local W = {}
-- управление из анимации гачи: ускорение вращения колец машины и скрытие витринного дрона
W.SpinBoost = 1
W.ShowcaseHidden = false

local function setupShowcase(anchor)
	local holder = Instance.new("Folder")
	holder.Name = "ZSS_Showcase"
	holder.Parent = workspace
	local current, label, highlight
	local order = {}
	for _, d in ipairs(Config.Drones) do
		table.insert(order, d)
	end
	table.sort(order, function(a, b)
		return Config.Rarities[a.rarity].order > Config.Rarities[b.rarity].order
	end)
	local idx = 0
	local bb = U.new("BillboardGui", {
		Size = UDim2.new(8, 0, 1.75, 0),
		StudsOffset = Vector3.new(0, 6.5, 0),
		Adornee = anchor,
		MaxDistance = 120,
		Parent = anchor,
	})
	local nameLbl = U.new("TextLabel", {
		Size = UDim2.new(1, 0, 0.6, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = bb,
	}, { U.textStroke(Color3.new(0, 0, 0), 2) })
	local rarLbl = U.new("TextLabel", {
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.new(1, 0, 0.4, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Parent = bb,
	}, { U.textStroke(Color3.new(0, 0, 0), 2) })
	label = { name = nameLbl, rarity = rarLbl }

	local popStart
	local function nextDrone()
		idx = idx % #order + 1
		local def = order[idx]
		if current then
			-- прошлый дрон плавно уменьшается и исчезает
			local old = current
			task.spawn(function()
				local t0 = os.clock()
				while old.Parent do
					local a = math.clamp((os.clock() - t0) / 0.25, 0, 1)
					old:ScaleTo(math.max(0.02, 1 - TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)))
					if a >= 1 then
						break
					end
					RunService.Heartbeat:Wait()
				end
				old:Destroy()
			end)
		end
		current = Builder.Build(def, 2.2)
		current:ScaleTo(0.02)
		popStart = os.clock()
		current.Parent = holder
		highlight = Instance.new("Highlight")
		highlight.FillColor = Config.Rarities[def.rarity].color
		highlight.OutlineColor = Config.Rarities[def.rarity].color
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = current
		TweenService:Create(highlight, TweenInfo.new(0.6), { FillTransparency = 0.85 }):Play()
		current:SetAttribute("Def", def.id)
		-- подпись меняется через короткое затухание
		local fadeT = label.name.Text ~= "" and 0.2 or 0
		for _, l in pairs(label) do
			TweenService:Create(l, TweenInfo.new(fadeT), { TextTransparency = 1 }):Play()
		end
		task.delay(fadeT, function()
			label.name.Text = def.rarity == "Secret" and "???" or def.name
			label.rarity.Text = Config.Rarities[def.rarity].label .. " • " .. Config.ChanceText(def.rarity)
			label.rarity.TextColor3 = Config.Rarities[def.rarity].color
			for _, l in pairs(label) do
				TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
			end
		end)
	end
	nextDrone()
	local switchAt = os.clock() + 3.5
	return function(t)
		local want = (not W.ShowcaseHidden) and workspace or nil
		if holder.Parent ~= want then
			holder.Parent = want
		end
		if t > switchAt then
			switchAt = t + 3.5
			nextDrone()
		end
		if current and popStart then
			-- новый дрон появляется с пружинкой
			local a = math.clamp((os.clock() - popStart) / 0.45, 0, 1)
			current:ScaleTo(math.max(0.02, TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)))
			if a >= 1 then
				popStart = nil
			end
		end
		if current then
			current:PivotTo(anchor.CFrame * CFrame.new(0, math.sin(t * 1.5) * 0.4, 0) * CFrame.Angles(0, t * 0.9, 0))
			if current:GetAttribute("Rainbow") then
				local c = Config.Rainbow(t)
				highlight.OutlineColor = c
				label.rarity.TextColor3 = c
			end
		end
	end
end

function W.Init()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	local spinners, rainbows, flickers, bobbers = {}, {}, {}, {}
	-- анимации магазина: мигание, покачивание, маятник, конвейер
	local blinks, wobblers, swings, belts, waves = {}, {}, {}, {}, {}
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("ZSS_Wave") then
			table.insert(waves, { p = d, base = d.CFrame, k = d:GetAttribute("ZSS_Wave") })
		end
		if d:IsA("BasePart") and d:GetAttribute("ZSS_Blink") then
			table.insert(blinks, { p = d, rate = d:GetAttribute("ZSS_Blink"), col = d.Color, ph = math.random() * 6 })
		elseif d:IsA("Model") and d:GetAttribute("ZSS_Wobble") then
			table.insert(wobblers, { m = d, base = d:GetPivot(), amp = math.rad(d:GetAttribute("ZSS_Wobble")), ph = math.random() * 6 })
		elseif d:IsA("Model") and d:GetAttribute("ZSS_Swing") then
			table.insert(swings, { m = d, base = d:GetPivot(), amp = d:GetAttribute("ZSS_Swing") })
		elseif d:IsA("Model") and d:GetAttribute("BeltX0") then
			local list = {}
			for _, c in ipairs(d:GetChildren()) do
				if c:IsA("BasePart") and c:GetAttribute("ZSS_Conveyor") then
					local fill
					for _, f in ipairs(d:GetChildren()) do
						if f.Name == "CrateFill" and math.abs(f.Position.X - c.Position.X) < 0.2 then
							fill = f
						end
					end
					table.insert(list, { p = c, fill = fill, rel = fill and c.CFrame:ToObjectSpace(fill.CFrame), x = c.Position.X })
				end
			end
			table.insert(belts, { x0 = d:GetAttribute("BeltX0"), x1 = d:GetAttribute("BeltX1"), list = list })
		end
	end
	local function shopTick(t, dt)
		-- флаг на ветру: волна бежит от древка к краю
		for _, w in ipairs(waves) do
			local amp = 0.08 + w.k * 0.06
			w.p.CFrame = w.base * CFrame.new(0, math.sin(t * 2 - w.k * 0.5) * 0.05, math.sin(t * 3.2 - w.k * 0.7) * amp) * CFrame.Angles(0, math.cos(t * 3.2 - w.k * 0.7) * 0.25, 0)
		end
		for _, b in ipairs(blinks) do
			local on = math.sin(t / b.rate * 3 + b.ph) > -0.3 or math.random() < 0.02
			b.p.Color = on and b.col or b.col:Lerp(Color3.new(0, 0, 0), 0.75)
		end
		for _, w in ipairs(wobblers) do
			w.m:PivotTo(w.base * CFrame.Angles(math.sin(t * 2.2 + w.ph) * w.amp, 0, math.sin(t * 1.7 + w.ph) * w.amp * 0.7))
		end
		for _, s in ipairs(swings) do
			s.m:PivotTo(s.base * CFrame.Angles(math.sin(t * 1.3) * s.amp, 0, math.sin(t * 0.9) * s.amp * 0.6))
		end
		for _, b in ipairs(belts) do
			local len = b.x1 - b.x0
			for _, c in ipairs(b.list) do
				c.x = c.x + dt * 2.2
				if c.x > b.x1 then
					c.x -= len
				end
				local p = c.p.Position
				c.p.CFrame = CFrame.new(c.x, p.Y, p.Z)
				if c.fill then
					c.fill.CFrame = c.p.CFrame * c.rel
				end
			end
		end
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:GetAttribute("ZSS_Spin") and (d:IsA("Model") or d:IsA("BasePart")) then
			local gz = map:FindFirstChild("GachaZone")
			table.insert(spinners, { inst = d, base = d:GetPivot(), speed = d:GetAttribute("ZSS_Spin"), bob = d:GetAttribute("ZSS_Bob"), ang = 0, gacha = gz and d:IsDescendantOf(gz) })
		end
		if d:GetAttribute("ZSS_Rainbow") and d:IsA("BasePart") then
			table.insert(rainbows, d)
		end
		if d:GetAttribute("ZSS_Flicker") and d:IsA("Light") then
			table.insert(flickers, { light = d, base = d.Brightness })
		end
	end
	-- гнёзда станций зарядки создаются сервером динамически: заряжающиеся мигают, шкала на гребне переливается
	local hives = map:FindFirstChild("Base") and map.Base:FindFirstChild("Hives")
	local slotList, meters = {}, {}
	local lastScan, lastCells = 0, 0
	local function scanSlots()
		slotList, meters = {}, {}
		if not hives then
			return
		end
		for _, h in ipairs(hives:GetChildren()) do
			local f = h:FindFirstChild("Slots")
			if f then
				for _, s in ipairs(f:GetChildren()) do
					table.insert(slotList, { model = s, ring = s:FindFirstChild("Ring"), led = s:FindFirstChild("Led"), phase = math.random() * 6 })
				end
			end
			local mf = h:FindFirstChild("MeterFill")
			if mf then
				table.insert(meters, { part = mf, base = mf.CFrame, w = mf.Size.X, hive = h })
			end
		end
	end
	-- Лаборатория дронов: бегущие огни, мониторы, прожекторы, разряды пилонов
	local runway, bars, lamps, teslas = {}, {}, {}, {}
	local gz = map:FindFirstChild("GachaZone")
	local labCenter = gz and gz:FindFirstChild("HoloAnchor", true)
	if gz then
		for _, d in ipairs(gz:GetDescendants()) do
			if d:GetAttribute("ZSS_Runway") then
				table.insert(runway, { p = d, k = d:GetAttribute("ZSS_Runway"), base = d.Color })
			elseif d:GetAttribute("ZSS_Bar") then
				table.insert(bars, { f = d, k = d:GetAttribute("ZSS_Bar"), h = d.Size.Y.Scale })
			elseif d:GetAttribute("ZSS_Sweep") and d:IsA("BasePart") then
				local group = {}
				for _, s in ipairs(d.Parent:GetChildren()) do
					if s:IsA("BasePart") and (s.Name == "Lens" or s.Name == "Cone") and (s.Position - d.Position).Magnitude < 16 then
						local rel = d.CFrame:ToObjectSpace(s.CFrame)
						if rel.Position.Z < 0.5 and math.abs(rel.Position.X) < 0.5 then
							table.insert(group, { p = s, rel = rel })
						end
					end
				end
				table.insert(lamps, { p = d, base = d.CFrame, k = d:GetAttribute("ZSS_Sweep"), group = group })
			elseif d.Name == "Tesla" and d:IsA("BasePart") then
				table.insert(teslas, d)
			end
		end
	end
	local arcFolder = Instance.new("Folder")
	arcFolder.Name = "ZSS_LabArcs"
	arcFolder.Parent = workspace
	local function arc(a, b, color)
		local prev = a
		local dir = b - a
		local side = dir:Cross(Vector3.new(0, 1, 0))
		side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
		local up = dir:Cross(side).Unit
		for i = 1, 6 do
			local p = a + dir * (i / 6)
			if i < 6 then
				p += side * (math.random() - 0.5) * 1.8 + up * (math.random() - 0.5) * 1.8
			end
			local s = Instance.new("Part")
			s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
			s.Material = Enum.Material.Neon
			s.Color = color
			s.Size = Vector3.new(0.12, 0.12, (p - prev).Magnitude)
			s.CFrame = CFrame.lookAt((prev + p) / 2, p)
			s.Parent = arcFolder
			task.delay(0.08 + math.random() * 0.06, function()
				s:Destroy()
			end)
			prev = p
		end
	end
	local nextArc = 0
	local labT = 0
	local function labTick(t)
		if not labCenter then
			return
		end
		local cam = workspace.CurrentCamera
		if (cam.CFrame.Position - labCenter.Position).Magnitude > 110 then
			return
		end
		if t - labT < 0.04 then
			return
		end
		labT = t
		-- бегущая волна огней к пульту
		for _, r in ipairs(runway) do
			local w = (math.sin(r.k * 1.1 - t * 6) + 1) / 2
			r.p.Transparency = 0.55 - w * 0.55
		end
		-- «живые» графики на мониторах
		for _, b in ipairs(bars) do
			local h = b.h * (0.6 + 0.8 * math.abs(math.sin(t * 1.7 + b.k * 0.9)))
			b.f.Size = UDim2.new(b.f.Size.X.Scale, 0, h, 0)
		 end
		-- прожекторы медленно шарят по машине
		for _, l in ipairs(lamps) do
			local cf = l.base * CFrame.Angles(math.sin(t * 0.7 + l.k) * 0.12, math.cos(t * 0.5 + l.k * 1.3) * 0.18, 0)
			l.p.CFrame = cf
			for _, g in ipairs(l.group) do
				g.p.CFrame = cf * g.rel
			end
		end
		-- случайные разряды между пилонами и камерой машины
		if #teslas > 0 and t > nextArc and W.SpinBoost <= 1 then
			nextArc = t + 0.5 + math.random() * 1.4
			local tp = teslas[math.random(1, #teslas)]
			local ang = math.random() * math.pi * 2
			local tgt = labCenter.Position + Vector3.new(math.cos(ang) * 4.8, (math.random() - 0.5) * 5, math.sin(ang) * 4.8)
			arc(tp.Position, tgt, Color3.fromRGB(150, 235, 255))
			if math.random() < 0.4 then
				local other = teslas[math.random(1, #teslas)]
				if other ~= tp then
					arc(tp.Position, other.Position, Color3.fromRGB(255, 140, 240))
				end
			end
		end
	end

	local showcase
	local anchor = map:FindFirstChild("HoloAnchor", true)
	if anchor then
		showcase = setupShowcase(anchor)
	end
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i, s in ipairs(spinners) do
			local cf = s.base
			if s.bob then
				cf = cf * CFrame.new(0, math.sin(t * 2 + i) * s.bob, 0)
			end
			s.ang += dt * s.speed * (s.gacha and W.SpinBoost or 1)
			s.inst:PivotTo(cf * CFrame.Angles(0, s.ang, 0))
		end
		for i, p in ipairs(rainbows) do
			p.Color = Config.Rainbow(t, i * 0.05)
		end
		for _, f in ipairs(flickers) do
			if math.random() < 0.06 then
				f.light.Brightness = f.base * (math.random() < 0.5 and 0.15 or 1)
			end
		end
		if showcase then
			showcase(t)
		end
		labTick(t)
		shopTick(t, dt)
		if t - lastScan > 1 then
			lastScan = t
			scanSlots()
		end
		if t - lastCells > 0.05 then
			lastCells = t
			for _, c in ipairs(slotList) do
				if c.ring and c.ring.Parent then
					if c.model:GetAttribute("Charging") then
						local k = 0.5 + 0.5 * math.sin(t * 5 + c.phase)
						c.ring.Transparency = 0.45 * k
						if c.led then
							c.led.Size = Vector3.new(0.12 + 0.38 * ((t * 0.6 + c.phase) % 1), 0.08, 0.06)
						end
					elseif c.ring.Transparency ~= 0 and not c.settling then
						-- зарядка закончилась: кольцо и индикатор плавно приходят в покой
						c.settling = true
						local tw = TweenService:Create(c.ring, TweenInfo.new(0.3), { Transparency = 0 })
						tw.Completed:Connect(function()
							c.settling = false
						end)
						tw:Play()
						if c.led then
							TweenService:Create(c.led, TweenInfo.new(0.3), { Size = Vector3.new(0.5, 0.08, 0.06) }):Play()
						end
					end
				end
			end
			for _, mtr in ipairs(meters) do
				local owned = (mtr.hive:GetAttribute("OwnerId") or 0) ~= 0
				local k = owned and (0.55 + 0.45 * math.sin(t * 1.5 + mtr.w)) or 0.08
				mtr.part.Size = Vector3.new(math.max(0.05, mtr.w * k), mtr.part.Size.Y, mtr.part.Size.Z)
				mtr.part.CFrame = mtr.base * CFrame.new(-(mtr.w - mtr.part.Size.X) / 2, 0, 0)
			end
		end
	end)
end

return W
