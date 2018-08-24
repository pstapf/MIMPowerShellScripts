<#
	.Synopsis
	Manage Azure AD Roles based on Active Directory Groups

	.Description
	Reads defined Active Directory group and adds/removes users to/from AzureAD Admin roles based on group memberships
		
	.Example
	AzureRoleAdmin -configfile config.xml
	Starts the AzureRoleAdmin management based on the specified config file.
	
	.Parameter configfile
	Specify the name of the XML config file
	
	.Notes
	NAME:  AzureRoleAdmin
	AUTHOR: Peter Stapf
	LASTEDIT: 07/20/2018
	KEYWORDS: AzureAD, Roles, ActiveDirectory

	#Requires -Version 4.0
#>
param ($configfile)
If (-not $configfile) { Throw "Configuration file mus be provided!" }
If (-not (Test-Path $configfile)) { Throw "Configuration file not found!" }
 
Import-Module MSOnline
Import-Module ActiveDirectory

$config = [XML](Get-Content $configfile)

function WriteLog ($message, $level)
{
    (Get-Date -Format s).ToString() + " [" + $level + "]: " + $message >> $config.azureRoles.logFile
}

function AddAzureRole ($RoleName, $Member)
{
    $message = "Add " + $Member + " to Role " + $RoleName
    WriteLog -message $message -level Debug
    Add-MsolRoleMember -RoleName $RoleName -RoleMemberEmailAddress $Member
    $message
}

function RemoveAzureRole ($RoleName, $Member)
{
    $message = "Remove " + $Member + " from Role " + $RoleName
    WriteLog -message $message -level Debug
    Remove-MsolRoleMember -RoleName $RoleName -RoleMemberEmailAddress $Member
    $message
}

foreach ($role in $config.azureRoles.managedRoles.Role)
{
    # Get member of ActiveDirectory group 
    $ADGroupMemberList = Get-ADGroupMember -Identity $role.ADGroupName

    # Get current member of AzureAD role
    $AzureRoleMemberList = Get-MsolRoleMember -RoleObjectId (Get-MsolRole -RoleName $role.AzureADRoleName).ObjectID -MemberObjectTypes User

    # Create UPN list of all members of the ActiveDirectory group, needed to compare to Azure Role Members
    [System.Collections.ArrayList]$ADGroupMemberUPNs = @()      
    foreach ($ADGroupMember in $ADGroupMemberList)
    {
        $ADGroupMemberUPNs += (Get-ADUser -Identity $ADGroupMember.samAccountName).UserPrincipalName
    }

    # Create UPN list of all current members of the AzureAD role 
    [System.Collections.ArrayList]$AzureRoleMemberUPNs = @($AzureRoleMemberList.EmailAddress)

    # Remove members to ignore from both UPN lists (see config file)
    foreach ($removeMember in $config.azureRoles.ignoreMemberList.memberName)
    {
        if ($AzureRoleMemberUPNs) 
        { $AzureRoleMemberUPNs.Remove($removeMember) }

        if ($ADGroupMemberUPNs)
        { $ADGroupMemberUPNs.Remove($removeMember) }
    }

    if (-not $AzureRoleMemberUPNs) { $AzureRoleMemberUPNs = @() }
    if (-not $ADGroupMemberUPNs) { $ADGroupMemberUPNs = @() }

    # Calculate delta between AD group and AzureAD roles
    $deltaList = Compare-Object -ReferenceObject $AzureRoleMemberUPNs -DifferenceObject $ADGroupMemberUPNs
   
    # Add or remove member of a AzureAD role
    foreach ($delta in $deltaList)
    {
        switch ($delta.SideIndicator)
        {
            "=>" { AddAzureRole -RoleName $role.AzureADRoleName -Member $delta.InputObject }
            "<=" { RemoveAzureRole -RoleName $role.AzureADRoleName -Member $delta.InputObject }
        }
    }
}