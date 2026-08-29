# Roth UI agent guide

Current production target: Retail/Midnight `12.1.0`, Interface `120100`, Blizzard build `12.1.0.69497`, oUF `14.0.2+`.

Authority order:

1. Current repository code and TOCs.
2. Pinned Blizzard source/generated API documentation.
3. oUF `14.0.2` source.
4. `UnknownAlienHuman/wow-addon-engineering-kb`.
5. Runtime evidence from the named client build.

Hard boundaries:

- `core/aura_runtime.lua` is the only first-party managed-aura owner.
- Do not add raw aura scans or addon-owned `UNIT_AURA` state.
- Do not poll casts outside oUF.
- Do not branch, compare, format, serialize or index secret-capable values before access gating.
- Do not restore replacement action buttons, LibActionButton, LibKeyBound or `oUF_Smooth` without a new measured design review.
- Do not register a second Blizzard Settings category owner.
- Do not write SavedVariables root globals outside `core/config_persistence_owner.lua`.
- Do not add permanent first-party `OnUpdate`; the active-drag worker is the sole approved exception.
- Do not override Blizzard globals or reparent/unregister protected Blizzard frames.

Before merge run:

```bash
python3 tools/validate_addon.py
lua5.1 tests/test_target_castbar.lua
lua5.1 tests/test_aura_lazy.lua
python3 tools/package_release.py
```

Do not call a build client-verified without attaching the complete in-game matrix and taint/profiler evidence.
