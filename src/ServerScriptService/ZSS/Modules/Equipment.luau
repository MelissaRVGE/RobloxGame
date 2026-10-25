-- Магазин и экипировка: покупка, оружие (Tool), снаряжение на персонаже, бонусы
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local Shop = require(RS.ZSS.ShopConfig)
local DonateCfg = require(RS.ZSS.DonateConfig)
local IB = require(RS.ZSS.ItemBuilder)
local Remotes = RS.ZSS.Remotes

local Equipment = {}
local Data, Drones, Fields, Zombies

function Equipment.Reconcile(p)
	p.consum = p.consum or {}
	p.items = p.items or {}
	p.items[Shop.DefaultWeapon] = true
	p.items[Shop.DefaultTool] = true
	p.items[Shop.DefaultBackpack] = true
	p.gear = p.gear or {}
	for slot, id in pairs(p.gear) do
		local it = Shop.ById[id]
		if not it or not p.items[id] then
			p.gear[slot] = nil
		elseif it.slot ~= slot then
			-- старые профили: предмет переехал в другой слот (Скребок теперь инструмент)
			p.gear[slot] = nil
			p.gear[it.slot] = p.gear[it.slot] or id
		end
	end
	p.gear.weapon = p.gear.weapon or Shop.DefaultWeapon
	p.gear.tool = p.gear.tool or Shop.DefaultTool
	p.gear.backpack = p.gear.backpack or Shop.DefaultBackpack
end

-- слоты, которые нельзя снять (только заменить другим предметом)
local FIXED = { weapon = true, tool = true, backpack = true }

local function bodyParts(char)
	local r15 = char:FindFirstChild("UpperTorso") ~= nil
	return {
		r15 = r15,
		torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
		head = char:FindFirstChild("Head"),
	}
end

local function attach(folder, model, part, offset)
	local root = model.PrimaryPart
	model:PivotTo(part.CFrame * offset)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	local w = Instance.new("Weld")
	w.Part0 = part
	w.Part1 = root
	w.C0 = offset
	w.Parent = root
	model.Parent = folder
end

-- сгенерированные 3D-модели не всегда рисуются внутри модели с Humanoid, поэтому броня и рюкзак
-- лежат в отдельной папке Workspace и приварены к торсу
local worn = {}

local function dropWorn(player)
	for _, m in ipairs(worn[player] or {}) do
		m:Destroy()
	end
	worn[player] = nil
end

local function wornFolder()
	local f = workspace:FindFirstChild("ZSS_WornBackpacks")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ZSS_WornBackpacks"
		f.Parent = workspace
	end
	return f
end

local function setHatsHidden(char, hidden)
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local t = acc.AccessoryType
			if t == Enum.AccessoryType.Hat or t == Enum.AccessoryType.Hair then
				local h = acc:FindFirstChild("Handle")
				if h then
					if h:GetAttribute("ZSS_OrigTr") == nil then
						h:SetAttribute("ZSS_OrigTr", h.Transparency)
					end
					h.Transparency = hidden and 1 or h:GetAttribute("ZSS_OrigTr")
				end
			end
		end
	end
end

-- под закрытым шлемом голова и лицо скрываются (иначе квадратная голова торчит из прорезей)
local function setHidden(part, hidden)
	if part:GetAttribute("ZSS_OrigTr") == nil then
		part:SetAttribute("ZSS_OrigTr", part.Transparency)
	end
	part.Transparency = hidden and 1 or part:GetAttribute("ZSS_OrigTr")
	for _, d in ipairs(part:GetChildren()) do
		if d:IsA("Decal") then
			if d:GetAttribute("ZSS_OrigTr") == nil then
				d:SetAttribute("ZSS_OrigTr", d.Transparency)
			end
			d.Transparency = hidden and 1 or d:GetAttribute("ZSS_OrigTr")
		end
	end
end

local function setHeadHidden(head, hidden)
	if head then
		setHidden(head, hidden)
	end
end

-- детали тела под 3D-снаряжением скрыты, меш сам изображает их: торс под бронёй,
-- кисти, предплечья, стопы и голени R15 под перчатками и ботинками
local COVERED = { "UpperTorso", "LowerTorso", "Torso", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg" }

-- аксессуары на кистях, предплечьях, стопах и голенях (гетры, напульсники, браслеты) скрываются вместе
-- с конечностью: иначе они висят поверх перчатки или ботинка
local LIMB = { LeftHand = true, RightHand = true, LeftLowerArm = true, RightLowerArm = true, LeftFoot = true, RightFoot = true, LeftLowerLeg = true, RightLowerLeg = true }

local function accessoryPart(acc)
	local h = acc:FindFirstChild("Handle")
	if not h or not h:IsA("BasePart") then
		return nil
	end
	for _, w in ipairs(h:GetChildren()) do
		if w:IsA("JointInstance") or w:IsA("WeldConstraint") or w:IsA("RigidConstraint") then
			local a = w:IsA("RigidConstraint") and w.Attachment1 and w.Attachment1.Parent or w.Part1
			local b = w:IsA("RigidConstraint") and w.Attachment0 and w.Attachment0.Parent or w.Part0
			local other = a == h and b or a
			if other and other:IsA("BasePart") then
				return h, other
			end
		end
	end
	return h, nil
end

local function setCoveredHidden(char, hide)
	for _, n in ipairs(COVERED) do
		local part = char:FindFirstChild(n)
		if part and part:IsA("BasePart") then
			setHidden(part, hide[part] == true)
		end
	end
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local h, on = accessoryPart(acc)
			if h and on and LIMB[on.Name] and on.Parent == char then
				setHidden(h, hide[on] == true)
			end
		end
	end
end

function Equipment.MakeTool(item)
	local model = IB.Weapon(item)
	local handle = model.PrimaryPart
	-- модель построена в начале координат: рабочая часть вдоль +Y. Рукоять-цилиндр повёрнута на 90°,
	-- поэтому хват считаем от её реальной ориентации: +Y предмета = +Y хвата (вертикально вверх)
	local handleInItem = handle.CFrame
	local tool = Instance.new("Tool")
	tool.Name = item.name
	if item.slot == "tool" then
		tool.ToolTip = ("⛏ Gather +%d • Radius %s"):format(item.stats.gather or 0, tostring(item.stats.radius))
	else
		tool.ToolTip = ("⚔ Damage %d • Radius %s"):format(item.stats.dmg or 0, tostring(item.stats.radius))
	end
	tool:SetAttribute("ZSSKind", item.slot)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ZSSWeapon", item.id)
	for _, d in ipairs(model:GetChildren()) do
		d.Parent = tool
	end
	model:Destroy()
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			if d ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	tool.Grip = handleInItem:Inverse()
	return tool
end

-- хотбар: ячейка 1 — выбранное оружие, ячейка 2 — выбранный инструмент (по одному)
local function hotbarWeapons(p)
	return { p.gear.weapon or Shop.DefaultWeapon, p.gear.tool or Shop.DefaultTool }
end
Equipment.HotbarWeapons = hotbarWeapons

local function giveWeapon(player, p)
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local want = hotbarWeapons(p)
	local wantSet = {}
	for i, id in ipairs(want) do
		wantSet[id] = i
	end
	local have = {}
	for _, container in ipairs({ backpack, char }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				local id = t:IsA("Tool") and t:GetAttribute("ZSSWeapon")
				if id then
					if wantSet[id] and not have[id] then
						have[id] = t
						t:SetAttribute("HotbarSlot", wantSet[id])
					else
						t:Destroy()
					end
				end
			end
		end
	end
	for i, id in ipairs(want) do
		if not have[id] then
			local tool = Equipment.MakeTool(Shop.ById[id])
			tool:SetAttribute("HotbarSlot", i)
			tool.Parent = backpack
		end
	end
end

-- аватар может догрузиться и сменить масштаб уже после появления (HumanoidDescription, слайдеры роста
-- и ширины): тогда снаряжение пересаживается по новым размерам тела
local function watchBody(player, char)
	if char:GetAttribute("ZSS_FitWatch") then
		return
	end
	char:SetAttribute("ZSS_FitWatch", true)
	local pending = false
	local function changed()
		if pending then
			return
		end
		pending = true
		task.delay(0.5, function()
			pending = false
			if player.Parent and player.Character == char and char.Parent then
				Equipment.Apply(player)
			end
		end)
	end
	for _, n in ipairs({ "UpperTorso", "LowerTorso", "Torso", "Head", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local part = char:FindFirstChild(n)
		if part and part:IsA("BasePart") then
			part:GetPropertyChangedSignal("Size"):Connect(changed)
		end
	end
end

function Equipment.Apply(player)
	local p = Data.Get(player)
	local char = player.Character
	if not p or not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local bp = bodyParts(char)
	if not hum or not bp.torso or not bp.head then
		return
	end

	-- снять старое снаряжение
	local folder = char:FindFirstChild("ZSS_Gear")
	if folder then
		folder:Destroy()
	end
	dropWorn(player)
	folder = Instance.new("Folder")
	folder.Name = "ZSS_Gear"
	folder.Parent = char

	local g = p.gear
	-- размеры берутся с тела самого игрока: снаряжение садится на любой аватар (R15/R6, рост, ширина)
	local fit = IB.Fit(char)
	local torsoBox = bp.torso.Size
	local list = {}
	local hide = {}
	if g.armor and fit.torso then
		local am = IB.Armor(Shop.ById[g.armor], fit.torso.box)
		if g.backpack then
			-- под рюкзаком прячем то, что у брони висит на спине (ранец, баллоны, выхлоп)
			for _, d in ipairs(am:GetChildren()) do
				if d:IsA("BasePart") and d.Name ~= "Wing" and d.Name ~= "Cape" and d.Position.Z > fit.torso.box.Z * 0.7 then
					d:Destroy()
				end
			end
		end
		-- торс под 3D-бронёй скрыт: броня сама изображает его и ничего не торчит сквозь меш
		local vest = am:FindFirstChild("Vest")
		if vest and vest:IsA("MeshPart") then
			for _, part in ipairs(fit.torso.hide) do
				hide[part] = true
			end
		end
		am.Name = "Armor_" .. player.UserId
		attach(wornFolder(), am, fit.torso.part, fit.torso.offset)
		table.insert(list, am)
	end
	if g.backpack and Shop.ById[g.backpack] then
		local bag = IB.Backpack(Shop.ById[g.backpack], torsoBox, g.armor ~= nil)
		bag.Name = "Backpack_" .. player.UserId
		attach(wornFolder(), bag, bp.torso, CFrame.new())
		table.insert(list, bag)
	end
	if #list > 0 then
		worn[player] = list
		local conn
		conn = char.AncestryChanged:Connect(function()
			if not char:IsDescendantOf(workspace) then
				conn:Disconnect()
				if worn[player] == list then
					dropWorn(player)
				end
			end
		end)
	end
	local hideHead = false
	if g.helmet and fit.head then
		local hm = IB.Helmet(Shop.ById[g.helmet], fit.head.size)
		hideHead = hm:GetAttribute("HideHead") == true
		attach(folder, hm, bp.head, fit.head.offset)
	end
	setHeadHidden(bp.head, hideHead)
	setHatsHidden(char, g.helmet ~= nil)
	local function limb(item, build, f)
		local m = build(item, f.box, f.reach)
		attach(folder, m, f.part, f.offset)
		-- скрываем конечность только под 3D-мешем; запасные блочные перчатки и ботинки надеты поверх руки
		if f.hide and m:FindFirstChild("Shell") then
			for _, part in ipairs(f.hide) do
				hide[part] = true
			end
		end
	end
	if g.gloves then
		for _, f in ipairs(fit.gloves) do
			limb(Shop.ById[g.gloves], IB.Glove, f)
		end
	end
	if g.boots then
		for _, f in ipairs(fit.boots) do
			limb(Shop.ById[g.boots], IB.Boot, f)
		end
	end
	setCoveredHidden(char, hide)
	watchBody(player, char)

	-- характеристики
	local t = Shop.Totals(g)
	local ratio = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	local perks = p.perks or {}
	-- пропуска доната (DonateConfig): умеренные прибавки поверх снаряжения
	local function pass(stat)
		return DonateCfg.Perk(p.passes, stat)
	end
	hum.MaxHealth = 100 + t.hp + (perks.hp or 0)
	hum.Health = math.max(1, hum.MaxHealth * ratio)
	char:SetAttribute("ZSS_BaseSpeed", 16 + t.speed + pass("speed"))
	Equipment.RefreshSpeed(player)
	if hum.UseJumpPower then
		hum.JumpPower = 50 + t.jump * 2.5
	else
		hum.JumpHeight = 7.2 + t.jump * 0.55
	end
	char:SetAttribute("ZSS_DmgMult", 1 - t.def)
	player:SetAttribute("ZSS_ScrapMult", 1 + t.scrap + (perks.scrap or 0))
	-- бонусы переработки от рюкзака (читают Переработчик и способность дрона «Переработка»)
	player:SetAttribute("ZSS_ConvMult", 1 + t.conv + pass("conv"))
	player:SetAttribute("ZSS_ConvSpeed", 1 + t.cspeed + pass("cspeed"))
	-- доп. характеристики в стиле BSS (читают Дроны, Поля, Зомби, Находки, Баффы)
	player:SetAttribute("ZSS_Crit", t.crit)
	player:SetAttribute("ZSS_CritX", t.critx)
	player:SetAttribute("ZSS_DroneDmg", 1 + t.ddmg)
	player:SetAttribute("ZSS_DroneGather", 1 + t.dgather + pass("dgather"))
	player:SetAttribute("ZSS_ToolGather", 1 + t.tgather)
	player:SetAttribute("ZSS_InstConv", t.instconv)
	player:SetAttribute("ZSS_Luck", 1 + t.luck + pass("luck"))
	player:SetAttribute("ZSS_Regen", t.regen)
	player:SetAttribute("ZSS_DroneEnergy", 1 + t.energy)
	player:SetAttribute("ZSS_DroneSpeed", 1 + t.dspeed)
	player:SetAttribute("ZSS_BuffDur", 1 + t.buffdur)

	giveWeapon(player, p)
end

-- выдать расходник: новый сам встаёт в первую свободную ячейку хотбара (потом его можно переложить)
function Equipment.GiveConsum(player, id, qty)
	local p = Data.Get(player)
	if not p or not Shop.ById[id] then
		return false
	end
	p.consum = p.consum or {}
	p.consum[id] = (p.consum[id] or 0) + qty
	local Hotbar = require(RS.ZSS.Hotbar)
	p.hotbar = Hotbar.Normalize(p.hotbar)
	if not Hotbar.IndexOf(p.hotbar, id) then
		local free = Hotbar.FirstEmpty(p.hotbar)
		if free then
			p.hotbar[free] = id
		end
	end
	Data.MarkDirty(player)
	return true
end

function Equipment.Buy(player, id, qty)
	local p = Data.Get(player)
	local item = Shop.ById[id]
	if not p or not item then
		return { ok = false, err = "Unknown item" }
	end
	if item.noShop then
		return { ok = false, err = "This item isn't sold: it drops from zombies and the boss" }
	end
	if item.stack then
		local qty = (qty == 5) and 5 or 1
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - Config.ShopZone.center).Magnitude > Config.ShopZone.radius + 10 then
			return { ok = false, err = "You can only buy things in the Shop!" }
		end
		local cost = item.price * qty
		if p.batteries < cost then
			return { ok = false, err = ("🔋 Not enough batteries: you need %d"):format(cost) }
		end
		p.batteries -= cost
		Equipment.GiveConsum(player, id, qty)
		Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
		return { ok = true, qty = qty }
	end
	if p.items[id] then
		return { ok = false, err = "Already bought" }
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Config.ShopZone.center).Magnitude > Config.ShopZone.radius + 10 then
		return { ok = false, err = "You can only buy things in the Shop!" }
	end
	if p.batteries < item.price then
		return { ok = false, err = ("🔋 Not enough batteries: you need %d"):format(item.price) }
	end
	-- крафт: нужны находки из рюкзака
	local ok, missing = Data.HasMats(p, item.mats)
	if not ok then
		return { ok = false, err = "🧰 Not enough materials: " .. missing }
	end
	Data.TakeMats(p, item.mats)
	p.batteries -= item.price
	p.items[id] = true
	p.gear[item.slot] = id
	Equipment.Apply(player)
	Data.MarkDirty(player)
	Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
	if item.mats then
		require(script.Parent.Quests).Event(player, "craft", { slot = item.slot })
	end
	return { ok = true }
end

function Equipment.Equip(player, id)
	local p = Data.Get(player)
	local item = Shop.ById[id]
	if not p or not item or not p.items[id] then
		return
	end
	if p.gear[item.slot] == id and not FIXED[item.slot] then
		p.gear[item.slot] = nil -- повторное нажатие снимает
	else
		p.gear[item.slot] = id
	end
	Equipment.Apply(player)
	Data.MarkDirty(player)
end

-- скорость = снаряжение × накопленный бафф «Ускорение» (x1.05 за каждую ступень)
local Buffs = require(RS.ZSS.BuffsConfig)
function Equipment.RefreshSpeed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.WalkSpeed = (char:GetAttribute("ZSS_BaseSpeed") or 16) * Buffs.Mult(player, "speed")
end

-- совместимость: временное ускорение = ступени баффа «Ускорение»
function Equipment.AddSpeedBuff(player, stacks)
	return require(script.Parent.Drops).AddStacks(player, "speed", stacks or 1)
end

-- характеристики предмета в руках (оружие или инструмент)
function Equipment.WeaponStats(player)
	local p = Data.Get(player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ZSSWeapon")
	if not (p and id and p.items[id]) then
		id = p and p.gear.weapon or Shop.DefaultWeapon
	end
	local item = Shop.ById[id] or Shop.ById[Shop.DefaultWeapon]
	return item.stats, item
end

-- ===== РАСХОДНИКИ =====
local lastUse = {}
function Equipment.Use(player, id)
	local p = Data.Get(player)
	local item = Shop.ById[id]
	if not p or not item or not item.stack then
		return
	end
	if (p.consum[id] or 0) <= 0 then
		Remotes.Notify:FireClient(player, ("You don't have “%s”. Buy it in the Shop"):format(item.name), "bad")
		return
	end
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < 0.8 then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return
	end
	if id == "medkit" then
		if hum.Health >= hum.MaxHealth - 0.5 then
			Remotes.Notify:FireClient(player, "❤ Health is already full", "info")
			return
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + item.stats.heal)
		Remotes.FX:FireAllClients("heal", { owner = player.UserId })
	elseif id == "energycell" then
		Drones.AddEnergy(player, item.stats.energy)
		Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = Color3.fromRGB(80, 220, 255), duration = 2 })
	elseif id == "adrenaline" then
		Equipment.AddSpeedBuff(player, item.stats.stacks)
		Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = Color3.fromRGB(255, 80, 120), duration = 2 })
	elseif id == "grenade" then
		local pos = hrp.Position + hrp.CFrame.LookVector * 8
		Remotes.FX:FireAllClients("grenade", { owner = player.UserId, from = hrp.Position, pos = pos, radius = item.stats.radius })
		local field = Fields.At(hrp.Position)
		task.delay(0.7, function()
			if field and player.Parent then
				for _, z in ipairs(Zombies.InRadius(field, pos, item.stats.radius, player)) do
					Zombies.Damage(z, item.stats.dmg, player)
				end
			end
		end)
	elseif item.use then
		local ok, err = Equipment.ApplyUse(player, p, item, hrp, hum)
		if not ok then
			if err then
				Remotes.Notify:FireClient(player, err, "bad")
			end
			return
		end
	end
	if item.fx then
		Remotes.FX:FireAllClients("consume", { owner = player.UserId, id = id, pos = hrp.Position })
	end
	lastUse[player] = now
	p.consum[id] -= 1
	Data.MarkDirty(player)
	require(script.Parent.Quests).Event(player, "use", { id = id })
end

-- ===== УНИВЕРСАЛЬНЫЕ ЭФФЕКТЫ РАСХОДНИКОВ (поле use в ShopConfig) =====
local rng = Random.new()

function Equipment.SpawnOrbs(player, field, pos, n, cat)
	local Drops = require(script.Parent.Drops)
	local c = field.cfg.center
	local h = field.half - 3
	for _ = 1, n do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(4, 10)
		local x = math.clamp(pos.X + math.cos(a) * d, c.X - h, c.X + h)
		local z = math.clamp(pos.Z + math.sin(a) * d, c.Z - h, c.Z + h)
		Drops.SpawnBuff(Buffs.Roll(rng, cat), Vector3.new(x, c.Y + 3.2, z), field.cfg.id, player)
	end
end

function Equipment.ApplyUse(player, p, item, hrp, hum)
	local u = item.use
	local field = Fields.At(hrp.Position)
	if u.field and (not field or field.cfg.boss) then
		return false, ("“%s” only works on a field with scrap"):format(item.name)
	end
	if u.home then
		local Hives = require(script.Parent.Hives)
		local i = Hives.Index(player)
		if not i then
			return false, "First claim a hive at the base"
		end
		player.Character:PivotTo(CFrame.new(Hives.FrontPos(i) + Vector3.new(0, 3, 0)))
	end
	if u.convert then
		if (p.scrap or 0) <= 0 then
			return false, "🎒 Your backpack is empty, nothing to recycle"
		end
		local n = Data.TakeScrap(p, p.scrap)
		local gain = math.floor(n * (player:GetAttribute("ZSS_ConvMult") or 1) * Buffs.Mult(player, "convb"))
		Data.AddBatteries(player, gain)
		require(script.Parent.Quests).Event(player, "convert", nil, n)
		Remotes.Notify:FireClient(player, ("♻ Recycled %d scrap → 🔋 +%d"):format(n, gain), "good")
	end
	if u.heal then
		hum.Health = u.heal == "full" and hum.MaxHealth or math.min(hum.MaxHealth, hum.Health + u.heal)
	end
	if u.energy then
		Drones.AddEnergy(player, u.energy)
	end
	if u.buffs then
		local Drops = require(script.Parent.Drops)
		for bid, n in pairs(u.buffs) do
			Drops.AddStacks(player, bid, n)
		end
	end
	if u.gold and field then
		for _, t in ipairs(Fields.TilesNear(field, hrp.Position, u.gold[1])) do
			Fields.SetGold(t, u.gold[2])
		end
	end
	if u.goldAll and field then
		for _, t in ipairs(field.tiles) do
			Fields.SetGold(t, u.goldAll)
		end
	end
	if u.refill and field then
		for _, t in ipairs(field.tiles) do
			t.fill = 1
			Fields.UpdateTile(t)
		end
	end
	if u.orbs and field then
		Equipment.SpawnOrbs(player, field, hrp.Position, u.orbs[1], u.orbs[2])
	end
	if u.minis and field then
		Drones.SpawnMinis(player, u.minis[1], u.minis[2])
	end
	if u.bomb and field then
		local pos = hrp.Position
		task.delay(0.6, function()
			if not player.Parent then
				return
			end
			local tool = Shop.ById[p.gear.tool or ""] or Shop.ById[Shop.DefaultTool]
			for _, t in ipairs(Fields.TilesNear(field, pos, u.bomb[1])) do
				Fields.Collect(player, t, tool.stats.gather, u.bomb[2] * (player:GetAttribute("ZSS_ToolGather") or 1))
			end
			for _, z in ipairs(Zombies.InRadius(field, pos, u.bomb[1], player)) do
				Zombies.Damage(z, u.bomb[3], player)
			end
		end)
	end
	return true
end

function Equipment.Init(dataModule, dronesModule, fieldsModule, zombiesModule)
	Data, Drones, Fields, Zombies = dataModule, dronesModule, fieldsModule, zombiesModule
	game:GetService("Players").PlayerRemoving:Connect(dropWorn)
end

return Equipment
