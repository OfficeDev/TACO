Param (
    [parameter(mandatory = $true)] [string]$displayName,   # Display name for your application registered in Azure AD 
    [parameter(mandatory = $true)] [ValidateLength(3, 24)] [string]$rgName,        # Name of the resource group for Azure
    [parameter(mandatory = $true)] [ValidateLength(3, 11)] [string]$resourcePrefix,                  # Prefix for the resources deployed on your Azure subscription (should be less than 11 characters)
    [parameter(mandatory = $true)] [ValidateSet('Australia Central','Australia East','Australia Southeast','Brazil South','Canada Central','Canada East','Central India','Central US','East Asia','East US 2','East US','France Central','Germany West Central','Japan East','Japan West','Korea Central','Korea South','North Central US','North Europe','Norway East','South Africa North','South Central US','South India','Southeast Asia','Sweden Central','Switzerland North','UAE North','UK South','UK West','West Central US','West Europe','West India','West US 2','West US 3','West US')] [string]$location,                   # Location (region) where the Azure resource are deployed
    [parameter(mandatory = $true)] [string]$serviceAccountUPN,                          # AzureAD Service Account UPN
    [parameter(mandatory = $true)] $serviceAccountSecret,                        # AzureAD Service Account password
    [parameter(mandatory = $false)] $teamsPSModuleVersion = "4.4.1",              # Microsoft Teams PowerShell module version
    [parameter(mandatory = $false)] $subscriptionID               # Microsoft Azure Subscription id  
)

$base = $PSScriptRoot
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Import required PowerShell modules for the deployment
If($PSVersionTable.PSVersion.Major -ne 7) { 
    Write-Error "Please install and use PowerShell v7.2.1 to run this script"
    Write-Error "Follow the instruction to install PowerShell on Windows here"
    Write-Error "https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2"
    return
}

Try
{
    Import-Module Az.Accounts, Az.Resources, Az.KeyVault -ErrorAction Stop  # Required to deploy the Azure resource
}
Catch
{
    Write-Error "Azure PowerShell module missing, please run Install-Module Az to install the required model"    
}

Try
{
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop  # Required to configure Graph permissions
}
Catch
{
    Write-Error "Microsoft.Graph.Applications module missing, please run Install-Module Microsoft.Graph to install the required model"    
}



# Connect to AzureAD and Azure using modern authentication
Write-Host -ForegroundColor blue "Azure sign-in request - Please check the sign-in window opened in your web browser"

Try
{
    Connect-AzAccount -WarningAction Ignore -ErrorAction Stop |Out-Null
}
Catch
{
    Write-Error "An error occured connecting to Azure using the Azure PowerShell module"
    $_.Exception.Message
}

# Validating if multiple Azure Subscriptions are active
If($subscriptionID -eq $null)
{
    [array]$AzSubscriptions = Get-AzSubscription |Where-Object {$_.State -eq "Enabled"}
    $menu = @{}
    If($(Get-AzSubscription |Where-Object {$_.State -eq "Enabled"}).Count -gt 1)
    {
        Write-Host "Multiple active Azure Subscriptions found, please select a subscription from the list below:"
        for ($i=1;$i -le $AzSubscriptions.count; $i++) 
        { 
                Write-Host "$i. $($AzSubscriptions[$i-1].Id)" 
                $menu.Add($i,($AzSubScriptions[$i-1].Id))
        }
        [int]$AZSelectedSubscription = Read-Host 'Enter selection'
        $selection = $menu.Item($AZSelectedSubscription) ; 
        Select-AzSubscription -Subscription $selection | Out-Null
    }
}
else
{
    Select-AzSubscription -Subscription $subscriptionID | Out-Null
}

Write-Host -ForegroundColor blue "Checking if app '$displayName' is already registered"
$AADapp = Get-AzADServicePrincipal -DisplayName $displayName
If ($AADapp.Count -gt 0) {
    Write-Warning "The Azure AD App name which was provided '$displayName' does already exist!"
    $ResetAADapp = Read-Host "Do you want to reset the credentials the existing Azure AD App registration? `r`nDoing this will impact any other application using this Azure AD App registration. (Answer with yes or no) "

    If($ResetAADapp -eq "yes")
    {
        Try
        {
            Remove-AzADSpCredential -DisplayName $displayName -ErrorAction Stop
        }
        Catch
        {
            Write-Error "An issue occured removing the credentials from the Azure AD application"
            $_.Exception.Message
        }

        Try
        {
            $newCredential = $AADapp|New-AzADSpCredential -ErrorAction Stop
        }
        Catch
        {
            Write-Error "An issue occured creating new credentials for the Azure AD application"
            $_.Exception.Message
        }

        #
        # Get the AppID and AppSecret from the newly registered App
        $clientID = $AADapp.AppId
        $clientsecret = $newCredential.SecretText

        # Get the tenantID from current AzureAD PowerShell session
        $tenantID = $(Get-AzTenant).Id
        Write-Host -ForegroundColor blue "New app '$displayName' registered into AzureAD"

    }
    ElseIf($ResetAADapp -eq "no")
    {
        write-host "user answered no"
        throw "Please rerun the deployment script by providing a different name for the displayname parameter"
    }
}
ElseIf([string]::IsNullOrEmpty($AADapp)){
    Write-Host -ForegroundColor blue "Register a new app in Azure AD using Azure Function app name"
    
    Try
    {
        $AADapp = New-AzADServicePrincipal -DisplayName $displayName -ErrorAction Stop
    }
    Catch
    {
        Write-Error "An issue occured creating registering the application"
        $_.Exception.Message
    }
  
    # Expose an API and create an Application ID URI
    $AppIdURI = "api://azfunc-" + $AADapp.AppId


    [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphApiApplication]$apiProperties = @{ 
        Oauth2PermissionScope  = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPermissionScope]@{ 
            AdminConsentDescription = "Allow the application to access $displayName on behalf of the signed-in user."
            AdminConsentDisplayName = "Access $displayName"
            IsEnabled = $true
            Type = "User"
            UserConsentDescription = "Allow the application to access $displayName on your behalf."
            UserConsentDisplayName = "Access $displayName"
            Value = "user_impersonation"
            Id = (New-Guid).Guid
        } 
    }

    Try {
        Get-AzAdApplication -DisplayName $displayName | Update-AzADApplication -IdentifierUri $AppIdURI -Api $apiProperties -ErrorAction Stop
        Write-Host -ForegroundColor blue "New app '$displayName' registered into AzureAD"
    }    
    Catch {
        Write-Error "Azure AD application registration error - Please check your permissions in Azure AD and review detailed error description below"
        $_.Exception.Message
    }

    #
    # Get the AppID and AppSecret from the newly registered App
    $clientID = $AADapp.AppId
    $clientsecret = $AADapp.PasswordCredentials.SecretText

    # Get the tenantID from current AzureAD PowerShell session
    $tenantID = $(Get-AzTenant).Id
}

Write-Host -ForegroundColor blue "Deploy resource to Azure subscription"
Try {
    New-AzResourceGroup -Name $rgName -Location $location -Force -ErrorAction Stop | Out-Null
}    
Catch {
    Write-Error "Azure Resource Group creation failed - Please verify your permissions on the subscription and review detailed error description below"
    $_.Exception.Message
}

Write-Host -ForegroundColor blue "Resource Group $rgName created in location $location - Now initiating Azure resource deployments..."
$deploymentName = 'deploy-' + (Get-Date -Format "yyyyMMdd-hhmm")
$parameters = @{
    resourcePrefix          = $resourcePrefix
    serviceAccountUPN       = $serviceAccountUPN
    serviceAccountSecret    = $serviceAccountSecret
    clientID                = $clientID
    appSecret               = $clientSecret
    TeamsPSModuleVersion    = $teamsPSModuleVersion
}

$outputs = New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $base\ZipDeploy\azuredeploy.json -TemplateParameterObject $parameters -Name $deploymentName
If ($outputs.provisioningState -ne 'Succeeded') {
    Write-Error "ARM deployment failed with error"
    $retry = Read-Host "Do you want to retry the deployment (yes/no)?"
    
    while($retry -eq "yes")
    {
        Write-Host "Retrying deployment Azure resource deployments"
        $outputs = New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $base\ZipDeploy\azuredeploy.json -TemplateParameterObject $parameters -Name $deploymentName

        If ($outputs.provisioningState -ne 'Succeeded') 
        {
            Write-Error "ARM deployment failed with error"
            $retry = Read-Host "Do you want to retry the deployment (yes/no)?"
        }
        If ($outputs.provisioningState -eq 'Succeeded') 
        {
            $retry = "no"
        }
    }

    if($retry -eq "no" -and $outputs.provisioningState -ne 'Succeeded')
    {
        throw "Deployment of the Azure resources failed, please review the error messages and review the logs available in the Azure Portal"
    }    
}

Write-Host -ForegroundColor blue "ARM template deployed successfully"

$CurrentUserId = Get-AzContext | ForEach-Object account | ForEach-Object Id

if($CurrentUserId -ne $serviceAccountUPN)
{
    # Assign current user with the permissions to list and read Azure KeyVault secrets (to enable the connection with the Power Automate flow)
    Write-Host -ForegroundColor blue "Assigning 'Secrets List & Get' policy on Azure KeyVault for user $CurrentUserId"
    Try {
        Set-AzKeyVaultAccessPolicy -VaultName $outputs.Outputs.azKeyVaultName.Value -ResourceGroupName $rgName -UserPrincipalName $CurrentUserId -PermissionsToSecrets list,get
    }
    Catch {
        Write-Error "Error - Couldn't assign user permissions to get,list the KeyVault secrets - Please review detailed error message below"
        $_.Exception.Message
    }

    # Assign service account with the permissions to list and read Azure KeyVault secrets (to enable the connection with the Power Automate flow)
    Write-Host -ForegroundColor blue "Assigning 'Secrets List & Get' policy on Azure KeyVault for user $serviceAccountUPN"
    Try {
        Set-AzKeyVaultAccessPolicy -VaultName $outputs.Outputs.azKeyVaultName.Value -ResourceGroupName $rgName -UserPrincipalName $serviceAccountUPN -PermissionsToSecrets list,get
    }
    Catch {
        Write-Error "Error - Couldn't assign user permissions to get,list the KeyVault secrets - Please review detailed error message below"
        $_.Exception.Message
    }    
}
else
{
    # Assign service account with the permissions to list and read Azure KeyVault secrets (to enable the connection with the Power Automate flow)
    Write-Host -ForegroundColor blue "Assigning 'Secrets List & Get' policy on Azure KeyVault for user $serviceAccountUPN"
    Try {
        Set-AzKeyVaultAccessPolicy -VaultName $outputs.Outputs.azKeyVaultName.Value -ResourceGroupName $rgName -UserPrincipalName $CurrentUserId -PermissionsToSecrets list,get
    }
    Catch {
        Write-Error "Error - Couldn't assign user permissions to get,list the KeyVault secrets - Please review detailed error message below"
        $_.Exception.Message
    }
}

<#
Write-Host -ForegroundColor blue "Getting the Azure Function App key for warm-up test"
## lookup the resource id for your Azure Function App ##
$azFuncResourceId = (Get-AzResource -ResourceGroupName $rgName -ResourceName $outputs.Outputs.azFuncAppName.Value -ResourceType "Microsoft.Web/sites").ResourceId

## compose the operation path for listing keys ##
$path = "$azFuncResourceId/host/default/listkeys?api-version=2021-02-01"
$result = Invoke-AzRestMethod -Path $path -Method POST

if($result -and $result.StatusCode -eq 200)
{
   ## Retrieve result from Content body as a JSON object ##
   $contentBody = $result.Content | ConvertFrom-Json
   $code = $contentBody.masterKey
}
else {
    Write-Error "Couldn't retrieve the Azure Function app master key - Warm-up tests not executed"
}

#Write-Host -ForegroundColor blue "Waiting 2 min to let the Azure function app to start"
#Start-Sleep -Seconds 120

#Write-Host -ForegroundColor blue "Warming-up Azure Function apps - This will take a few minutes"
#& $base\warmup.ps1 -hostname $outputs.Outputs.azFuncHostName.Value -code $code -tenantID $tenantID -clientID $clientID -secret $clientSecret
#>

Write-Host -ForegroundColor blue "Deployment script completed"

## Assigning the correct permissions to the Managed Identity of the App

$MSI = Get-AzFunctionApp -Name $($outputs.Outputs.azFuncAppName.Value) -ResourceGroup $rgName

## Connect to Graph API and retrieving Graph API id
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
Connect-MgGraph -AccessToken $token.Token
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "startswith(DisplayName,'Microsoft Graph')" | Select-Object -first 1 

# Assigning sites selected permission
$PermissionName = "Sites.Selected" 
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -AppRoleId $AppRole.Id -ServicePrincipalId $MSI.identityprincipalid -ResourceId $GraphServicePrincipal.Id -PrincipalId $MSI.IdentityPrincipalId | Out-Null

# Assigning group read all permissions
$PermissionName = "Group.Read.All"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -AppRoleId $AppRole.Id -ServicePrincipalId $MSI.IdentityPrincipalId -ResourceId $GraphServicePrincipal.Id -PrincipalId $MSI.IdentityPrincipalId | Out-Null

# Generating outputs
$outputsData = [ordered]@{
    FunctionApp       = 'https://'+ $outputs.Outputs.azFuncHostName.value
    FunctionKey      = $outputs.Outputs.azFuncAppCode.Value
    Tenant    = $tenantName
    ApplicationID      = $clientID
    KeyVaultName = $outputs.Outputs.azKeyVaultName.Value
    AzFunctionIPs = $outputs.Outputs.outboundIpAddresses.Value
}

Write-Host -ForegroundColor magenta "Here is the information you'll need to deploy and configure the Power Application"

# Disconnecting sessions
disconnect-MgGraph
disconnect-AzAccount

$outputsData