# Audit Trail System

Every business can independently choose how much audit logging it wants — this isn't an all-or-nothing switch, because logging everything at maximum detail has a real storage and performance cost, and not every business needs that level of forensic detail.

## Three configurable audit levels

Set per business (`zbusiness.xisaudit`), the system supports three tiers:

| Level | Behavior |
|---|---|
| **Basic** | No audit records written at all — for businesses that don't need this overhead |
| **Moderate** | Logs a **summary** entry per action (`xlogs`) — who did what, when, on which record |
| **Advance** | Logs both the summary (`xlogs`) *and* **field-level detail** of what changed (`xlogsdt`) — a full before/after trail |

This tiered design means the audit system's cost scales with what a business actually needs, rather than forcing every deployment to pay for full field-level logging whether they use it or not.

## What gets captured

Every auditable action records:
- The business (`zid`) and acting user (`zemail`) / employee (`xstaff`)
- A timestamp
- The screen/action that generated the entry
- (Advance tier only) the specific field-level changes

## The audit trail screen itself (SA17)

The review screen lets an admin filter logged activity by date range, user, employee, and audit type, then:

- **View** — pulls the top 1,000 matching records, server-side paginated, ordered by time
- **Print** — generates a formal report (`xlogssm.rpt` for summary-level, `xlogsdt.rpt` for detail-level), parameterized by the same filters (business, date range, user, employee)
- **Count** — a quick count-only query for the same filter set, without pulling full records
- **Delete** — allows purging old audit records outside a retention window, scoped to the same filters

## Why this design holds up

- **Tiered cost control.** A small business doesn't pay the storage/performance cost of Advance-level logging if Basic or Moderate is all it needs — but the option to go deeper is a business-level configuration change, not a code change.
- **Consistent filter vocabulary.** View, Print, Count, and Delete all use the exact same filter logic (date range, user, employee) — so there's no risk of the "what you saw" and "what you printed" or "what you deleted" disagreeing with each other, because it's the same query pattern applied four ways.
- **Separation of summary vs. detail.** Keeping `xlogs` (summary) and `xlogsdt` (field-level detail) as separate tables/tiers means the common case — "who touched this record and when" — stays fast and cheap to query, while the expensive full-detail trail is only paid for when a business actually opts into it.
