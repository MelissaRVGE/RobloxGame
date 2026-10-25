-- Поля с ресурсами (аналог цветочных полей из BSS): у поля 1–3 вида ресурсов, один главный
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes
local FieldTiles = require(RS.ZSS.FieldTiles)

local Fields = {}
Fields.List = {}

local Data, Loot
-- плитки в стиле BSS: при сборе проседают и плавно поднимаются при восстановлении.
-- Сервер хранит полноту и пишет её в атрибут Fill, а двигает плитки клиент (FieldTilesFX) —
-- так анимация плавная и не грузит сеть.
local GOLD = Color3.fromRGB(255, 200, 40)
local lastFullWarn = {}

function Fields.UpdateTile(tile)
	local q = math.floor(tile.fill * 40 + 0.5) / 40
	if q ~= tile.sent then
		tile.sent = q
		tile.part:SetAttribute("Fill", q)
	end
end

function Fields.TopPos(tile)
	return Vector3.new(tile.x, tile.top - Config.TileDepth * (1 - tile.fill) + 0.5, tile.z)
end

function Fields.At(pos)
	for _, f in ipairs(Fields.List) do
		local c = f.cfg.center
		if math.abs(pos.X - c.X) <= f.half + 1 and math.abs(pos.Z - c.Z) <= f.half + 1 and pos.Y < c.Y + 40 and pos.Y > c.Y - 8 then
			return f
		end
	end
	return nil
end

local GATE_DIR = {
	south = Vector3.new(0, 0, -1),
	north = Vector3.new(0, 0, 1),
	west = Vector3.new(-1, 0, 0),
	east = Vector3.new(1, 0, 0),
}
function Fields.GateDir(field)
	return GATE_DIR[field.cfg.gate or "south"]
end

function Fields.Entrance(field)
	return field.cfg.center + Vector3.new(0, 4, 0) + Fields.GateDir(field) * (field.half + 7)
end

function Fields.RandomPoint(field)
	local c = field.cfg.center
	local h = field.half - 3
	return Vector3.new(c.X + math.random(-h, h), c.Y + 3, c.Z + math.random(-h, h))
end

function Fields.TilesNear(field, pos, radius)
	local out = {}
	local r2 = radius * radius
	for _, t in ipairs(field.tiles) do
		local dx, dz = t.x - pos.X, t.z - pos.Z
		if dx * dx + dz * dz <= r2 then
			table.insert(out, t)
		end
	end
	return out
end

function Fields.RandomTileNear(field, pos, radius)
	local list = Fields.TilesNear(field, pos, radius)
	if #list == 0 then
		return nil
	end
	local best
	for _ = 1, 3 do
		local t = list[math.random(#list)]
		if not best or t.fill > best.fill then
			best = t
		end
	end
	return best
end

-- mult: во сколько раз золотая плитка даёт больше (Мидас — меньше, чем расходник)
function Fields.SetGold(tile, duration, mult)
	tile.gold = true
	tile.goldMult = mult or 5
	tile.goldUntil = os.clock() + duration
	tile.part.Color = GOLD
	tile.part.Material = Enum.Material.Neon
end

local function clearGold(tile)
	tile.gold = false
	tile.part.Color = tile.baseColor
	tile.part.Material = tile.baseMat
end

-- bud: лимит сбора одной способности { left = сколько ещё можно добыть }; nil — без лимита
function Fields.Collect(player, tile, base, mult, bud)
	local f = tile.field
	local gold = tile.gold and (tile.goldMult or 5) or 1
	local amount = base * (mult or 1) * f.cfg.mult * tile.kmult * gold * (0.4 + 0.6 * tile.fill)
	amount = amount * (player:GetAttribute("ZSS_ScrapMult") or 1)
	amount = amount * require(RS.ZSS.BuffsConfig).Mult(player, "scrap")
	if Loot.IsNight() then
		amount *= Config.DayNight.rewardMult
	end
	amount = math.max(1, math.floor(amount + 0.5))
	if bud then
		amount = math.min(amount, math.floor(bud.left))
		if amount < 1 then
			return 0
		end
		bud.left -= amount
	end
	tile.fill = math.max(0, tile.fill - Config.TileTake)
	Fields.UpdateTile(tile)
	-- «Мгновенная переработка»: часть лома сразу становится батареями, мимо рюкзака
	local inst = player:GetAttribute("ZSS_InstConv") or 0
	if inst > 0 then
		local conv = amount * inst
		local whole = math.floor(conv)
		if math.random() < conv - whole then
			whole += 1
		end
		if whole > 0 then
			amount -= whole
			local B = require(RS.ZSS.BuffsConfig)
			Data.AddBatteries(player, math.max(1, math.floor(whole * (player:GetAttribute("ZSS_ConvMult") or 1) * B.Mult(player, "convb") + 0.5)))
		end
	end
	local added, full = Data.AddScrap(player, amount, tile.res)
	if added > 0 then
		Remotes.Popup:FireClient(player, Fields.TopPos(tile), "+" .. added, gold > 1 and "gold" or ("res:" .. tile.res))
		require(script.Parent.Quests).Event(player, "scrap", { field = f.cfg.id, res = tile.res }, added)
	end
	-- хэллоуинская тыква на плитке
	if tile.pumpkin then
		require(script.Parent.Halloween).OnCollect(player, tile)
	end
	-- случайная находка в куче лома
	Loot.TryDrop(player, "droneGather", f.index, Fields.TopPos(tile))
	-- добыча — активность: рядом может появиться «добывающий» бафф
	require(script.Parent.Drops).OnActivity(player, "gather", Fields.TopPos(tile), f)
	if full then
		local now = os.clock()
		if not lastFullWarn[player] or now - lastFullWarn[player] > 6 then
			lastFullWarn[player] = now
			Remotes.Notify:FireClient(player, "🎒 Backpack full! Take your resources to the Recycler at the base.", "bad")
		end
	end
	return added
end

function Fields.Init(dataModule)
	Data = dataModule
	Loot = require(script.Parent.Loot)
	local root = workspace:WaitForChild("Map"):WaitForChild("Fields")
	for i, cfg in ipairs(Config.Fields) do
		local folder = root:FindFirstChild(cfg.id) or root:WaitForChild(cfg.id, 10)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = cfg.id
			folder.Parent = root
		end
		if not folder:FindFirstChild("Tiles") then
			local tf = Instance.new("Folder")
			tf.Name = "Tiles"
			tf.Parent = folder
		end
		FieldTiles.Build(folder, cfg, i)
		local field = { cfg = cfg, index = i, tiles = {}, folder = folder, half = cfg.size / 2, zcount = 0 }
		local main = Config.ResourceByField[cfg.id]
		for _, t in ipairs(folder:WaitForChild("Tiles"):GetChildren()) do
			local tile = {
				part = t,
				fill = 1,
				sent = 1,
				gold = false,
				goldUntil = 0,
				res = t:GetAttribute("Res") or (main and main.id) or "rust",
				kmult = cfg.tileMult or 1,
				baseColor = t.Color,
				baseMat = t.Material,
				top = t:GetAttribute("TopY") or (t.Position.Y + t.Size.Y / 2),
				x = t.Position.X,
				z = t.Position.Z,
				field = field,
			}
			t:SetAttribute("Fill", 1)
			table.insert(field.tiles, tile)
		end
		Fields.List[i] = field
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, f in ipairs(Fields.List) do
				for _, tile in ipairs(f.tiles) do
					if tile.fill < 1 then
						tile.fill = math.min(1, tile.fill + Config.TileRegen)
						Fields.UpdateTile(tile)
					end
					if tile.gold and now > tile.goldUntil then
						clearGold(tile)
					end
				end
			end
		end
	end)
end

return Fields
