using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-AutoAttendantGreeting')

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
        $AAGreetingAudioBH= $Request.Body.GreetingAudioBusinessHours
        $AAGreetingTTSBH= $Request.Body.GreetingTextBusinessHours        
        $AAGreetingTypeBH= $Request.Body.GreetingTypeBusinessHours
        $AAGreetingAudioAH= $Request.Body.GreetingAudioAfterBusinessHours
        $AAGreetingTTSAH= $Request.Body.GreetingTextAfterBusinessHours        
        $AAGreetingTypeAH= $Request.Body.GreetingTypeAfterBusinessHours        
        $AAGreetingHours = $Request.Body.GreetingHours 
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

# Retrieving auto attendant configuration
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $AutoAttendant= Get-CsAutoAttendant -Name $AAName -ErrorAction Stop
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

If ($AAGreetingHours -eq "business hours")
{
    # Setting greeting 
    If ($StatusCode -eq [HttpStatusCode]::OK) {
        Try {
            Write-Host "Setting new greeting business hours"
            If ($AAGreetingAudioBH -ne $null -and $AAGreetingTypeBH -eq "audio")
            {
                Write-Host "Using audio file as greeting: $AAGreetingAudioBH"
                $AuthHeader = Get-AuthenticationToken
                $AudioPrompt = Upload-AudioPrompt -Token $AuthHeader -Site $Site -Path $AAName -FileName $AAGreetingAudioBH -Type OrgAutoAttendant
                $Greeting = New-CsAutoAttendantPrompt -AudioFilePrompt $AudioPrompt -ErrorAction Stop
                $AutoAttendant.DefaultCallFlow.Greetings = @($Greeting)
            }
            ElseIf ($AAGreetingTTSBH -ne $null -and $AAGreetingTypeBH -eq "text")
            {
                Write-Host "Using text as greeting"
                $Greeting = New-CsAutoAttendantPrompt -TextToSpeechPrompt $AAGreetingTTSBH -ErrorAction Stop
                $AutoAttendant.DefaultCallFlow.Greetings = @($Greeting)
            }
            ElseIf ($AAGreetingTypeBH -eq "No greeting")
            {
                Write-Host "Remove greeting"
                $AutoAttendant.DefaultCallFlow.Greetings = $null
            }                                                        

        }
        Catch {
            $Greeting = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
    }
}

If ($AAGreetingHours -eq "after business hours")
{
    # Setting greeting 
    If ($StatusCode -eq [HttpStatusCode]::OK) {
        Try {
            Write-Host "Setting new greeting after business hours"
            If ($AAGreetingAudioAH -ne $null -and $AAGreetingTypeAH -eq "audio")
            {
                Write-Host "Using audio file as greeting"
                $AuthHeader = Get-AuthenticationToken
                $AudioPrompt = Upload-AudioPrompt -Token $AuthHeader -Site $Site -Path $AAName -FileName $AAGreetingAudioAH -Type OrgAutoAttendant
                $Greeting = New-CsAutoAttendantPrompt -AudioFilePrompt $AudioPrompt -ErrorAction Stop
                $($AutoAttendant.CallFlows| where-object {$_.Name -eq "$($AutoAttendant.Name) After hours call flow"}).Greetings = @($Greeting)
            }
            ElseIf ($AAGreetingTTSAH -ne $null -and $AAGreetingTypeAH -eq "text")
            {
                Write-Host "Using text as greeting"
                $Greeting = New-CsAutoAttendantPrompt -TextToSpeechPrompt $AAGreetingTTSAH -ErrorAction Stop
                $($AutoAttendant.CallFlows| where-object {$_.Name -eq "$($AutoAttendant.Name) After hours call flow"}).Greetings = @($Greeting)
            }
            ElseIf ($AAGreetingTypeAH -eq "No greeting")
            {
                Write-Host "Remove greeting"
                $($AutoAttendant.CallFlows| where-object {$_.Name -eq "$($AutoAttendant.Name) After hours call flow"}).Greetings = $null
            }                                                                    

        }
        Catch {
            $Greeting = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
    }
}

# Modifying auto attendant
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        Write-Host "Updating auto attendant"
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