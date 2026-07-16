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

Every screen in the system — transactional, report, or system utility — is registered as a row: a code (e.g. `SO14`), a title, a type (`Screen` / `Report` / `System` / `Default`), a starting transaction-number seed, an icon, and free-text keywords used for search indexing.

This registry is what makes global search, favourites, and access-privilege assignment all possible without touching code — they all just reference `xscreen` codes.

## Menu-to-screen mapping (SA13)

A join table connects menu nodes to the actual screens that live under them, which is what lets the same screen (in principle) be exposed from more than one place in the navigation without duplicating anything.

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
