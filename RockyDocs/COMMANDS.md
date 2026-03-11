# Rocky — Commands Reference

## rocky start <project>

Starts a timer for the given project.

```bash
rocky start acme-corp
rocky start side-project
```

**Behaviour:**
- If the project doesn't exist, create it automatically (no separate `add` command needed)
- If a timer is already running for this project, print an error: `Timer already running for acme-corp`
- Multiple projects can have timers running simultaneously — this is intentional and supported
- Always print what happened after starting:
  ```
  Started acme-corp
  ```
- If other timers are running, also show them:
  ```
  Started side-project
  Currently running: acme-corp, side-project
  ```

---

## rocky stop [project] [--all]

Stops a running timer.

```bash
rocky stop                  # interactive if multiple running
rocky stop acme-corp        # stop specific project
rocky stop --all            # stop all running timers
```

**Behaviour — no args, one timer running:**
```
Stopped acme-corp (2h 30m)
```

**Behaviour — no args, multiple timers running:**
```
Multiple timers running:

    Project           Duration
────────────────────────────────
  1. acme-corp        2h 30m
  2. side-project     0h 45m
────────────────────────────────

Stop which? (1/2/all): 
```
User types `1`, `2`, or `all`. Then confirm what was stopped:
```
Stopped acme-corp (2h 30m)
```

**Behaviour — `rocky stop acme-corp`:**
```
Stopped acme-corp (2h 30m)
```

**Behaviour — `rocky stop --all`:**
```
Stopped acme-corp     (2h 30m)
Stopped side-project  (0h 45m)
```

**Behaviour — no timers running:**
```
No timers currently running.
```

---

## rocky status [flags]

Shows time tracking summary. See `OUTPUT.md` for exact table formatting.

### Flags

| Flag | Description |
|------|-------------|
| *(none)* | Show all projects with currently running durations |
| `--today` | Show totals for today |
| `--week` | Show totals by day for the current week (Mon–Sun) |
| `--month` | Show totals by week for the current month |
| `--year` | Show totals by month for the current year |
| `--from <date>` | Custom range start (YYYY-MM-DD) |
| `--to <date>` | Custom range end (YYYY-MM-DD), defaults to today |
| `--verbose` / `-v` | Show individual sessions with start/stop times |
| `--project <name>` | Filter to a single project |

### Flag combinations

```bash
rocky status                            # current timer state only
rocky status --today                    # today's totals
rocky status --week                     # this week by day
rocky status --month                    # this month by week
rocky status --year                     # this year by month
rocky status --from 2026-01-01          # custom range
rocky status --from 2026-01-01 --to 2026-02-01
rocky status --week --verbose           # this week, individual sessions
rocky status --week --project acme-corp # this week filtered to one project
rocky status --week --verbose --project acme-corp  # drill down on one project
```

### --from/--to auto column grouping

When using `--from/--to`, automatically pick the best column grouping:
- Range ≤ 7 days → columns by day
- Range ≤ 60 days → columns by week
- Range > 60 days → columns by month

---

## rocky dashboard

Show an analytics dashboard with trends and insights.

```bash
rocky dashboard
```

**Behaviour:**
- No flags — displays a full-width dashboard with multiple analytics widgets
- Widgets include:
  - Running timers (if any)
  - Time summaries: this week, last week, this month, last month, this year (with week/month deltas)
  - Activity heatmap: 12-week grid (Mon-Sun rows, week columns) with intensity levels `· ░ ▒ ▓ █`
  - Weekly sparkline: 12-week trend using `▁▂▃▄▅▆▇█` characters
  - Project distribution: bar chart for current week with percentage breakdown
  - Peak hours: intensity chart showing busiest hours of the day
  - Streaks & stats: current/longest streak, average/longest session, most active weekday
- Dashboard uses double-line border `╔═╗║╚═╝` for outer frame and rounded single-line `╭─╮│╰─╯` for widget borders
- All data computed from session history — no additional database tables required
- Week starts on Monday (per DECISIONS.md)

---

## rocky edit [project] [flags]

Edit the start, stop, or duration of a session.

### Interactive mode

```bash
rocky edit rocky
```

Shows recent sessions for the project and prompts for which to edit:

```
Sessions for rocky:

   ID   Date   Start      Stop   Duration
──────────────────────────────────────────
   41   Mon    23:20     10:14    10h 54m
▶  42   Tue    17:05   running     0h 05m
──────────────────────────────────────────

Edit which? 41

  Mon 09 Mar    23:20 — 10:14    10h 54m

  1. Start    (23:20)
  2. Stop     (10:14)
  3. Duration (10h 54m)

Edit which field? 3
New value (Xh Ym): 2h 10m

Updated: Mon 09 Mar  23:20 — 01:30  (2h 10m)
```

### Non-interactive mode (flags)

```bash
rocky edit --session 41 --start "2026-03-09 23:00" --stop "2026-03-10 01:30"
rocky edit --session 41 --start "2026-03-09 23:00"
rocky edit --session 41 --stop "2026-03-10 01:30"
rocky edit --session 41 --duration "2h 10m"
rocky edit --session 41 --start "2026-03-09 23:00" --duration "2h 10m"
rocky edit --session 41 --stop "2026-03-10 01:30" --duration "2h 10m"
```

### Flags

| Flag | Description |
|------|-------------|
| `--session <id>` | Session ID (shown in `--verbose` output) |
| `--start <datetime>` | New start time (`YYYY-MM-DD HH:MM`) |
| `--stop <datetime>` | New stop time (`YYYY-MM-DD HH:MM`) |
| `--duration <duration>` | Duration (`Xh Ym`) — used to compute start or stop |

### Flag combinations

| Flags | Result |
|-------|--------|
| `--start + --stop` | Set both explicitly |
| `--start` | Change start, keep existing stop |
| `--stop` | Change stop, keep existing start |
| `--duration` | Keep existing start, set stop = start + duration |
| `--start + --duration` | Set new start, set stop = new start + duration |
| `--stop + --duration` | Set new stop, set start = new stop − duration |
| `--start + --stop + --duration` | Error — overdetermined |

### Behaviour

- **Interactive mode** (`rocky edit <project>`): shows sessions for the project, prompts for session ID, field, and new value
- **Non-interactive mode** (`rocky edit --session <id> --start/--stop/--duration`): no prompts, fails with error if required flags are missing
- Datetime format is always `YYYY-MM-DD HH:MM` in local timezone — no ambiguity for multi-day sessions
- Duration format is `Xh Ym` (e.g. `2h 10m`, `0h 45m`)
- **Validation:**
  - Computed or explicit stop time must be after start time
  - Cannot edit the stop time of a running session (stop it first)
  - Cannot set start time to the future
  - Duration must be positive
- On success, print the updated session details

---

## rocky config

Manage user preferences.

```bash
rocky config set auto-stop true
rocky config set auto-stop false
rocky config get auto-stop
rocky config list
```

### Available settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `auto-stop` | bool | `true` | Automatically stop current timer when starting a new one on the same project |

Config stored at `~/.rocky/config.json`.

---

## rocky projects

List all projects.

```bash
rocky projects
```

Output:
```
  Project           Created
──────────────────────────────────
  acme-corp         Jan 2026
  side-project      Feb 2026
  studio-client     Feb 2026
  old-agency        Mar 2025
```

---

## General CLI behaviour

- Project names are case-insensitive for matching (`ACME-CORP` matches `acme-corp`)
- Project names are stored exactly as first provided
- Unknown project names in `start` auto-create the project
- Unknown project names in `stop`/`status --project` print an error
- All times displayed in local timezone
- Durations displayed as `Xh Ym` (e.g. `2h 30m`, `0h 45m`, `1h 00m`)
