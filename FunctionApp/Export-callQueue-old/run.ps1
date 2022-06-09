using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$StringGuid
    )

   $ObjectGuid = [System.Guid]::empty
   return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid) # Returns True if successfully parsed
}

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Export-CallQueue')

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
        $CQName = $Request.Body.Identity
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

$GroupModuleLocation = ".\Modules\GetGroupInfo\GetGroupInfo.psd1"
Import-Module $GroupModuleLocation

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

# Collecting information about Call Queue
$cq = Get-CsCallQueue -Name $CQName

# Retrieving displayname for overflow action target
If($cq.OverflowActionTarget.Id -ne $null)
{
    If($(Test-IsGuid -StringGuid $cq.OverflowActionTarget.Id) -and $cq.OverflowAction -ne "SharedVoicemail")
    {
        write-host "running get-csonlineuser"
        $OverflowActionTarget = $(Get-CsOnlineuser $cq.OverflowActionTarget.Id).DisplayName
    }
    ElseIf($cq.OverflowAction -eq "SharedVoicemail")
    {
        write-host "getting group info"
        $authHeader = Get-AuthenticationToken
        $OverflowActionTarget = $(Get-GroupObjectInfo -Token $authHeader -ObjectId $cq.OverflowActionTarget.Id).displayName
        write-host "overflow: $OverflowActionTarget"
    }
    Else
    {
        $OverflowActionTarget = $($cq.OverflowActionTarget.Id).split(":")[0]
    }
}

# Retrieving displayname for timeout action target
If($cq.TimeoutActionTarget -ne $null)
{
    If($(Test-IsGuid -StringGuid $cq.TimeoutActionTarget) -and $cq.TimeoutAction -ne "SharedVoicemail")
    {
        $TimeoutActionTarget = Get-CsOnlineuser $cq.TimeoutActionTarget
    }
    ElseIf($cq.TimeoutAction -eq "SharedVoicemail")
    {
        $authHeader = Get-AuthenticationToken
        $TimeoutActionTarget = $(Get-GroupObjectInfo -Token $authHeader -ObjectId $cq.TimeoutActionTarget.Id).displayName
    }    
    Else
    {
        $TimeoutActionTarget = $($cq.TimeoutActionTarget).split(":")[0]
    }
}


# Determining greeting music type
If($cq.WelcomeMusicFileName -eq $null)
{
    $UseDefaultWelcomeMusic = "Default"
}
Else
{
    $UseDefaultWelcomeMusic = "Custom"
}

# Determining MoH music type
If($cq.UseDefaultMusicOnHold)
{
    $UseDefaultOnHoldMusic = "Default"
}
Else
{
    $UseDefaultOnHoldMusic = "Custom"
}


# Determining overflow action
If($cq.OverflowAction -eq "Disconnect")
{
    $OverflowAction = "Disconnect"
}
ElseIf($cq.OverflowAction -eq "Forward" -and $cq.OverflowActionTarget -eq "User") 
{
    $OverflowAction = "Redirect: Person in organization"
}
ElseIf($cq.OverflowAction -eq "Forward" -and $cq.OverflowActionTarget -eq "ApplicationEndpoint") 
{
    $OverflowAction = "Redirect: Voice app"
}
ElseIf($cq.OverflowAction -eq "Forward" -and $cq.OverflowActionTarget -eq "Phone") 
{
    $OverflowAction = "Redirect: External phone number"
}
ElseIf($cq.OverflowAction -eq "SharedVoicemail") 
{
    $OverflowAction = "Redirect: Voicemail"
}

# Determining timeout action
If($cq.TimeoutAction -eq "Disconnect")
{
    $TimeoutAction = "Disconnect"
}
ElseIf($cq.TimeoutAction -eq "Forward" -and $cq.TimeoutActionTarget -eq "User") 
{
    $TimeoutAction = "Redirect: Person in organization"
}
ElseIf($cq.OverflowAction -eq "Forward" -and $cq.TimeoutActionTarget -eq "ApplicationEndpoint") 
{
    $TimeoutwAction = "Redirect: Voice app"
}
ElseIf($cq.TimeOutAction -eq "Forward" -and $cq.TimeoutActionTarget -eq "Phone") 
{
    $TimeoutAction = "Redirect: External phone number"
}
ElseIf($cq.TimeOutAction -eq "SharedVoicemail") 
{
    $TimeoutAction = "Redirect: Voicemail"
}

$output = New-Object -TypeName PSObject
$output | Add-Member -MemberType NoteProperty -Name Name -Value $cq.Name
$output | Add-Member -MemberType NoteProperty -Name AgentAlertTime -Value $cq.AgentAlertTime
$output | Add-Member -MemberType NoteProperty -Name OverflowThreshold -Value $cq.OverflowThreshold
$output | Add-Member -MemberType NoteProperty -Name OverflowAction -Value $OverflowAction
$output | Add-Member -MemberType NoteProperty -Name OverflowActionTarget -Value $OverflowActionTarget
$output | Add-Member -MemberType NoteProperty -Name OverflowSharedTextToSpeechPrompt -Value $cq.OverflowSharedVoicemailTextToSpeechPrompt
$output | Add-Member -MemberType NoteProperty -Name OverflowSharedVoicemailAudioFilePromptFileName -Value $cq.OverflowSharedVoicemailAudioFilePromptFileName
$output | Add-Member -MemberType NoteProperty -Name TimeoutThreshold -Value $cq.TimeoutThreshold
$output | Add-Member -MemberType NoteProperty -Name TimeoutAction -Value $TimeoutAction
$output | Add-Member -MemberType NoteProperty -Name TimeoutActionTarget -Value $TimeoutActionTarget
$output | Add-Member -MemberType NoteProperty -Name TimeoutSharedTextToSpeechPrompt -Value $cq.TimeoutSharedVoicemailTextToSpeechPrompt
$output | Add-Member -MemberType NoteProperty -Name TimeoutSharedVoicemailAudioFilePromptFileName -Value $cq.TimeoutSharedVoicemailAudioFilePromptFileName
$output | Add-Member -MemberType NoteProperty -Name UseDefaultWelcomeMusic -Value $UseDefaultWelcomeMusic
$output | Add-Member -MemberType NoteProperty -Name WelcomeMusicFileName -Value $cq.WelcomeMusicFileName
$output | Add-Member -MemberType NoteProperty -Name UseDefaultMusicOnHold -Value $UseDefaultOnHoldMusic
$output | Add-Member -MemberType NoteProperty -Name MusicOnHoldFileName -Value $cq.MusicOnHoldFileName

$output = $output|ConvertTo-Json

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $output
})

Disconnect-MicrosoftTeams
Get-PSSession | Remove-PSSession

# Trap all other exceptions that may occur at runtime and EXIT Azure Function
Trap {
    Write-Error $_
    Disconnect-MicrosoftTeams
    break
}
