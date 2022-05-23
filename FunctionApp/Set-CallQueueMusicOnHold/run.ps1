using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-CallQueueGreeting')

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
        $CallQueueName = $Request.Body.Identity
        $CallQueueMoH = $Request.Body.MoH
        $CallQueueMoHType = $Request.Body.MoHType
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

Write-Host "retrieving call queue id"
# Retrieving call queue id
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $CallQueueId = $(Get-CsCallQueue -Name $CallQueueName -ErrorAction Stop|Select Identity) 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Retrieving call queue id
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        If ($CallQueueMoH -ne $null -and $CallQueueMoHType -eq "Custom")
        {
            $authHeader = Get-AuthenticationToken
            $audioPrompt = Upload-AudioPrompt -Token $authHeader -Site $Site -Path $CallQueueName -FileName $CallQueueMoH -Type HuntGroup
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -MusicOnHoldAudioFileId $audioPrompt.id  -ErrorAction Stop
        }                                               
        ElseIf ($CallQueueMoH -eq $null -and $CallQueueMoHType -eq "Default")
        {
            $Resp = Set-CsCallQueue -Identity $CallQueueId.Identity -UseDefaultMusicOnHold $true -ErrorAction Stop
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