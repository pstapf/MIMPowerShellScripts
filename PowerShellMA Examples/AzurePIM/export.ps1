param
(
	$username = "",
	$password = ""
)

begin
{
	function log($message)
	{
		write-debug $message
		$datum = Get-Date -Format "dd.MM.yyyy - HH:mm:ss"
		$datum + ": " + $message | out-file C:\PSMA\AzurePIM\logs\PIMRole-export.log -append
	}
	
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
	$error.clear()
	
	$errorstatus = "success"
	$errordetails = ""
		
	$identifier = $_."[Identifier]"
	$anchor = $_."[DN]"
	$objectmodificationtype = $_."[ObjectModificationType]"
	$changedattrs = $_.'[ChangedAttributeNames]'
	$_ | out-file C:\PSMA\AzurePIM\logs\RoleAssignmentExportObjects.txt -Force
	
	try
	{
		$errorstatus = "success"
		
        # Create new PIM role assignment objects
		if ( $objectmodificationtype -eq 'Add' )
		{
            $newrole = @{}
            $newrole.roleId = $_.RoleId
            $newrole.userId = $_.UserId
            $body = $newrole | ConvertTo-Json
            $result=Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/beta/privilegedRoleAssignments" -Headers $headers -Body $body
            
            # Role Assignments are Eligible by default, so only change if it should be permanent.
            if ($_.RoleAssignmentType -eq "Permanent")
            {
                $uri = "https://graph.microsoft.com/beta/privilegedRoleAssignments/" + $anchor + "/makePermanent"
                $result=Invoke-RestMethod -Method POST -Uri $uri -Headers $headers
            }
            
            $message = "[PIM Role assignment] adding user: " + $_.UserLogonName + " as a " + $_.RoleAssignmentType + " member to: " + $_.RoleDisplayName
            log $message
		}

        # Delete old PIM role assignment objects
		if ( $objectmodificationtype -eq 'Delete' )
		{
            $uri = "https://graph.microsoft.com/beta/privilegedRoleAssignments/" + $anchor
            $result=Invoke-RestMethod -Method DELETE -Uri $uri -Headers $headers

            $message = "[PIM Role assignment] removing user: " + $_.UserLogonName + " from role: " + $_.RoleDisplayName
            log $message
		}

        # Switch PIM role assignment type between permanent and eligible
		if ( $objectmodificationtype -eq 'Replace' )
		{
            if ( $changedattrs -contains "RoleAssignmentType" )
            {
                if ($_.RoleAssignmentType -eq "Eligible")
                {
                    $uri = "https://graph.microsoft.com/beta/privilegedRoleAssignments/" + $anchor + "/makeEligible"
                    $result=Invoke-RestMethod -Method POST -Uri $uri -Headers $headers

                    $message = "[PIM Role modification] change user: " + $_.UserLogonName + " to a " + $_.RoleAssignmentType + " member in: " + $_.RoleDisplayName
                    log $message
                }

                if ($_.RoleAssignmentType -eq "Permanent")
                {
                    $uri = "https://graph.microsoft.com/beta/privilegedRoleAssignments/" + $anchor + "/makePermanent"
                    $result=Invoke-RestMethod -Method POST -Uri $uri -Headers $headers

                    $message = "[PIM Role modification] change user: " + $_.UserLogonName + " to a " + $_.RoleAssignmentType + " member in: " + $_.RoleDisplayName
                    log $message
                }
            }
		}
	}
	catch [exception]
	{
		$errorstatus = "export-exception"
		$errordetails = $error[0].exception
        log $errordetails
	}

	# we do not handle any errors in the current version but
	# instead just return success and let FIM handle any discovery
	# of missing adds or updates
	$status = @{}
	$status."[Identifier]" = $identifier
	$status."[ErrorName]" = $errorstatus
	$status."[ErrorDetail]" = $errordetails
	$status
}

end
{
}