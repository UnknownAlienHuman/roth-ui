# Roth UI code graph — B4.3

```text
Roth_UI.toc
  init.lua
  config persistence owner -> config.lua -> persistence services
  runtime helpers
    unit values / tags / movers / native bars
    target castbar visual adapter
    lazy managed aura lifecycle
    reversible Blizzard frame policy
  unit layouts -> oUF 14
  Blizzard action-button skin + decorative artwork

Roth_UI_Options.toc (LoadOnDemand)
  logger / reports / SV doctor
  Settings owner and page builders
  transfer/import/export
  debug commands
```

High-frequency state remains in oUF or native Blizzard widgets. Roth UI callbacks primarily configure regions and react to framework events.
