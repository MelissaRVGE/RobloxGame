-- Сборка качественных манекенов и NPC для карты (запускается из редактора)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local K = {}
local C = Color3.fromRGB

local function req(m)
	local c = m:Clone()
	c.Parent = m.Parent
	local ok, r = pcall(require, c)
	c:Destroy()
	assert(ok, r)
	return r
end

local function part(parent, o)
	local p = Instance.new(o.class or "Part")
	p.Anchored = true
	p.CanCollide = o.collide or false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		p.Shape = o.shape
	end
	p.Size = o.size
	p.CFrame = o.cf
	p.Color = o.color or C(255, 255, 255)
	p.Material = o.mat or Enum.Material.SmoothPlastic
	if o.var then
		p.MaterialVariant = o.var
	end
	p.Reflectance = o.refl or 0
	p.Transparency = o.tr or 0
	p.Name = o.name or "Part"
	p.Parent = parent
	return p
end
K.part = part

-- чистое R15-тело без скриптов; все детали закреплены
function K.Body(colors, keepHumanoid)
	local d = Instance.new("HumanoidDescription")
	local skin = colors.skin or C(236, 232, 224)
	d.HeadColor = colors.head or skin
	d.TorsoColor = colors.torso or skin
	d.LeftArmColor = colors.arms or skin
	d.RightArmColor = colors.arms or skin
	d.LeftLegColor = colors.legs or skin
	d.RightLegColor = colors.legs or skin
	local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	for _, c in ipairs(m:GetDescendants()) do
		if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("Animator") then
			c:Destroy()
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if not keepHumanoid then
			hum:Destroy()
		end
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = true
		end
	end
	m.HumanoidRootPart.Transparency = 1
	return m
end

-- надеть снаряжение из магазина (как Equipment.Apply для R15)
function K.Dress(m, gear)
	local Shop = req(RS.ZSS.ShopConfig)
	local IB = req(RS.ZSS.ItemBuilder)
	local function put(model, partRef, offset)
		model:PivotTo(partRef.CFrame * (offset or CFrame.new()))
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		model.Parent = m
	end
	if gear.armor then
		put(IB.Armor(Shop.ById[gear.armor], m.UpperTorso.Size), m.UpperTorso)
	end
	if gear.backpack and Shop.ById[gear.backpack] then
		put(IB.Backpack(Shop.ById[gear.backpack], m.UpperTorso.Size, gear.armor ~= nil), m.UpperTorso)
	end
	if gear.helmet then
		local face = m.Head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local hm = IB.Helmet(Shop.ById[gear.helmet], m.Head.Size.Y)
		if hm:GetAttribute("HideHead") then
			m.Head.Transparency = 1
		end
		put(hm, m.Head)
	end
	if gear.gloves then
		for _, h in ipairs({ m.LeftHand, m.RightHand }) do
			local arm = m:FindFirstChild((h.Name:gsub("Hand", "LowerArm")))
			put(IB.Glove(Shop.ById[gear.gloves], h.Size, arm and arm.Size.Y * 0.8), h)
		end
	end
	if gear.boots then
		for _, f in ipairs({ m.LeftFoot, m.RightFoot }) do
			local leg = m:FindFirstChild((f.Name:gsub("Foot", "LowerLeg")))
			put(IB.Boot(Shop.ById[gear.boots], f.Size, leg and leg.Size.Y * 0.6), f)
		end
	end
	if gear.weapon then
		local w = IB.Weapon(Shop.ById[gear.weapon])
		local h = w.PrimaryPart
		-- в правой руке, рабочей частью вверх (как держит игрок)
		local rel = h.CFrame
		w:PivotTo(m.RightHand.CFrame * CFrame.new(0, -0.15, 0) * rel)
		for _, p in ipairs(w:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		w.Parent = m
	end
end

-- повернуть руки вокруг плечевого сустава (детали закреплены, поэтому двигаем их сами)
-- spread — отведение в сторону, fwd — подъём вперёд (радианы), отдельно для левой/правой
function K.PoseArms(body, spread, fwdL, fwdR)
	for _, side in ipairs({ { "Left", 1, fwdL or 0 }, { "Right", -1, fwdR or 0 } }) do
		local up = body:FindFirstChild(side[1] .. "UpperArm")
		local m6 = up and up:FindFirstChild(side[1] .. "Shoulder")
		if m6 and m6.Part0 then
			local pivot = m6.Part0.CFrame * m6.C0
			local rot = pivot * CFrame.Angles(side[3], 0, side[2] * -spread) * pivot:Inverse()
			for _, n in ipairs({ "UpperArm", "LowerArm", "Hand" }) do
				local p = body:FindFirstChild(side[1] .. n)
				if p then
					p.CFrame = rot * p.CFrame
				end
			end
		end
	end
end

-- фарфоровый манекен без лица на подиуме с светящимся кольцом
function K.Mannequin(floorPos, yaw, gear, ringColor)
	local holder = Instance.new("Model")
	holder.Name = "ArmorMannequin"
	local body = K.Body({ skin = C(238, 234, 226) })
	for _, p in ipairs(body:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.08
		end
		if p:IsA("Decal") then
			p:Destroy()
		end
	end
	-- слегка отведённые руки — поза витринного манекена
	K.PoseArms(body, 0.07)
	-- поставить на подиум: стопы на высоте 0.5 над полом
	local baseH = 0.5
	body:PivotTo(CFrame.new(floorPos) * CFrame.Angles(0, yaw, 0))
	local lowest = math.huge
	for _, p in ipairs(body:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2)
		end
	end
	body:PivotTo(body:GetPivot() + Vector3.new(0, floorPos.Y + baseH - lowest, 0))
	K.Dress(body, gear)
	body.Name = "Body"
	body.Parent = holder
	-- подиум
	local cyl = Enum.PartType.Cylinder
	part(holder, { name = "Base", shape = cyl, size = Vector3.new(baseH, 3.4, 3.4), cf = CFrame.new(floorPos + Vector3.new(0, baseH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = C(40, 44, 52), mat = Enum.Material.Metal, var = "ZSSG_W_Steel", collide = true })
	part(holder, { name = "BaseRing", shape = cyl, size = Vector3.new(0.12, 3.55, 3.55), cf = CFrame.new(floorPos + Vector3.new(0, baseH - 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = ringColor or C(80, 230, 255), mat = Enum.Material.Neon })
	part(holder, { name = "BaseTop", shape = cyl, size = Vector3.new(0.06, 3.1, 3.1), cf = CFrame.new(floorPos + Vector3.new(0, baseH + 0.01, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = C(225, 228, 235), mat = Enum.Material.Metal, refl = 0.25 })
	holder.WorldPivot = CFrame.new(floorPos)
	return holder
end

return K
