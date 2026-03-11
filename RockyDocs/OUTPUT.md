# Rocky — Output Format

All output uses a monospace font. Columns are space-padded for alignment.
`▶` indicates a currently running timer. All other rows use `  ` (two spaces) for alignment.

---

## rocky status (no flags)

Shows all projects with currently running durations.

```
  Project           Duration
──────────────────────────────
▶ acme-corp         2h 30m
▶ side-project      0h 45m
  studio-client     -
  old-agency        -
  ancient-corp      -
```

**Rules:**
- Projects with running timers shown first, sorted by start time
- Remaining projects sorted by most recently worked on
- `-` shown for projects with no active timer
- No period header (no time range for this view)

---

## rocky status --today

```
Period:  Friday 06 Mar 2026

  Project           Total
──────────────────────────────
▶ acme-corp         2h 00m
▶ side-project      0h 45m
  studio-client     2h 00m
──────────────────────────────
  Total             4h 45m
```

**Rules:**
- Projects with no time today are omitted
- Running timers show current elapsed time (live, not when command was run)
- Total row at bottom

---

## rocky status --week

```
Period:  Mon 02 Mar — Fri 06 Mar 2026

  Project           Mon      Tue      Wed      Thu      Fri      Total
──────────────────────────────────────────────────────────────────────
▶ acme-corp         5h 30m   -        3h 30m   -        2h 00m   11h 00m
▶ side-project      -        2h 00m   -        -        0h 45m   2h 45m
  studio-client     -        -        2h 00m   3h 00m   -        5h 00m
  old-agency        1h 00m   -        -        -        -        1h 00m
──────────────────────────────────────────────────────────────────────
  Total             6h 30m   2h 00m   5h 30m   3h 00m   2h 45m   19h 45m
```

**Rules:**
- Week runs Monday–Sunday
- `-` for days with no time logged
- Projects with no time this week are omitted
- Running timers: show elapsed time for today's column only, rest are completed totals
- Total row at bottom

---

## rocky status --month

```
Period:  March 2026

  Project           Week 1   Week 2   Week 3   Week 4   Total
──────────────────────────────────────────────────────────────
▶ acme-corp         11h      9h 30m   -        -        20h 30m
▶ side-project      2h 45m   3h 00m   -        -        5h 45m
  studio-client     5h 00m   6h 00m   -        -        11h 00m
  old-agency        1h 00m   -        -        -        1h 00m
  ancient-corp      -        -        -        -        -
──────────────────────────────────────────────────────────────
  Total             19h 45m  18h 30m  -        -        38h 15m
```

**Rules:**
- Weeks are determined by the system calendar's `weekOfMonth` — a month may have 4 or 5 weeks depending on what day it starts on
- Projects with no time this month still shown (they may have been active recently)
- Hours-only format acceptable when >= 10h (e.g. `11h` instead of `11h 00m`)

---

## rocky status --year

```
Period:  2026

  Project           Jan     Feb     Mar     Apr     May     Jun     Jul     Aug     Sep     Oct     Nov     Dec     Total
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
▶ acme-corp         30h     28h     35h     -       -       -       -       -       -       -       -       -       93h
▶ side-project      6h      4h      8h      -       -       -       -       -       -       -       -       -       18h
  studio-client     12h     10h     11h     -       -       -       -       -       -       -       -       -       33h
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  Total             48h     42h     54h     -       -       -       -       -       -       -       -       -       144h
```

**Rules:**
- Future months show `-`
- Hours-only format for year view (no minutes)

---

## rocky status --week --verbose

Shows individual sessions instead of daily totals.

```
Period:  Mon 02 Mar — Fri 06 Mar 2026

   ID   Date    Project           Start    Stop      Duration
──────────────────────────────────────────────────────────────
   12   Mon     studio-client     09:00    11:00     2h 00m
   13   Mon     old-agency        11:30    12:30     1h 00m
   14   Mon     acme-corp         14:00    19:30     5h 30m
   15   Tue     side-project      10:00    12:00     2h 00m
   16   Wed     studio-client     09:30    12:30     3h 00m
   17   Wed     acme-corp         14:00    17:30     3h 30m
   18   Thu     studio-client     10:00    13:00     3h 00m
   19   Fri     acme-corp         09:00    11:00     2h 00m
▶  20   Fri     side-project      11:30    running   0h 45m
──────────────────────────────────────────────────────────────
                                                     19h 45m
```

**Rules:**
- `▶` on rows where the timer is still running
- `running` shown in Stop column for active sessions
- Sessions sorted by date then start time
- Total at bottom right-aligned under Duration column
- `ID` column shows the database session ID for use with `rocky edit --session <id>`

---

## rocky status --week --verbose --project acme-corp

Single project drill-down. Project name shown in header.

```
Project: acme-corp
Period:  Mon 02 Mar — Fri 06 Mar 2026

   ID   Date    Start    Stop     Duration
──────────────────────────────────────────
   14   Mon     14:00    19:30    5h 30m
   17   Wed     14:00    17:30    3h 30m
   19   Fri     09:00    11:00    2h 00m
──────────────────────────────────────────
                                  11h 00m
```

---

## rocky status --week --project acme-corp (non-verbose)

Single project, summary view. Project name in header, simplified table.

```
Project: acme-corp
Period:  Mon 02 Mar — Fri 06 Mar 2026

  Mon      Tue      Wed      Thu      Fri      Total
──────────────────────────────────────────────────────
  5h 30m   -        3h 30m   -        2h 00m   11h 00m
```

---

## General formatting rules

- Column widths: pad all columns to consistent width based on content
- Divider line: `─` (U+2500) repeated to match table width
- Header row uses same column widths as data rows
- `▶` (U+25B6) for active timer indicator, ` ` (one space) otherwise
- Duration format: `Xh Ym` — always show both hours and minutes except in year view
- Zero minutes: `2h 00m` not `2h`
- Times: formatted per system locale (12h or 24h depending on user preference)
- Dates in period header: `Mon 02 Mar — Fri 06 Mar 2026`
- `running` (lowercase) in Stop column for active sessions
- Total rows use same column alignment as data rows
