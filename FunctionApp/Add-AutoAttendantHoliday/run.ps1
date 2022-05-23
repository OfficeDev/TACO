using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Add-AutoAttendantHoliday')

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

# Creating new prompt
If ($StatusCode -eq [HttpStatusCode]::OK -and $AAHolidayGreetingType -ne "No greeting") {
    Try {
            Write-Host "Setting new greeting"
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

# Creating new menu options
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Write-Host "Creating new menu option"
    Try {
            if($AAHolidayRedirectType -eq "Disconnect")
            {
                $menuOption = New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse "automatic" -ErrorAction Stop
            }
            if($AAHolidayRedirectType -eq "Redirect: Person in organization")
            {
                $ObjectId = $(Get-CsOnlineUser -Identity $AAHolidayRedirectTarget -ErrorAction Stop|Select Identity)
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type ApplicationEndpoint -ErrorAction Stop
                $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity -ErrorAction Stop
            }
            if($AAHolidayRedirectType -eq "Redirect: Voice app")
            {
                $ObjectId = $(Get-CsOnlineUser -Identity $AAHolidayRedirectTarget -ErrorAction Stop|Select Identity)
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type ApplicationEndpoint -ErrorAction Stop
                $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity -ErrorAction Stop
            }
            if($AAHolidayRedirectType -eq "Redirect: External phone number")
            {
                $CallForwardNumber = "tel:" + $AAHolidayRedirectTarget
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $CallForwardNumber -Type ExternalPSTN
                $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
            }
            if($AAHolidayRedirectTargetType -eq "Redirect: Voicemail")
            {
                $authHeader = Get-AuthenticationToken
                $GroupInfo = Get-GroupObjectId -Token $authHeader -DisplayName $AAHolidayVoicemailTarget
                $ObjectId = ($GroupInfo | select-object Value).Value.id
                
                $Callable_Entity = New-CsAutoAttendantCallableEntity -Identity $ObjectId.Identity -Type SharedVoicemail
                $menuOption = New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse "automatic" -CallTarget $Callable_Entity
            }
        }
    Catch 
        {
            $menuOption = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Creating new menu
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $Menu = New-CsAutoAttendantMenu -Name $AAHolidayName -MenuOptions @($menuOption)

        }
    Catch {
        $Menu = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

Write-Host "Creating call flow"
# Creating call flow
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($AAHolidayGreetingType -ne "No greeting")
            {
                $CallFlow = New-CsAutoAttendantCallFlow -Name $AAHolidayName -Greetings @($Greeting) -Menu $menu
            }
            ElseIf($AAHolidayGreetingType -eq "No greeting")
            {
                Write-Host "no greeting"
                $CallFlow = New-CsAutoAttendantCallFlow -Name $AAHolidayName -Menu $menu
            }
        }
    Catch {
        $CallFlow = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Creating new schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $StartDate = "{0:d/M/yyyy}" -f [datetime]$AAHolidayStartDate
            $EndDate = "{0:d/M/yyyy}" -f [datetime]$AAHolidayEndDate
            If($(Get-CsOnlineSchedule |where Name -like $AAHolidayName) -eq $null)
            { 
                $DateRange = New-CsOnlineDateTimeRange -Start $StartDate -End $EndDate
                $Schedule = New-CsOnlineSchedule -Name $AAHolidayName -FixedSchedule -DateTimeRanges @($DateRange)
            }
            Else
            {
                If($(Get-CsOnlineSchedule |where Name -like $AAHolidayName).FixedSchedule.DateTimeRanges.Start -like $StartDate -And $(Get-CsOnlineSchedule |where Name -like "New Years day").FixedSchedule.DateTimeRanges.End -like $EndDate)
                {
                    $Schedule = Get-CsOnlineSchedule |where Name -like $AAHolidayName
                }
                Else
                {
                    $DateRange = New-CsOnlineDateTimeRange -Start $StartDate -End $EndDate
                    $Schedule = New-CsOnlineSchedule -Name $AAHolidayName -FixedSchedule -DateTimeRanges @($DateRange)
                }
            }
        }
    Catch {
        $Schedule = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Creating call handling association
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $CallHandlingAssociation = New-CsAutoAttendantCallHandlingAssociation -Type Holiday -ScheduleId $Schedule.Id -CallFlowId $CallFlow.Id
        }
    Catch {
        $CallHandlingAssociation = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

#Updating call flows and handling associations
$autoAttendant.CallFlows += @($CallFlow)
$autoAttendant.CallHandlingAssociations += @($CallHandlingAssociation)

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

$Resp

# Trap all other exceptions that may occur at runtime and EXIT Azure Function
Trap {
    Write-Error $_
    Disconnect-MicrosoftTeams
    break
}