# Screen Specification: SO14 — Direct Invoice

A complete, real screen specification from the blueprint — included as a representative example of how every transactional screen in the system is documented and built: header fields, item-detail grid, and explicit button-level business logic.

Direct Invoice is a "walk-up" sales invoice — no prior sales order required — used for immediate, single-step billing.

---

## Header screen

**Buttons:** Add, Update, Delete (standard CRUD) · Confirm Invoice, Print Invoice, Print Challan (custom) · Top/Previous/Next/Bottom (navigation)

| Field | Caption | Input Type | Validation | Default | Notes |
|---|---|---|---|---|---|
| `xdornum` | Invoice Number | Search | Required | — | Auto-generated transaction number |
| `xdate` | Invoice Date | Calendar | Required | Today | |
| `xbuid` | Business Unit | Conditional | Required | — | Auto-selected and locked if the business has only one unit; otherwise a picker |
| `xcus` | Customer | Search | Required | — | |
| `xwh` | Store/Warehouse | Search | Required | — | |
| `xref` | Reference | Text | — | — | |
| `xlineamt` | Sub Total | Disabled (calculated) | Required | 0.00 | |
| `xdiscamt` | Discount (Amt) | Decimal | Required, `0 ≤ x ≤ xlineamt` | 0.00 | |
| `xtotamt` | Total Amount | Disabled (calculated) | Required | 0.00 | `= xlineamt − xdiscamt` |
| `xstatus` | Status | Disabled | Required | "Open" | Header workflow state |
| `xstatusim` | Inventory Status | Disabled | Required | "Open" | Tracks whether inventory has been committed |
| `xstatusjv` | GL Status | Disabled | Required | "Open" | Tracks whether the GL voucher has posted |
| `xvoucher` | GL Voucher | Conditional link | — | — | Only shown once `xstatusjv = "Confirmed"` — clicking it deep-links to the actual GL voucher (FA17) |
| `xstaff` | Employee | Hidden | Required | Session user | |
| `xnote` | Note | Text area | — | — | |
| `xtotcost` | COGS | Hidden | Required | 0.00 | Cost of goods sold, computed at confirm time |
| `xtype` | (internal) | Hidden | Required | "Direct Invoice" | Distinguishes this from order-based invoices sharing the same underlying table |

## Header button logic

**Add**
1. Validate required fields
2. Generate the invoice number via the shared transaction-numbering service: `xdornum = Fn_GetTrn(zid, "SO14")`
3. Save

**Update**
1. Only enabled while `xstatus = "Open"`
2. Re-check status server-side at submit time (not just client-side) — if it's no longer "Open," reject with an error rather than trusting the client's cached state
3. Re-validate required fields
4. Recompute totals from the detail lines and persist

**Delete**
1. Only enabled while `xstatus = "Open"`
2. Server-side status re-check, same as Update
3. Confirmation prompt before proceeding
4. Delete detail lines first, then the header (referential order)

**Confirm Invoice** — the core workflow transition, with real safeguards:
1. Only enabled while both `xstatus = "Open"` AND `xstatusim = "Open"`
2. Server-side re-check of both statuses at submit time
3. Reject if there are zero detail lines ("Please add item!")
4. Full required-field re-validation before allowing confirmation
5. Reject if the invoice date no longer matches today's date server-side — prevents a stale/backdated invoice from being confirmed after sitting open
6. **Inventory availability check** — for every item on the invoice, sum the requested quantity and run it through a shared stock-check routine (`im_process_stock_check`) against the selected business/warehouse. If any item is short, the confirm action is blocked and the user sees a breakdown per item (requested vs. actual available quantity) rather than a generic error
7. Final "Are you sure?" confirmation
8. On confirm, a single stored procedure (`SO_ConfirmInvoice`) handles the actual state transition — inventory deduction and GL posting are triggered from this one call rather than being orchestrated ad hoc in the UI layer
9. Reload the record to reflect the new state

**Print Invoice / Print Challan**
Both route through the same [report resolution mechanism](./MENU_AND_SCREEN_ARCHITECTURE.md#report-rendering-mechanism) as every other report in the system — business-specific report file if one exists, shared default otherwise.

---

## Item detail grid

| Field | Caption | Input Type | Validation | Default | Notes |
|---|---|---|---|---|---|
| `xrow` | (internal) | Hidden | Required | Next sequence | `= max(xrow) + 1` for this invoice |
| `xitem` | Item | Search | Required | — | |
| `xunit` | Unit | Virtual/Disabled | — | Auto-filled | Pulled from the item master based on selected item |
| `xqty` | Quantity | Decimal | Required, `> 0.00` | — | |
| `xrate` | Rate | Decimal | Required | Auto-filled, editable | Defaults from item master pricing but the user can override it — pricing flexibility is intentional here, not a gap |
| `xlineamt` | Line Amount | Disabled (calculated) | Required | — | `= xqty × xrate` |
| `xrategrn` | COGS Rate | Hidden | Required | 0.00 | Populated at confirm time from inventory costing |
| `xnote` | Note | Text area | — | — | |

## Item detail button logic

**Add**
1. Only enabled while the parent invoice is still "Open"
2. Server-side status re-check
3. Validate the line
4. Insert the detail row
5. Recompute and persist the header's running totals immediately — the header total is never allowed to drift out of sync with its detail lines, even mid-edit

**Delete**
1. Only enabled while the parent invoice is "Open"
2. Server-side status re-check
3. Remove the line
4. Recompute and persist header totals

---

## What this example illustrates about the system as a whole

- **Every status check happens twice** — once to control what the UI shows, and again, independently, at the moment of submission. The client-side state is never trusted as the source of truth for whether an action is actually allowed.
- **Totals are recalculated from detail lines, not accumulated** — every add/delete on the item grid triggers a full re-sum of the header total from the detail table, rather than incrementing/decrementing a running number. This avoids an entire class of rounding/drift bugs that incremental totals are prone to.
- **Business logic that spans multiple concerns (inventory + GL) is centralized in one stored procedure call at the confirm step**, not spread across the UI — which is what makes it possible for this same pattern to repeat consistently across dozens of similar screens (purchase orders, sales returns, GRNs) without each one reinventing how confirmation, inventory checks, and GL posting interact.
