# Rocky

A fast, local CLI time tracker. Track time across projects, view reports by day/week/month/year, and drill down into individual sessions. All data stays on your machine in a local SQLite database.

## Installation

### Homebrew (macOS and Linux)

```bash
brew tap argylebits/tap
brew install rocky
```

### From source

Requires Swift 6.2+.

```bash
git clone https://github.com/argylebits/RockyCLI.git
cd RockyCLI
swift build -c release
cp .build/release/App /usr/local/bin/rocky
```

## Getting started

```bash
# Start tracking time on a project (creates it if it doesn't exist)
rocky start acme-corp

# Check what's running
rocky status

# Stop the timer
rocky stop
```

That's it. No accounts, no setup, no config files required.

## Commands

### `rocky start <project>`

Start a timer for a project. Creates the project automatically if it doesn't exist.

```bash
rocky start acme-corp
# Started acme-corp

rocky start side-project
# Started side-project
# Currently running: acme-corp, side-project
```

Multiple timers can run simultaneously.

### `rocky stop [project] [--all]`

Stop a running timer.

```bash
rocky stop                  # auto-stops if only one running, prompts if multiple
rocky stop acme-corp        # stop a specific project
rocky stop --all            # stop everything
```

When multiple timers are running and no project is specified, Rocky shows an interactive prompt:

```
Multiple timers running:

    Project           Duration
────────────────────────────────
  1. acme-corp        2h 30m
  2. side-project     0h 45m
────────────────────────────────

Stop which? (1/2/all):
```

### `rocky status [flags]`

Show time tracking reports.

```bash
rocky status                # what's running right now
rocky status --today        # today's totals
rocky status --week         # this week, broken down by day
rocky status --month        # this month, broken down by week
rocky status --year         # this year, broken down by month
```

#### Custom date ranges

```bash
rocky status --from 2026-01-01
rocky status --from 2026-01-01 --to 2026-02-01
```

#### Filter by project

```bash
rocky status --week --project acme-corp
```

#### Verbose mode — individual sessions

Add `-v` or `--verbose` to see individual session start/stop times:

```bash
rocky status --week --verbose
```

```
Period:  Mon 02 Mar — Fri 06 Mar 2026

   ID   Date    Project           Start    Stop      Duration
──────────────────────────────────────────────────────────────
   12   Mon     studio-client     09:00    11:00     2h 00m
   13   Mon     acme-corp         14:00    19:30     5h 30m
   15   Tue     side-project      10:00    12:00     2h 00m
   17   Wed     acme-corp         14:00    17:30     3h 30m
   19   Fri     acme-corp         09:00    11:00     2h 00m
▶  20   Fri     side-project      11:30    running   0h 45m
──────────────────────────────────────────────────────────────
                                                     19h 45m
```

### `rocky dashboard`

Show an analytics dashboard with trends and insights.

```bash
rocky dashboard
```

Displays a full-width dashboard including:
- Running timers
- Time summaries with deltas (this week, this month, this year)
- Activity heatmap (31 weeks, Mon–Sun grid)
- Weekly trend sparkline (31 weeks with month labels)
- Project distribution for the current week
- Peak working hours
- Streaks & stats (streak, sessions, daily avg, total hours, top project, and more)

### `rocky edit [project] [flags]`

Edit the start, stop, or duration of a session.

```bash
# Interactive — shows recent sessions, prompts for what to edit
rocky edit acme-corp

# Non-interactive — edit by session ID (shown in --verbose output)
rocky edit --session 41 --start "2026-03-09 23:00" --stop "2026-03-10 01:30"
rocky edit --session 41 --start "2026-03-09 23:00"
rocky edit --session 41 --stop "2026-03-10 01:30"
rocky edit --session 41 --duration 7800
rocky edit --session 41 --start "2026-03-09 23:00" --duration 7800
rocky edit --session 41 --stop "2026-03-10 01:30" --duration 7800
```

| Flag | Description |
|------|-------------|
| `--session <id>` | Session ID (shown in `--verbose` output) |
| `--start <datetime>` | New start time (`YYYY-MM-DD HH:MM`) |
| `--stop <datetime>` | New stop time (`YYYY-MM-DD HH:MM`) |
| `--duration <seconds>` | Duration in seconds — used to compute start or stop |

### `rocky projects`

List all projects.

```bash
rocky projects
```

```
  Project           Created
──────────────────────────────────
  acme-corp         Jan 2026
  side-project      Feb 2026
  studio-client     Feb 2026
```

### `rocky config`

Manage preferences. Config is stored at `~/.rocky/config.json`.

```bash
rocky config list               # show all settings
rocky config get auto-stop      # get a specific setting
rocky config set auto-stop true # set a value
```

| Setting | Default | Description |
|---------|---------|-------------|
| `auto-stop` | `true` | Prevent starting duplicate timers on the same project |

## How it works

- Data is stored locally in `~/.rocky/rocky.db` (SQLite)
- Project names are case-insensitive for matching, stored as first entered
- All times displayed in your local timezone
- Durations shown as `Xh Ym` (e.g., `2h 30m`, `0h 45m`)

## Updating

```bash
brew upgrade rocky
```

## Requirements

- macOS 15+ or Linux (x86_64 / arm64)
- No runtime dependencies when installed via Homebrew

## License

MIT
