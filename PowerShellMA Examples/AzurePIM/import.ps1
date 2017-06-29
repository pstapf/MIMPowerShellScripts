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
    # Get this DLL from Windows Azure SDK or Azure AD Connect Folder
    Add-Type -Path 'C:\PSMA\AzurePIM\Microsoft.IdentityModel.Clients.ActiveDirectory.dll'

    # Load configuration data file
    $config = [XML](Get-Content C:\PSMA\AzurePIM\config.xml)

    # This is the tenant id of you Azure AD. You can use tenant name instead if you want.
    $tenantID = $config.AzurePIM.TenantName
    $authString = "https://login.microsoftonline.com/$tenantID" 

    # The resource URI for your token.
    $resource = "https://graph.microsoft.com/"

    # This is the common client id.
    $client_id = "1950a258-227b-4e31-a9cf-717495945fc2"

    # Create a client credential with the above common client id, username and password.
    $creds = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential" -ArgumentList $username,$password

    # Create a authentication context with the above authentication string.
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authString

    # Acquire access token from server.
    $authenticationResult = $authContext.AcquireToken($resource,$client_id,$creds)

    # Use the access token to setup headers for your http request.
    $authHeader = $authenticationResult.AccessTokenType + " " + $authenticationResult.AccessToken
    $headers = @{"Authorization"=$authHeader; "Content-Type"="application/json"}
}

process
{
    # Get list of all roles with displayName, all role assignments and all role operational events 
    $allRoles=(Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/privilegedRoles" -Headers $headers).value
    $allRolesAssignments=(Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/privilegedRoleAssignments" -Headers $headers).value
    $allRoleEvents=(Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/privilegedOperationEvents" -Headers $headers).value

    foreach ($RoleAssignment in $allRolesAssignments)
    {
        # Exclude role assignments of uses defined in XML config (Cloud Only Users)
        if ($config.AzurePIM.ExcludedUsers.user.objectid -notcontains $RoleAssignment.userId)
        {
            $obj = @{}
	        $obj.RoleAssignmentId = $RoleAssignment.Id
	        $obj.objectclass = "PIMRoleAssignment"
            $obj.RoleId = $RoleAssignment.roleId
            $obj.UserId = $RoleAssignment.userId

            $obj.RoleDisplayName = ($allRoles | where { $_.Id -eq $RoleAssignment.roleId }).Name

            # Call GraphAPI to get userPrincipalName
            $uri = "https://graph.microsoft.com/v1.0/users/" + $RoleAssignment.userId
            $user = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
            $obj.UserLogonName = $user.userPrincipalName

            # Eligible role assignments show up as isElevated=false, or isElevated=true AND a expirationDateTime assigned.
            If ($RoleAssignment.isElevated -eq $true -and $RoleAssignment.expirationDateTime -eq $null)
            {
                $obj.RoleAssignmentType = "Permanent"
            }
            else
            {
                $obj.RoleAssignmentType = "Eligible"
            }

            $obj
        }
    }

    foreach ($RoleEvent in $allRoleEvents)
    {
            $obj = @{}
            $obj.EventId = $RoleEvent.Id
            $obj.objectClass = "PIMRoleEvent"
            If ($RoleEvent.additionalInformation -ne "") { $obj.AdditionalInformation = $RoleEvent.additionalInformation }
            If ($RoleEvent.creationDateTime -ne "") { $obj.CreationDateTime = $RoleEvent.creationDateTime }
            If ($RoleEvent.expirationDateTime -ne "") { $obj.ExpirationDateTime = $RoleEvent.expirationDateTime }
            If ($RoleEvent.requestType -ne "") { $obj.RequestType = $RoleEvent.requestType }
            If ($RoleEvent.requestorId -ne "") { $obj.RequestorId = $RoleEvent.requestorId }
            If ($RoleEvent.requestorName -ne "") { $obj.RequestorName = $RoleEvent.requestorName }
            If ($RoleEvent.roleId -ne "") { $obj.RoleId = $RoleEvent.roleId }
            If ($RoleEvent.roleName -ne "") { $obj.RoleDisplayName = $RoleEvent.roleName }
            If ($RoleEvent.tenantId -ne "") { $obj.TenantId = $RoleEvent.tenantId }
            If ($RoleEvent.userId -ne "") { $obj.UserId = $RoleEvent.userId }
            If ($RoleEvent.userMail -ne "") { $obj.UserLogonName = $RoleEvent.userMail }
            If ($RoleEvent.userName -ne "") { $obj.UserDisplayName = $RoleEvent.userName }
            If ($RoleEvent.referenceKey -ne "") { $obj.ReferenceKey = $RoleEvent.referenceKey }
            If ($RoleEvent.referenceSystem -ne "") { $obj.ReferenceSystem = $RoleEvent.referenceSystem }
            $obj
    }
}

end
{
}