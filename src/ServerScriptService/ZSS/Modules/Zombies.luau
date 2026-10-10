-- Зомби на полях: спавн, ИИ, урон, награда
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(RS.ZSS.Config)
local ZIcons = require(RS.ZSS.Icons).zombie
local Remotes = RS.ZSS.Remotes

local Zombies = {}
Zombies.Active = {}

local Data, Fields, Loot
local folder
local C = Color3.fromRGB

local LOOKS = {
	wasteland = { skin = C(120, 150, 95), shirt = C(190, 180, 160), pants = C(55, 60, 70), shirtVariant = "ZSS_Camo" },
	deadcity = { skin = C(140, 150, 130), shirt = C(40, 60, 110), pants = C(170, 170, 180), pantsVariant = "ZSS_CamoUrban" },
	radzone = { skin = C(90, 200, 90), shirt = C(200, 210, 170), pants = C(45, 50, 35), glow = true, shirtVariant = "ZSS_CamoUrban" },
	swamp = { skin = C(95, 120, 110), shirt = C(160, 150, 130), pants = C(120, 130, 150), shirtVariant = "ZSS_I_Burlap", pantsVariant = "ZSS_I_Denim" },
	military = { skin = C(130, 140, 115), shirt = C(210, 215, 190), pants = C(210, 215, 190), shirtVariant = "ZSS_D_Camo", pantsVariant = "ZSS_D_Camo", helmet = true },
}

local function U_darken(c)
	return Color3.new(c.R * 0.6, c.G * 0.6, c.B * 0.6)
end

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
	return m
end

local function weldDecor(m, base, name, size, offset, color, mat)
	local p = part(m, name, size, color, mat)
	p.Massless = true
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	return p
end

local function build(field)
	local cfg = field.cfg.zombies
	local look = LOOKS[field.cfg.id] or LOOKS.wasteland
	local m = Instance.new("Model")
	m.Name = cfg.name

	local hrp = part(m, "HumanoidRootPart", Vector3.new(2, 2, 1), C(0, 0, 0))
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3, 0)
	local torso = part(m, "Torso", Vector3.new(2, 2, 1), look.shirt, Enum.Material.Fabric)
	torso.CanCollide = true
	local head = part(m, "Head", Vector3.new(2, 1, 1), look.skin)
	head.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local la = part(m, "Left Arm", Vector3.new(1, 2, 1), look.skin)
	local ra = part(m, "Right Arm", Vector3.new(1, 2, 1), look.skin)
	local ll = part(m, "Left Leg", Vector3.new(1, 2, 1), look.pants, Enum.Material.Fabric)
	local rl = part(m, "Right Leg", Vector3.new(1, 2, 1), look.pants, Enum.Material.Fabric)
	local MS = game:GetService("MaterialService")
	local function applyV(part, name)
		local mv = MS:FindFirstChild(name, true)
		if mv then
			part.Material = mv.BaseMaterial
			part.MaterialVariant = name
		end
	end
	if look.shirtVariant then
		applyV(torso, look.shirtVariant)
	end
	if look.pantsVariant then
		applyV(ll, look.pantsVariant)
		applyV(rl, look.pantsVariant)
	else
		applyV(ll, "ZSSG_W_Kevlar")
		applyV(rl, "ZSSG_W_Kevlar")
	end
	-- гниющая кожа (сгенерированная PBR-текстура)
	applyV(la, "ZSSG_ZombieSkin")
	applyV(ra, "ZSSG_ZombieSkin")
	applyV(head, "ZSSG_ZombieSkin")

	local rot = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", hrp, torso, rot, rot)
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	-- детали: нарисованное лицо, рваная одежда с кровью, вены и раны на коже
	local function decal(p, tex, face)
		local d = Instance.new("Decal")
		d.Texture = tex
		d.Face = face or Enum.NormalId.Front
		d.Parent = p
		return d
	end
	local face = decal(head, look.glow and ZIcons.faceGreen or ZIcons.faceRed)
	face.Name = "face"
	local torn = math.random() < 0.5 and ZIcons.torn1 or ZIcons.torn2
	decal(torso, torn, Enum.NormalId.Front)
	decal(torso, torn == ZIcons.torn1 and ZIcons.torn2 or ZIcons.torn1, Enum.NormalId.Back)
	for _, limb in ipairs({ la, ra }) do
		decal(limb, ZIcons.skin, Enum.NormalId.Front)
		decal(limb, ZIcons.skin, Enum.NormalId.Back)
	end
	decal(ll, torn, Enum.NormalId.Front)
	-- разнообразие: тени цвета кожи/одежды, причёска, торчащая кость, обрывки рукава
	local tint = 0.85 + math.random() * 0.3
	for _, p in ipairs({ head, la, ra }) do
		p.Color = Color3.new(math.min(1, look.skin.R * tint), math.min(1, look.skin.G * tint), math.min(1, look.skin.B * tint))
	end
	if math.random() < 0.6 then
		weldDecor(m, ra, "Bone", Vector3.new(0.35, 0.3, 0.35), CFrame.new(0, -1.05, 0), C(230, 225, 205))
	end
	if math.random() < 0.55 then
		local sleeve = weldDecor(m, la, "Sleeve", Vector3.new(1.06, 0.7, 1.06), CFrame.new(0, 0.62, 0), look.shirt, Enum.Material.Fabric)
		if look.shirtVariant then
			applyV(sleeve, look.shirtVariant)
		end
	end
	weldDecor(m, torso, "Collar", Vector3.new(1.4, 0.18, 0.9), CFrame.new(0, 0.95, 0), U_darken(look.shirt), Enum.Material.Fabric)
	if look.helmet then
		local hp = weldDecor(m, head, "Helmet", Vector3.new(1.4, 0.6, 1.4), CFrame.new(0, 0.42, 0), C(200, 210, 180))
		hp.Shape = Enum.PartType.Ball
		hp.Size = Vector3.new(1.45, 0.9, 1.45)
		local mv = game:GetService("MaterialService"):FindFirstChild("ZSS_D_Camo", true)
		if mv then
			hp.Material = mv.BaseMaterial
			hp.MaterialVariant = mv.Name
		end
	end
	if look.glow then
		for k = -1, 1 do
			weldDecor(m, torso, "Vein", Vector3.new(0.1, 1.4, 0.05), CFrame.new(k * 0.55, 0, -0.52) * CFrame.Angles(0, 0, k * 0.25), C(120, 255, 60), Enum.Material.Neon)
		end
		local light = Instance.new("PointLight")
		light.Color = C(120, 255, 60)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = torso
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = cfg.hp
	hum.Health = cfg.hp
	hum.WalkSpeed = cfg.speed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	m.PrimaryPart = hrp

	-- полоска здоровья
	local bb = Instance.new("BillboardGui")
	bb.Name = "HP"
	bb.Size = UDim2.new(4.4, 0, 1.3, 0)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80
	bb.Adornee = head
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.fromScale(1, 0.42)
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextScaled = true
	nameLbl.Text = "☠ " .. cfg.name
	nameLbl.TextColor3 = look.glow and C(160, 255, 90) or C(255, 120, 100)
	nameLbl.TextStrokeTransparency = 0.3
	nameLbl.Parent = bb
	local bg = Instance.new("Frame")
	bg.Position = UDim2.fromScale(0, 0.48)
	bg.Size = UDim2.fromScale(1, 0.5)
	local st = Instance.new("UIStroke")
	st.Color = C(0, 0, 0)
	st.Thickness = 1.5
	st.Parent = bg
	bg.BackgroundColor3 = C(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C(220, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg
	local corner2 = corner:Clone()
	corner2.Parent = fill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(C(255, 120, 110), C(170, 20, 20))
	grad.Rotation = 90
	grad.Parent = fill
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.GothamBlack
	hpText.TextScaled = true
	hpText.Text = ("%d / %d"):format(cfg.hp, cfg.hp)
	hpText.TextColor3 = C(255, 255, 255)
	hpText.TextStrokeTransparency = 0
	hpText.ZIndex = 3
	hpText.Parent = bg
	bb.Parent = m

	return m, hum, hrp, fill
end

local function updateBar(z)
	local ratio = math.clamp(z.hum.Health / z.hum.MaxHealth, 0, 1)
	z.bar.Size = UDim2.fromScale(ratio, 1)
	local txt = z.bar.Parent:FindFirstChild("HPText")
	if txt then
		txt.Text = ("%d / %d"):format(math.max(0, math.ceil(z.hum.Health)), z.hum.MaxHealth)
	end
end

function Zombies.Spawn(field)
	local m, hum, hrp, bar = build(field)
	pcall(function()
		m:ScaleTo(0.92 + math.random() * 0.2) -- зомби разного роста
	end)
	local pos = Fields.RandomPoint(field)
	m:PivotTo(CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	m.Parent = folder
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
		slowUntil = 0,
		nextWander = 0,
		lastHit = nil,
		dead = false,
		rewardMult = 1,
	}
	Zombies.Active[m] = z
	field.zcount += 1
	hum.HealthChanged:Connect(function()
		updateBar(z)
	end)
	hum.Died:Connect(function()
		Zombies.OnDeath(z)
	end)
	return z
end

function Zombies.OnDeath(z)
	if z.dead then
		return
	end
	z.dead = true
	Zombies.Active[z.model] = nil
	if z.boss then
		if Zombies.OnBossDeath then
			task.spawn(Zombies.OnBossDeath, z)
		end
		return
	end
	z.field.zcount -= 1
	local killer = z.lastHit
	if killer and killer.Parent then
		local p = Data.Get(killer)
		if p then
			p.kills += 1
			local night = Loot.IsNight() and Config.DayNight.rewardMult or 1
			local res = Config.ResourceByField[z.field.cfg.id]
			local added = Data.AddScrap(killer, z.cfg.reward * z.rewardMult * night, res and res.id)
			Remotes.Popup:FireClient(killer, z.root.Position + Vector3.new(0, 4, 0), "☠ +" .. added, "kill")
			Loot.TryDrop(killer, "zombieKill", z.field.index, z.root.Position)
			require(script.Parent.Drops).ZombieKilled(z.root.Position, z.field)
			require(script.Parent.Quests).Event(killer, "kill", { field = z.field.cfg.id, night = Loot.IsNight() })
		end
	end
	Remotes.FX:FireAllClients("zdeath", { pos = z.root.Position, glow = z.field.cfg.id == "radzone" })
	-- падение и растворение
	local bb = z.model:FindFirstChild("HP")
	if bb then
		bb:Destroy()
	end
	for _, d in ipairs(z.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	local field = z.field
	task.delay(1.3, function()
		z.model:Destroy()
	end)
	-- новые зомби появляются сами в цикле populate(), пока на поле есть игроки
	field.nextSpawn = math.max(field.nextSpawn or 0, os.clock() + math.random(50, 80) / 10)
end

-- убрать зомби без награды (игроки ушли с поля)
local function despawn(z)
	if z.dead or z.boss then
		return
	end
	z.dead = true
	Zombies.Active[z.model] = nil
	z.field.zcount -= 1
	local bb = z.model:FindFirstChild("HP")
	if bb then
		bb:Destroy()
	end
	for _, d in ipairs(z.model:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.9, function()
		z.model:Destroy()
	end)
end

-- зомби живут только на полях, где есть игроки: появляются по одному, когда игрок вошёл,
-- и исчезают через несколько секунд после того, как все ушли
local EMPTY_DESPAWN = 8
local function populate(now)
	local occupied = {}
	local playerPos = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local f = Fields.At(hrp.Position)
			if f then
				occupied[f] = true
				playerPos[f] = playerPos[f] or {}
				table.insert(playerPos[f], hrp.Position)
			end
		end
	end
	for _, f in ipairs(Fields.List) do
		if not f.cfg.boss and f.cfg.zombies and f.cfg.zombies.max > 0 then
			if occupied[f] then
				f.lastOccupied = now
				if f.zcount < f.cfg.zombies.max and now >= (f.nextSpawn or 0) then
					f.nextSpawn = now + 0.9
					local z = Zombies.Spawn(f)
					-- не появляться вплотную к игроку
					for _ = 1, 6 do
						local close = false
						for _, pp in ipairs(playerPos[f]) do
							if (z.root.Position - pp).Magnitude < 12 then
								close = true
							end
						end
						if not close then
							break
						end
						z.model:PivotTo(CFrame.new(Fields.RandomPoint(f) + Vector3.new(0, 1, 0)))
					end
					Remotes.FX:FireAllClients("zspawn", { pos = z.root.Position })
				end
			elseif f.zcount > 0 and now - (f.lastOccupied or 0) > EMPTY_DESPAWN then
				for _, z in ipairs(Zombies.InField(f)) do
					despawn(z)
				end
			end
		end
	end
end

function Zombies.Damage(z, dmg, player)
	if not z or z.dead then
		return
	end
	z.lastHit = player
	-- перк урона за финал цепочки Сержанта
	local pp = player and Data.Get(player)
	if pp and pp.perks and pp.perks.dmg then
		dmg *= 1 + pp.perks.dmg
	end
	-- бафф «Ярость роя»
	if player then
		dmg *= require(game:GetService("ReplicatedStorage").ZSS.BuffsConfig).Mult(player, "rage")
	end
	if z.contrib and player then
		local real = math.min(dmg, z.hum.Health)
		z.contrib[player] = (z.contrib[player] or 0) + real
		if z.boss then
			require(script.Parent.Quests).Event(player, "bossDamage", nil, math.floor(real + 0.5))
		end
	end
	z.hum:TakeDamage(dmg)
	if player then
		Remotes.Popup:FireClient(player, z.root.Position + Vector3.new(math.random(-10, 10) / 10, 3, 0), tostring(math.floor(dmg + 0.5)), "dmg")
		-- бой — активность: рядом может появиться боевой бафф
		if not z.boss then
			require(script.Parent.Drops).OnActivity(player, "combat", z.root.Position, z.field)
		end
	end
end

function Zombies.Kill(z, player, rewardMult)
	if not z or z.dead then
		return
	end
	if z.boss then
		Zombies.Damage(z, 5000, player)
		return
	end
	z.lastHit = player
	z.rewardMult = rewardMult or 1
	z.hum.Health = 0
end

function Zombies.Slow(z, duration)
	z.slowUntil = os.clock() + duration
end

function Zombies.InField(field)
	local out = {}
	for _, z in pairs(Zombies.Active) do
		if z.field == field and not z.dead then
			table.insert(out, z)
		end
	end
	return out
end

function Zombies.InRadius(field, pos, radius)
	local out = {}
	for _, z in pairs(Zombies.Active) do
		if z.field == field and not z.dead and (z.root.Position - pos).Magnitude <= radius then
			table.insert(out, z)
		end
	end
	table.sort(out, function(a, b)
		return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude
	end)
	return out
end

function Zombies.Nearest(field, pos, radius)
	local best, bd = nil, radius
	for _, z in pairs(Zombies.Active) do
		if z.field == field and not z.dead then
			local d = (z.root.Position - pos).Magnitude
			if d <= bd then
				best, bd = z, d
			end
		end
	end
	return best
end

local function think(now)
	local targets = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local f = Fields.At(hrp.Position)
			if f then
				table.insert(targets, { hrp = hrp, hum = hum, field = f })
			end
		end
	end
	local nightMult = Loot.IsNight() and Config.DayNight.damageMult or 1
	for m, z in pairs(Zombies.Active) do
		if not z.dead and not z.boss and z.root.Parent then
			local target, tdist = nil, math.huge
			for _, t in ipairs(targets) do
				if t.field == z.field then
					local d = (t.hrp.Position - z.root.Position).Magnitude
					if d < tdist then
						target, tdist = t, d
					end
				end
			end
			local slow = now < z.slowUntil
			z.hum.WalkSpeed = z.cfg.speed * (slow and 0.4 or 1)
			if slow ~= (m:GetAttribute("Frozen") == true) then
				m:SetAttribute("Frozen", slow)
			end
			if target and tdist < 30 then
				z.hum:MoveTo(target.hrp.Position)
				if tdist < 4.5 and now - z.lastAttack > 1.6 then
					z.lastAttack = now
					-- анимация замаха на клиентах, урон — в момент удара
					m:SetAttribute("Atk", (m:GetAttribute("Atk") or 0) + 1)
					local dmg = z.cfg.damage * nightMult
					task.delay(0.35, function()
						if z.dead or not target.hrp.Parent or target.hum.Health <= 0 then
							return
						end
						if (target.hrp.Position - z.root.Position).Magnitude > 6.5 then
							return
						end
						local mult = target.hrp.Parent:GetAttribute("ZSS_DmgMult") or 1
						target.hum:TakeDamage(dmg * mult)
						Remotes.FX:FireAllClients("hit", { pos = target.hrp.Position })
					end)
				end
			elseif now > z.nextWander then
				z.nextWander = now + math.random(30, 60) / 10
				z.hum:MoveTo(Fields.RandomPoint(z.field))
			end
		end
	end
end

function Zombies.Init(dataModule, fieldsModule)
	Data, Fields = dataModule, fieldsModule
	Loot = require(script.Parent.Loot)
	folder = workspace:FindFirstChild("Zombies") or Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = workspace
	-- на старте поля пустые: зомби появятся, когда на поле зайдёт игрок
	local acc = 0
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local ok, err = pcall(think, now)
			if not ok then
				warn("[ZSS] Zombie AI:", err)
			end
			acc += 1
			if acc % 2 == 0 then
				local ok2, err2 = pcall(populate, now)
				if not ok2 then
					warn("[ZSS] Zombie spawn:", err2)
				end
			end
		end
	end)
end

return Zombies
