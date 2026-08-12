local addonName, ns = ...
local root = _G.Roth_UI

-- Ensure legacy module code keeps working even after splitting modules out.
-- Many embedded modules call methods like Roth_UI:ListenForLoaded(), but after
-- splitting they receive their own addon table as the 2nd vararg.
-- We provide forwarding wrappers to the root addon.

if root then
  local mt = getmetatable(ns)
  if not mt or mt.__index ~= root then
    setmetatable(ns, { __index = root })
  end

	-- Common fields referenced by legacy module code
	-- Provide a config proxy that always contains embeds flags.
	-- We removed the old embedded-modules system from Roth_UI, so root.cfg.embeds
	-- may not exist anymore. Legacy code still checks cfg.embeds.* and would throw.
	local baseCfg = root.cfg or {}
	local embeds = {}
	if type(baseCfg.embeds) == "table" then
	  for k, v in pairs(baseCfg.embeds) do embeds[k] = v end
	end
	if embeds.rActionBarStyler == nil then embeds.rActionBarStyler = true end
	if embeds.rButtonTemplate == nil then embeds.rButtonTemplate = true end
	ns.cfg = setmetatable({ embeds = embeds }, { __index = baseCfg })
  ns.db = root.db
  ns.oUF = root.oUF or _G.oUF
  ns.func = root.func
  ns.bars = root.bars
  ns.unit = root.unit
end

-- Forwarders (module-local) so calls like ns:ListenForLoaded() always exist.
ns.ListenForLoaded = ns.ListenForLoaded or function(self, cb)
  if root and type(root.ListenForLoaded) == "function" then
    return root.ListenForLoaded(root, cb)
  end
  if type(cb) == "function" then cb() end
end

ns.ListenForMediaChange = ns.ListenForMediaChange or function(self, cb)
  if root and type(root.ListenForMediaChange) == "function" then
    return root.ListenForMediaChange(root, cb)
  end
end
