local addon, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by group_header_visibility.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by group_header_visibility.lua")
local TryMethod = assert(safety.TryMethod, "Roth_UI: safety.TryMethod is required by group_header_visibility.lua")

local service = ns.GroupHeaderVisibility or {}
ns.GroupHeaderVisibility = service

service.hiddenParents = service.hiddenParents or {}

function service.Normalize(visibility)
  if visibility == nil then
    return nil
  end
  return tostring(visibility):gsub("^custom%s+", "")
end

function service.GetHiddenParent(key)
  local id = type(key) == "string" and key or "default"
  local parent = service.hiddenParents[id]
  if parent then
    return parent
  end

  parent = CreateFrame("Frame")
  parent:Hide()
  service.hiddenParents[id] = parent
  return parent
end

function service.Apply(frame, visibility)
  if not (frame and visibility) then
    return false
  end

  local vis = service.Normalize(visibility)
  if not vis or vis == "" then
    return false
  end

  if UnregisterStateDriver then
    TryCall(UnregisterStateDriver, frame, "visibility")
  end
  local ok = TryCall(RegisterStateDriver, frame, "visibility", vis)
  return ok == true
end

function service.Hide(frame)
  if not frame then
    return false
  end

  service.Apply(frame, "hide")
  TryMethod(frame, "Hide")
  return true
end

function service.Show(frame)
  if not frame then
    return false
  end

  service.Apply(frame, "show")
  TryMethod(frame, "Show")
  return true
end

function service.Park(frame, key)
  if not frame then
    return false
  end

  service.Hide(frame)
  if frame.SetParent then
    TryCall(frame.SetParent, frame, service.GetHiddenParent(key))
  end
  return true
end
