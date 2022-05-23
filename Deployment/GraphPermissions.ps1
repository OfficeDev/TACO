# Your tenant id (in Azure Portal, under Azure Active Directory -> Overview )
$TenantID=""
# Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"
# Name of the manage identity (same as the Logic App name)
$DisplayNameOfMSI="AACQAdministration" 
# Check the Microsoft Graph documentation for the permission you need for the operation

$MSI = Get-AzFunctionApp -Name $($outputs.Outputs.azFuncAppName.Value) -ResourceGroup $rgName

$PermissionName = "Sites.ReadWrite.All" 
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
Connect-MgGraph -AccessToken $token.Token


$GraphServicePrincipal = Get-MgServicePrincipal -Filter "startswith(DisplayName,'Microsoft Graph')" | Select-Object -first 1 
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -AppRoleId $AppRole.Id -ServicePrincipalId $MSI.identityprincipalid -ResourceId $GraphServicePrincipal.Id -PrincipalId $MSI.IdentityPrincipalId

$PermissionName = "Files.Read.All"

$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -AppRoleId $AppRole.Id -ServicePrincipalId $MSI.IdentityPrincipalId -ResourceId $GraphServicePrincipal.Id -PrincipalId $MSI.IdentityPrincipalId

$PermissionName = "Group.Read.All"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -AppRoleId $AppRole.Id -ServicePrincipalId $MSI.IdentityPrincipalId -ResourceId $GraphServicePrincipal.Id -PrincipalId $MSI.IdentityPrincipalId
