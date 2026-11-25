# phantomdocs (Arya)

Feature docs for Phantom (PHI), backend side. Same layout as `mnhafid/phantomdocs`.

| Folder | Feature | Sprint | Status (25 Nov 2026) |
|---|---|---|---|
| [`ProductionReport/`](ProductionReport/) | Production Report: Summary, Top 10, Chart, Input Target (RKAP / WPNB, SOT / OPS) | Sprint 3 (M011, M012, Input Target) | BE merged on `phi-dev` |

Each feature folder has the same 7 files:
1. `01-Decision-Log.md`: decisions (date and source), changes to the docs, facts from the code and the database.
2. `02-Knowledge.md`: open gaps, PRD summary, FE contract, data sources, formulas, design notes, access, links.
3. `03-Endpoint-Plan.md`: every endpoint (built and changed), with its request and response.
4. `04-Endpoint-Figma-Screens.md`: which screen calls which endpoint.
5. `05-Production-Checklist.md`: PRs, migration, data, release steps, decisions needed before go-live.
6. `06-Test-Cases-and-Users.md`: test cases and test users.
7. `07-Ticket.md`: one ticket per Jira ticket, business logic only.

Rules:
- Write a new entry at the bottom of a section. Do not change old entries. If a decision changes, write a new entry that names the old one.
- No secrets: no passwords, tokens, connection strings or server addresses. `{{base_url}}` stands for the API host.
