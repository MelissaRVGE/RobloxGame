-- Донат-магазин: покупки за Robux (MarketplaceService).
-- Товары (Developer Products) выдаются в ProcessReceipt. Каждая покупка записывается в профиль
-- по PurchaseId, поэтому повторный вызов той же покупки ничего не выдаёт второй раз.
-- Пропуска (Game Passes) проверяются при входе и сразу после покупки, бонусы — в Equipment.Apply.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local DC = require(RS.ZSS.DonateConfig)
local Shop = require(RS.ZSS.ShopConfig)
local Items = require(RS.ZSS.ItemsConfig)
local Hotbar = require(RS.ZSS.Hotbar)
local Remotes = RS.ZSS.Remotes

local Donate = {}
local Data, Equipment
local MAX_RECEIPTS = 200 -- сколько последних покупок помнить в профиле
local pending = {} -- player -> { key, t } — какое окно оплаты открыто
local policy = {} -- player -> true/false: платные случайные предметы запрещены (ответ PolicyService)

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

-- расходник в запас + в первую свободную ячейку хотбара (как при покупке в Магазине)
local function addConsum(p, id, n)
	p.consum = p.consum or {}
	p.consum[id] = (p.consum[id] or 0) + n
	p.hotbar = Hotbar.Normalize(p.hotbar)
	if not Hotbar.IndexOf(p.hotbar, id) then
		local free = Hotbar.FirstEmpty(p.hotbar)
		if free then
			p.hotbar[free] = id
		end
	end
end

-- выдать содержимое товара; оплаченное кладётся в рюкзак даже сверх лимита ячеек
local function grant(player, p, o)
	local g = o.grant or {}
	if g.gems then
		Data.AddGems(player, g.gems)
	end
	for id, n in pairs(g.items or {}) do
		if Items.ById[id] then
			p.bag = p.bag or {}
			p.bag[id] = (p.bag[id] or 0) + n
		end
	end
	for id, n in pairs(g.consum or {}) do
		if Shop.ById[id] then
			addConsum(p, id, n)
		end
	end
	if o.once then
		p.donateOnce = p.donateOnce or {}
		p.donateOnce[o.key] = true
	end
	p.robuxSpent = (p.robuxSpent or 0) + (o.price or 0)
	Data.MarkDirty(player)
end

-- праздник у игрока и короткая вспышка у всех вокруг
local function celebrate(player, o)
	Remotes.DonateDone:FireClient(player, o.key)
	Remotes.FX:FireAllClients("aura", { owner = player.UserId, color = o.color, duration = 2.5, rainbow = o.anim == "rainbow" })
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			notify(other, ("💖 %s supported the game: “%s”!"):format(player.DisplayName, o.name), "Legendary")
		end
	end
end

local function setPass(player, p, o)
	p.passes = p.passes or {}
	if p.passes[o.key] then
		return false
	end
	p.passes[o.key] = true
	player:SetAttribute("ZSS_Pass_" .. o.key, true)
	Equipment.Apply(player)
	Data.MarkDirty(player)
	return true
end

-- Гемы тратятся на гачу дронов, поэтому по правилам Roblox гемы за Robux — платные случайные предметы.
-- Там, где они запрещены (PolicyService.ArePaidRandomItemsRestricted), гемы за Robux не продаются:
-- гача остаётся, но крутится только на заработанных в игре гемах.
local function grantsGems(o)
	return o.grant ~= nil and (o.grant.gems or 0) > 0
end

local function checkPolicy(player)
	if policy[player] ~= nil then
		return policy[player]
	end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or type(info) ~= "table" then
		-- сервис не ответил: не продаём гемы, пока не узнаем точно (спросим снова при следующей покупке)
		player:SetAttribute("ZSS_NoPaidRandom", true)
		return true
	end
	local restricted = info.ArePaidRandomItemsRestricted == true
	if player.Parent then
		policy[player] = restricted
		player:SetAttribute("ZSS_NoPaidRandom", restricted)
	end
	return restricted
end

function Donate.CheckPolicy(player)
	checkPolicy(player)
end

-- проверить купленные пропуска (при входе): результат сохраняем, чтобы бонус работал,
-- даже если сервис Roblox временно не ответил
local function checkPasses(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	p.passes = p.passes or {}
	for key, on in pairs(p.passes) do
		if on and DC.ByKey[key] then
			player:SetAttribute("ZSS_Pass_" .. key, true)
		end
	end
	local changed = false
	for _, o in ipairs(DC.List) do
		if o.kind == "pass" and o.id > 0 and not p.passes[o.key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, o.id)
			if ok and owns and player.Parent then
				p.passes[o.key] = true
				player:SetAttribute("ZSS_Pass_" .. o.key, true)
				changed = true
			end
		end
	end
	if changed then
		Equipment.Apply(player)
		Data.MarkDirty(player)
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local p = player and Data.Get(player)
	if not p then
		-- игрок вышел или профиль ещё грузится: Roblox повторит позже
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- профиль не загрузился (эта сессия не сохраняется): не выдаём, Roblox повторит при следующем входе
	local studio = RunService:IsStudio()
	if not Data.CanSave(player) and not studio then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pid = tostring(info.PurchaseId)
	p.receipts = p.receipts or {}
	if not table.find(p.receipts, pid) then
		local o = DC.ByProduct[info.ProductId]
		if not o then
			warn("[ZSS] Donate: unknown product", info.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		grant(player, p, o)
		table.insert(p.receipts, pid)
		while #p.receipts > MAX_RECEIPTS do
			table.remove(p.receipts, 1)
		end
		pending[player] = nil
		celebrate(player, o)
	end
	-- подтверждаем покупку, только когда она записана в профиль; при неудаче Roblox повторит вызов,
	-- а запись PurchaseId в профиле не даст выдать товар второй раз
	if not studio and not Data.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- запрос окна оплаты (проверки на сервере, чтобы нельзя было купить «один раз» дважды)
function Donate.Buy(player, key)
	local o = typeof(key) == "string" and DC.ByKey[key]
	local p = Data.Get(player)
	if not o or not p then
		return { ok = false, err = "Unknown offer" }
	end
	if o.kind == "pass" and p.passes and p.passes[o.key] then
		return { ok = false, err = "✔ You already own this pass" }
	end
	if o.once and p.donateOnce and p.donateOnce[o.key] then
		return { ok = false, err = "This bundle can only be bought once" }
	end
	if not o.id or o.id <= 0 then
		return { ok = false, err = "⏳ Coming soon!", soon = true }
	end
	if grantsGems(o) and checkPolicy(player) then
		return { ok = false, err = "🌍 Gem purchases aren't available in your region. You can still earn gems in the game!", region = true }
	end
	local last = pending[player]
	if last and os.clock() - last.t < 1 then
		return { ok = false, err = "Wait a second" }
	end
	pending[player] = { key = o.key, t = os.clock() }
	local ok = pcall(function()
		if o.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, o.id)
		else
			MarketplaceService:PromptProductPurchase(player, o.id)
		end
	end)
	if not ok then
		return { ok = false, err = "Roblox store is not responding, try again" }
	end
	return { ok = true }
end

-- выдать предложение без оплаты (только отладка в Studio)
function Donate.DebugGrant(player, key)
	local o = DC.ByKey[key]
	local p = Data.Get(player)
	if not o or not p then
		return false
	end
	if o.kind == "pass" then
		setPass(player, p, o)
	else
		grant(player, p, o)
	end
	celebrate(player, o)
	return true
end

function Donate.Init(dataModule, equipmentModule)
	Data, Equipment = dataModule, equipmentModule
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		pending[player] = nil
		local o = DC.ByPass[passId]
		local p = Data.Get(player)
		if purchased and o and p and setPass(player, p, o) then
			p.robuxSpent = (p.robuxSpent or 0) + (o.price or 0)
			task.spawn(Data.Save, player)
			celebrate(player, o)
		end
	end)
	Remotes.DonateBuy.OnServerInvoke = Donate.Buy
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		policy[player] = nil
	end)
	Donate.CheckPasses = function(player)
		task.spawn(checkPasses, player)
	end
	if RunService:IsStudio() then
		local n = 0
		for _, o in ipairs(DC.List) do
			if o.id <= 0 then
				n += 1
			end
		end
		if n > 0 then
			print(("[ZSS] Donate: %d offers without an id (buttons will show “coming soon”), see DonateConfig"):format(n))
		end
	end
end

return Donate
