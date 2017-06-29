param
(
	$username,
	$password,
	$operationtype = "full",
	[bool] $usepagedimport,
	$pagesize
)

begin
{
    # Load Active Directory Module für PowerShell
    Import-Module ActiveDirectory
    Import-Module AzureAD

    # Connect to AzureAD with credentials from MA config
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential $Username, $SecurePassword
    Connect-AzureAD -Credential $creds | Out-Null

    # Get FQDN domain name from DN components
    function GetDomainNameFromDN($dn)
    {
        $domainName= $dn -replace '^.*?,dc=' -replace ',dc=', '.'
        $domainName   
    }

    # Convert ms-DS-consistencyGUID to Azure ImmutableId
    function GetImmutableIdFromConsistancyGUID($consistancyGUID)
    {
        $ImmutableId = [System.Convert]::ToBase64String($consistancyGUID)
        $ImmutableId
    }

    # Load configuration data from xml file
    $config = [XML](Get-Content C:\PSMA\PIMRoleAssignment\config.xml)

}

process
{
    # Get list of all roles with displayName and GUID
    $allEligibleRoles=Get-ADGroup -Filter 'extensionAttribute15 -eq "Eligible"' -SearchBase $config.PimRoles.ADRoleContainer -Properties extensionAttribute14,extensionAttribute15
    $allPermanentRoles=Get-ADGroup -Filter 'extensionAttribute15 -eq "Permanent"' -SearchBase $config.PimRoles.ADRoleContainer -Properties extensionAttribute14,extensionAttribute15

    foreach ($EligibleRole in $allEligibleRoles)
    {
        $EligibleMember = Get-ADGroupMember -Identity $EligibleRole.SamAccountName
        $PermanentRole = $allPermanentRoles | where { $_.extensionAttribute14 -eq $EligibleRole.extensionAttribute14 }
        $PermanentMember = Get-ADGroupMember -Identity $PermanentRole.SamAccountName

        If ($EligibleMember -eq $null) { $EligibleMember = @() }
        If ($PermanentMember -eq $null) { $PermanentMember = @() }

        $PermanentMemberClean = (Compare-Object -ReferenceObject $EligibleMember -DifferenceObject $PermanentMember | where { $_.SideIndicator -eq '=>' }).InputObject

        foreach ($eMember in $EligibleMember)
        {
            $domain = GetDomainNameFromDN $eMember.distinguishedName
            $user = Get-ADUser -Identity $eMember.ObjectGUID -Properties ms-DS-ConsistencyGUID -Server $domain

            $ImmutableId = GetImmutableIdFromConsistancyGUID $user.'ms-DS-ConsistencyGUID'
            $AADUser=Get-AzureADUser -Filter "ImmutableId eq '$ImmutableId'" 


            $obj = @{}
	        $obj.RoleAssignmentId =  $AADUser.ObjectId + "_" + $EligibleRole.extensionAttribute14
	        $obj.objectclass = "PIMRoleAssignment"
            $obj.RoleId = $EligibleRole.extensionAttribute14
            $obj.UserId = $AADUser.ObjectId
            $obj.RoleDisplayName = ($EligibleRole.Name.Replace('(Eligible)',"")).Trim()
            $obj.UserLogonName = $AADUser.UserPrincipalName
            $obj.RoleAssignmentType = "Eligible"
            $obj
        }

        foreach ($pMember in $PermanentMemberClean)
        {
            $domain = GetDomainNameFromDN $pMember.distinguishedName
            $user = Get-ADUser -Identity $pMember.ObjectGUID -Properties ms-DS-ConsistencyGUID -Server $domain

            $ImmutableId = GetImmutableIdFromConsistancyGUID $user.'ms-DS-ConsistencyGUID'
            $AADUser=Get-AzureADUser -Filter "ImmutableId eq '$ImmutableId'" 


            $obj = @{}
	        $obj.RoleAssignmentId =  $AADUser.ObjectId + "_" + $PermanentRole.extensionAttribute14
	        $obj.objectclass = "PIMRoleAssignment"
            $obj.RoleId = $PermanentRole.extensionAttribute14
            $obj.UserId = $AADUser.ObjectId
            $obj.RoleDisplayName = ($PermanentRole.Name.Replace('(Permanent)',"")).Trim()
            $obj.UserLogonName = $AADUser.UserPrincipalName
            $obj.RoleAssignmentType = "Permanent"
            $obj
        }

    }
}

end
{
}