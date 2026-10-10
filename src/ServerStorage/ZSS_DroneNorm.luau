local M = {}
function M.Normalize(model, id, targetW, yawDeg)
  local RS = game:GetService("ReplicatedStorage")
  local lib = RS.ZSS:FindFirstChild("DroneMeshes") or Instance.new("Folder")
  lib.Name = "DroneMeshes"; lib.Parent = RS.ZSS
  local old = lib:FindFirstChild(id); if old then old:Destroy() end
  local t = Instance.new("Model"); t.Name = id
  local parts = {}
  for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
  local rot = 0
  for _, p in ipairs(parts) do
    local isRotor = p.Name:lower():find("rotor") or p.Name:lower():find("propeller")
    if isRotor then rot += 1; p.Name = "Rotor" .. rot; p:SetAttribute("Rotor", true) else p.Name = "Hull" end
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
    p.Parent = t
  end
  t.Parent = workspace
  local cf, sz = t:GetBoundingBox()
  t.WorldPivot = CFrame.new(cf.Position)
  t:PivotTo(CFrame.Angles(0, math.rad(yawDeg or 0), 0))
  cf, sz = t:GetBoundingBox()
  local k = targetW / math.max(sz.X, sz.Z)
  t:ScaleTo(k)
  cf, sz = t:GetBoundingBox()
  t.WorldPivot = CFrame.new(cf.Position)
  t:PivotTo(CFrame.new())
  t:SetAttribute("Rotors", rot)
  t.Parent = lib
  model:Destroy()
  return t
end
return M
