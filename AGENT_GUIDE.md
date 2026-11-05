# Roth UI agent guide

Target: addon `3.4.3`, Retail `12.1.5`, Interface `120105`, selected source build `12.1.5.70688`, reviewed post-selected source `12.1.5.70783`, oUF `14.2.1+`.

Before editing, read `README.md`, `ARCHITECTURE.md`, `CURRENT_STATUS.md`, `CODE_INDEX.md`, `CODE_GRAPH.md`, the TOC and the applicable contracts in `UnknownAlienHuman/wow-addon-engineering-kb`.

## Workflow

- One dedicated Git worktree per manager/agent. Never share a dirty worktree between managers.
- Preserve unrelated edits; do not restore deleted legacy files.
- Keep source evidence, local tests, CI and in-client evidence separate.
- Do not publish or merge until the complete repository gate passes on the exact commit.

## Non-negotiable ownership

- Persistence root mutation: `persistence_control_plane` transaction only.
- No raw root getter/writer exported after owner capture.
- Combat deferral: `frame_policy` only.
- Next-frame scheduling: `deferred_scheduler` only; one timer drains each coalesced generation.
- Managed auras, movers, fonts and Settings keep one owner each.
- oUF owns unit frames and secure group headers; Blizzard owns secure action state.

## Safety

- Gate inaccessible/secret-capable values before comparison, formatting, indexing, storage or retention.
- Portable documents are bounded trees, not arbitrary graphs.
- Never reparent protected frames, override Blizzard globals, unregister Blizzard events, write CVars or add first-party `OnUpdate` loops.
- Structural party/raid changes require reload.

## Validation

Run all repository validators, Lua 5.1 syntax/tests and deterministic packaging. Report unavailable WoW checks as `NOT-RUN`; never infer taint/combat/visual/performance acceptance from stubs.
