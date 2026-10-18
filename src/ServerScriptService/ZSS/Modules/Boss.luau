-- Босс «Колосс»: здоровье из Config (Логово Колосса), удары и ударная волна, восстанавливается, если игроки ушли
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes

local Boss = {}
local Data, Fields, Zombies, Loot
local BC = Config.Boss
local C = Color3.fromRGB
local S = 3.4 -- масштаб относительно обычного зомби

local field
local current
local lastPresence = 0

local function part(m, name, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Parent = m
	return p
end

local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	p1.CFrame = p0.CFrame * c0 * c1:Inverse()
end

local function sc(cf)
	return cf - cf.Position + cf.Position * S
end

local function decor(m, base, name, size, offset, color, mat, shape)
	local p = part(m, name, size * S, color, mat)
	if shape then
		p.Shape = shape
	end
	p.Massless = true
	local off = sc(offset)
	p.CFrame = base.CFrame * off
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = off
	w.Parent = p
	return p
end

local function variant(p, name)
	local mv = game:GetService("MaterialService"):FindFirstChild(name, true)
	if mv then
		p.Material = mv.BaseMaterial
		p.MaterialVariant = name
	end
end

local function build()
	local m = Instance.new("Model")
	m.Name = "Boss_Colossus"
	local skin, flesh = C(110, 125, 95), C(150, 40, 40)
	local hrp = part(m, "HumanoidRootPart", Vector3.new(2, 2, 1) * S, C(0, 0, 0))
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3 * S, 0)
	local torso = part(m, "Torso", Vector3.new(2, 2, 1) * S, C(85, 55, 45), Enum.Material.Leather)
	torso.CanCollide = true
	local head = part(m, "Head", Vector3.new(2, 1, 1) * S, skin)
	head.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local la = part(m, "Left Arm", Vector3.new(1, 2, 1) * S, skin)
	local ra = part(m, "Right Arm", Vector3.new(1, 2, 1) * S, skin)
	local ll = part(m, "Left Leg", Vector3.new(1, 2, 1) * S, C(45, 45, 55), Enum.Material.Fabric)
	local rl = part(m, "Right Leg", Vector3.new(1, 2, 1) * S, C(45, 45, 55), Enum.Material.Fabric)
	variant(ll, "ZSSG_W_Kevlar")
	variant(rl, "ZSSG_W_Kevlar")
	variant(la, "ZSSG_ZombieSkin")
	variant(ra, "ZSSG_ZombieSkin")
	variant(head, "ZSSG_ZombieSkin")
	ll.CanCollide, rl.CanCollide = true, true

	local rot = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", hrp, torso, rot, rot)
	motor("Neck", torso, head, sc(CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)), sc(CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)))
	motor("Right Shoulder", torso, ra, sc(CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)), sc(CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)))
	motor("Left Shoulder", torso, la, sc(CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)), sc(CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)))
	motor("Right Hip", torso, rl, sc(CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)), sc(CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)))
	motor("Left Hip", torso, ll, sc(CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)), sc(CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)))

	-- лицо и раны — нарисованные декали
	local ZI = require(RS.ZSS.Icons).zombie
	local function decal(p, tex, face)
		local d = Instance.new("Decal")
		d.Texture = tex
		d.Face = face
		d.Parent = p
	end
	decal(head, ZI.faceBoss, Enum.NormalId.Front)
	decal(torso, ZI.torn1, Enum.NormalId.Front)
	decal(torso, ZI.torn2, Enum.NormalId.Back)
	for _, limb in ipairs({ la, ra }) do
		decal(limb, ZI.skin, Enum.NormalId.Front)
		decal(limb, ZI.skin, Enum.NormalId.Back)
		decal(limb, ZI.skin, Enum.NormalId.Left)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local eye = decor(m, head, "EyeGlow", Vector3.new(0.12, 0.08, 0.04), CFrame.new(sx * 0.27, 0.06, -0.62), C(255, 140, 30), Enum.Material.Neon)
		eye.Transparency = 0.35
	end
	local pl = decor(m, head, "Plate", Vector3.new(0.9, 0.5, 0.9), CFrame.new(0.25, 0.45, 0), C(120, 120, 125), Enum.Material.CorrodedMetal)
	pl.Shape = Enum.PartType.Ball
	-- тело: раны, рёбра, шипы, цепи
	decor(m, torso, "Wound", Vector3.new(0.9, 0.8, 0.06), CFrame.new(0.35, 0.1, -0.52), flesh)
	for k = 0, 2 do
		decor(m, torso, "Rib", Vector3.new(0.7, 0.08, 0.08), CFrame.new(0.35, 0.35 - k * 0.22, -0.56), C(230, 220, 195))
	end
	decor(m, torso, "Belt", Vector3.new(2.05, 0.25, 1.05), CFrame.new(0, -0.85, 0), C(50, 35, 25), Enum.Material.Leather)
	decor(m, torso, "Buckle", Vector3.new(0.35, 0.22, 0.08), CFrame.new(0, -0.85, -0.53), C(180, 160, 90), Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		local pad = decor(m, torso, "Pauldron", Vector3.new(1.3, 0.6, 1.3), CFrame.new(sx * 1.05, 1.0, 0), C(95, 95, 100), Enum.Material.CorrodedMetal)
		pad.Shape = Enum.PartType.Ball
		for k = -1, 1 do
			local sp = decor(m, torso, "Spike", Vector3.new(0.18, 0.6, 0.18), CFrame.new(sx * (1.05 + k * 0.05), 1.45, k * 0.3) * CFrame.Angles(0, 0, -sx * 0.4), C(210, 205, 190), Enum.Material.Metal)
			sp.Shape = Enum.PartType.Cylinder
		end
	end
	for k = 0, 4 do
		local sp = decor(m, torso, "BackSpike", Vector3.new(0.5, 0.15, 0.15), CFrame.new(0, 0.7 - k * 0.35, 0.65) * CFrame.Angles(0, math.rad(90), math.rad(-60)), C(225, 215, 190))
		sp.Shape = Enum.PartType.Cylinder
	end
	decor(m, torso, "Chain", Vector3.new(0.12, 2.6, 0.12), CFrame.new(0, 0, -0.56) * CFrame.Angles(0, 0, 0.75), C(130, 130, 135), Enum.Material.Metal)
	decor(m, la, "Wrap", Vector3.new(1.05, 0.5, 1.05), CFrame.new(0, -0.6, 0), C(190, 180, 150), Enum.Material.Fabric)
	decor(m, ll, "Boot", Vector3.new(1.08, 0.6, 1.2), CFrame.new(0, -0.72, -0.08), C(35, 30, 28), Enum.Material.Leather)
	decor(m, rl, "Boot", Vector3.new(1.08, 0.6, 1.2), CFrame.new(0, -0.72, -0.08), C(35, 30, 28), Enum.Material.Leather)
	-- гигантский тесак в правой руке
	decor(m, ra, "Handle", Vector3.new(0.25, 0.9, 0.25), CFrame.new(0, -1.1, -0.35) * CFrame.Angles(math.rad(90), 0, 0), C(60, 40, 25), Enum.Material.Wood)
	local blade = decor(m, ra, "Cleaver", Vector3.new(0.1, 1.1, 2.2), CFrame.new(0, -1.35, -1.6), C(150, 150, 155), Enum.Material.CorrodedMetal)
	decor(m, ra, "Edge", Vector3.new(0.12, 0.15, 2.2), CFrame.new(0, -1.95, -1.6), C(220, 225, 230), Enum.Material.Metal)
	decor(m, ra, "Blood", Vector3.new(0.13, 0.5, 0.8), CFrame.new(0, -1.6, -2.2), C(110, 10, 10))
	blade.Name = "Cleaver"
	-- аура
	local light = Instance.new("PointLight")
	light.Color = C(255, 70, 30)
	light.Range = 30
	light.Brightness = 2
	light.Parent = torso
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(C(60, 20, 20), C(20, 20, 20))
	pe.Size = NumberSequence.new(4, 9)
	pe.Transparency = NumberSequence.new(0.7, 1)
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Rate = 6
	pe.Speed = NumberRange.new(1, 3)
	pe.Parent = torso

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = field.cfg.zombies.hp
	hum.Health = field.cfg.zombies.hp
	hum.WalkSpeed = field.cfg.zombies.speed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	m.PrimaryPart = hrp
	m:SetAttribute("Boss", true)
	m:SetAttribute("BossName", field.cfg.zombies.name)

	-- большая полоска здоровья
	local bb = Instance.new("BillboardGui")
	bb.Name = "HP"
	bb.Size = UDim2.new(16, 0, 3, 0)
	bb.StudsOffset = Vector3.new(0, 4 * S * 0.75, 0)
	bb.MaxDistance = 220
	bb.Adornee = head
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.fromScale(1, 0.45)
	nameLbl.Font = Enum.Font.Creepster
	nameLbl.TextScaled = true
	nameLbl.Text = "☠ " .. field.cfg.zombies.name:upper() .. " ☠"
	nameLbl.TextColor3 = C(255, 90, 60)
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Parent = bb
	local bg = Instance.new("Frame")
	bg.Position = UDim2.fromScale(0, 0.5)
	bg.Size = UDim2.fromScale(1, 0.45)
	bg.BackgroundColor3 = C(20, 10, 10)
	bg.BorderSizePixel = 0
	bg.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = C(0, 0, 0)
	st.Parent = bg
	Instance.new("UICorner").Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C(220, 30, 30)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner").Parent = fill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(C(255, 120, 60), C(150, 0, 20))
	grad.Rotation = 90
	grad.Parent = fill
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.GothamBlack
	hpText.TextScaled = true
	hpText.TextColor3 = C(255, 255, 255)
	hpText.TextStrokeTransparency = 0
	hpText.ZIndex = 3
	hpText.Parent = bg
	bb.Parent = m
	return m, hum, hrp, fill
end

local function fmt(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end

local function updateBar(z)
	local ratio = math.clamp(z.hum.Health / z.hum.MaxHealth, 0, 1)
	z.bar.Size = UDim2.fromScale(ratio, 1)
	z.bar.Parent.HPText.Text = fmt(math.max(0, math.ceil(z.hum.Health))) .. " / " .. fmt(z.hum.MaxHealth)
end

function Boss.Spawn()
	local m, hum, hrp, bar = build()
	require(script.Parent.Halloween).DecorateBoss(m)
	local c = field.cfg.center
	m:PivotTo(CFrame.new(c + Vector3.new(0, 3 * S + 1, 0)) * CFrame.Angles(0, math.pi, 0))
	m.Parent = workspace:FindFirstChild("Zombies") or workspace
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	local z = {
		model = m,
		hum = hum,
		root = hrp,
		bar = bar,
		field = field,
		cfg = field.cfg.zombies,
		lastAttack = 0,
		lastSlam = os.clock(),
		slowUntil = 0,
		nextWander = 0,
		dead = false,
		rewardMult = 1,
		boss = true,
		contrib = {},
	}
	current = z
	Zombies.Active[m] = z
	updateBar(z)
	hum.HealthChanged:Connect(function()
		updateBar(z)
	end)
	hum.Died:Connect(function()
		Zombies.OnDeath(z)
	end)
	workspace:SetAttribute("ZSS_BossRespawn", 0)
	lastPresence = os.clock()
	return z
end

local function playersInArena(radius)
	local list = {}
	local c = field.cfg.center
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = Vector3.new(hrp.Position.X - c.X, 0, hrp.Position.Z - c.Z).Magnitude
			if d <= radius and hrp.Position.Y < c.Y + 40 then
				table.insert(list, { player = plr, hrp = hrp, hum = hum })
			end
		end
	end
	return list
end

local function hurt(t, dmg)
	local mult = t.hrp.Parent:GetAttribute("ZSS_DmgMult") or 1
	t.hum:TakeDamage(dmg * mult)
	Remotes.FX:FireAllClients("hit", { pos = t.hrp.Position })
end

local function think(now)
	local z = current
	if not z or z.dead or not z.root.Parent then
		return
	end
	local c = field.cfg.center
	-- если возле логова никого нет 3 минуты — полное восстановление
	if #playersInArena(field.half + 30) > 0 then
		lastPresence = now
	elseif now - lastPresence >= BC.resetTime and z.hum.Health < z.hum.MaxHealth then
		z.hum.Health = z.hum.MaxHealth
		z.contrib = {}
		z.model:SetAttribute("Healed", (z.model:GetAttribute("Healed") or 0) + 1)
		z.hum:MoveTo(c)
	end
	z.model:SetAttribute("ResetIn", math.max(0, math.ceil(BC.resetTime - (now - lastPresence))))

	local targets = playersInArena(field.half + 2)
	local night = Loot.IsNight() and Config.DayNight.damageMult or 1
	local target, tdist = nil, math.huge
	for _, t in ipairs(targets) do
		local d = (t.hrp.Position - z.root.Position).Magnitude
		if d < tdist then
			target, tdist = t, d
		end
	end
	local slow = now < z.slowUntil
	z.hum.WalkSpeed = z.cfg.speed * (slow and 0.6 or 1)
	if not target then
		if (z.root.Position - c).Magnitude > 6 then
			z.hum:MoveTo(c)
		end
		return
	end
	z.hum:MoveTo(target.hrp.Position)
	-- ударная волна по всем рядом
	if now - z.lastSlam > BC.slamCd and tdist < BC.slamRadius + 4 then
		z.lastSlam = now
		z.lastAttack = now
		z.model:SetAttribute("Slam", (z.model:GetAttribute("Slam") or 0) + 1)
		task.delay(0.85, function()
			if z.dead then
				return
			end
			local pos = z.root.Position + z.root.CFrame.LookVector * 5
			Remotes.FX:FireAllClients("bossslam", { pos = Vector3.new(pos.X, c.Y + 0.5, pos.Z), radius = BC.slamRadius })
			for _, t in ipairs(playersInArena(field.half + 2)) do
				if (t.hrp.Position - pos).Magnitude <= BC.slamRadius then
					hurt(t, BC.slamDamage * night)
					t.hrp.AssemblyLinearVelocity += (t.hrp.Position - pos).Unit * 60 + Vector3.new(0, 45, 0)
				end
			end
		end)
	elseif now - z.lastAttack > BC.meleeCd and tdist < 12 then
		z.lastAttack = now
		z.model:SetAttribute("Atk", (z.model:GetAttribute("Atk") or 0) + 1)
		local dmg = z.cfg.damage * night
		task.delay(0.45, function()
			if z.dead or not target.hrp.Parent then
				return
			end
			if (target.hrp.Position - z.root.Position).Magnitude <= 13 then
				hurt(target, dmg)
			end
		end)
	end
end

-- награды всем, кто внёс вклад
local function onDeath(z)
	current = nil
	local total = 0
	for _, v in pairs(z.contrib) do
		total += v
	end
	local night = Loot.IsNight() and Config.DayNight.rewardMult or 1
	local pos = z.root.Position
	Remotes.FX:FireAllClients("bossdeath", { pos = pos })
	Remotes.Notify:FireAllClients("☠ The Colossus has fallen! Rewards given to everyone in the fight", "boss")
	for plr, dmg in pairs(z.contrib) do
		local share = total > 0 and dmg / total or 0
		if plr.Parent and share >= BC.minShare then
			local p = Data.Get(plr)
			if p then
				p.bossKills = (p.bossKills or 0) + 1
				require(script.Parent.Quests).Event(plr, "bossKill")
				local k = 0.4 + 0.6 * math.min(1, share * 2)
				local gems = math.floor(math.random(BC.gems[1], BC.gems[2]) * k * night)
				local bats = math.floor(BC.batteries * k * night)
				Data.AddGems(plr, gems)
				Data.AddBatteries(plr, bats)
				local got = Loot.Many(plr, math.random(BC.items[1], BC.items[2]), 2.5, pos)
				Loot.ManyConsum(plr, math.random(2, 4), pos)
				local names = {}
				for _, it in ipairs(got) do
					table.insert(names, it.name)
				end
				local pumpkins = require(script.Parent.Halloween).OnBossKill(plr, k * night, pos)
				Remotes.FX:FireClient(plr, "bossreward", { gems = gems, batteries = bats, items = names, share = share, pumpkins = pumpkins })
			end
		end
	end
	local bb = z.model:FindFirstChild("HP")
	if bb then
		bb:Destroy()
	end
	for _, d in ipairs(z.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, TweenInfo.new(3), { Transparency = 1 }):Play()
		end
	end
	task.delay(3.2, function()
		z.model:Destroy()
	end)
	workspace:SetAttribute("ZSS_BossRespawn", workspace:GetServerTimeNow() + BC.respawnTime)
	task.delay(BC.respawnTime, function()
		Boss.Spawn()
		Remotes.Notify:FireAllClients("☠ The Colossus has awakened in its lair again!", "boss")
	end)
end

function Boss.Init(dataModule, fieldsModule, zombiesModule)
	Data, Fields, Zombies = dataModule, fieldsModule, zombiesModule
	Loot = require(script.Parent.Loot)
	for _, f in ipairs(Fields.List) do
		if f.cfg.boss then
			field = f
		end
	end
	if not field then
		return
	end
	Zombies.OnBossDeath = onDeath
	Boss.Spawn()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(think, os.clock())
			if not ok then
				warn("[ZSS] Boss AI:", err)
			end
		end
	end)
end

return Boss
