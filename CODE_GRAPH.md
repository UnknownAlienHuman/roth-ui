# Roth UI code graph — B4.3.4

```text
Roth_UI.toc
  embeds/rLib
    core + snapguides + temporary drag worker
  libraries
  init bridge
  safety -> forbidden-aspect guards -> oUF 14.1.1 capability contract
  config persistence owner -> defaults/config -> persistence services
  runtime services
    frame registry / movers / shared post-combat queue / event-driven combat fader
    lazy Settings owner + actions/pages / diagnostics / slash aliases / minimap entry
    unit values / tags / bars / orb controllers
    target castbar visual adapter
    lazy managed aura lifecycle
    reversible Blizzard frame/group policy
    secure group-header visibility owner
  unit layouts -> external oUF
  post-layout secure group-structure contract
  forbidden-aware Blizzard action-button skin + UIParent-owned action-bar artwork
```

```text
secure party/raid structure setting
  -> persist ordinary config
  -> mark reload required
  -> no live protected-header rebuild
```

```text
Blizzard_Settings absent at login
  -> no category/page construction
  -> user opens Roth Settings or Blizzard loads Settings
  -> idempotent category registration and builder execution
```

High-frequency state remains in oUF or Blizzard native widgets. Roth callbacks configure addon-owned regions and react to bounded framework/native events. Static tests and packaging files are not loaded by the addon and are excluded from release archives.
