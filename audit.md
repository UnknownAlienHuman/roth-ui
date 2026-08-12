# Roth_UI audit report

Дата аудита: 2026-03-14
Тип проверки: статический аудит кода + полная ревизия `todo.md`.

## Update after audit

После составления этого отчёта код ушёл дальше:

- legacy `RuneFrame` kill path уже убран;
- group aura recolor переведён на incremental-aware cache, а `/roth aurastats` снова backed runtime counters.

Поэтому разделы ниже про эти два хвоста нужно читать как исторический snapshot. Актуальное состояние смотреть в `history.md` и `todo.md`.

## Итоговый вердикт

Основной pass от `2026-03-13` **в целом выполнен**.

Это не выглядит как ситуация, где todo «написан вперёд», а код отстал. Наоборот: по коду видно, что большая часть верхнего implementation pass действительно приземлилась.

Остаток работы сейчас другой по природе:

1. **live-валидация** того, что уже переписано;
2. **дожим ownership/service границ** в persistence и legacy mirrors;
3. **perf/polish** для group aura stack и mini castbar paths;
4. **дочистка монолитов и старого compat слоя**.

## Что я реально проверил

- Прочитан весь `todo.md` (`2711` строк в исходной версии).
- Просмотрены ключевые runtime-файлы по верхнему backlog-блоку.
- Прогнан синтаксический smoke по всем `.lua` файлам проекта: **92 файла, 0 parse errors**.
- Отдельно проверены old-risk паттерны: `Show = Hide`, `UnregisterAllEvents`, `C_Timer.After`, registry mirrors, castbar ownership, BuffFrame legacy entrypoints.

## Что сделано и подтверждено

См. `history.md`.

Коротко:

- combat-lockdown layout paths для micromenu / stance / bags закрыты;
- irreversible kill path у player/pet Blizzard castbar убран;
- default aura styling path для BuffFrame отрезан;
- action-bar runtime и registry ownership реально вынесены;
- ExtraAction / ZoneAbility уже идут по holder/follower модели;
- frame policy стек реально разрезан;
- safe group aura watch и часть settings/runtime surface уже на месте;
- target/mini castbar runtime действительно переписан.

## Что НЕ сделано

### 1. Runtime-proof нет

Статический код выглядит правильно, но без клиента нельзя закрыть:

- `BuffFrame` secret-taint retest;
- Edit Mode ↔ player castbar retest (`CastingBarFrame.lua:722` / `StopFinishAnims`);
- mini castbar matrix (`targettarget`, `focus`, `boss`);
- vehicle / override / possess / ExtraAction / ZoneAbility переходы;
- save/reload/reset/import/export/migration smoke.

### 2. Persistence ещё не сжата до одного owner

Да, стало лучше. Нет, ещё не закончено.

Причина:

- `config.lua` всё ещё владеет defaults/schema/config-root логикой;
- `core/sv_store.lua` всё ещё крупный owner + transfer + mirror + runtime слой;
- `core/db.lua` всё ещё большой consumer/service слой;
- compatibility surface `ns.cfgSaved` и `db.char` пока живы.

### 3. Group aura stack безопаснее, но не окончательно дожат

- safe watcher есть;
- toggles есть;
- queued recolor path есть;
- но `core/unit_misc_runtime.lua:193-200` всё ещё делает полный harmful aura scan.

То есть это уже не «сломано», но ещё и не финальная perf-модель.

### 4. Monolith split всё ещё большой долг

Самые тяжёлые файлы на текущем снимке:

- `core/lib.lua` — `2351` строка;
- `config.lua` — `1622`;
- `core/sv_store.lua` — `1536`;
- `core/bars.lua` — `1074`;
- `units/player.lua` — `1049`;
- `core/db.lua` — `970`.

## Обновлённый статус ранее найденного хвоста

`RuneFrame` kill/override path уже снят и больше не является активным issue; в текущем коде этот пункт должен считаться закрытым. Оставался в историческом аудите как stale note.

## Что я изменил в рабочем наборе файлов

- создал `history.md` и вынес туда всё, что было отмечено как `done`;
- сохранил полный старый файл как `todo.archive.md`;
- переписал `todo.md` в короткий активный backlog;
- собрал этот отчёт как `audit.md`.

## Практический вывод

Новый `todo.md` теперь должен использоваться как **рабочий backlog**, а не как смесь архива, заметок и старых гипотез.

Если продолжать работу дальше, правильный порядок такой:

1. закрыть live verification;
2. добить persistence ownership;
3. решить, оставлять ли full harmful scan в group aura runtime;
4. уже потом резать монолиты и чистить media/compat слой.
