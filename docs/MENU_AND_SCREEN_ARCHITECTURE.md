# Menu & Screen Architecture

How navigation, screens, and reports are structured — entirely as configuration data, not hardcoded UI.

## The core idea

Nothing about "what menus exist" or "what's on a screen" is hardcoded in the application. It's all rows in a handful of admin tables, read by a generic rendering engine. Add a row, and a new menu item or field appears — no redeploy required.

## Menu structure (SA11 — Menu Master)

Menus are a self-referencing tree: every menu row points to a parent menu code, so the engine builds the nested navigation by walking `Parent Menu → Child Menus → Grandchild Menus`, ordered by a sequence number at each level.

Example of the real menu tree structure used in this system:

```
M   (root)
├── M10 Administration
│   ├── M11 Administration
│   ├── M12 Master Data
│   └── M13 Administration Reports
├── M20 Accounting
│   ├── M21 General Accounting
│   ├── M22 GL Interface
│   └── M23 Accounting Reports
├── M30 Procurement
│   ├── M31 Purchase & Procurement
│   └── M32 Procurement Reports
├── M40 Sales
│   ├── M41 Sales & Invoice
│   ├── M42 POS
│   └── M43 Sales Reports
└── M50 Inventory
    ├── M51 Inventory Management
    └── M52 Inventory Reports
```

Each menu row carries: a code, a title, a parent reference, an icon, and a sequence number. That's the entire vocabulary needed to represent unlimited depth and breadth of navigation.

## Screen registry (SA12 — Screen Master)

Every screen in the system — transactional, report, or system utility — is registered as its own row before it ever appears in a menu. The registry fields:

| Field | Purpose |
|---|---|
| `xscreen` | The screen code — e.g. `SO14`, `PO12`, `R101`. This code is the single identifier used everywhere else in the system: privileges, favourites, search, audit logs, menu mapping — nothing references a screen any other way. |
| `xtitle` | Human-readable display name |
| `xtype` | One of `Screen` / `Report` / `System` / `Default` — this classification is what lets global search return a blended list of transactional screens *and* reports from one query, and lets the report-rendering mechanism know a code refers to a printable report rather than an interactive form |
| `xnum` | The starting seed for that screen's transaction-numbering sequence (feeds into the shared `Fn_GetTrn` numbering service used across the system) |
| `xicon` | Icon reference for menu/search rendering |
| `xkeywords` | A free-text field packed with synonyms and related terms — this is what makes global search actually useful |

**The keyword field is doing more work than it looks like.** Rather than relying on users knowing the exact screen code or title, each screen's keyword list is deliberately over-stuffed with alternate names a user might actually type. A few real examples from the registry:

- `SO14` (Direct Invoice) → *"Spot Invoice, Immediate Invoice, Quick Invoice, Cash Invoice, Instant Invoice, Direct Billing, Fast Invoice Creation"*
- `FA15` (Voucher Entry) → *"Journal Voucher, Payment Voucher, Receipt Voucher, Contra Voucher, Adjustment Voucher, Transaction Entry, Manual Voucher"*
- `PO14` (Direct Purchase) → *"Spot Purchase, Immediate Purchase, Cash Purchase, One Step Purchase, Quick Purchase Entry"*

This is a deliberate design choice: a user typing "cash purchase" into search should land on Direct Purchase even though nothing in the screen's title says "cash." Search quality here comes entirely from how well this field is populated per screen, not from any fuzzy-matching cleverness in the query itself — the intelligence lives in the data, not the code.

## Menu-to-screen mapping (SA13)

A join table (`xmenuscreens`) connects menu nodes to the screens that live under them — just three fields: `xmenu` (which menu node), `xscreen` (which screen), and `xsequence` (display order within that menu). Nothing more. This simplicity is what lets the same screen be exposed from more than one place in the navigation without duplicating anything, and it's what the "add company #9 without new development" scaling model actually depends on: onboarding a new business unit that needs a different module subset is a matter of inserting different rows here, not shipping new code.

### The full real menu-to-screen map

This is the actual, complete mapping from the blueprint — every screen and report in the system, organized under its menu. It's worth including in full because the shape of it *is* the product: this single table is effectively the entire functional footprint of the ERP.

**M10 Administration**
- **M11 Administration:** AD11 Business Profile · AD12 User Profile Setup · AD13 Manage Users · AD14 Codes & Parameters
- **M12 Master Data:** AD17 Business Unit · MD11 Store Setup · MD12 Item Master
- **M13 Administration Reports:** R101 User Listing · R102 Profile Wise Access · R103 Store Listing · R104 Item Master · R105–R106 Purchase Detail/Summary (MIS) · R107–R108 Purchase Pending Ageing (Detail/Summary) · R109–R110 Sales Invoice Detail/Summary (MIS) · R111–R112 Sales Pending Ageing (Detail/Summary) · R113 Current Stock (MIS) · R114 Item Ledger Detail · R115 Date Wise Stock Status · R116 Item Movement Frequency · R117–R118 Inventory Ageing (Detail/Summary)

**M20 Accounting**
- **M21 General Accounting:** FA11 Account Default · FA12 Account Group · FA13 Chart of Account · FA14 Sub Account · FA15 Voucher Entry · FA16 Imported Voucher · FA17 Integrated Voucher · FA18 Voucher Post/Unpost · FA19 Year End Processing · FA20 Import Voucher
- **M22 GL Interface:** FA31 Purchase to GL · FA32 Sales to GL (Income) · FA33 Inventory to GL
- **M23 Accounting Reports:** R201–R202 Chart of Account (Detail/Summary) · R203 Sub Account · R204 General Journal · R205 Account Ledger · R206 Cash/Bank Book · R207–R208 Trial Balance (Detail/Summary) · R209–R210 Profit & Loss (Detail/Statement) · R211–R212 Balance Sheet (Detail/Summary) · R213–R215 Cross-Year Ledger/Trial Balance/P&L · R216–R217 Sub Account Ledger (Detail/Summary) · R218 Statement of Financial Position

**M30 Procurement**
- **M31 Purchase & Procurement:** PO12 Purchase Order · PO13 Purchase Order to GRN · PO14 Direct Purchase · PO15 GRN Process · PO16 Purchase Return (Direct) · PO17 Purchase Return (GRN)
- **M32 Procurement Reports:** R301–R302 Purchase Order (Detail/Summary) · R303–R304 Pending Item (Detail/Summary) · R305 Party Pending Statement · R306–R308 Purchase Detail/Summary/Item Summary · R309 Order vs. GRN Summary · R310–R312 Purchase Return (Detail/Summary/Item Summary)

**M40 Sales**
- **M41 Sales & Invoice:** SO12 Sales Order · SO13 Sales Order to Invoice · SO14 Direct Invoice · SO15 Invoice Process · SO16 Sales Return (Direct) · SO17 Sales Return (Invoice)
- **M42 POS:** AD19 Print Barcode · SO18 POS Entry · SO19 POS Process
- **M43 Sales Reports:** R401–R402 Sales Order (Detail/Summary) · R403–R405 Undelivered Item Detail/Summary/Party Statement · R406–R408 Sales Detail/Summary/Item Summary · R409 Order vs. Delivery Summary · R410 Date Wise Dismissed Order · R411–R413 Sales Return (Detail/Summary/Item Summary)

**M50 Inventory**
- **M51 Inventory Management:** IM11 Inventory Transfer (Direct) · IM12 Inventory Transfer (Business) · IM13 Inventory Issue · IM14 Batch Process · IM15 Inventory Adjustment · IM16 Inventory Opening · IM50 Inventory Transaction
- **M52 Inventory Reports:** R501–R503 Transfer Detail/Summary/Item Summary · R504–R506 Issue Detail/Summary/Item Summary · R507–R511 Batch Production/Consumption/By-Products (Detail/Summary) · R512–R514 Adjustment (Detail/Summary/Item Summary) · R515 Current Stock · R516 Item Ledger Detail · R517 Date Wise Stock Status

### What this reveals structurally

- **Reports are first-class screens, not an afterthought.** Every `R###` code lives in the exact same registry, gets the exact same access-privilege treatment, and shows up in the exact same search as a transactional screen — there's no separate "reporting module" bolted on.
- **The Undelivered/Ageing report family recurs in almost every module** (Purchase Pending Ageing, Sales Undelivered, Inventory Ageing) — this is the menu-level evidence of the "undelivery problem" and "ageing" pain points mentioned elsewhere in this portfolio: they weren't solved once, they were solved as a repeatable reporting pattern applied consistently across Purchase, Sales, and Inventory.
- **Roughly 2 reports exist for every 1 transactional screen** across this map (~52 screens vs. ~90+ reports) — which reflects a design bias toward visibility over pure data entry: the point of the system was never just capturing transactions, it was making the resulting position legible to the people who need to act on it.

## Global search (menu bar)

Typing in the top search bar queries the registered screens *and* reports by keyword in real time:

```sql
select top 5 xicon, xtitle, xtype from profilescreenv
where zid=@zid and xprofile=@xprofile and xtype='Screen'
  and xkeyword like '%searchText%'
union
select top 5 xicon, xtitle, xtype from profilescreenv
where zid=@zid and xprofile=@xprofile and xtype='Report'
  and xkeyword like '%searchText%'
```

Results respect the current user's **profile** — someone without access to a screen simply never sees it in search results, because the query joins through the same privilege view used everywhere else in the system. Selecting a result (click or Enter) revalidates access server-side before redirecting — search can't be used to bypass permissions even if a stale client-side list briefly shows something.

## Favourites

Users can pin frequently used screens to a personal favourites list on the menu bar — a simple per-user, per-screen mapping, rendered as quick-access shortcuts.

## Report rendering mechanism

Reports resolve to their physical file dynamically rather than being bundled into the application build:

1. On any report request (whether triggered from a screen's "Print" button or the general Report Panel), the system first looks up the business's custom report directory:
   `SELECT xrptpath FROM zbusiness WHERE zid = @zid`
2. It searches that directory for the requested report file.
3. **If found**, it runs that version directly — this is what allows a specific client/business to have a customized report layout without forking the whole application.
4. **If not found**, it falls back to a shared default report directory:
   `SELECT xrptdefault FROM zbusiness WHERE zid = @zid`

This is a small mechanism, but it's what makes 150+ reports maintainable: reports can be customized per business without ever touching the core codebase, and a business with no customizations silently gets the shared default — no special-casing required anywhere else in the system.
