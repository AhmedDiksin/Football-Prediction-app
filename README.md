# World Cup Friends Predictor

A Flutter Android app for friends to predict FIFA World Cup matches, score points, and watch Supabase-backed leaderboards update near real time.

The repo is designed to be public and rebuildable. Real Supabase and provider credentials belong in local `.env`, Supabase secrets, and GitHub secrets only.

## What It Includes

- Flutter Android app with demo mode and Supabase mode.
- Email/password auth, profile setup, match predictions, leagues, invite codes, scoring, and leaderboards.
- Supabase migrations with RLS, RPCs, realtime-ready tables, and demo seed data.
- Edge Functions for World Cup provider sync and demo seeding.
- Unit/widget/integration test entrypoints, including emulator flow tests.

## Quick Start

1. Install Flutter and Android tooling from [scripts/setup_android_toolchain.md](scripts/setup_android_toolchain.md).
2. Use the default `APP_MODE=demo` for local UI/testing without Supabase.
3. Run:

```powershell
flutter pub get
flutter run -d android
```

## Supabase Setup

1. Create a Supabase project.
2. Install and login to the Supabase CLI.
3. Link the project:

```powershell
supabase link --project-ref <your-project-ref>
supabase db push
```

4. Set secrets:

```powershell
supabase secrets set FOOTBALL_DATA_TOKEN=<token>
supabase secrets set API_FOOTBALL_KEY=<optional-token>
supabase secrets set API_FOOTBALL_WORLD_CUP_LEAGUE_ID=<optional-league-id>
supabase secrets set THESPORTSDB_KEY=123
```

5. Deploy functions:

```powershell
supabase functions deploy sync-worldcup
supabase functions deploy seed-demo-worldcup
```

6. Run the app with public client credentials passed as Dart defines:

```powershell
flutter run -d android `
  --dart-define=APP_MODE=supabase `
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

## Testing

Local checks:

```powershell
.\scripts\run_local_checks.ps1
```

Android emulator flow:

```powershell
.\scripts\run_emulator_flow_tests.ps1
```

The integration tests run against demo mode by default so they do not depend on live football APIs.

## GitHub Repo

Current public repo target:

```text
https://github.com/AhmedDiksin/Football-Prediction-app
```

If publishing from a fresh machine:

```powershell
git init
git add .
git commit -m "Initial World Cup predictor app"
git branch -M main
git remote add origin https://github.com/AhmedDiksin/Football-Prediction-app.git
git push -u origin main
```

## Data Sources

- `football-data.org`: primary World Cup fixtures/scores source. Free tier includes Worldcup, with delayed scores.
- API-Football: optional fresher live score override when a key and league ID are configured. Free tier is request-limited.
- TheSportsDB: optional team artwork/badges only.
