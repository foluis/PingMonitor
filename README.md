# PingMonitor.ps1 Guide

## Read this document (Markdown viewer)

You can open this file with any Markdown editor you already use, for example:
- VS Code (built-in Markdown preview)
- Obsidian
- Typora
- Any editor that supports `.md` files

If you do not have a Markdown editor, you can use this online preview tool:
- https://markdownlivepreview.com/

Steps:
- Open the site
- Paste this whole document into the editor pane
- Read the formatted preview on the right

---

## What PingMonitor.ps1 does

- Continuously pings a target IP or host on a fixed interval.
- Writes results to a log file named `ping_monitor.log`.
- Detects state changes:
  - Logs a detailed **FAILED** block only when the target first goes down.
  - Logs a **RECOVERED** line when the target comes back up.
- Shows a live spinner in the console with:
  - Current status (UP or DOWN)
  - Seconds until the next ping
- Rotates the log file after N hours (default 24), archiving it with a timestamped name.

---

## Parameters

- `-Target` (string), default: `192.178.220.100`
- `-IntervalSeconds` (int), default: `5`
- `-RotateHours` (double), default: `24`
- `-LogDirectory` (string), default: script folder (often the same folder as the `.ps1`)

---

## How you run it

### Before you start (recommended setup)

- Put `PingMonitor.ps1` in a known folder, for example:
  - `C:\Tools\PingMonitor\PingMonitor.ps1`

- Decide what values you want:
  - Target: IP or hostname
  - IntervalSeconds: how often to ping
  - RotateHours: how often to archive the log
  - LogDirectory: where to write logs (optional)

Example values used below:
- Target: `192.178.220.100`
- IntervalSeconds: `3`
- RotateHours: `12`

---

### Run from PowerShell (detailed)

#### Option A: Run by full path (simplest)

1. Open PowerShell
2. Run:

   - If you are already in the script folder:
     - `.\PingMonitor.ps1 -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

   - If you are not in the folder, run with full path:
     - `C:\Tools\PingMonitor\PingMonitor.ps1 -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

#### Option B: Change directory first, then run

1. Open PowerShell
2. Go to the folder:

   - `cd C:\Tools\PingMonitor`

3. Run:

   - `.\PingMonitor.ps1 -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

#### If PowerShell blocks script execution

If you see an execution policy error, try one of these approaches:

- Run the script with a one-time bypass (recommended for quick runs):
  - `powershell -ExecutionPolicy Bypass -File "C:\Tools\PingMonitor\PingMonitor.ps1" -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

- Or, set policy for your user (requires you to understand your environment policies):
  - `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

To stop the script:
- Press `Ctrl + C`

---

### Run from CMD (detailed)

CMD cannot run a `.ps1` directly like an `.exe`, so you call PowerShell from CMD.

#### Option A: Run using `powershell.exe` (Windows PowerShell)

1. Open Command Prompt (CMD)
2. Run:

   - `powershell.exe -ExecutionPolicy Bypass -File "C:\Tools\PingMonitor\PingMonitor.ps1" -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

Notes:
- `-ExecutionPolicy Bypass` helps avoid policy errors for this single run.
- Quotes around the file path are required if there are spaces.

#### Option B: Run using `pwsh` (PowerShell 7, if installed)

1. Open Command Prompt (CMD)
2. Run:

   - `pwsh -ExecutionPolicy Bypass -File "C:\Tools\PingMonitor\PingMonitor.ps1" -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12`

To stop the script:
- Press `Ctrl + C`

---

## What gets written to the log

### On every start (always)
- Appends a header block showing:
  - Local time
  - Target
  - Interval
  - Rotate hours

### When the target first becomes unreachable
- Writes a **FAILED** block once per outage, includes:
  - Timestamp
  - EventId (a new GUID for that outage)
  - Exception type and message
  - Full PowerShell error record details
  - Full exception dump

### While it remains down
- It does not spam the log every interval, it only logs the first failure for that outage.

### When it comes back
- Writes a **RECOVERED** line with timestamp.
- Resets state so the next outage gets a new EventId.

---

## Console behavior

- Prints a "Started PingMonitor" message once.
- Then continuously updates one console line with:
  - Spinner (`-`, `\`, `|`, `/`)
  - Target
  - Status
  - Countdown to next ping
- When an outage starts or recovers, it prints a normal line without breaking the spinner display.

---

## Log rotation behavior

- Uses the log file creation time to decide age.
- If age is greater than or equal to `RotateHours`:
  - Renames `ping_monitor.log` to `ping_monitor_yyyyMMdd_HHmmss.log`
  - Creates a new `ping_monitor.log`
  - Writes a new header into the new log

---

## Practical notes

- The script runs forever (`while ($true)`), stop it with `Ctrl + C`.
- Ping is done via `Test-Connection -Count 1`.
- If DNS or ICMP is blocked, you can see failures even if the host is reachable by other means.

---
