# Admin & IT Support Panel

Distinct from day-to-day business administration (user management, codes & parameters, business profile), this system includes a **separate technical panel** intended only for IT/support staff — not business users. This split matters: it means the people managing sales reps and chart-of-accounts codes are never one click away from tools that touch raw data or infrastructure.

> A note on scope: this document describes what these tools do and why they exist. It deliberately does not include the literal implementation of the more powerful admin procedures (see "What's intentionally left out" below) — some of what lives in this panel is capable of destructive, tenant-wide data operations, and publishing exact executable specifications for that kind of tooling isn't something I'd want to put in a public repo regardless of confidentiality status, since the same pattern could exist in other live systems.

## Query console (SA15)

A restricted, admin-only (`#zadmin = 1`) raw query interface supporting Select / Insert / Update / Delete / Execute operations directly against the database, plus two higher-level operational tools:

- **Business data reset** — clears a business's transactional data (either everything, or a specified list of tables), typically used when re-running an onboarding pilot or clearing test data before go-live
- **Business data cloning** — copies a set of tables from one business unit to another, re-pointing the business-scope key — used to fast-track onboarding a new company by starting from an existing one's configuration (chart of accounts, codes, item master, etc.) rather than re-entering it all from scratch

Results from Select queries are capped and exportable to CSV/Excel for ad-hoc investigation without needing separate DB tooling access.

## Database backup (SA16)

An admin-only, on-demand backup trigger: runs a compressed backup and streams it directly to the browser as a timestamped file (`{business}_{YYMMDD}_{HHMMSS}.bak`). Combined with scheduled automated backups at the infrastructure level, this gives IT staff a manual "backup right now, before I do something risky" option — which matters a lot when you're about to run one of the tools above.

## Server monitoring (SA18)

A dashboard surface for IT staff to check system/server health without needing separate infrastructure-monitoring tooling or server access.

## Why this separation matters

- **Blast radius control.** Business admins (AD-series screens) can manage users, codes, and parameters — but never touch raw data or infrastructure. IT/support staff (SA-series screens) have that power, but it's gated behind `#zadmin`, not just "logged in."
- **Operational tools embedded, not external.** Rather than requiring IT staff to have direct database credentials for routine tasks (cloning a business for onboarding, resetting pilot data), those operations are wrapped in application-level tools — which means every use of them is still subject to the application's own audit trail.
- **Backup-before-danger workflow.** Having on-demand backup live in the same panel as the destructive tools isn't an accident — it's designed so "back it up first" is a one-click action right next to the tools that could need it.

## What's intentionally left out here

The actual stored procedures behind business-wide data reset and cloning use dynamic SQL to iterate every table in the database and act on rows matching a business ID — genuinely useful for legitimate onboarding/reset workflows, but also exactly the shape of a tool that could delete or exfiltrate an entire tenant's data if it were ever exposed without proper access control. That implementation detail stays out of this repo.
