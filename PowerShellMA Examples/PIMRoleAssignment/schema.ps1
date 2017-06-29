$obj = new-object -type pscustomobject
$obj | add-member -type noteproperty -name "Anchor-RoleAssignmentId|String" -Value "RoleAssignmentGUID"
$obj | add-member -type noteproperty -name "objectClass|String" -Value "PIMRoleAssignment"
$obj | add-member -type noteproperty -name 'RoleId|String' -value "RoleGUID Azure"
$obj | add-member -type noteproperty -name 'UserId|String' -value "UserGUID Azure"
$obj | add-member -type noteproperty -name 'RoleDisplayName|String' -value "RoleDisplayName"
$obj | add-member -type noteproperty -name 'UserLogonName|String' -value "UserLogonName"
$obj | add-member -type noteproperty -name 'RoleAssignmentType|String' -value "Eligible|Permanent"
$obj

$obj = new-object -type pscustomobject
$obj | add-member -type noteproperty -name "Anchor-EventId|String" -Value "identifier"
$obj | add-member -type noteproperty -name "objectClass|String" -Value "PIMRoleEvent"
$obj | add-member -type noteproperty -name "AdditionalInformation|String" -Value "infostring"
$obj | add-member -type noteproperty -name "CreationDateTime|String" -Value "timestamp"
$obj | add-member -type noteproperty -name "ExpirationDateTime|String" -Value "timestamp"
$obj | add-member -type noteproperty -name "RequestType|String" -Value "requestType"
$obj | add-member -type noteproperty -name "RequestorId|String" -Value "requestorId"
$obj | add-member -type noteproperty -name "RequestorName|String" -Value "requestorName"
$obj | add-member -type noteproperty -name "RoleId|String" -Value "roleId"
$obj | add-member -type noteproperty -name "RoleDisplayName|String" -Value "roleDisplayName"
$obj | add-member -type noteproperty -name "TenantId|String" -Value "TenantId"
$obj | add-member -type noteproperty -name "UserId|String" -Value "UserId"
$obj | add-member -type noteproperty -name "UserLogonName|String" -Value "UPN"
$obj | add-member -type noteproperty -name "UserDisplayName|String" -Value "UserDisplayName"
$obj