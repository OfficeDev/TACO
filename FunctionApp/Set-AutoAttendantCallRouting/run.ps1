using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-AutoAttendantCallRouting')

If (-Not $Request.Body) {
    $Resp = @{ "Error" = "Missing JSON body in the POST request"}
    $StatusCode =  [HttpStatusCode]::BadRequest 
}
Else {
    # Test JSON format and content
    $Result = $Request.Body | ConvertTo-Json | Test-Json -Schema $Schema

    If (-Not $Result){
        $Resp = @{
             "Error" = "The JSON body format is not compliant with the API specifications"
             "detail" = "Verify that the body complies with the definition in module JSON-Schemas and check detailed error code in the Azure Function logs"
         }
         $StatusCode =  [HttpStatusCode]::BadRequest
    }
    else {
        # Set the function variables
        Write-Host 'Inputs validated'
        $AAName = $Request.Body.Identity
        $AARedirectTargetBH = $Request.Body.RedirectTargetBH
        $AARedirectTargetTypeBH = $Request.Body.RedirectTargetTypeBH
        $AARedirectTargetVoicemailPromptSuppressionBH = $Request.Body.RedirectTargetVoicemailPromptSuppressionBH
        $AARedirectTargetAH = $Request.Body.RedirectTargetAH
        $AARedirectTargetTypeAH = $Request.Body.RedirectTargetTypeAH
        $AARedirectTargetVoicemailPromptSuppressionAH = $Request.Body.RedirectTargetVoicemailPromptSuppressionAH
        $AARoutingHours = $Request.Body.RoutingHours
    }    
}


# Authenticate to MicrosofTeams using service account
$Account = $env:ServiceAccountLogin 
$PWord = ConvertTo-SecureString -String $env:ServiceAccountPassword -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Account, $PWord

# Importing PowerShell Modules
$MSTeamsDModuleLocation = ".\Modules\MicrosoftTeams\$($env:TeamsPSVersion)\MicrosoftTeams.psd1"
Import-Module $MSTeamsDModuleLocation

# Connect to Microsoft Teams
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        Connect-MicrosoftTeams -Credential $Credential -ErrorAction Stop
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

Write-Host "retrieving auto attendant id"

# Retrieving auto attendant information
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $AutoAttendant= $(Get-CsAutoAttendant -Name $AAName -ErrorAction Stop) 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Reconfiguring menu options business hours"
If ($AARoutingHours -eq "business hours")
{
    If ($StatusCode -eq [HttpStatusCode]::OK) {
        Try {
                if($AARedirectTargetTypeBH -eq "Disconnect")
                {
                    $menuOption = New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse "automatic"
                    $AutoAttendant.DefaultCallFlow.Menu.MenuOptions = @($menuOption)
                }

                if($AARedirectTargetTypeBH -eq "Redirect: Person in organization")
                {
                    $ObjectId = $(Get-CsOnlineUser -Identity $AARedirectTargetBH -ErrorAction Stop|Select Identity)
                    $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type User
                    $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                    $AutoAttendant.DefaultCallFlow.Menu.MenuOptions = @($menuOption)
                }

                if($AARedirectTargetTypeBH -eq "Redirect: Voice app")
                {
                    $ObjectId = $(Get-CsOnlineUser -Identity $AARedirectTargetBH -ErrorAction Stop|Select Identity)
                    $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type ApplicationEndpoint
                    $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                    $AutoAttendant.DefaultCallFlow.Menu.MenuOptions = @($menuOption)
                }

                if($AARedirectTargetTypeBH -eq "Redirect: External phone number")
                {
                    $CallForwardNumber = "tel:" + $AARedirectTargetBH
                    $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $CallForwardNumber -Type ExternalPSTN
                    $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                    $AutoAttendant.DefaultCallFlow.Menu.MenuOptions= @($menuOption)
                }

                if($AARedirectTargetTypeBH -eq "Redirect: Voicemail")
                {
                    $authHeader = Get-AuthenticationToken
                    $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $AARedirectTargetBH
                    $ObjectId = ($GroupInfo | select-object Value).Value.id
                    
                    if($AARedirectTargetVoicemailPromptSuppressionBH -eq $true)
                    {
                        $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId -Type SharedVoicemail -EnableSharedVoicemailSystemPromptSuppression
                    }
                    else
                    {
                        $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId -Type SharedVoicemail                            
                    }
                    
                    $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                    $AutoAttendant.DefaultCallFlow.Menu.MenuOptions = @($menuOption)                
                }
            }
            Catch 
                {
                    $Resp = @{ "Error" = $_.Exception.Message }
                    $StatusCode =  [HttpStatusCode]::BadGateway
                    Write-Error $_
            }
    }
}

# Reconfiguring menu options after business hours"
If ($AARoutingHours -eq "after business hours")
{
    If ($StatusCode -eq [HttpStatusCode]::OK) {
        Try {
                if($AARedirectTargetTypeAH -eq "Disconnect")
                {
                    Write-Host redirect target type "disconnect"
                    $menuOptionAH = New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse "automatic"
                    $($AutoAttendant.Callflows|where name -eq "$($AutoAttendant.Name) After hours call flow").menu.menuoptions = @($menuoptionAH)
                }

                if($AARedirectTargetTypeAH -eq "Redirect: Person in organization")
                {
                    Write-Host redirect target type "Person in organization"                
                    $ObjectId = $(Get-CsOnlineUser -Identity $AARedirectTargetAH -ErrorAction Stop|Select Identity)
                    $Callable_EntityAH = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type User
                    $menuOptionAH = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_EntityAH
                    $($AutoAttendant.Callflows|where name -eq "$($AutoAttendant.Name) After hours call flow").menu.menuoptions = @($menuoptionAH)
                }

                if($AARedirectTargetTypeAH -eq "Redirect: Voice app")
                {
                    Write-Host redirect target type "Voice app"                
                    $ObjectId = $(Get-CsOnlineUser -Identity $AARedirectTargetAH -ErrorAction Stop|Select Identity)
                    $Callable_EntityAH = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type ApplicationEndpoint
                    $menuOptionAH = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_EntityAH
                    $($AutoAttendant.Callflows|where name -eq "$($AutoAttendant.Name) After hours call flow").menu.menuoptions = @($menuoptionAH)
                }

                if($AARedirectTargetTypeAH -eq "Redirect: External phone number")
                {
                    Write-Host redirect target type "External phone number"                
                    $CallForwardNumberAH = "tel:" + $AARedirectTargetAH
                    $Callable_EntityAH = New-CsAutoAttendantCallableEntity -Identity $CallForwardNumberAH -Type ExternalPSTN
                    $menuOptionAH = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_EntityAH
                    $($AutoAttendant.Callflows|where name -eq "$($AutoAttendant.Name) After hours call flow").menu.menuoptions = @($menuoptionAH)
                }

                if($AARedirectTargetTypeAH -eq "Redirect: Voicemail")
                {
                    Write-Host redirect target type "Voicemail"                
                    $authHeader = Get-AuthenticationToken
                    $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $AARedirectTargetAH
                    $ObjectId = ($GroupInfo | select-object Value).Value.id

                    if($AARedirectTargetVoicemailPromptSuppressionAH -eq $true)
                    {
                        $Callable_Entity_AH = New-CsAutoAttendantCallableEntity -Identity $ObjectId -Type SharedVoicemail -EnableSharedVoicemailSystemPromptSuppression
                    }
                    else
                    {
                        $Callable_Entity_AH = New-CsAutoAttendantCallableEntity -Identity $ObjectId -Type SharedVoicemail
                    }
                    
                    $menuOption_AH = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity_AH
                    $($AutoAttendant.Callflows|where name -eq "$($AutoAttendant.Name) After hours call flow").menu.menuoptions = @($menuoption_AH)                
                }
            }
            Catch 
                {
                    $Resp = @{ "Error" = $_.Exception.Message }
                    $StatusCode =  [HttpStatusCode]::BadGateway
                    Write-Error $_
            }
    }
}

# Reconfiguring auto attendant redirect settings
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $Resp = Set-CsAutoAttendant -Instance $AutoAttendant -ErrorAction Stop
        }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    ContentType = 'application/json'
    Body = $Resp
})

Disconnect-MicrosoftTeams
Get-PSSession | Remove-PSSession

# Trap all other exceptions that may occur at runtime and EXIT Azure Function
Trap {
    Write-Error $_
    Disconnect-MicrosoftTeams
    break
}