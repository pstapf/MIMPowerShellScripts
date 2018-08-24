<#
	.Synopsis
	Starts the FIM 2010 Management Agents in a sequence

	.Description
	Starting FIM 2010 Management Agents in a sequence based on a XML config file
		
	.Example
	FIMRunCycle -configfile config.xml
	Starts the RunCycle based on the specified config file.
	
	.Example
	FIMRunCycle -configfile config.xml -profiles default,ad
	Starts only MA RunProfiles in category default and ad

	.Parameter configfile
	Specify the name of the XML config file
	
	.Parameter disableExport
	Do not run MA Profiles called Export "E"
	
	.Parameter profiles
	Specify one or more Profilecategories to run, default is all, seperate by comma
	
	.Notes
	NAME:  FIMRunCycle
	AUTHOR: Peter Stapf
	LASTEDIT: 04/04/2018
	KEYWORDS: FIM 2010, Run Cycle, Management Agent

	#Requires -Version 2.0
#>
param(
	[string]$configfile=$(Read-Host -prompt "Configfile"),
	[array]$profiles="all",
	[switch]$disableExport
)

### Load Configuration Data ###
[xml]$maconfig=(Get-Content $configfile)
"" > $maconfig.runcycle.logfile
"" > runScriptLog.txt

### Functions ###
$line = "---------------------------------------------------------------------------------"
function Write-Output-Banner([string]$msg) {
	Write-Output $line,(" "+$msg),$line
	Write-Output $line,(" "+$msg),$line >> $maconfig.runcycle.logfile
}

function Write-Output-Text([string]$msg,[bool]$IsError=$false) { 
	
	if ($IsError)
	{
		Write-Host -BackgroundColor Black -ForegroundColor Yellow $msg
	}
	else
	{
		Write-Output $msg
	}
	Write-Output $msg >> $maconfig.runcycle.logfile
}

function CalculateRuntime($startTime) {
	$datetimeAfter = Get-Date
	$timeSpan = [string]($datetimeAfter - $startTime)
	$timeSpanString = ("{0:hh:mm:ss}" -f $timeSpan).substring(0,8)
	$timeSpanString
}

function OutputScriptResult($returnCode) {
	if ($returnCode) 
	{
		$runtime=Calculateruntime($datetimeBefore)
		Write-Output-Text(" - Done with status: success - runtime: "+$runtime + "`n") 
	}
	else
	{ Write-Output-Text " - Script failed`n" $true }
}

function AgentHasImports($agent) {
	$maData=get-wmiobject -class "MIIS_ManagementAgent" `
							-namespace "root\MicrosoftIdentityIntegrationServer" `
							-computername $maconfig.runcycle.computername `
							| where {$_.name -eq $agent }

	#Anzahl der Import Änderungen ermitteln
	[xml]$maResult=$maData.RunDetails().ReturnValue
	[int]$ImportSum+=$maResult."run-history"."run-details"."step-details"."staging-counters"."stage-add"."#text"
	[int]$ImportSum+=$maResult."run-history"."run-details"."step-details"."staging-counters"."stage-update"."#text"
	[int]$ImportSum+=$maResult."run-history"."run-details"."step-details"."staging-counters"."stage-delete"."#text"
	[int]$ImportSum+=$maResult."run-history"."run-details"."step-details"."staging-counters"."stage-delete-add"."#text"
	[int]$ImportSum+=$maResult."run-history"."run-details"."step-details"."staging-counters"."stage-rename"."#text"

	if ($ImportSum -eq 0) 
		{ $false }
	else 
		{ $true }
}

function StartRunProfile($MAobj, $runProfile) {
		Write-Output-Text(" - Starting Profile: "+$runProfile)
		$datetimeBefore = Get-Date
		$result = $MAobj.Execute($runProfile)
		$runtime=Calculateruntime($datetimeBefore)
		if ($result.ReturnValue.tostring() -eq "success")
			{ Write-Output-Text(" - Done with status: " + $result.ReturnValue + " - runtime: " + $runtime + "`n") }
		else
			{ 
			$message=" - Done with status: " + $result.ReturnValue + " - runtime: " + $runtime + "`n"
			Write-Output-Text $message $true
			}
}

function AgentHasExports($agent) {
	$maData=get-wmiobject -class "MIIS_ManagementAgent" `
							-namespace "root\MicrosoftIdentityIntegrationServer" `
							-computername $maconfig.runcycle.computername `
							| where {$_.name -eq $agent }
	
	#Anzahl Pending Exports ermitteln
	[int]$ExportSum+=$maData.NumExportAdd().ReturnValue
	[int]$ExportSum+=$maData.NumExportUpdate().ReturnValue
	[int]$ExportSum+=$maData.NumExportDelete().ReturnValue

	if ($ExportSum -eq 0) 
		{ $false }
	else 
		{ $true }
}


### Get Management Agent Data ###
$allMA = @(get-wmiobject -class "MIIS_ManagementAgent" -namespace "root\MicrosoftIdentityIntegrationServer" -computername $maconfig.runcycle.computername)
$numOfExecDone = 0


### Main Script ###
do {
	Write-Output-Banner("Execution #:"+(++$numOfExecDone)+" - Date: "+(date) + " - Profiles: " + $profiles)
	$CycleStartTime=Get-Date
	
	foreach($MANextRun in $maconfig.runcycle.ma) {
		$found = $false;
		
		foreach($MA in $allMA) {	
		    if(!$found) {
			if($MA.Name.Equals($MANextRun.name)) {
				$MAstartTime = get-date
				$found=$true
				if ($profiles -eq "all" -or $profiles -eq $MANextRun.profile -or $MANextRun.profile -eq $null)
				{
						
				Write-Output-Banner("MA: "+$MA.Name+" [Type: "+$MA.Type+"]")
				# PreScripte starten
				if ( $MANextRun.preScript -ne "" )
				{
					Write-Output-Text(" - Starting Pre-Script: "+$MANextRun.preScript.name)
					$datetimeBefore = Get-Date
					powershell -c $MANextRun.preScript.name >> runScriptLog.txt
					$scriptReturn=$?
					OutputScriptResult($scriptReturn)
					if ($scriptReturn -eq $false -and $MANextRun.preScript.ContinueOnError -eq $false)
					{ 
						"Error in PreScript - Skipping RunProfiles for this MA"
						continue
					}
				}
				
				# MA Profile starten
				$skipConfirm=$false
				foreach($profileName in $MANextRun.profilesToRun) {
					if (($disableExport.IsPresent) -and ($profileName -eq "E")) 
					{
						Write-Output-Text " - !! Export Profile disabled on user request !!`n" $true
						$skipConfirm=$true
					}
					else
					{
						$msg=" - RunProfile " + $profileName + " skipped: no changes`n"
						$doCheckUpdates=$MANextRun.checkUpdates
						
						#Wenn UpdateCheck aktiviert, dann prüfe auf Import-Änderungen und Pending Exporte
						#und überspringe Sync bzw Export Profile. Sonst Lauf komplett starten.
						if ($doCheckUpdates -eq "true")
						{
							switch ($profileName) {
								"DS" {
										if ( AgentHasImports($MANextRun.Name) )
											{ StartRunProfile $MA $profileName }
										else
											{ Write-Output-Text $msg $true }
									 }
								"FS" {
										if ( AgentHasImports($MANextRun.Name) )
											{ StartRunProfile $MA $profileName }	 	
										else
											{ Write-Output-Text $msg $true }								 }
								"E" {
										if ( AgentHasExports($MANextRun.Name) )
											{ StartRunProfile $MA $profileName }
										else
											{ Write-Output-Text $msg $true ; $skipConfirm=$true }
									}
								"DISO" {
										if ($skipConfirm)
											{ Write-Output-Text " - Confirming DISO skipped: no export`n" $true }	 	
										else
											{ StartRunProfile $MA $profileName }								 }
								"FISO" {
										if ($skipConfirm)
											{ Write-Output-Text " - Confirming FISO skipped: no export`n" $true }	 	
										else
											{ StartRunProfile $MA $profileName }								 }
								default { StartRunProfile $MA $profileName }
							}
						}
						else
						{
							StartRunProfile $MA $profileName
						}
					}
				}
				
				# PostScripte starten
				if ( $MANextRun.postScript -ne "")
				{
					if ( $MANextRun.postScript.RunOnExportOnly -eq $true -and $skipConfirm -eq $true )
					{
						Write-Output-Text " - PostScript skipped: no export " $true
					}
					else
					{
						Write-Output-Text(" - Starting Post-Script: "+$MANextRun.postScript.name)
						$datetimeBefore = Get-Date;
						powershell -c $MANextRun.postScript.name >> runScriptLog.txt
						OutputScriptResult($?)
					}
				}
				$runtime=Calculateruntime($MAstartTime)
				Write-Output-Banner("Complete MA runtime: " + $runtime)
				Write-Output-Text("")
				Start-Sleep -s $MANextRun.waitSeconds
			}
			}
		    }
		}
		if(!$found) { Write-Output-Text("Not found MA name :"+$MANextRun.name); }
	}
	
	$runtime=Calculateruntime($CycleStartTime)
	Write-Output-Banner("Complete Cycle runtime: " + $runtime)
	"Profiles: " + $profiles + " - Runtime: " + $runtime + " - " + (get-date) >> runTimes.log
	
	$continue = ($numOfExecDone -lt $maconfig.runcycle.numOfExecs) -OR ($maconfig.runcycle.numOfExecs -EQ 0)
	if($continue) { 
		Write-Output-Banner("Sleeping "+$maconfig.runcycle.cycleWaitSeconds+" seconds")
		Start-Sleep -s $maconfig.runcycle.cycleWaitSeconds
	}
} while($continue)
