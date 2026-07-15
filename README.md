# Enterprise Accounting Engine — SQL Design Highlights

**Role:** ERP Architect / Database Designer
**Origin:** Personal design work — a multi-business, multi-profile ERP accounting & inventory engine (T-SQL / SQL Server)

This repo contains selected, working SQL Server stored procedures from a larger enterprise accounting blueprint I designed independently. It's not the full document — just the pieces that best show core financial-engine design: fiscal period logic, double-entry voucher posting, year-end closing, and multi-method inventory costing.

---

## What's in here

| File | What it does |
|---|---|
| [`sql/FA_GetYearPeriod.sql`](./sql/FA_GetYearPeriod.sql) | Resolves fiscal year & period from a transaction date, supporting a configurable fiscal-year offset (non-January year starts) |
| [`sql/FA_VoucherPost.sql`](./sql/FA_VoucherPost.sql) | Posts a balanced journal voucher into the GL balance table, enforcing that debits and credits are validated before posting |
| [`sql/FA_VoucherUnPost.sql`](./sql/FA_VoucherUnPost.sql) | Reverses a posted voucher transactionally (with rollback on failure) — lets accountants safely correct mistakes without orphaned balance rows |
| [`sql/FA_YearEnd.sql`](./sql/FA_YearEnd.sql) | Year-end close: rolls forward Asset/Liability balances, nets Income/Expenditure into Retained Earnings, and opens the new fiscal year |
| [`sql/Fn_GetTrn.sql`](./sql/Fn_GetTrn.sql) | Race-condition-safe transaction number generator, scoped per business + per screen |
| [`sql/Fn_InventoryCosting.sql`](./sql/Fn_InventoryCosting.sql) | Inventory issue costing engine supporting **FIFO**, **LIFO**, and **Weighted Average** — consumes open receipt lots and computes issue cost dynamically |

## Design principles behind these procedures

- **Multi-business scoping.** Every table and procedure is scoped by a business ID (`@zid`), so the same schema and logic serve multiple legal entities from one database.
- **Balanced-entry enforcement.** Vouchers can't post unless header status confirms a balanced debit/credit set — `FA_VoucherPost` checks this before touching the GL balance table.
- **Reversible operations.** Posting and unposting are both explicit, transactional operations — nothing is ever silently overwritten; `FA_VoucherUnPost` wraps its work in `BEGIN TRY...BEGIN CATCH` with rollback on error.
- **Configurable fiscal calendars.** `FA_GetYearPeriod` supports businesses whose fiscal year doesn't start in January, via a per-business offset stored in the accounting defaults table.
- **Method-agnostic inventory costing.** Rather than hardcoding one costing method, `Fn_InventoryCosting` branches on a per-business setting and consumes open lots (`imtrn`) in the correct order for FIFO (oldest first), LIFO (newest first), or blends them for Weighted Average — all while tracking partially-consumed lots via a running-use column.

## Note

This is a curated excerpt, not the full blueprint. Screen designs, complete database schema, and the remaining ~30 stored procedures (purchase/sales GL interfaces, batch processing, inventory adjustments, etc.) are part of the original working document and aren't published here.
