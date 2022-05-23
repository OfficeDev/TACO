using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-CallQueueTimeOutAction')

If (-Not $Request.Body) {
    $Resp = @{ "Error" = "Missing JSON body in the POST request"}
    $StatusCode =  [HttpStatusCode]::BadRequest 
}
Else {
    # Test JSON format and content
    $Request.Body
    $Result = $Request.Body | ConvertTo-Json | Test-Json -Schema $Schema
    If (-Not $Result){
        Write-Host "validating JSON"
        $Resp = @{
             "Error" = "The JSON body format is not compliant with the API specifications"
             "detail" = "Verify that the body complies with the definition in module JSON-Schemas and check detailed error code in the Azure Function logs"
         }
         $StatusCode =  [HttpStatusCode]::BadRequest
    }
    else {
        # Set the function variables        
        Write-Host 'Inputs validated'
        $CallQueueName = $Request.Body.Identity
        $TimeoutAction= $Request.Body.TimeoutAction
        $TimeoutActionTarget= $Request.Body.TimeoutTarget
        $TimeoutThreshold= $Request.Body.TimeoutThreshold
        $TimeoutVoicemailTarget= $Request.Body.TimeoutSharedVoicemailTarget        
        $TimeoutVoicemailTranscription= $Request.Body.TimeoutSharedVoicemailTranscription                             
        $TimeoutVoicemailTextPrompt= $Request.Body.TimeoutVoicemailText
        $TimeoutVoicemailAudioPrompt= $Request.Body.TimeoutVoicemailAudioPrompt
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

$GroupObjectIdModuleLocation = ".\Modules\GetGroupObjectId\GetGroupObjectId.psd1"
Import-Module $GroupObjectIdModuleLocation

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

Write-Host "retrieving call queue id"
# Retrieving call queue id
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $CallQueueId = $(Get-CsCallQueue -Name $CallQueueName -ErrorAction Stop|Select Identity, EnableTimeoutSharedVoicemailTranscription) 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

#Checking current transcription state to make sure we leave it as is
If($CallQueueId.EnableTimeoutSharedVoicemailTranscription -eq $false -and $TimeoutVoicemailTranscription -eq $null)
{
    Write-Output "Transcription currently disabled and no value for TimeoutVoicemailTranscription found"
    $TimeoutVoicemailTranscription = $false
}
ElseIf($CallQueueId.EnableTimeoutSharedVoicemailTranscription -eq $true -and $TimeoutVoicemailTranscription -eq $null)
{
    Write-Output "Transcription currently enabled and no value for TimeoutVoicemailTranscription found"
    $TimeoutVoicemailTranscription= $true
}

# Updating call time-out settings
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        If ($TimeoutAction -eq "Disconnect" -and $TimeoutThreshold -eq $null)
        {
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Disconnect -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Disconnect" -and $TimeoutThreshold -ne $null)
        {
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Disconnect -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: Person in organization" -and $TimeoutThreshold -eq $null)
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $TimeoutActionTarget -ErrorAction Stop|Select Identity) 
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $ObjectId.Identity -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: Person in organization" -and $TimeoutThreshold -ne $null)
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $TimeoutActionTarget -ErrorAction Stop|Select Identity) 
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $ObjectId.Identity -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: Voice App" -and $TimeoutThreshold -eq $null)
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $TimeoutActionTarget -ErrorAction Stop|Select Identity) 
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $ObjectId.Identity -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: Voice app" -and $TimeoutThreshold -ne $null)
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $TimeoutActionTarget ErrorAction Stop|Select Identity) 
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $ObjectId.Identity -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: External phone number" -and $TimeoutThreshold -eq $null)
        {
            $PhoneNumber = "tel:" + $TimeoutActionTarget
            $Resp =Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $PhoneNumber -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: External phone number" -and $TimeoutThreshold -ne $null)
        {
            $PhoneNumber = "tel:" + $TimeoutActionTarget
            $Resp =Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction Forward -TimeoutActionTarget $PhoneNumber -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
        }

        If ($TimeoutAction -eq "Redirect: voicemail" )
        { 
            Write-Host "Voicemail group: $TimeoutVoicemailTarget and $TimeoutVoicemailTextPrompt and $TimeOutSharedVoicemailTranscription"
            $authHeader = Get-AuthenticationToken
            $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $TimeoutVoicemailTarget
            $ObjectId = ($GroupInfo | select-object Value).Value.id

            If($TimeoutVoicemailTextPrompt -ne $null -and $TimeOutVoicemailTranscription -eq $false)
            {  
                Write-Host "voicemail text"           
                If($TimeoutThreshold -eq $null)
                {
                    Write-Host "Threshold not changed"
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailTextToSpeechPrompt $TimeoutVoicemailTextPrompt -EnableTimeOutSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailTextToSpeechPrompt $TimeoutVoicemailTextPrompt -EnableTimeOutSharedVoicemailTranscription $false -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
                }                
            }
            ElseIf($TimeoutVoicemailTextPrompt -ne $null -and $TimeOutVoicemailTranscription -eq $true)
            {             
                If($TimeoutThreshold -eq $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailTextToSpeechPrompt $TimeoutVoicemailTextPrompt -EnableTimeOutSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailTextToSpeechPrompt $TimeoutVoicemailTextPrompt -EnableTimeOutSharedVoicemailTranscription $true -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
                }                
            }
            ElseIf($TimeoutVoicemailAudioPrompt -ne $null -and $TimeOutVoicemailTranscription -eq $false)
            {              
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $TimeoutVoicemailAudioPrompt -Type HuntGroup

                If($TimeoutThreshold -eq $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableTimeOutSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableTimeOutSharedVoicemailTranscription $false -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
                }
            }
            ElseIf($TimeoutVoicemailAudioPrompt -ne $null -and $TimeOutSharedVoicemailTranscription -eq $true)
            {           
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $TimeoutVoicemailAudioPrompt -Type HuntGroup

                If($TimeoutThreshold -eq $null)
                {                
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableTimeOutSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {                
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -TimeOutAction SharedVoicemail -TimeOutActionTarget $ObjectId -TimeOutSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableTimeOutSharedVoicemailTranscription $true -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
                }                
            }
            ElseIf(($TimeoutVoicemailAudioPrompt -eq $null -and $TimeoutVoicemailTextPrompt -eq $null) -and $TimeOutActionSharedVoicemailTranscription -eq $false)
            {             
                If($TimeoutThreshold -eq $null)
                {                 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -EnableTimeOutSharedVoicemailTranscription $TimeOutSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -EnableTimeOutSharedVoicemailTranscription $TimeOutSharedVoicemailTranscription $false -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop                    
                }
            }
            ElseIf(($TimeoutVoicemailAudioPrompt -eq $null -and $TimeoutVoicemailTextPrompt -eq $null) -and $TimeOutActionSharedVoicemailTranscription -eq $true)
            {   
                If($TimeoutThreshold -eq $null)
                {                           
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -EnableTimeOutSharedVoicemailTranscription $TimeOutSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($TimeoutThreshold -ne $null)
                {                           
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -EnableTimeOutSharedVoicemailTranscription $TimeOutSharedVoicemailTranscription $true -TimeoutThreshold $TimeoutThreshold -ErrorAction Stop
                }                
            }                                                
        } 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

$Resp

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