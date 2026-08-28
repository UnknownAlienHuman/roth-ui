# Roth UI current status

Status date: 2026-08-28

This file is the authoritative short status for the Retail 12.1 migration. `todo.md`, `todo.archive.md`, `history.md`, and the older sections of `audit.md` contain historical findings and hypotheses; verify them against current source before implementing them.

## Source-validated Retail 12.1 integration

- Interface metadata is `120100`; author remains Neomorph.
- Addon version is `3.3.8-v57.8-B4.1`.
- The verified Blizzard UI source baseline is build `12.1.0.69497`, commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`.
- oUF `14.0.2` or newer is required for managed unit auras.
- The settings initialization order is repaired: `settings_actions.lua` loads before `settings_general.lua`.
- Active target, focus, party and raid aura rendering is routed through oUF managed `AuraContainer` objects.
- Healer aura watch uses managed `includeSpellIDs` plus `isFromPlayerOrPlayerPet` filtering.
- The own-caster candidate-filter upgrade is applied once per managed group rather than forcing another full update on every refresh.
- The obsolete raw `core/group_aura_watch.lua` implementation remains available for history but is excluded from the TOC runtime graph.
- Raw harmful-aura inference is removed from the active health-frame color path.
- Roth UI's obsolete `UNIT_AURA` callback detaches itself without unregistering unrelated oUF handlers.
- Static CI validates the TOC/XML load graph, exact metadata, order invariants, retired-module exclusion, managed-aura boundary, all Lua syntax, whitespace and merge markers.

The repository owner explicitly directed this source/static-validated changeset to be integrated into `main`. That integration status must not be interpreted as completed Retail-client validation.

See [`MIDNIGHT_12_1_MIGRATION.md`](MIDNIGHT_12_1_MIGRATION.md) for the implementation boundary and required client matrix.

## Reclassified historical findings

### `todo.md` item 0.3: `GetCVarBool`

The statement that global `GetCVarBool` was removed in WoW 12.x is not supported by the pinned live source. Blizzard 12.1 UI code still calls `GetCVarBool`, while `C_CVar.GetCVarBool` is also available through the current CVar API.

Do not change the action-button click behavior solely on the basis of that stale todo entry. Any CVar wrapper cleanup should be a separate, source-backed change and must be validated with click-on-down, bindings and secure action buttons in the client.

### `todo.md` item 0.7: party/raid `UNIT_AURA` cleanup

The Retail 12.1 guard removes only Roth UI's legacy recolor callback via oUF's per-function `UnregisterEvent`. This closes that specific aura callback path. It does not constitute complete proof of every header park/rebuild lifecycle; threat and header behavior still belong in the client matrix.

## Intentionally not enabled

- `Roth_UI.disableProtectedActionBarOwnership` remains enabled.
- `cfg.bars.secureOwnerBars` remains disabled.
- The experimental LibActionButton owner path is not promoted without combat, paging, vehicle, override, possess and binding evidence.

## Still open

- Retail client validation and taint/secret-value evidence.
- Existing action-bar/dock runtime issues.
- Single-owner mover consolidation.
- Persistence owner consolidation.
- Existing target castbar, orb/unit-value and SavedVariables runtime issues tracked in GitHub.
- Removal of dormant legacy aura compatibility code from `core/lib.lua` after the managed migration is proven in-client.

## Runtime-verification gate

Do not describe the addon or a release as runtime-verified until all client checks in `MIDNIGHT_12_1_MIGRATION.md` pass and the evidence is attached to the corresponding commit, issue, pull request or release record.
