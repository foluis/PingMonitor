# .\PingMonitor.ps1 -Target "192.178.220.100" -IntervalSeconds 3 -RotateHours 12

param(
    [Parameter(Mandatory = $false)]
    [string]$Target = "192.178.220.100",

    [Parameter(Mandatory = $false)]
    [int]$IntervalSeconds = 5,

    # How many hours to keep writing to the same log file before rotating it.
    [Parameter(Mandatory = $false)]
    [double]$RotateHours = 24,

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = $PSScriptRoot
)

$LogPath = Join-Path $LogDirectory "ping_monitor.log"

function Get-LocalTimestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

function Write-LogLine {
    param([string]$Message)
    Add-Content -Path $LogPath -Value $Message
}

function Write-Header {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType File -Path $LogPath -Force | Out-Null
    }

    $ts = Get-LocalTimestamp
    $line = ("-" * 90)

    Write-LogLine ""
    Write-LogLine $line
    Write-LogLine ("   P I N G   M O N I T O R   S T A R T E D")
    Write-LogLine ("   LOCAL TIME: {0}" -f $ts)
    Write-LogLine ("   TARGET:     {0}" -f $Target)
    Write-LogLine ("   INTERVAL:   {0} seconds" -f $IntervalSeconds)
    Write-LogLine ("   ROTATE:     {0} hours" -f $RotateHours)
    Write-LogLine $line
    Write-LogLine ""
}

# Returns $true if the log was rotated OR created new, otherwise $false
function Rotate-LogIfNeeded {
    if (-not (Test-Path $LogPath)) {
        return $true
    }

    $file = Get-Item $LogPath
    $age = (Get-Date) - $file.CreationTime

    if ($age.TotalHours -ge $RotateHours) {
        $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $archived = Join-Path $LogDirectory ("ping_monitor_{0}.log" -f $stamp)

        Move-Item -Path $LogPath -Destination $archived -Force
        return $true
    }

    return $false
}

# Clears the current console line (so messages do not collide with the spinner line)
function Clear-CurrentConsoleLine {
    $width = [Console]::BufferWidth
    if ($width -lt 2) { $width = 120 }
    Write-Host ("`r" + (" " * ($width - 1)) + "`r") -NoNewline
}

# Writes an "event" line to the console without breaking the spinner UX
function Write-ConsoleEvent([string]$message) {
    Clear-CurrentConsoleLine
    Write-Host $message
}

Write-Host "Started PingMonitor"

# Rotate if needed, then ALWAYS append a STARTED block (every run)
$null = Rotate-LogIfNeeded
Write-Header

$spinnerChars = @('-', '\', '|', '/')
$spinnerIndex = 0
$wasDown = $false

# EventId is created and logged only on FAIL. Not written on RECOVERED.
$currentEventId = $null

# Spinner refresh is independent from IntervalSeconds
$spinnerTickMilliseconds = 500
$nextPingAt = Get-Date  # ping immediately on start

while ($true) {
    # Spinner update every 0.5s
    $spin = $spinnerChars[$spinnerIndex % $spinnerChars.Count]
    $spinnerIndex++

    $now = Get-Date
    $statusText = if ($wasDown) { "DOWN" } else { "UP" }
    $secondsToNextPing = [Math]::Max(0, [int]([Math]::Ceiling(($nextPingAt - $now).TotalSeconds)))

    Write-Host ("`r{0} {1} | Status: {2} | Next ping: {3}s " -f $spin, $Target, $statusText, $secondsToNextPing) -NoNewline

    if ($now -ge $nextPingAt) {
        # Rotate if needed while running (header only on startup, not on rotation)
        $rotated = Rotate-LogIfNeeded
        if ($rotated) {
            # When rotation happens mid-run, write a header into the new log
            Write-Header
        }

        try {
            $null = Test-Connection -ComputerName $Target -Count 1 -ErrorAction Stop

            if ($wasDown) {
                $ts = Get-LocalTimestamp

                Write-LogLine ""
                Write-LogLine ("RECOVERED at Local Date time: {0}" -f $ts)
                Write-LogLine ""

                Write-ConsoleEvent ("RECOVERED {0} | Target: {1}" -f $ts, $Target)

                $wasDown = $false
                $currentEventId = $null
            }
        }
        catch {
            if (-not $wasDown) {
                $ts = Get-LocalTimestamp

                # Create a new EventId for this outage (log it only on FAILED)
                $currentEventId = ([Guid]::NewGuid()).ToString()

                $errType = $_.Exception.GetType().FullName
                $errMsg = $_.Exception.Message
                $psErrorDetails = ($_ | Out-String).TrimEnd()
                $rawException = ($_.Exception | Format-List * -Force | Out-String).TrimEnd()

                Write-LogLine ""
                Write-LogLine ("FAILED at Local Date time: {0}" -f $ts)
                Write-LogLine ("EventId: {0}" -f $currentEventId)
                Write-LogLine ("ErrorType: {0}" -f $errType)
                Write-LogLine "PowerShell error record details:"
                Write-LogLine $psErrorDetails
                Write-LogLine ""
                Write-LogLine "Raw exception:"
                Write-LogLine $rawException
                Write-LogLine ""

                Write-ConsoleEvent ("FAILED {0} | Target: {1} | EventId: {2} | {3} | {4}" -f $ts, $Target, $currentEventId, $errType, $errMsg)

                $wasDown = $true
            }
        }

        $nextPingAt = (Get-Date).AddSeconds($IntervalSeconds)
    }

    Start-Sleep -Milliseconds $spinnerTickMilliseconds
}