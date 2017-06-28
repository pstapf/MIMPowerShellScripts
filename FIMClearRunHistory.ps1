<#
	.Synopsis
	Remove Entries from the Management Agent Run History of a FIM 2010 Server

	.Description
	Remove FIM 2010 Run History Entries and preserve Entries of "x" Days
		
	.Example
	FIMClearRunHistory -preserveDays 0
	Clears the FIM 2010 Run History Completely

	.Example
	FIMClearRunHistory -preserveDays 5
	Clears the FIM 2010 Run History but preserve entries from the last 5 Days

	.Parameter PreserveDays
	Only delete Run History entries older than x Days

	.Notes
	NAME:  FIMClearRunHistory
	AUTHOR: Peter Stapf
	LASTEDIT: 20.01.2016
	KEYWORDS: FIM 2010, Run History, Management Agent

	#Requires -Version 2.0
#>

param([int]$PreserveDays=$(read-host -prompt "PreserveDays"))
$PreserveDays--

$DeleteDay = Get-Date
$DayDiff = New-Object System.TimeSpan $PreserveDays, 0, 0, 0, 0
$DeleteDay = $DeleteDay.Subtract($DayDiff)

if ($PreserveDays -eq -1)
	{
	Write-Host "Deleting complete run history"
	}
else
	{
	Write-Host "Deleting run history earlier than:" $DeleteDay.toString(‘dd.MM.yyyy’)
	}
	
$lstSrv = @(get-wmiobject -class "MIIS_SERVER" -namespace "root\MicrosoftIdentityIntegrationServer" -computer ".")
Write-Host "Result: " $lstSrv[0].ClearRuns($DeleteDay.toString(‘yyyy-MM-dd’)).ReturnValue

Trap
	{
  Write-Host "`nError: $($_.Exception.Message)`n" -foregroundcolor white -backgroundcolor darkred
  Exit
	}
