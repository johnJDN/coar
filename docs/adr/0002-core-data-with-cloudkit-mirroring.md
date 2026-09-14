# 0002. Core Data with NSPersistentCloudKitContainer for app-authored data

**Status:** accepted (2026-09-09). Supersedes the earlier SwiftData + CloudKit choice.

## Context

Data the user authors in-app (habits and check-ins, foods/meals/log entries, exercises,
plans, workouts, body weight, progress photos) must be local-first (fast, works offline
in a gym) and must survive device loss and appear on the user's other Apple devices.
There is no account system; the Apple ID is the identity.

SwiftData was chosen while the UI was SwiftUI, chiefly for `@Query`. With UIKit
(ADR 0001) that advantage disappears, and the UIKit-native pipeline is
`NSFetchedResultsController` → diffable data source snapshots.

Sleep and steps are *not* app-authored: they are read live from HealthKit, which has its
own encrypted iCloud sync, and Apple's guidelines forbid storing HealthKit data in
iCloud/CloudKit.

Supabase (or any server) was considered and deferred: a single-user app needs no
server-side data access, and the first server need will be a thin edge function proxying
AI calls, not a database.

## Decision

- Persistence is Core Data via `NSPersistentCloudKitContainer`, mirroring to the user's
  private CloudKit database.
- The model is written to CloudKit's constraints from day one: every attribute optional
  or defaulted, every relationship optional with an inverse, no unique constraints, no
  ordered relationships (store an explicit `sortOrder`).
- HealthKit-sourced data (sleep, steps) is never persisted in the store. Body weight is
  stored in the app and also written to HealthKit.
- Progress photos use external binary storage so CloudKit syncs them as assets.
- No Supabase or other backend until a feature needs a server.

## Consequences

- Multi-device visibility is eventual (typically seconds), not instant; UI must tolerate
  a brief stale window.
- Data is tied to the Apple ecosystem; a cross-platform future would add a server-side
  sync layer rather than replacing the local store.
- Progress photos consume iCloud quota; a "keep photos on this device only" option is
  a likely later addition.
- Schema changes must be additive (lightweight migration) to stay CloudKit-compatible.
