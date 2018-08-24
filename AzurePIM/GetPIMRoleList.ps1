# Getting a list of all Azure PIM roles by Microsoft Graph API
# Used to setup onPremises AD groups for Azure AD PIM PowerShell Connector for MIM 2016

# Get this DLL from Windows Azure SDK or Azure AD Connect Folder
Add-Type -Path 'C:\PSMA\AzurePIM\Microsoft.IdentityModel.Clients.ActiveDirectory.dll'

# This is the tenant id of you Azure AD. You can use tenant name instead if you want.
$tenantID = "<tenantname>.onmicrosoft.com"
$authString = "https://login.microsoftonline.com/$tenantID" 

# Here, the username must be MFA disabled user Admin at least, and must not be a live id.
$username = read-host -Prompt "AzureAD Account Name"
$response = Read-host "Password" -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($response))

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

# Get list of PIM roles
$result=Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/privilegedRoles" -Headers $headers
$result.value
