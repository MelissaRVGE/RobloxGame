local Placer = {}
local lib = game.ServerStorage.ZSS_ThemeLib
local Map = workspace.Map
local Z = {192, 304, 416, 528, 668}
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {workspace.Terrain}
function Placer.ground(x, z) local r = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp); if r then return r.Position.Y, r.Material end end
function Placer.nearRamp(x, z, r) for k = 1, 5 do if math.abs(z - Z[k]) < 22 + r and math.abs(x) < 28 + r then return true end end return false end
function Placer.folder(name)
  local root = Map:FindFirstChild("ThemeDecor") or Instance.new("Folder"); root.Name = "ThemeDecor"; root.Parent = Map
  local f = root:FindFirstChild(name) or Instance.new("Folder"); f.Name = name; f.Parent = root
  return f
end
-- opts: y (expected ground), tol (flat tolerance), margin, sink (fraction of height), scale {a,b}, water (allow water), yaw
function Placer.try(name, x, z, parent, opts, rng)
  opts = opts or {}
  if Placer.nearRamp(x, z, 0) then return nil end
  local g, mat = Placer.ground(x, z)
  if not g then return nil end
  if mat == Enum.Material.Water and not opts.water then return nil end
  if opts.y and math.abs(g - opts.y) > (opts.ytol or 1.2) then return nil end
  local m = lib[name]:Clone()
  if opts.scale then m:ScaleTo(m:GetScale() * rng:NextNumber(opts.scale[1], opts.scale[2])) end
  local yaw = opts.yaw or rng:NextNumber(0, math.pi * 2)
  m:PivotTo(CFrame.new(x, g, z) * CFrame.Angles(0, yaw, 0))
  local cf, sz = m:GetBoundingBox()
  if Placer.nearRamp(cf.X, cf.Z, math.max(sz.X, sz.Z) / 2) then m:Destroy(); return nil end
  local tol = opts.tol or 1.3
  local fx0 = opts.foot or 1
  for _, d in ipairs({{-1,-1},{1,-1},{-1,1},{1,1},{0,-1},{0,1},{-1,0},{1,0}}) do
    local c = cf * Vector3.new(d[1] * sz.X * 0.45 * fx0, 0, d[2] * sz.Z * 0.45 * fx0)
    if math.abs(c.X) > 210 then m:Destroy(); return nil end
    local gg, mm = Placer.ground(c.X, c.Z)
    if not gg or math.abs(gg - g) > tol or (mm == Enum.Material.Water and not opts.water) then m:Destroy(); return nil end
  end
  local sink = (opts.sink or 0.04) * sz.Y + 0.1
  m:PivotTo(m:GetPivot() + Vector3.new(0, (g - sink) - (cf.Y - sz.Y / 2), 0))
  cf, sz = m:GetBoundingBox()
  local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; local ex = {m, workspace.Terrain}; for _, i in ipairs(opts.ignore or {}) do table.insert(ex, i) end; op.FilterDescendantsInstances = ex
  local mg = opts.margin or 2
  local fx = opts.foot or 1
  local hits = workspace:GetPartBoundsInBox(cf * CFrame.new(0, sink + 0.3, 0), Vector3.new(sz.X * fx + mg * 2, sz.Y - (sink + 0.3), sz.Z * fx + mg * 2), op)
  for _, h in ipairs(hits) do
    if h.Transparency < 1 or h.CanCollide then m:Destroy(); return nil end
  end
  m.Parent = parent
  return m
end
function Placer.scatter(name, count, gen, parent, opts, rng, tries)
  local placed = 0
  for _ = 1, (tries or count * 40) do
    if placed >= count then break end
    local x, z = gen()
    if Placer.try(name, x, z, parent, opts, rng) then placed += 1 end
  end
  return placed
end
return Placer
