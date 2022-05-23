using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-CallQueueOverflowAction')

If (-Not $Request.Body) {
    $Resp = @{ "Error" = "Missing JSON body in the POST request"}
    $StatusCode =  [HttpStatusCode]::BadRequest 
}
Else {
    # Test JSON format and content

    write-host "Test: $($Request.Body)"
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
        $CallQueueName = $Request.Body.Identity        
        $OverflowAction = $Request.Body.OverflowAction
        $OverflowActionTarget = $Request.Body.OverflowTarget
        $OverflowThreshold = $Request.Body.OverflowThreshold        
        $OverflowVoicemailTarget = $Request.Body.OverflowVoicemailTarget   
        $OverflowVoicemailTranscription = $Request.Body.OverflowVoicemailTranscription                             
        $OverflowVoicemailTTSPrompt = $Request.Body.OverflowVoicemailTTSPrompt
        $OverflowVoicemailAudioPrompt = $Request.Body.OverflowVoicemailAudioPrompt
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
If($CallQueueId.EnableTimeoutSharedVoicemailTranscription -eq $false -and $OverflowVoicemailTranscription -eq $null)
{
    Write-Output "Transcription currently disabled and no value for OverflowVoicemailTranscription found"
    $OverflowVoicemailTranscription = $false
}
ElseIf($CallQueueId.EnableTimeoutSharedVoicemailTranscription -eq $true -and $OverflowVoicemailTranscription -eq $null)
{
    Write-Output "Transcription currently enabled and no value for OverflowVoicemailTranscription found"
    $OverflowVoicemailTranscription = $true
}

# Updating call overflow action
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        If ($OverflowAction -eq "Disconnect" )
        {
            If($OverflowThreshold -eq $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Disconnect -ErrorAction Stop
            }
            ElseIf($OverflowThreshold -ne $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Disconnect -OverflowThreshold $OverflowThreshold -ErrorAction Stop                
            }
        }

        If ($OverflowAction -eq "Redirect: Person in organization")
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $OverflowActionTarget -ErrorAction Stop|Select Identity)

            Write-Output "Redirect: Person in organization: $OverflowActionTarget $($ObjectId.Identity) and threshold $OverflowThreshold"
            If($OverflowThreshold -eq $null)
            { 
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $ObjectId.Identity -ErrorAction Stop
            }
            ElseIf($OverflowThreshold -ne $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $ObjectId.Identity -OverflowThreshold $OverflowThreshold -ErrorAction Stop
            }
        }

        If ($OverflowAction -eq "Redirect: Voice app" )
        {
            $ObjectId = $(Get-CsOnlineUser -Identity $OverflowActionTarget -ErrorAction Stop|Select Identity) 

            Write-Output "Redirect: Voice app: $OverflowActionTarget $($ObjectId.Identity) and threshold $OverflowThreshold"
            If($OverflowThreshold -eq $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $ObjectId.Identity -ErrorAction Stop
            }
            ElseIf($OverflowThreshold -ne $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $ObjectId.Identity -OverflowThreshold $OverflowThreshold -ErrorAction Stop                
            }
        }

        If ($OverflowAction -eq "Redirect: External phone number" )
        {
            $PhoneNumber = "tel:" + $OverflowActionTarget

            If($OverflowThreshold -eq $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $PhoneNumber -ErrorAction Stop
            }
            ElseIf($OverflowThreshold -ne $null)
            {
                $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction Forward -OverflowActionTarget $PhoneNumber -OverflowThreshold $OverflowThreshold -ErrorAction Stop                
            }
        }

        If ($OverflowAction -eq "Redirect: Voicemail" )
        {
            $authHeader = Get-AuthenticationToken
            $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $OverflowVoicemailTarget
            $ObjectId = ($GroupInfo | select-object Value).Value.id

            Write-Output "Redirect to voicemail, TTS: $OverflowVoicemailTranscription"     

            If($OverflowVoicemailTTSPrompt -ne $null -and $OverflowVoicemailTranscription -eq $false)
            {      
                Write-Output "Text, $OverflowThreshold"
                If($OverflowThreshold -eq $null)
                {
                    Write-Output "OverflowThreshold not specified"
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailTextToSpeechPrompt $OverflowVoicemailTTSPrompt -EnableOverflowSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -ne $null)
                {
                    Write-Output "OverflowThreshold specified"
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailTextToSpeechPrompt $OverflowVoicemailTTSPrompt -EnableOverflowSharedVoicemailTranscription $false -OverflowThreshold $OverflowThreshold -ErrorAction Stop                    
                }
            }
            ElseIf($OverflowVoicemailTTSPrompt -ne $null -and $OverflowVoicemailTranscription -eq $true)
            {             
                If($OverflowThreshold -eq $null)
                {                
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailTextToSpeechPrompt $OverflowVoicemailTTSPrompt -EnableOverflowSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -ne $null)
                {                
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailTextToSpeechPrompt $OverflowVoicemailTTSPrompt -EnableOverflowSharedVoicemailTranscription $true -OverflowThreshold $OverflowThreshold -ErrorAction Stop
                }                
            }
            ElseIf($OverflowVoicemailAudioPrompt -ne $null -and $OverflowVoicemailTranscription -eq $false)
            {
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $OverflowVoicemailAudioPrompt -Type HuntGroup
                
                If($OverflowThreshold -eq $null)
                { 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableOverflowSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -eq $null)
                { 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableOverflowSharedVoicemailTranscription $false -OverflowThreshold $OverflowThreshold -ErrorAction Stop
                }                
            }
            ElseIf($OverflowVoicemailAudioPrompt -ne $null -and $OverflowVoicemailTranscription -eq $true)
            {
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $OverflowVoicemailAudioPrompt -Type HuntGroup

                If($OverflowThreshold -eq $null)
                {                 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableOverflowSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -ne $null)
                {                 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -OverflowSharedVoicemailAudioFilePrompt $audioPrompt.id -EnableOverflowSharedVoicemailTranscription $true -OverflowThreshold $OverflowThreshold -ErrorAction Stop
                }                
            }
            ElseIf(($OverflowVoicemailTTSPrompt -eq $null -and $OverflowVoicemailAudioPrompt -eq $null) -and $OverflowVoicemailTranscription -eq $false)
            {
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $OverflowVoicemailAudioPrompt -Type HuntGroup
                
                If($OverflowThreshold -eq $null)
                { 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -EnableOverflowSharedVoicemailTranscription $false -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -ne $null)
                { 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -EnableOverflowSharedVoicemailTranscription $false -OverflowThreshold $OverflowThreshold -ErrorAction Stop
                }                
            }
            ElseIf(($OverflowVoicemailTTSPrompt -eq $null -and $OverflowVoicemailAudioPrompt -eq $null) -and $OverflowVoicemailTranscription -eq $true)
            {
                $authHeader = Get-AuthenticationToken
                $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $OverflowVoicemailAudioPrompt -Type HuntGroup

                If($OverflowThreshold -eq $null)
                {                 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -EnableOverflowSharedVoicemailTranscription $true -ErrorAction Stop
                }
                ElseIf($OverflowThreshold -eq $null)
                {                 
                    $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -OverflowAction SharedVoicemail -OverflowActionTarget $ObjectId -EnableOverflowSharedVoicemailTranscription $true -OverflowThreshold $OverflowThreshold -ErrorAction Stop
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