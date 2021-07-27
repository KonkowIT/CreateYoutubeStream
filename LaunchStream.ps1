[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,HelpMessage="Czas zakonczenia odtwarzania stream'u - Format 'yyyy-MM-dd HH:mm:ss'")]
    [ValidateNotNull()]
    [datetime] $TimeEnd
)

$ErrorActionPreference = "Continue"

$checkPlayer = "C:\SCREENNETWORK\admin\check-player.ps1"
$pathToChrome = "C:\Program Files\Google\Chrome\Application\chrome.exe" 
$pathTemp = 'c:\SnTemp\chrome'
$tempFolder = "--user-data-dir=$pathTemp"
$startmode = '--start-fullscreen'
$htmlPath = "C:\SCREENNETWORK\stream_YT.html"

# Block check-player.ps1
do {
    $Lock = $false

    try {
        $Lock = [System.IO.File]::Open($checkPlayer, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        Write-Verbose "Trying to block check-player.ps1"
    }
    catch { }
    sleep -s 10
    Write-Verbose "Waiting to block check-player.ps1"
} while (!$Lock)
Write-Verbose "Check-player.ps1 blocked"

# Kill SN process
get-process -ProcessName "sn*" | Stop-Process -Verbose

# Run chrome
mkdir $pathTemp -Force | Out-Null
Start-Process -FilePath $pathToChrome -ArgumentList $tempFolder, $startmode, $htmlPath

# Stream ON
do {
    sleep -Seconds 30
    $timeNow = Get-Date -DisplayHint Time
} until($timeNow -gt $TimeEnd)

# Kill Chrome
Get-Process chrome* | Stop-Process -Force -verbose
Get-Process Google* | Stop-Process -Force -verbose

# Start SNPlayer
Write-Verbose "Launching SNPlayer"
&("C:\SCREENNETWORK\Player\Release\SNplayer.exe")

# Unblock check-player.ps1
$lock.close()
Write-Verbose "Check-player.ps1 unblocked"

# Remove temporary files
rm $pathTemp -Force -Recurse