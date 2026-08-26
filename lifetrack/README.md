# LifeTrack

> Know where my time goes, know where my money goes, and know what I should do next.

Flutter + Dart app. SQLite locally for V1 (Firebase/Supabase for cloud sync in V3).
This is currently just the **project scaffold** — folders and install files only.
No screens/logic yet — waiting on the phase docs.

## Folder structure

```
lib/
  core/                 shared, app-wide code
    constants/            colors, sizes, strings, category enums
    theme/                app theme / typography
    utils/                formatters (₱, dates), helpers
    widgets/              shared reusable widgets (buttons, cards, progress bars)
  data/
    models/               Task, Transaction, Account, Asset, Debt, Goal, Skill...
    database/              sqflite setup, schema, migrations
    repositories/          data access layer between DB and features
  features/
    dashboard/             "How am I doing today?" home screen
    schedule/               calendar (day/week/month), categories, tasks     -> Time Management
    money/                  accounts, income/expense transactions
    assets_networth/        assets, liabilities, net worth
    goals/                  savings/skill goals with progress bars
    analytics/              weekly/monthly reports & charts               [V2]
    skills/                 skill tracker (Java, JS, React, Flutter...)    [V2]
    notifications/          reminders, budget/goal alerts                 [V2]
    settings/               PIN/biometric lock, backup/export, privacy
    each feature/*/
      screens/               full pages
      widgets/                feature-specific widgets
      providers/              state management (Provider)
  routes/                 app navigation/route definitions
  main.dart               entry point (to be added)
assets/
  images/, icons/, fonts/
test/
  unit/, widget/
```

## Roadmap mapping (from the plan doc)

| Version | Scope |
|---|---|
| V1 | Dashboard, Schedule, Tasks, Income/Expenses, Accounts, Assets, Net Worth, Goals, Local storage |
| V2 | Analytics, "I'm Free" recommendations, Skill tracking, Notifications, Backup/export |
| V3 | Cloud sync, Multiple devices, Advanced analytics, AI assistant |

## Tech

- **Flutter + Dart**
- **SQLite** (`sqflite`) for local data
- **Provider** for state management
- **Firebase/Supabase** — later, for V3 cloud sync

## Install

```bash
flutter pub get
flutter run
```

## Status

Scaffold only. Waiting for phase docs before writing screens/logic (UI design → database design → Flutter project → dashboard → time management → money → assets/net worth → goals → analytics → testing → APK).
