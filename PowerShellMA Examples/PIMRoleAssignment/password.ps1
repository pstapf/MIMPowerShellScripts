param
(

 $Username,
 $Password,
 $Action, # will be set to either 'Set' or 'Change'
 $OldPassword,
 $NewPassword,
 [switch] $UnlockAccount,
 [switch] $ForceChangeAtLogOn,
 [switch] $ValidatePassword
)

BEGIN
{
}

PROCESS
{
  # grab the sAMAccountName value for use with this
  # strange system, that we are sync'in passwords
  # with using this MA
  $AccountName = $_["username"].Value
  "Action: $Action" | Out-File "C:\Temp\_Options.txt"
  "Old pwd: $OldPassword" | Out-File "C:\Temp\_Options.txt" -Append
  "New pwd: $NewPassword" | Out-File "C:\Temp\_Options.txt" -Append
  "Unlock: $UnlockAccount" | Out-File "C:\Temp\_Options.txt" -Append
  "Force change: $ForceChangeAtLogOn" | Out-File "C:\Temp\_Options.txt" -Append
  "Validate: $ValidatePassword" | Out-File "C:\Temp\_Options.txt" -Append
  "$AccountName - $NewPassword" | Out-File "C:\Temp\_PasswordSets.txt"
  # just throw an exception if the password set/change is unsuccesful
}

END
{
}