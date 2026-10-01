# Roth UI code graph — B4.3.2

```text
Roth_UI.toc
  embeds/rLib
    core + snapguides + temporary drag worker
  libraries
  init bridge
  safety -> oUF capability contract
  config persistence owner -> defaults/config -> persistence services
  runtime services
    frame registry / movers / event-driven combat fader
    Settings actions/pages / diagnostics / slash aliases / minimap entry
    unit values / tags / bars / orb controllers
    target castbar visual adapter
    lazy managed aura lifecycle
    reversible Blizzard frame/group policy
  unit layouts -> external oUF 14
  Blizzard action-button skin + UIParent-owned action-bar artwork
```

## State flow

```text
SavedVariables owner
  -> validated/migrated ordinary config
  -> runtime config/store services
  -> settings actions and frame refresh callbacks
```

```text
oUF events/elements
  -> Roth integration adapters
  -> native widgets/addon-owned regions
```

```text
Blizzard action/vehicle/Edit Mode signals
  -> coalesced presentation refresh
  -> no replacement secure owner
```

High-frequency state remains in oUF or Blizzard native widgets. Roth callbacks configure addon-owned regions and react to bounded framework/native events. Static tests and packaging files are not loaded by the addon and are excluded from release archives.
