# Roth UI code graph

```mermaid
flowchart TD
  T["Roth_UI.toc"] --> I["init.lua"]
  I --> C["core bootstrap and safety"]
  C --> P["persistence services"]
  C --> S["settings and slash control plane"]
  C --> B["bar and mover registries"]
  C --> O["orb and unit runtime"]
  B --> AB["action bars and dock"]
  O --> U["oUF units and elements"]
  AB --> M["embedded action-bar/button XML"]
  M -. "separate optional wrappers" .-> MT["module TOCs"]
  P --> DB[("Roth_UI_DB")]
```

The graph is a repository-level ownership map, not a claim that every runtime call is synchronous. Deferred and post-combat paths are intentionally coordinated by core services.
