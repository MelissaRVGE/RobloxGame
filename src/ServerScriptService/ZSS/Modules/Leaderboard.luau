-- Лидерборды на спавне: гемы сейчас, батареи сейчас, батарей заработано за всё время, убито зомби;
-- в Призрачной роще — тыкв собрано за всё время (только пока идёт Хэллоуин).
-- Использует OrderedDataStore (глобальный топ); если он недоступен (Studio без API) — топ игроков на сервере.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local LB = {}
local Data
local BOARDS = {
	{ id = "gems", store = "ZSS_LB_Gems_v1", field = "gems" },
	{ id = "batteries", store = "ZSS_LB_Bats_v1", field = "batteries" },
	{ id = "total", store = "ZSS_LB_Total_v1", field = "totalBatteries" },
	{ id = "kills", store = "ZSS_LB_Kills_v1", field = "kills" },
	{ id = "pumpkins", store = "ZSS_LB_Pumpkins_v1", field = "totalPumpkins" },
}
local stores = {}
local nameCache = {}
local useGlobal = true
local TOP = 10

local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		nameCache[userId] = plr.DisplayName
		return plr.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and n or ("Player " .. userId)
	return nameCache[userId]
end

local function boardGui(id)
	local f = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Leaderboards")
	local b = f and f:FindFirstChild("Board_" .. id)
	local screen = b and b:FindFirstChild("Screen")
	return screen and screen:FindFirstChild("Gui")
end

-- числа полностью, без K/M/B: 14242455 -> "14 242 455"
local function fmt(n)
	n = math.floor(n or 0)
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (s:gsub("^ ", ""):gsub("^%- ", "-"))
end

-- колонка значения шире, чтобы полное число влезало; длинные числа плавно ужимаются шрифтом
local VALUE_W = 180
local function fitRow(row)
	if row:GetAttribute("FullNums") then
		return
	end
	row:SetAttribute("FullNums", true)
	local v, nm = row.Value, row.Name_
	local grow = VALUE_W - v.Size.X.Offset
	if grow > 0 then
		v.Size = UDim2.new(v.Size.X.Scale, VALUE_W, v.Size.Y.Scale, v.Size.Y.Offset)
		nm.Size = UDim2.new(nm.Size.X.Scale, nm.Size.X.Offset - grow, nm.Size.Y.Scale, nm.Size.Y.Offset)
	end
	local maxTs = v.TextSize
	v.TextScaled = true
	local c = v:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxTs
	c.MinTextSize = 10
	c.Parent = v
end

local function render(id, entries)
	local gui = boardGui(id)
	if not gui then
		return
	end
	for i = 1, TOP do
		local row = gui:FindFirstChild("Row" .. i, true)
		if row then
			local e = entries[i]
			-- все 10 мест видны всегда: пустые — блёклые с прочерком (доска не выглядит пустой чёрной)
			row.Visible = true
			if row:GetAttribute("BaseTr") == nil then
				row:SetAttribute("BaseTr", row.BackgroundTransparency)
			end
			fitRow(row)
			if e then
				row.Name_.Text = e.name
				row.Value.Text = fmt(e.value)
				row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(e.userId)
				row.Name_.TextTransparency = 0
				row.Value.TextTransparency = 0
				row.BackgroundTransparency = row:GetAttribute("BaseTr")
			else
				row.Name_.Text = "— free —"
				row.Value.Text = ""
				row.Avatar.Image = ""
				row.Name_.TextTransparency = 0.6
				row.BackgroundTransparency = math.min(1, row:GetAttribute("BaseTr") + 0.4)
			end
		end
	end
	local empty = gui:FindFirstChild("Empty", true)
	if empty then
		empty.Visible = false
	end
end

-- записать текущие значения всех игроков
local function push()
	if not useGlobal then
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local p = Data.Get(plr)
		if p then
			for _, b in ipairs(BOARDS) do
				local st = stores[b.id]
				if st then
					local v = math.floor(p[b.field] or 0)
					local ok = pcall(function()
						st:SetAsync(tostring(plr.UserId), v)
					end)
					if not ok then
						useGlobal = false
						return
					end
				end
			end
		end
	end
end

local function pull()
	for _, b in ipairs(BOARDS) do
		local entries = {}
		local ok = false
		if useGlobal and stores[b.id] then
			ok = pcall(function()
				local page = stores[b.id]:GetSortedAsync(false, TOP):GetCurrentPage()
				for _, e in ipairs(page) do
					local uid = tonumber(e.key)
					if uid then
						table.insert(entries, { userId = uid, name = getName(uid), value = e.value })
					end
				end
			end)
		end
		if not ok then
			-- запасной вариант: игроки на сервере
			entries = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				local p = Data.Get(plr)
				if p then
					table.insert(entries, { userId = plr.UserId, name = plr.DisplayName, value = p[b.field] or 0 })
				end
			end
			table.sort(entries, function(x, y)
				return x.value > y.value
			end)
		end
		render(b.id, entries)
	end
end

function LB.Init(dataModule)
	Data = dataModule
	for _, b in ipairs(BOARDS) do
		local ok, st = pcall(function()
			return DataStoreService:GetOrderedDataStore(b.store)
		end)
		if ok then
			stores[b.id] = st
		else
			useGlobal = false
		end
	end
	task.spawn(function()
		task.wait(5)
		local n = 0
		while true do
			if n % 6 == 0 then
				pcall(push) -- запись раз в ~3 минуты (лимиты DataStore)
			end
			pcall(pull)
			n += 1
			task.wait(useGlobal and 30 or 5)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		local p = Data.Get(plr)
		if p and useGlobal then
			for _, b in ipairs(BOARDS) do
				if stores[b.id] then
					pcall(function()
						stores[b.id]:SetAsync(tostring(plr.UserId), math.floor(p[b.field] or 0))
					end)
				end
			end
		end
	end)
end

return LB
