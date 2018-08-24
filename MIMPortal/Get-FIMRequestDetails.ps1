param($objectType, $attribute, $searchValue)
#Get all FIM/MIM request details of an object even it was a batch processing (msidmCompositeType)
#objectType = The objectType of the target object you are trying to get requests for.
#attribute = The attribute of the target object you want to use for searching
#searchValue = The value of the attribute of the target object you are searching requests for
#
#ex. Get-FIMRequestDetails.ps1 -objectType "Person" -attribute "AccountName" -searchValue "pstapf"
#
#This gets all requests matching the given target object.
#

# Load FIMAutomation SnapIn and FIMPowershellModule (http://fimpowershellmodule.codeplex.com)
if(@(get-pssnapin | where-object {$_.Name -eq "FIMAutomation"} ).count -eq 0) {add-pssnapin FIMAutomation}
Import-Module C:\Windows\System32\WindowsPowerShell\V1.0\Modules\FIM\FIMPowerShellModule.psm1

# Check if the object you are searching requests for exists in portal and get its GUID
$filter = "/" + $objectType + "[" + $attribute + "='" + $searchValue + "']"
$searchObject = Export-FIMConfig -OnlyBaseResources -CustomConfig "$filter"

If ($searchObject -ne $null)
{
    $searchObjectGuid = $searchObject.ResourceManagementObject.ObjectIdentifier.Replace("urn:uuid:","")
    Write-Host "Object found:" $searchValue " with GUID:" $searchObjectGuid
}
else
{
    Write-Host "The object you are searching for does not exists in FIM Portal"
    Exit
}

# Get the aggregated requests of the object you search for
$export=@()
$filter = "/Request[Target=/msidmCompositeType[/msidmElement=/" + $objectType + "[" + $attribute + "='" + $searchValue + "']]]" 
$export = Export-FIMConfig -OnlyBaseResources -CustomConfig "$filter"

# Get the single requests of the object you search for
$filter = "/Request[Target=/" + $objectType + "[" + $attribute + "='" + $searchValue + "']]"
$export += Export-FIMConfig -OnlyBaseResources -CustomConfig "$filter"
$requestlist = $export | Convert-FimExportToPSObject | Sort-Object msidmCompletedTime

# Get the RequestParameter of the object you search fo from all requests and add some requestDetails
If ($requestlist.count -gt 0)
{
    $resultItems = @()
    foreach ($requestItem in $requestList)
    {
        $resultItems += $requestItem | Get-FimRequestParameter | where { $_.Target -eq $searchObjectGuid } | ForEach-Object { 
        New-Object PSObject -Property @{
            Target = $_.Target
            Operation = $_.Operation
            Mode = $_.Mode
            Attribute = $_.PropertyName
            Value = $_.Value
            RequestName = $requestItem.DisplayName
            RequestGuid = $requestItem.ObjectID.Replace("urn:uuid:","")
            CompleteTime = $requestItem.msidmCompletedTime
            Status = $requestItem.RequestStatus
            }
        }
    }
    $resultItems
    
}
else
{
    Write-Host "No request found for the object you searched for."
}

