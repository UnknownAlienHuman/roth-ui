# Roth UI dependency and event graph — 3.4.3

## Critical load dependencies

| Consumer | Must already be loaded | Purpose |
|---|---|---|
| Frame policy and oUF contract | namespace, safety and forbidden-aspect owners | access gates and shared combat work |
| Persistence root store | config owner and runtime-state service | one canonical root boundary |
| Transfer/control plane | strict safety copy, root store and reconcile service | detached export and reversible import/reset |
| Orb persistence owner | orb defaults/text controller and canonical roots | migrate templates and character orb state at its bounded lifecycle boundary |
| Unit styles | value/aura/cast helpers and mini scaffold | frame construction without duplicate runtime owners |
| Action presentation | unit styles, mover runtime and frame policy | additive Blizzard-button styling and retained layouts |

## Bounded paths

| Request | Authoritative path | Completion |
|---|---|---|
| Combat-sensitive mutation | keyed `framePolicy.DeferUntilOutOfCombat` | drain once outside combat and unregister listener |
| Foreign-frame suppression | capture → apply alpha/mouse → rollback partial failure | retain state only while unresolved/suppressed |
| Next-frame layout refresh | keyed `defer.RunNextFrame` | newest callback runs once |
| Export | strict detached root copy → encode | no live mutation |
| Import | validate → snapshot → replace → reconcile | accept or rollback snapshot |
| Factory reset | snapshot → clear roots → reload | rollback if reload fails |
| Structural party/raid setting | persistence + reload contract | no live secure-header rebuild |

Blizzard retains secure action state; oUF retains unit/header/element lifecycle. Tests and build tooling are excluded from runtime packages.
