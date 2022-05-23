using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-AutoAttendantHoliday')

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
        $AAHolidayName = $Request.Body.HolidayName
        $AAHolidayStartDate = $Request.Body.HolidayStartDate
        $AAHolidayEndDate = $Request.Body.HolidayEndDate
        $AAHolidayGreetingType = $Request.Body.HolidayGreetingType
        $AAHolidayGreetingAudio = $Request.Body.HolidayGreetingAudio
        $AAHolidayGreetingText = $Request.Body.HolidayGreetingText
        $AAHolidayRedirectTarget = $Request.Body.HolidayRedirectTarget
        $AAHolidayRedirectType = $Request.Body.HolidayRedirectType
        $AAHolidayVoicemailTarget = $Request.Body.HolidayVoicemailTarget
        $AAHolidayVoicemailSuppression = $Request.Body.HolidayVoicemailSuppression
        $Site = $Request.Body.SPSite
    }    
}

# Authenticate to MicrosofTeams using service account
$Account = $env:ServiceAccountLogin 
$PWord = ConvertTo-SecureString -String $env:ServiceAccountPassword -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Account, $PWord

# Importing PowerShell Modules
$MSTeamsDModuleLocation = ".\Modules\MicrosoftTeams\$($env:TeamsPSVersion)\MicrosoftTeams.psd1"
Import-Module $MSTeamsDModuleLocation

$AuthentionModuleLocation = ".\Modules\GetAuthenticationToken\GetAuthenticationToken.psd1"
Import-Module $AuthentionModuleLocation

$AudioPromptModuleLocation = ".\Modules\UploadAudioPrompt\UploadAudioPrompt.psd1"
Import-Module $AudioPromptModuleLocation

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

Write-Host $StatusCode
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

# Updating prompt
Write-Host "updating prompt"
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If ($AAHolidayGreetingAudio -ne $null -and $AAHolidayGreetingType -eq "audio")
            {
                Write-Host "Using audio file as greeting"
                $AuthHeader = Get-AuthenticationToken
                $AudioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $AAName -FileName $AAHolidayGreetingAudio -Type OrgAutoAttendant
                $Greeting = New-CsAutoAttendantPrompt -AudioFilePrompt $audioPrompt -ErrorAction Stop
            }
            ElseIf ($AAHolidayGreetingText -ne $null -and $AAHolidayGreetingType -eq "text")
            {
                Write-Host "Using text as greeting"
                $Greeting = New-CsAutoAttendantPrompt -TextToSpeechPrompt $AAHolidayGreetingText -ErrorAction Stop
            }
       }                                                        
    Catch {
            $Greeting = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
          }

} 

# Modifying call flow
Write-Host "Modify call flow"
If ($StatusCode -eq [HttpStatusCode]::OK -and $Greeting -ne $null) {
    Try {
            $($Autoattendant.CallFlows |where Name -eq $AAHolidayName).Greetings = @($Greeting)
        }
    Catch {
        $CallFlow = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Modify call routing
# Reconfiguring menu options"
Write-Host "Reconfiguring menu options"
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            if($AAHolidayRedirectType -eq "Disconnect")
            {
                $HolidayMenuOption = New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse Automatic
                $($AutoAttendant.CallFlows | where name -eq $AAHolidayName).menu.menuoptions = @($HolidayMenuOption)
                
            }
            if($AAHolidayRedirectType -eq "Redirect: Person in organization")
            {
                Write-Host "person in org"
                $ObjectId = $(Get-CsOnlineUser -Identity $AAHolidayRedirectTarget -ErrorAction Stop|Select Identity)
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type User
                $HolidayMenuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                $($AutoAttendant.CallFlows | where name -eq $AAHolidayName).menu.menuoptions = @($HolidayMenuOption)                
            }
            if($AAHolidayRedirectType -eq "Redirect: Voice app")
            {
                $ObjectId = $(Get-CsOnlineUser -Identity $AAHolidayRedirectTarget-ErrorAction Stop|Select Identity)
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type ApplicationEndpoint
                $HolidayMenuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                $($AutoAttendant.CallFlows | where name -eq $AAHolidayName).menu.menuoptions = @($HolidayMenuOption)
                
            }
            if($AAHolidayRedirectType -eq "Redirect: External phone number")
            {
                $CallForwardNumber = "tel:" + $AAHolidayRedirectTarget
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $CallForwardNumber -Type ExternalPSTN
                $HolidayMenuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                $($AutoAttendant.CallFlows | where name -eq $AAHolidayName).menu.menuoptions = @($HolidayMenuOption)
                
            } 
            if($AAHolidayRedirectType -eq "Redirect: Voicemail")
            {
                $authHeader = Get-AuthenticationToken
                $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $AAHolidayVoicemailTarget
                $ObjectId = ($GroupInfo | select-object Value).Value.id
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type SharedVoicemail
                $HolidayMenuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
                $($AutoAttendant.CallFlows | where name -eq $AAHolidayName).menu.menuoptions = @($HolidayMenuOption)
                
            }                                                   
        }
        Catch 
            {
                $Resp = @{ "Error" = $_.Exception.Message }
                $StatusCode =  [HttpStatusCode]::BadGateway
                Write-Error $_
        }
}

# Reconfiguring auto attendant greetings settings
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            Write-Host "Applying changes"
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

$Resp

# Trap all other exceptions that may occur at runtime and EXIT Azure Function
Trap {
    Write-Error $_
    Disconnect-MicrosoftTeams
    break
}