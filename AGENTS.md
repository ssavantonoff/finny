# Finny — Agent Instructions

## Project

Finny is an offline-first Flutter application for children aged 7–11 that teaches basic financial literacy through a virtual pet.

The project is developed by a team of two developers with separate Codex agents.

The repository is the source of truth for implementation.
Detailed product and architecture documentation belongs in `docs/`.

## Before making changes

Before implementing a substantial task:

1. Inspect the current repository state.
2. Read relevant documentation in `docs/`.
3. Inspect existing models, services, repositories, and tests.
4. Reuse the existing architecture instead of creating parallel systems.
5. Do not change established product rules unless the task explicitly requires it.

## Technical direction

Primary stack:

- Flutter
- Dart
- Riverpod
- GoRouter
- SQLite / sqflite
- JSON assets for game and educational content

The MVP is offline-first.

Do not add without an explicit task:

- backend
- Firebase
- cloud synchronization
- user accounts
- AI features
- advertising
- social features
- real payments
- push notifications

Prefer the simplest solution that fully satisfies the current requirements.

## Architecture

Intended dependency direction:

UI / Features
→ State / Controllers
→ Domain Services
→ Repositories
→ SQLite / JSON

UI must not directly mutate core game state.

UI code must not directly:

- change wallet balance
- move savings
- reward tasks
- progress periods
- change pet development
- write directly to SQLite

These operations must go through the appropriate service/repository layer.

## Data ownership

SQLite stores runtime player state, including:

- profiles
- pet state
- wallet
- savings
- current period
- transactions
- inventory
- task progress
- pet progression

JSON assets store game content, including:

- tasks
- shop items
- savings goals
- period definitions
- glossary entries

Do not hardcode game content into UI widgets when it belongs in content data.

## Profiles

The application supports two local profile types:

- NORMAL
- DEMO

All runtime state must be isolated by profile ID.

Resetting DEMO data must never affect NORMAL profile data.

## Economy rules

All balance changes must be explainable and traceable.

Every balance mutation should have a transaction/source.

Negative wallet balance must not be possible.

Remaining wallet money carries into later periods.

A large balance earned through low spending is not itself considered a bug.

Exact economy values are configurable and are not final until playtesting.

## Product principles

Finny should teach through consequences rather than punishment.

Financial mistakes must be recoverable.

Do not use:

- shame
- fear
- pet death
- severe illness as punishment
- manipulative FOMO

Optional purchases are not inherently bad.

A player can buy wants and still demonstrate good financial behavior if needs, planning, and savings are handled responsibly.

## Scope control

Do not add new gameplay systems unless they are explicitly requested.

If you notice a useful idea:

1. mention it in the final report;
2. explain its value;
3. do not implement it automatically.

Do not overengineer the project for hypothetical future requirements.

## Collaboration

Two developers and two Codex agents work in this repository.

Avoid broad unrelated refactors that increase merge conflicts.

Preserve shared service/model contracts unless the current task requires changing them.

If a shared contract must change:

- explain why;
- update its usages;
- update relevant tests and documentation.

Do not duplicate an existing service or state system to solve a local feature problem.

## Git

Before changes, inspect:

- current branch
- git status
- existing relevant code

Do not commit:

- secrets
- API keys
- signing keys
- keystores
- build output
- machine-specific temporary files

Do not rewrite unrelated existing history.

## Validation

Before declaring a coding task complete, run all relevant checks.

At minimum when applicable:

`flutter analyze`

`flutter test`

Also run targeted tests for changed modules.

If a check cannot be run, state that explicitly.

Do not silently ignore failing tests or analyzer errors.

## Testing priorities

Core financial logic requires strong tests, especially:

- budget validation
- purchases
- savings
- transactions
- period transitions
- one-time rewards
- profile isolation
- persistence
- pet progression

Bug fixes should include a regression test when practical.

## Documentation

Keep documentation synchronized with meaningful architectural changes.

Do not duplicate large documentation sections inside this file.

Use this file for stable rules and navigation only.

## Completion report

After a substantial task, report:

1. what changed;
2. important files changed;
3. tests/checks run;
4. unresolved risks;
5. anything intentionally left out of scope.
