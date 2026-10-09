# SG Tutor Match — Namecheap PHP/MySQL migration staging

This branch is isolated from `main`. It does not change the live GitHub Pages site and is not a deployment.

## Target
- Test first in a separate Namecheap directory/database.
- Production destination after acceptance: `public_html/tutormatch/`.
- End state: no Supabase Auth, database, Storage, or Edge Functions.

## Current migration inventory
- Frontend `index.html`: Supabase client/config; parent request submission; tutor profile submission; tutor resume upload; match-interest and case status reads.
- Admin `admin.html`: Supabase Auth and `platform_admins`; case/note CRUD; parent/tutor status updates; signed resume URLs; internal scores; `smartmatch-run` Edge Function; `admin_confirm_match_case` RPC.

## Mandatory migration order
1. Inspect and record the actual MySQL schema before changing existing data.
2. Build PHP/PDO API and native admin auth in a separate test directory/database.
3. Migrate parent/tutor forms and data reads/writes.
4. Migrate cases, notes, status transitions, internal scoring and dashboard.
5. Port SmartMatch and confirmation logic to PHP transactions; enforce unique parent/tutor pair to prevent duplicates.
6. Migrate resumes to private storage with authenticated download.
7. Test subject/level canonicalization (e.g. H2 Chemistry and JC2/A-Level aliases).
8. Search final frontend/backend for all Supabase dependencies.
9. Only after tests and record-count reconciliation, deploy to the production directory with a rollback backup.

## Safety
Do not copy test credentials into this repository. Do not overwrite `main` or the current Namecheap site while migration is incomplete. Any endpoint not implemented must fail explicitly rather than pretending the feature is migrated.
