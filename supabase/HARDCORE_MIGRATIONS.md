# Hardcore SQL migrations — squash plan

This document orders every Hardcore-related migration and explains how to bootstrap a **new** database vs. maintain an **existing** production database.

## Quick reference

| Scenario | What to run |
|----------|-------------|
| **Brownfield (prod already live)** | Keep incremental files; only apply migrations you have not run yet. Never re-run `schema_hardcore.sql` wholesale. |
| **Greenfield (after `schema.sql` + economy/security)** | Run the ordered chain below, **or** run `schema_hardcore.sql` then the “RPC chain” files in §3. |
| **Client-only rule changes** | Usually `room_game_tuning` JSON + `app_economy_config` — no SQL unless economy RPCs change. |

## 1. Core incremental chain (run in this order)

These files build the live Hardcore arena end-to-end.

| # | File | Purpose |
|---|------|---------|
| 1 | `migration_hardcore_universe.sql` | Room type allowlist, trophy gate on `join_game_room`, economy allowlists |
| 2 | `migration_hardcore_rules_v2.sql` | `hardcore_points`, cooldown column, queue table, kill claims, join/queue RPCs |
| 3 | `migration_hardcore_arena_package_v2.sql` | Arena tuning JSON defaults, economy knobs |
| 4 | `migration_hardcore_singleton_always_open.sql` | Single always-open room, `_hardcore_max_players`, `join_hardcore_universe` |
| 5 | `migration_hardcore_admin_seat_exempt.sql` | Admin does not consume a seat |
| 6 | `migration_hardcore_seat_release.sql` | Release prey seat on kill |
| 7 | `migration_hardcore_match_afk_idle.sql` | Match AFK idle overrides |
| 8 | `migration_hardcore_passive_mode_economy.sql` | **Current** kill (active only) + passive elim (5m, no diamonds) |
| 9 | `migration_admin_hardcore_live_ops.sql` | `get_admin_hardcore_live_ops` dashboard RPC |
| 10 | `migration_hardcore_lobby_status.sql` | Public lobby card: seats + queue count |

## 2. Patches & ops (after core chain)

Apply when needed; safe to skip on fresh installs if a later file already includes the behaviour.

| File | Purpose |
|------|---------|
| `migration_hardcore_rank_points.sql` | HC win → rank points hook |
| `migration_hardcore_rank_points_7.sql` | Default +7 HC rank points |
| `migration_hardcore_victory_live_announce.sql` | Lobby banner on HC win |
| `migration_hardcore_announce_skip_game_trial.sql` | Skip announce for game trial |
| `migration_hardcore_purge_no_recurse.sql` | Heartbeat / ghost seat purge |
| `migration_hardcore_always_accept_joins.sql` | Join acceptance hardening |
| `migration_hardcore_test_no_heartbeat_purge.sql` | Arena test heartbeat exception |
| `migration_admin_reserved_hardcore.sql` | Reserved admin seat behaviour |
| `migration_hardcore_admin_opt_in_seat.sql` | Admin opt-in seat |
| `migration_member_current_radius.sql` | Member radius sync (HC softcap hint) |

## 3. Arena Test & Game Trial (isolated — not live arena)

| File | Purpose |
|------|---------|
| `migration_hardcore_arena_test.sql` | Isolated test room + harness RPCs |
| `migration_hardcore_arena_test_parity.sql` | Parity with live rules |
| `migration_hardcore_arena_test_reset_delete_where.sql` | Test reset helper |
| `migration_game_trial_*.sql` | Sim players, economy bypass, cooldown overrides |

**Rule:** Game Trial and Arena Test must never be required for live player traffic.

## 4. Consolidated file: `schema_hardcore.sql`

Contains:

- Profile columns (`hardcore_points`, `hardcore_cooldown_until`)
- Tables (`hardcore_queue`, `hardcore_kill_claims`)
- Default `room_game_tuning` row for `hardcore`
- Latest economy RPCs (`apply_hardcore_kill_reward`, `apply_hardcore_passive_elim`)

Does **not** include (still from incremental chain):

- `join_hardcore_universe` / `get_hardcore_queue_status` / `leave_hardcore_queue`
- `_ensure_hardcore_singleton` / seat occupancy helpers
- `get_admin_hardcore_live_ops`
- Victory claim / cooldown on win paths inside `apply_match_result`

After `schema_hardcore.sql` on greenfield, run at minimum:

1. `migration_hardcore_rules_v2.sql` (queue + join RPCs) — skip duplicate table DDL if already applied
2. `migration_hardcore_singleton_always_open.sql`
3. `migration_admin_hardcore_live_ops.sql`

## 5. Squash strategy for production

**Do not** delete incremental files from git until:

1. `schema_hardcore.sql` + documented RPC chain verified on a staging clone.
2. A migration audit table (or Supabase migration history) records what prod has applied.
3. One final “squashed” migration is generated via `pg_dump --schema-only` diff, not manual merge.

Recommended squash steps:

1. Clone prod → staging.
2. Apply any missing incremental files; run smoke tests (join, queue, kill, passive elim, win, cooldown).
3. `pg_dump -s` Hardcore functions/tables → new `migration_hardcore_squashed_YYYYMMDD.sql`.
4. Mark incremental files as archived in this README; new environments use squashed + base schema only.

## 6. Live rule summary (must match client)

| Mode | Condition | Kill ♦ | Elim ♦ | Cooldown |
|------|-----------|--------|--------|----------|
| **Passive** | alive &lt; min-alive (default 6) | 0 | 0 | 5 minutes |
| **Active** | alive ≥ min-alive | +4 (config) | −15 (config) | ~1 hour on win/elim |

Victory: radius ≥ 600 (size-only, no PvP% gate in live).

## 7. Client ↔ SQL contract

| Client surface | SQL / config |
|----------------|--------------|
| `joinHardcoreUniverse()` | `join_hardcore_universe` |
| `getHardcoreQueueStatus()` | `get_hardcore_queue_status` |
| Lobby Hardcore card seats/queue | `get_hardcore_lobby_status` |
| `applyHardcoreKillReward()` | `apply_hardcore_kill_reward` |
| `applyHardcorePassiveElim()` | `apply_hardcore_passive_elim` |
| `HardcoreRules.arena` | `room_game_tuning.config.hardcoreArena` |
| Kill/elim amounts | `app_economy_config` keys `rewardHardcoreKill`, `penaltyHardcore` |

When changing rules, update **both** SQL RPCs and `lib/game/config/hardcore_rules.dart` comments, then `how_to_play_hardcore_desc` in `lang_service.dart`.
