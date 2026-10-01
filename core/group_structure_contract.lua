-- Secure group-frame structure contract.
--
-- Party/raid oUF headers and their child regions are constructed once per UI
-- session. Structural settings are persisted with a reload-required marker;
-- live scale, position, range and provider visibility remain supported.

local addonName, ns = ...

-- Retire the old public rebuild entry points after the layout files load. They
-- created additional protected headers that oUF retained for the whole session.
ns.RebuildPartyStructureRuntime = nil
ns.RebuildRaidStructureRuntime = nil

ns.groupStructureContract = {
  liveRebuild = false,
  reloadRequired = true,
  secureHeadersAreSessionOwned = true,
}
