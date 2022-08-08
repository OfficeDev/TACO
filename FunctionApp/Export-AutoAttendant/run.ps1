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
$autoattendants = @()
$output = @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Export-AutoAttendant')

If ($Request.Body.Identity -ne $null) {
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
        $AAName= $Request.Body.Identity
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

$StatusCode = [HttpStatusCode]::OK

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

Write-Host "$($Request.Body.Identity)"

#Retrieve all AA's
If($($Request.Body.Identity) -eq $null)
{
    $autoattendants = Get-CsAutoAttendant |Select Name
}
Else
{
    Write-Host "Only requesting info for one AA"
    $autoattendants = Get-CsAutoAttendant -Name $($Request.Body.Identity) |Select Name    
}

Foreach($AAName in $autoattendants)
{
    $AHGreetingType = $null
    $AHGreetingText = $null
    $AHGreetingAudiofile = $null
    $AHTarget = $null
    $AHAction = $null
    $AHCallFlow = $null
    $BHGreetingType = $null
    $BHGreetingText = $null
    $BHGreetingAudiofile = $null
    $BHAction = $null
    $BHTarget = $null
    $holidayresults = @()
    $holidays = @()
    
    #Retrieving AA configuration
    $aa = Get-CsAutoAttendant -Name $AAName.Name -First 1

    #Determining business hours call flow target displayname
    If($aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id -ne $null)
    {
        If((Test-IsGuid -StringGuid $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id) -and $aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -ne "SharedVoicemail")
        {
            $BHTarget = $(Get-CsOnlineuser  $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id).DisplayName
        }
        ElseIf($aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -eq "SharedVoicemail")
        {
            $authHeader = Get-AuthenticationToken
            $BHTarget = $(Get-GroupObjectInfo -Token $authHeader -ObjectId $cq.TimeoutActionTarget.Id).displayName
        } 
        Else
        {
            $BHTarget =  $($aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id).split(":")[1]
        }
    }

    #Determining business hour greeting prompt type
    If($aa.DefaultCallFlow.Greetings.ActiveType -eq "AudioFile")
    {
        $BHGreetingType = "Play an audio file"
        $BHGreetingAudiofile = $($aa.DefaultCallFlow.Greetings.AudioFilePrompt.FileName)
    }
    ElseIf($aa.DefaultCallFlow.Greetings.ActiveType -eq "Text")
    {
        $BHGreetingType = "Add a greeting message"
        $BHGreetingText = $($aa.DefaultCallFlow.Greetings.TextToSpeechPrompt)
    }
    ElseIf($($aa.DefaultCallFlow.Greetings).Greetings.count -eq 0)
    {
        $BHGreetingType = "No greeting"
    }

    #Determining business hours call action
    If($aa.DefaultCallFlow.Menu.MenuOptions.Action -eq "DisconnectCall")
    {
        $BHAction = "Disconnect"
    }
    ElseIf($aa.DefaultCallFlow.Menu.MenuOptions.Action -eq "TransferCallToTarget" -and $aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -eq "User")
    {
        $BHAction = "Redirect: Person in organization"
    }
    ElseIf($($aa.DefaultCallFlow.Menu.MenuOptions.Action -eq "TransferCallToTarget") -and $aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -eq "ApplicationEndpoint")
    {
        $BHAction = "Redirect: Voice app"
    }
    ElseIf($aa.DefaultCallFlow.Menu.MenuOptions.Action -eq "TransferCallToTarget" -and $aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -eq "ExternalPstn")
    {
        $BHAction = "Redirect: External phone number"
    }
    ElseIf($aa.DefaultCallFlow.Menu.MenuOptions.Action -eq "TransferCallToTarget" -and $aa.DefaultCallFlow.Menu.MenuOptions.calltarget.Type -eq "SharedVoicemail")
    {
        $BHAction = "Redirect: Voicemail"
    }

    #Retrieving after hours call flow settings
    $AHCallFlow = $aa.CallFlows.Menu|where-Object {$_.Name -eq "After hours call flow"}

    If($AHCallFlow.MenuOptions.CallTarget.Id -ne $null)
    {
        If((Test-IsGuid -StringGuid $AHCallFlow.MenuOptions.CallTarget.Id) -and $AHCallflow.MenuOptions.CallTarget.Type -ne "SharedVoicemail")
        {
            $AHTarget = $(Get-CsOnlineuser $AHCallFlow.MenuOptions.CallTarget.Id).DisplayName
        }
        Else
        {
            $AHTarget =  $($AHCallFlow.MenuOptions.CallTarget.Id).split(":")[1]
        }
    }

    #Determining after hours greeting type
    If($($aa.CallFlows | where {$_.menu.name -eq "After hours call flow"}).Greetings.ActiveType -eq "AudioFile")
    {
        $AHGreetingType = "Play an audio file"
        $AHGreetingAudiofile = $($aa.CallFlows | where {$_.menu.name -eq "After hours call flow"}).Greetings.AudioFilePrompt
    }
    ElseIf($($aa.CallFlows | where {$_.menu.name -eq "After hours call flow"}).Greetings.ActiveType -eq "Text")
    {
        $AHGreetingType = "Add a greeting message"
        $AHGreetingText = $($aa.CallFlows | where {$_.menu.name -eq "After hours call flow"}).Greetings.TextToSpeechPrompt
    }
    ElseIf($($aa.CallFlows | where {$_.menu.name -eq "After hours call flow"}).Greetings.count -eq 0)
    {
        $AHGreetingType = "No greeting"
    }

    #Determining after hours call action
    If($AHCallFlow.menuoptions.Action -eq "DisconnectCall")
    {
        $AHAction = "Disconnect"
    }
    ElseIf($AHCallFlow.menuoptions.Action -eq "TransferCallToTarget" -and $AHCallflow.MenuOptions.CallTarget.Type -eq "User")
    {
        $AHAction = "Redirect: Person in organization"
    }
    ElseIf($AHCallFlow.menuoptions.Action -eq "TransferCallToTarget" -and $AHCallflow.MenuOptions.CallTarget.Type -eq "ApplicationEndpoint")
    {
        $AHAction = "Redirect: Voice app"
    }
    ElseIf($AHCallFlow.menuoptions.Action -eq "TransferCallToTarget" -and $AHCallflow.MenuOptions.CallTarget.Type -eq "ExternalPstn")
    {
        $AHAction = "Redirect: External phone number"
    }
    ElseIf($AHCallFlow.menuoptions.Action -eq "TransferCallToTarget" -and $AHCallflow.MenuOptions.CallTarget.Type -eq "SharedVoicemail")
    {
        $AHAction = "Redirect: Voicemail"
    }


    #Retrieving business hours

    $BusinessHours = $aa.Schedules|where-object{$_.Name -eq "$($AAName.Name) After Hours Schedule" -or $_.Name -eq "After hours $($AAName.Name)"}
    
    #Retrieving Monday hours
    If($BusinessHours.WeeklyRecurrentSchedule.MondayHours.count -eq 2)
    {
        $MondayExtraRange = $true
        $MondayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.Start[0].ToString("hh\:mm")
        $MondayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.End[0].ToString("hh\:mm")
        $MondayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.Start[1].ToString("hh\:mm")
        
        If($BusinessHours.WeeklyRecurrentSchedule.MondayHours.End[1].Days -eq 1)
        {
            $MondayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $MondayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.MondayHours.count -eq 1)
    {
        $MondayExtraRange = $false
        $MondayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.MondayHours.End.Days -eq 1)
        {
            $MondayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $MondayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.MondayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Tuesday hours
    If($BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.count -eq 2)
    {
        $TuesdayExtraRange = $true
        $TuesdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.Start[0].ToString("hh\:mm")
        $TuesdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.End[0].ToString("hh\:mm")
        $TuesdayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.Start[1].ToString("hh\:mm")
        
        If($BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.End[1].Days -eq 1)
        {
            $TuesdayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $TuesdayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.count -eq 1)
    {
        $TuesdayExtraRange = $false
        $TuesdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.End.Days -eq 1)
        {
            $TuesdayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $TuesdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.TuesdayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Wednesday hours
    If($BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.count -eq 2)
    {
        $WednesdayExtraRange = $true
        $WednesdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.Start[0].ToString("hh\:mm")
        $WednesdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.End[0].ToString("hh\:mm")
        $WednesdayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.Start[1].ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.End[1].Days -eq 1)
        {
            $WednesdayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $WednesdayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.count -eq 1)
    {
        $WednesdayExtraRange = $false
        $WednesdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.End.Days -eq 1)
        {
            $WednesdayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $WednesdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.WednesdayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Thursday hours
    If($BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.count -eq 2)
    {
        $ThursdayExtraRange = $true
        $ThursdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.Start[0].ToString("hh\:mm")
        $ThursdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.End[0].ToString("hh\:mm")
        $ThursdayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.Start[1].ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.End[1].Days -eq 1)
        {
            $ThursdayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $ThursdayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.count -eq 1)
    {
        $ThursdayExtraRange = $false
        $ThursdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.End.Days -eq 1)
        {
            $ThursdayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $ThursdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.ThursdayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Friday hours
    If($BusinessHours.WeeklyRecurrentSchedule.FridayHours.count -eq 2)
    {
        $FridayExtraRange = $true
        $FridayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.Start[0].ToString("hh\:mm")
        $FridayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.End[0].ToString("hh\:mm")
        $FridayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.Start[1].ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.FridayHours.End[1].Days -eq 1)
        {
            $FridayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $FridayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.FridayHours.count -eq 1)
    {
        $FridayExtraRange = $false
        $FridayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.FridayHours.End.Days -eq 1)
        {
            $FridayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $FridayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.FridayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Saturday hours
    If($BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.count -eq 2)
    {
        $SaturdayExtraRange = $true
        $SaturdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.Start[0].ToString("hh\:mm")
        $SaturdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.End[0].ToString("hh\:mm")
        $SaturdayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.Start[1].ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.End[1].Days -eq 1)
        {
            $SaturdayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $SaturdayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.count -eq 1)
    {
        $SaturdayExtraRange = $false
        $SaturdayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.End.Days -eq 1)
        {
            $SaturdayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $SaturdayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.SaturdayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving Sunday hours
    If($BusinessHours.WeeklyRecurrentSchedule.SundayHours.count -eq 2)
    {
        $SundayExtraRange = $true
        $SundayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.Start[0].ToString("hh\:mm")
        $SundayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.End[0].ToString("hh\:mm")
        $SundayStartTime2 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.Start[1].ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.SundayHours.End[1].Days -eq 1)
        {
            $SundayEndTime2 = "00:00 (next day)"
        }
        Else
        {
            $SundayEndTime2 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.End[1].ToString("hh\:mm")
        }
    }
    ElseIf($BusinessHours.WeeklyRecurrentSchedule.SundayHours.count -eq 1)
    {
        $SundayExtraRange = $false
        $SundayStartTime1 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.Start.ToString("hh\:mm")

        If($BusinessHours.WeeklyRecurrentSchedule.SundayHours.End.Days -eq 1)
        {
            $SundayEndTime1 = "00:00 (next day)"
        }
        Else
        {
            $SundayEndTime1 = $BusinessHours.WeeklyRecurrentSchedule.SundayHours.End.ToString("hh\:mm")
        }
    }

    #Retrieving holidays

    $holidays = $aa.Schedules|where-object {$_.Type -eq "Fixed"}

    foreach($holiday in $holidays)
    {
        $Greeting = $null
        $MenuOptions = $null
        $CallTarget = $null
        $CallTargetId = $null
        $CallTargetType = $null
        $HolidayGreetingAudiofile = $null
        $HolidayGreetingText = $null
        $HolidayGreetingType = $null
        
        $CallHandlingAssociation = $aa.CallhandlingAssociations |Where {$_.ScheduleId -eq $($holiday.Id)}
        $Greeting = $($aa.callflows|where-object {$_.Id -eq $CallHandlingAssociation.CallFlowId}).Greetings
        $MenuOptions = $($aa.callflows|where-object {$_.Id -eq $CallHandlingAssociation.CallFlowId}).Menu.MenuOptions

        $holidayInfo = [PSCustomObject]@{
            HolidayName = $null
            HolidayStart = $null
            HolidayEnd = $null       
            HolidayGreetingtype = $null    
            HolidayGreetingtext = $null
            HolidayGreetingaudio = $null
            HolidayAction = $null
            HolidayCallTarget = $null
            #$holidayinfo | Add-Member -MemberType NoteProperty -Name HolidayCallTargetType -Value $CallTargetType
        }        

        #Determining holiday greeting prompt type
        If($Greeting.ActiveType -eq "AudioFile")
        {
            $HolidayGreetingType = "Play an audio file"
            $HolidayGreetingAudiofile = $($Greeting.AudioFilePrompt.FileName)
        }
        ElseIf($Greeting.ActiveType -eq "TextToSpeech")
        {
            $HolidayGreetingType = "Add a greeting message"
            $HolidayGreetingText = $($Greeting.TextToSpeechPrompt)
        }
        ElseIf($($Greeting.Greetings).Greetings.count -eq 0)
        {
            $HolidayGreetingType = "No greeting"
        }


        #Determining holiday call flow target displayname
        If($MenuOptions.CallTarget.Id -ne $null)
        {
            If((Test-IsGuid -StringGuid $MenuOptions.CallTarget.Id) -and $MenuOptions.CallTarget.Type -ne "SharedVoicemail")
            {
                $CallTargetId = $(Get-CsOnlineuser  $MenuOptions.CallTarget.Id).DisplayName
            }
            ElseIf($MenuOptions.CallTarget.Type -eq "SharedVoicemail")
            {
                $authHeader = Get-AuthenticationToken
                $CallTargetId = $(Get-GroupObjectInfo -Token $authHeader -ObjectId $cq.TimeoutActionTarget.Id).displayName
            } 
            Else
            {
                $CallTargetId =  $($MenuOptions.CallTarget.Id).split(":")[1]
            }
        }

        #Determining holiday call flow target displayname
        If($MenuOptions.Action -eq "DisconnectCall")
        {
            $CallTargetType = "Disconnect"
        }
        ElseIf($MenuOptions.Action -eq "TransferCallToTarget" -and $MenuOptions.CallTarget.Type -eq "User")
        {
            $CallTargetType = "Redirect: Person in organization"
        }
        ElseIf($($MenuOptions.Action -eq "TransferCallToTarget") -and $MenuOptions.CallTarget.Type -eq "ApplicationEndpoint")
        {
            $CallTargetType = "Redirect: Voice app"
        }
        ElseIf($MenuOptions.Action -eq "TransferCallToTarget" -and $MenuOptions.CallTarget.Type -eq "ExternalPstn")
        {
            $CallTargetType = "Redirect: External phone number"
        }
        ElseIf($MenuOptions.Action -eq "TransferCallToTarget" -and $MenuOptions.CallTarget.Type -eq "SharedVoicemail")
        {
            $CallTargetType = "Redirect: Voicemail"
        }
        
        $holidayinfo.HolidayName = $holiday.name
        $holidayinfo.HolidayStart = $holiday.FixedSchedule.DateTimeRanges.Start
        $holidayinfo.HolidayEnd = $holiday.FixedSchedule.DateTimeRanges.End        
        $holidayinfo.HolidayGreetingtype = $HolidayGreetingType    
        $holidayinfo.HolidayGreetingtext = $HolidayGreetingText
        $holidayinfo.HolidayGreetingaudio = $HolidayGreetingAudiofile
        $holidayinfo.HolidayAction = $CallTargetType
        $holidayinfo.HolidayCallTarget = $CallTargetId
        #$holidayinfo | Add-Member -MemberType NoteProperty -Name HolidayCallTargetType -Value $CallTargetType

        $holidayresults += $holidayinfo
    }

    #Creating output object
    $aaoutput = New-Object -TypeName PSObject
    $aaoutput | Add-Member -MemberType NoteProperty -Name Name -Value $aa.Name
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHGreetingType -Value $BHGreetingType
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHGreetingAudio -Value $BHGreetingAudiofile
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHGreetingText -Value $BHGreetingText
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHAction -Value $BHAction
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHTarget -Value $BHTarget
    $aaoutput | Add-Member -MemberType NoteProperty -Name BHEnableSharedVoicemailSystemPromptSuppression -Value $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.EnableSharedVoicemailSystemPromptSuppression
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHGreetingType -Value $AHGreetingType
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHGreetingAudio -Value $AHGreetingAudiofile.FileName
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHGreetingText -Value $AHGreetingText
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHAction -Value $AHAction
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHTarget -Value $AHTarget
    $aaoutput | Add-Member -MemberType NoteProperty -Name AHEnableSharedVoicemailSystemPromptSuppression -Value $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.EnableSharedVoicemailSystemPromptSuppression
    $aaoutput | Add-Member -MemberType NoteProperty -Name MondayExtraRange -Value $MondayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name MondayStartTime1 -Value $MondayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name MondayEndTime1 -Value $MondayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name MondayStartTime2 -Value $MondayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name MondayEndTime2 -Value $MondayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name TuesdayExtraRange -Value $TuesdayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name TuesdayStartTime1 -Value $TuesdayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name TuesdayEndTime1 -Value $TuesdayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name TuesdayStartTime2 -Value $TuesdayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name TuesdayEndTime2 -Value $TuesdayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name WednesdayExtraRange -Value $WednesdayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name WednesdayStartTime1 -Value $WednesdayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name WednesdayEndTime1 -Value $WednesdayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name WednesdayStartTime2 -Value $WednesdayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name WednesdayEndTime2 -Value $WednesdayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name ThursdayExtraRange -Value $ThursdayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name ThursdayStartTime1 -Value $ThursdayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name ThursdayEndTime1 -Value $ThursdayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name ThursdayStartTime2 -Value $ThursdayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name ThursdayEndTime2 -Value $ThursdayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name FridayExtraRange -Value $FridayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name FridayStartTime1 -Value $FridayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name FridayEndTime1 -Value $FridayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name FridayStartTime2 -Value $FridayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name FridayEndTime2 -Value $FridayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name SaturdayExtraRange -Value $SaturdayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name SaturdayStartTime1 -Value $SaturdayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name SaturdayEndTime1 -Value $SaturdayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name SaturdayStartTime2 -Value $SaturdayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name SaturdayEndTime2 -Value $SaturdayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name SundayExtraRange -Value $SundayExtraRange
    $aaoutput | Add-Member -MemberType NoteProperty -Name SundayStartTime1 -Value $SundayStartTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name SundayEndTime1 -Value $SundayEndTime1
    $aaoutput | Add-Member -MemberType NoteProperty -Name SundayStartTime2 -Value $SundayStartTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name SundayEndTime2 -Value $SundayEndTime2
    $aaoutput | Add-Member -MemberType NoteProperty -Name Holidays -Value $holidayresults

    $output += $aaoutput
}

$output = $output|ConvertTo-Json -Depth 16

$output

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