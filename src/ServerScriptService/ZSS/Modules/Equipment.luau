-- Магазин и экипировка: покупка, оружие (Tool), снаряжение на персонаже, бонусы
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.ZSS.Config)
local Shop = require(RS.ZSS.ShopConfig)
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
		lhand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm"),
		rhand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"),
		lfoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg"),
		rfoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg"),
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
local function setHeadHidden(head, hidden)
	if not head then
		return
	end
	if head:GetAttribute("ZSS_OrigTr") == nil then
		head:SetAttribute("ZSS_OrigTr", head.Transparency)
	end
	head.Transparency = hidden and 1 or head:GetAttribute("ZSS_OrigTr")
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			if d:GetAttribute("ZSS_OrigTr") == nil then
				d:SetAttribute("ZSS_OrigTr", d.Transparency)
			end
			d.Transparency = hidden and 1 or d:GetAttribute("ZSS_OrigTr")
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
		tool.ToolTip = ("⛏ Добыча +%d • Радиус %s"):format(item.stats.gather or 0, tostring(item.stats.radius))
	else
		tool.ToolTip = ("⚔ Урон %d • Радиус %s"):format(item.stats.dmg or 0, tostring(item.stats.radius))
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
	folder = Instance.new("Folder")
	folder.Name = "ZSS_Gear"
	folder.Parent = char

	local g = p.gear
	local torsoBox = bp.r15 and bp.torso.Size or Vector3.new(2, 2, 1)
	if g.armor then
		local am = IB.Armor(Shop.ById[g.armor], torsoBox)
		if g.backpack then
			-- под рюкзаком прячем то, что у брони висит на спине (ранец, баллоны, выхлоп)
			for _, d in ipairs(am:GetChildren()) do
				if d:IsA("BasePart") and d.Name ~= "Wing" and d.Name ~= "Cape" and d.Position.Z > torsoBox.Z * 0.7 then
					d:Destroy()
				end
			end
		end
		attach(folder, am, bp.torso, CFrame.new())
	end
	if g.backpack and Shop.ById[g.backpack] then
		attach(folder, IB.Backpack(Shop.ById[g.backpack], torsoBox, g.armor ~= nil), bp.torso, CFrame.new())
	end
	local hideHead = false
	if g.helmet then
		local hs = bp.r15 and bp.head.Size.Y or 1.25
		local hm = IB.Helmet(Shop.ById[g.helmet], hs)
		hideHead = hm:GetAttribute("HideHead") == true
		attach(folder, hm, bp.head, CFrame.new(0, bp.r15 and 0 or 0.05, 0))
	end
	setHeadHidden(bp.head, hideHead)
	setHatsHidden(char, g.helmet ~= nil)
	if g.gloves then
		for _, hand in ipairs({ bp.lhand, bp.rhand }) do
			if hand then
				local box = bp.r15 and hand.Size or Vector3.new(1, 0.6, 1)
				attach(folder, IB.Glove(Shop.ById[g.gloves], box), hand, bp.r15 and CFrame.new() or CFrame.new(0, -0.7, 0))
			end
		end
	end
	if g.boots then
		for _, foot in ipairs({ bp.lfoot, bp.rfoot }) do
			if foot then
				local box = bp.r15 and foot.Size or Vector3.new(1, 0.6, 1.1)
				attach(folder, IB.Boot(Shop.ById[g.boots], box), foot, bp.r15 and CFrame.new() or CFrame.new(0, -0.72, -0.05))
			end
		end
	end

	-- характеристики
	local t = Shop.Totals(g)
	local ratio = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	local perks = p.perks or {}
	hum.MaxHealth = 100 + t.hp + (perks.hp or 0)
	hum.Health = math.max(1, hum.MaxHealth * ratio)
	char:SetAttribute("ZSS_BaseSpeed", 16 + t.speed)
	Equipment.RefreshSpeed(player)
	if hum.UseJumpPower then
		hum.JumpPower = 50 + t.jump * 2.5
	else
		hum.JumpHeight = 7.2 + t.jump * 0.55
	end
	char:SetAttribute("ZSS_DmgMult", 1 - t.def)
	player:SetAttribute("ZSS_ScrapMult", 1 + t.scrap + (perks.scrap or 0))
	-- бонусы переработки от рюкзака (читают Переработчик и способность дрона «Переработка»)
	player:SetAttribute("ZSS_ConvMult", 1 + t.conv)
	player:SetAttribute("ZSS_ConvSpeed", 1 + t.cspeed)

	giveWeapon(player, p)
end

function Equipment.Buy(player, id, qty)
	local p = Data.Get(player)
	local item = Shop.ById[id]
	if not p or not item then
		return { ok = false, err = "Неизвестный предмет" }
	end
	if item.stack then
		local qty = (qty == 5) and 5 or 1
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - Config.ShopZone.center).Magnitude > Config.ShopZone.radius + 10 then
			return { ok = false, err = "Покупать можно только в Магазине!" }
		end
		local cost = item.price * qty
		if p.batteries < cost then
			return { ok = false, err = ("🔋 Не хватает батарей: нужно %d"):format(cost) }
		end
		p.batteries -= cost
		p.consum[id] = (p.consum[id] or 0) + qty
		Data.MarkDirty(player)
		Remotes.FX:FireAllClients("purchase", { owner = player.UserId })
		return { ok = true, qty = qty }
	end
	if p.items[id] then
		return { ok = false, err = "Уже куплено" }
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Config.ShopZone.center).Magnitude > Config.ShopZone.radius + 10 then
		return { ok = false, err = "Покупать можно только в Магазине!" }
	end
	if p.batteries < item.price then
		return { ok = false, err = ("🔋 Не хватает батарей: нужно %d"):format(item.price) }
	end
	-- крафт: нужны находки из рюкзака
	local ok, missing = Data.HasMats(p, item.mats)
	if not ok then
		return { ok = false, err = "🧰 Не хватает материалов: " .. missing }
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
		Remotes.Notify:FireClient(player, ("Нет предмета «%s» — купи в Магазине"):format(item.name), "bad")
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
			Remotes.Notify:FireClient(player, "❤ Здоровье уже полное", "info")
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
				for _, z in ipairs(Zombies.InRadius(field, pos, item.stats.radius)) do
					Zombies.Damage(z, item.stats.dmg, player)
				end
			end
		end)
	end
	lastUse[player] = now
	p.consum[id] -= 1
	Data.MarkDirty(player)
	require(script.Parent.Quests).Event(player, "use", { id = id })
end

function Equipment.Init(dataModule, dronesModule, fieldsModule, zombiesModule)
	Data, Drones, Fields, Zombies = dataModule, dronesModule, fieldsModule, zombiesModule
end

return Equipment
