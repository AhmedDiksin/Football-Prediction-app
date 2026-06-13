# Architecture

## Runtime Modes

- `APP_MODE=demo`: app uses `DemoPredictorRepository`, seeded in memory. This is the default for local development and emulator tests.
- `APP_MODE=supabase`: app uses Supabase Auth, Postgres RPCs, and Realtime streams.

## Data Flow

1. Supabase Cron invokes `sync-worldcup`.
2. The function polls provider APIs once for all users.
3. Normalized teams and matches are upserted into Postgres.
4. Finished matches trigger `recalculate_match_scores`.
5. Clients stream `matches`, `predictions`, and leaderboard RPC refreshes.

Phones never call football providers directly. This protects free API quotas and keeps provider keys private.

## Scoring

- Exact score: 3 points.
- Correct winner or correctly predicted draw: 1 point.
- Wrong outcome: 0 points.
- Predictions are editable only before kickoff.
- Score recalculation is idempotent so provider corrections can safely rerun.

## Security

All public tables have RLS enabled. The authenticated user can write their profile, membership, and own unlocked predictions. Official scores and calculated scores are written only by service-role Edge Functions.

## Testing Strategy

- Unit tests cover scoring, locks, ranking, and provider normalization.
- Widget tests cover the dark prediction UI.
- Integration tests run full user flows on Android emulator in demo mode.
- Supabase SQL is kept in migrations for repeatable setup.
