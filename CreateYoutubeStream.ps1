<# PSScriptInfo
	.SYNOPSIS
		Skrypt sluzy do tworzenia zadania w harmonogramie, ktore uruchamia 
		skrypt LaunchStream.ps1
	
	===========================================================================
	 	Created:   	16-10-2020
	 	Created by:   	Konrad Kowalski
	 	Organization: 	KonkowIT 
		Filename:     	CreateYoutubeStream.ps1
	===========================================================================
#>

# Check privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = ( -join ("& ", $myinvocation.mycommand.definition))
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Exit 
}

# Global variables
$ErrorActionPreference = "Continue"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

####################### ZMIENIAMY TYLKO TO ! ###################################

# ID filmu na Youtube
#  np. "https://www.youtube.com/embed/V5hYi70n510?autoplay=1&mute=1" czyli ID filmu to "V5hYi70n510"
$YoutubeID = "5qap5aO4i9A"

# Podwojny panel (na Marriott Corner)
$Corner = $false

# Czas rozpoczeczia streamu
#  format = "yyyy-MM-dd HH:mm:ss"
$timeStart = "2020-10-16 19:39:00"

# Czas zakonczenia streamu
#  format = "yyyy-MM-dd HH:mm:ss"
$timeEnd = "2020-10-16 19:39:15"

################################################################################

# Home variable 
$hDir = Split-Path -Parent $myinvocation.mycommand.definition

# Chrome variables
$chromeInstaller = "ChromeInstaller.exe"
$chromeDownloadLink = "http://dl.google.com/chrome/install/375.126/chrome_installer.exe"
$chromeProcess2Monitor = "ChromeInstaller"
$chromeCheck = (Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ea SilentlyContinue).'(Default)' -ea SilentlyContinue).VersionInfo

# User variables
$timeStart = Get-Date $timeStart
$timeEnd = Get-Date $timeEnd

# Task variables
$actionW7 = "-WindowStyle Minimized -file '$hDir\LaunchStream.ps1' -TimeEnd `'$timeEnd`' -Verbose"
$actionW10 = "-WindowStyle Minimized -Command `"& `'$hDir\admin\LaunchStream.ps1`' -TimeEnd `'$timeEnd`' -Verbose`""
$taskDescription = "Uruchamianie streamu z YT"
$taskName = "LaunchYTStream"

# API variables
$snName = $env:computername
$requestURL = 'http://***/'
$requestHeaders = @{'sn-api-token' = 'XXX'; 'sn-player' = "$snName"}

# Other variables
$localTempDir = $env:TEMP
$snDir = "C:\SCREENNETWORK"

# OS version
$VersionMajor = [environment]::OSVersion.Version.Major
$VersionMinor = [environment]::OSVersion.Version.Minor
[String]$OSVersion = ( -join ($VersionMajor, ".", $VersionMinor))
Switch ($OSVersion) {
	"10.0" { $Win10 = $true }
    "5.1" { $WinXP = $true }
}

# WinXP exclude
if ($WinXP) {
	Write-warning "System not supported, terminating"
	Exit
}

# Chrome installation
if ($null -eq $chromeCheck) {
	Write-Host "Google Chrome missing, installing"
	(new-object System.Net.WebClient).DownloadFile("$chromeDownloadLink", "$localTempDir\$chromeInstaller")
	& "$localTempDir\$chromeInstaller" /silent /install
	do { 
		$processesFound = Get-Process | ? { $chromeProcess2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name
	
		if ($processesFound) { 
			"Still running: $($processesFound -join ', ')" | Write-Host
			Start-Sleep -Seconds 10 
		} 
		else { 
			Remove-Item "$localTempDir\$chromeInstaller" -ErrorAction SilentlyContinue -Verbose 
			Remove-Item "C:\Users\Public\Desktop\Google Chrome.lnk" -ErrorAction SilentlyContinue -Verbose
			Remove-Item "C:\Users\sn\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Google Chrome.lnk" -ErrorAction SilentlyContinue -Verbose
			Write-host "Deleting Google Chrome scheduled tasks"
			$tasks = Get-TasksWindows7

			if ($win10) {
				Get-ScheduledTask | ? { $_.TaskName -like "*google*" } | % { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false }
			}
			elseif ((!$win10) -and ($null -ne ($tasks | ? { $_.name -like "*google*" }))) {
				$taskScheduler = New-Object -ComObject Schedule.Service
				$taskScheduler.Connect('localhost')
				$rootFolder = $taskScheduler.GetFolder('\')
				$tasks = $rootFolder.GetTasks(0) 
				$tasks | ? { $_.name -like "*google*" } | % {
					$rootFolder.DeleteTask($_.Name, $null)
				}
			}
		} 
	} until (!$processesFound)
}
else {
	Write-host "Google Chrome is installed on this computer"
}

# HTML creating
if ($Corner){
	$htmlBody = @"
	<html>
	<head>
		<style>
			* {
				margin: 0;
				padding: 0;
			}
			body{
				background-color: black;
			}
		</style>
	</head>
	<body id="main">
		<div style="display: inline-block">
		<iframe id="ytplayer" type="text/html" width="1536" height="864"
			src="http://www.youtube.com/embed/$($YoutubeID)?autoplay=1&mute=1&showinfo=0&controls=0" frameborder="0"></iframe>
		<iframe id="ytplayer" type="text/html" width="1536" height="864"
			src="http://www.youtube.com/embed/$($YoutubeID)?autoplay=1&mute=1&showinfo=0&controls=0" frameborder="0"></iframe>
		</div>
	</body>
	
	</html>
"@
}
else {
	# API request
	try {
		$request = Invoke-WebRequest -Uri $requestURL -Method POST -Headers $requestHeaders -ea Stop
	}
	catch [exception] {
		$Error[0]
	}

	$requestContent = ($request.Content | ConvertFrom-Json).value | ConvertFrom-Json
	$displayHeight = $requestContent | ? { $_.key -eq "display.height" } | % { $_.value }
	$displayWidth = $requestContent | ? { $_.key -eq "display.width" } | % { $_.value }

	if (($displayHeight -eq $null) -or ($displayWidth -eq $null) -or`
		($displayHeight -eq "") -or ($displayWidth -eq "") -or `
		($displayHeight -eq 0) -or ($displayWidth -eq 0)) {
			$a = Get-WmiObject -Class Win32_DesktopMonitor
			
			for ($i = 0; $i -le (($a | measure-object).count - 1); $i++) {
				(-join($a[$i].screenwidth, 'x', $a[$i].screenheight))
				
				if ($a[$i].screenwidth -ne $null) {
					$displayWidth = $a[$i].screenwidth
				}

				if ($a[$i].screenheight -ne $null) {
					$displayHeight = $a[$i].screenheight
				}
			}
	}

	$htmlBody = @"
	<html>
	<head>
		<style>
			* {
				margin: 0;
				padding: 0;
			}
			body{
				background-color: black;
			}
		</style>
	</head>
	<body id="main">
		<iframe id="ytplayer" type="text/html" width="$($displayWidth)" height="$($displayHeight)"
			src="http://www.youtube.com/embed/$($YoutubeID)?autoplay=1&mute=1&showinfo=0&controls=0" frameborder="0"></iframe>
	</body>
	</html>
"@
}

New-Item -Path $snDir -Name "stream_YT.html" -ItemType File -Value $htmlBody -Force 

# Adding Task
if ($win10) {
	$taskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $actionW10
	$taskPrincipal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId "sn"
	$taskTriger = New-ScheduledTaskTrigger -Once -at $timeStart

	Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $taskAction -Principal $taskPrincipal -Trigger $taskTriger -Force
}
else {
	$dateStart = New-Object -TypeName DateTime -ArgumentList:(2020,10,16)
	$timeStart = (Get-Date $timeStart -DisplayHint Time -Format "HH:mm" | Out-String).trim()
	$FormatHack = ($([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortDatePattern) -replace 'M+/', 'MM/') -replace 'd+/', 'dd/'
	schtasks.exe /Create /TN $taskName /TR "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe $actionW7" /SC once /ST $timeStart /SD $dateStart.ToString($FormatHack) /RL HIGHEST /F
}
