using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize PS script
$StatusCode = [HttpStatusCode]::OK
$Resp = ConvertTo-Json @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Set-AutoAttendantBusinessHour')

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
        $AAMondayStartTime1 = $Request.Body.days.Monday.StartTime1
        $AAMondayEndTime1 = $Request.Body.days.Monday.EndTime1
        $AAMondayStartTime2 = $Request.Body.days.Monday.StartTime2
        $AAMondayEndTime2 = $Request.Body.days.Monday.EndTime2
        $AATuesdayStartTime1 = $Request.Body.days.Tuesday.StartTime1
        $AATuesdayEndTime1 = $Request.Body.days.Tuesday.EndTime1
        $AATuesdayStartTime2 = $Request.Body.days.Tuesday.StartTime2
        $AATuesdayEndTime2 = $Request.Body.days.Tuesday.EndTime2
        $AAWednesdayStartTime1 = $Request.Body.days.Wednesday.StartTime1
        $AAWednesdayEndTime1 = $Request.Body.days.Wednesday.EndTime1
        $AAWednesdayStartTime2 = $Request.Body.days.Wednesday.StartTime2
        $AAWednesdayEndTime2 = $Request.Body.days.Wednesday.EndTime2
        $AAThursdayStartTime1 = $Request.Body.days.Thursday.StartTime1
        $AAThursdayEndTime1 = $Request.Body.days.Thursday.EndTime1
        $AAThursdayStartTime2 = $Request.Body.days.Thursday.StartTime2
        $AAThursdayEndTime2 = $Request.Body.days.Thursday.EndTime2
        $AAFridayStartTime1 = $Request.Body.days.Friday.StartTime1
        $AAFridayEndTime1 = $Request.Body.days.Friday.EndTime1
        $AAFridayStartTime2 = $Request.Body.days.Friday.StartTime2
        $AAFridayEndTime2 = $Request.Body.days.Friday.EndTime2
        $AASaturdayStartTime1 = $Request.Body.days.Saturday.StartTime1
        $AASaturdayEndTime1 = $Request.Body.days.Saturday.EndTime1
        $AASaturdayStartTime2 = $Request.Body.days.Saturday.StartTime2
        $AASaturdayEndTime2 = $Request.Body.days.Saturday.EndTime2
        $AASundayEndTime2 = $Request.Body.days.Sunday.EndTime2
        $AASundayStartTime1 = $Request.Body.days.Sunday.StartTime1
        $AASundayEndTime1 = $Request.Body.days.Sunday.EndTime1
        $AASundayStartTime2 = $Request.Body.days.Sunday.StartTime2
        $AASundayEndTime2 = $Request.Body.days.Sunday.EndTime2        
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

Write-Host "retrieving auto attendant id: $($Request.Body.Identity)"

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
#Retrieving current holiday call handling item
$HolidayCallHandling = $AutoAttendant.CallHandlingAssociations|where type -like "Holiday"

#Retrieving CurrentCallHandling id
$CurrentCallHandling = $AutoAttendant.CallHandlingAssociations|where type -like "Afterhours"

#Retrieving current call flow id
$CallFlow = $AutoAttendant.CallFlows | where name -eq "$($AutoAttendant.Name) After hours call flow"

#Monday timeranges
If(($AAMondayStartTime1 -ne $null -and $AAMondayStartTime1 -ne "none" -and $AAMondayEndTime1 -ne "0:00 (next day)") -and ($AAMondayStartTime2 -ne $null -and $AAMondayStartTime2 -ne "none" -and $AAMondayEndTime2 -ne "0:00 (next day)"))
{
    $MondayTimeRange1 = New-CsOnlineTimeRange -Start $AAMondayStartTime1 -End $AAMondayEndTime1 -ErrorAction Stop
    $MondayTimeRange2 = New-CsOnlineTimeRange -Start $AAMondayStartTime2 -End $AAMondayEndTime2 -ErrorAction Stop   
}
ElseIf(($AAMondayStartTime1 -ne $null -and $AAMondayStartTime1 -ne "none" -and $AAMondayEndTime1 -ne "0:00 (next day)") -and ($AAMondayStartTime2 -ne $null -and $AAMondayStartTime2 -ne "none" -and $AAMondayEndTime2 -eq "0:00 (next day)"))
{
    $MondayTimeRange1 = New-CsOnlineTimeRange -Start $AAMondayStartTime1 -End $AAMondayEndTime1 -ErrorAction Stop
    $MondayTimeRange2 = New-CsOnlineTimeRange -Start $AAMondayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AAMondayStartTime1 -ne $null -and $AAMondayStartTime1 -ne "none" -and $AAMondayEndTime1 -ne "0:00 (next day)")
{
    $MondayTimeRange1 = New-CsOnlineTimeRange -Start $AAMondayStartTime1 -End $AAMondayEndTime1 -ErrorAction Stop
}
ElseIf($AAMondayStartTime1 -ne $null -and $AAMondayStartTime1 -ne "none" -and $AAMondayEndTime1 -eq "0:00 (next day)")
{
    $MondayTimeRange1 = New-CsOnlineTimeRange -Start $AAMondayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Tuesday timeranges
If(($AATuesdayStartTime1 -ne $null -and $AATuesdayStartTime1 -ne "none" -and $AATuesdayEndTime1 -ne "0:00 (next day)") -and ($AATuesdayStartTime2 -ne $null -and $AATuesdayStartTime2 -ne "none" -and $AATuesdayEndTime2 -ne "0:00 (next day)"))
{
    $TuesdayTimeRange1 = New-CsOnlineTimeRange -Start $AATuesdayStartTime1 -End $AATuesdayEndTime1 -ErrorAction Stop
    $TuesdayTimeRange2 = New-CsOnlineTimeRange -Start $AATuesdayStartTime2 -End $AATuesdayEndTime2 -ErrorAction Stop   
}
ElseIf(($AATuesdayStartTime1 -ne $null -and $AATuesdayStartTime1 -ne "none" -and $AATuesdayEndTime1 -ne "0:00 (next day)") -and ($AATuesdayStartTime2 -ne $null -and $AATuesdayStartTime2 -ne "none" -and $AATuesdayEndTime2 -eq "0:00 (next day)"))
{
    $TuesdayTimeRange1 = New-CsOnlineTimeRange -Start $AATuesdayStartTime1 -End $AATuesdayEndTime1 -ErrorAction Stop
    $TuesdayTimeRange2 = New-CsOnlineTimeRange -Start $AATuesdayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AATuesdayStartTime1 -ne $null -and $AATuesdayStartTime1 -ne "none" -and $AATuesdayEndTime1 -ne "0:00 (next day)")
{
    $TuesdayTimeRange1 = New-CsOnlineTimeRange -Start $AATuesdayStartTime1 -End $AATuesdayEndTime1 -ErrorAction Stop
}
ElseIf($AATuesdayStartTime1 -ne $null -and $AATuesdayStartTime1 -ne "none" -and $AATuesdayEndTime1 -eq "0:00 (next day)")
{
    $TuesdayTimeRange1 = New-CsOnlineTimeRange -Start $AATuesdayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Wednesday timeranges
If(($AAWednesdayStartTime1 -ne $null -and $AAWednesdayStartTime1 -ne "none" -and $AAWednesdayEndTime1 -ne "0:00 (next day)") -and ($AAWednesdayStartTime2 -ne $null -and $AAWednesdayStartTime2 -ne "none" -and $AAWednesdayEndTime2 -ne "0:00 (next day)"))
{
    $WednesdayTimeRange1 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime1 -End $AAWednesdayEndTime1 -ErrorAction Stop
    $WednesdayTimeRange2 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime2 -End $AAWednesdayEndTime2 -ErrorAction Stop   
}
ElseIf(($AAWednesdayStartTime1 -ne $null -and $AAWednesdayStartTime1 -ne "none" -and $AAWednesdayEndTime1 -ne "0:00 (next day)") -and ($AAWednesdayStartTime2 -ne $null -and $AAWednesdayStartTime2 -ne "none" -and $AAWednesdayEndTime2 -eq "0:00 (next day)"))
{
    $WednesdayTimeRange1 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime1 -End $AAWednesdayEndTime1 -ErrorAction Stop
    $WednesdayTimeRange2 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AAWednesdayStartTime1 -ne $null -and $AAWednesdayStartTime1 -ne "none" -and $AAWednesdayEndTime1 -ne "0:00 (next day)")
{
    $WednesdayTimeRange1 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime1 -End $AAWednesdayEndTime1 -ErrorAction Stop
}
ElseIf($AAWednesdayStartTime1 -ne $null -and $AAWednesdayStartTime1 -ne "none" -and $AAWednesdayEndTime1 -eq "0:00 (next day)")
{
    $WednesdayTimeRange1 = New-CsOnlineTimeRange -Start $AAWednesdayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Thursday timeranges
If(($AAThursdayStartTime1 -ne $null -and $AAThursdayStartTime1 -ne "none" -and $AAThursdayEndTime1 -ne "0:00 (next day)") -and ($AAThursdayStartTime2 -ne $null -and $AAThursdayStartTime2 -ne "none" -and $AAThursdayEndTime2 -ne "0:00 (next day)"))
{
    $ThursdayTimeRange1 = New-CsOnlineTimeRange -Start $AAThursdayStartTime1 -End $AAThursdayEndTime1 -ErrorAction Stop
    $ThursdayTimeRange2 = New-CsOnlineTimeRange -Start $AAThursdayStartTime2 -End $AAThursdayEndTime2 -ErrorAction Stop   
}
ElseIf(($AAThursdayStartTime1 -ne $null -and $AAThursdayStartTime1 -ne "none" -and $AAThursdayEndTime1 -ne "0:00 (next day)") -and ($AAThursdayStartTime2 -ne $null -and $AAThursdayStartTime2 -ne "none" -and $AAThursdayEndTime2 -eq "0:00 (next day)"))
{
    $ThursdayTimeRange1 = New-CsOnlineTimeRange -Start $AAThursdayStartTime1 -End $AAThursdayEndTime1 -ErrorAction Stop
    $ThursdayTimeRange2 = New-CsOnlineTimeRange -Start $AAThursdayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AAThursdayStartTime1 -ne $null -and $AAThursdayStartTime1 -ne "none" -and $AAThursdayEndTime1 -ne "0:00 (next day)")
{
    $ThursdayTimeRange1 = New-CsOnlineTimeRange -Start $AAThursdayStartTime1 -End $AAThursdayEndTime1 -ErrorAction Stop
}
ElseIf($AAThursdayStartTime1 -ne $null -and $AAThursdayStartTime1 -ne "none" -and $AAThursdayEndTime1 -eq "0:00 (next day)")
{
    $ThursdayTimeRange1 = New-CsOnlineTimeRange -Start $AAThursdayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Friday timeranges
If(($AAFridayStartTime1 -ne $null -and $AAFridayStartTime1 -ne "none" -and $AAFridayEndTime1 -ne "0:00 (next day)") -and ($AAFridayStartTime2 -ne $null -and $AAFridayStartTime2 -ne "none" -and $AAFridayEndTime2 -ne "0:00 (next day)"))
{
    $FridayTimeRange1 = New-CsOnlineTimeRange -Start $AAFridayStartTime1 -End $AAFridayEndTime1 -ErrorAction Stop
    $FridayTimeRange2 = New-CsOnlineTimeRange -Start $AAFridayStartTime2 -End $AAFridayEndTime2 -ErrorAction Stop   
}
ElseIf(($AAFridayStartTime1 -ne $null -and $AAFridayStartTime1 -ne "none" -and $AAFridayEndTime1 -ne "0:00 (next day)") -and ($AAFridayStartTime2 -ne $null -and $AAFridayStartTime2 -ne "none" -and $AAFridayEndTime2 -eq "0:00 (next day)"))
{
    $FridayTimeRange1 = New-CsOnlineTimeRange -Start $AAFridayStartTime1 -End $AAFridayEndTime1 -ErrorAction Stop
    $FridayTimeRange2 = New-CsOnlineTimeRange -Start $AAFridayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AAFridayStartTime1 -ne $null -and $AAFridayStartTime1 -ne "none" -and $AAFridayEndTime1 -ne "0:00 (next day)")
{
    $FridayTimeRange1 = New-CsOnlineTimeRange -Start $AAFridayStartTime1 -End $AAFridayEndTime1 -ErrorAction Stop
}
ElseIf($AAFridayStartTime1 -ne $null -and $AAFridayStartTime1 -ne "none" -and $AAFridayEndTime1 -eq "0:00 (next day)")
{
    $FridayTimeRange1 = New-CsOnlineTimeRange -Start $AAFridayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Saturday timeranges
If(($AASaturdayStartTime1 -ne $null -and $AASaturdayStartTime1 -ne "none" -and $AASaturdayEndTime1 -ne "0:00 (next day)") -and ($AASaturdayStartTime2 -ne $null -and $AASaturdayStartTime2 -ne "none" -and $AASaturdayEndTime2 -ne "0:00 (next day)"))
{
    $SaturdayTimeRange1 = New-CsOnlineTimeRange -Start $AASaturdayStartTime1 -End $AASaturdayEndTime1 -ErrorAction Stop
    $SaturdayTimeRange2 = New-CsOnlineTimeRange -Start $AASaturdayStartTime2 -End $AASaturdayEndTime2 -ErrorAction Stop   
}
ElseIf(($AASaturdayStartTime1 -ne $null -and $AASaturdayStartTime1 -ne "none" -and $AASaturdayEndTime1 -ne "0:00 (next day)") -and ($AASaturdayStartTime2 -ne $null -and $AASaturdayStartTime2 -ne "none" -and $AASaturdayEndTime2 -eq "0:00 (next day)"))
{
    $SaturdayTimeRange1 = New-CsOnlineTimeRange -Start $AASaturdayStartTime1 -End $AASaturdayEndTime1 -ErrorAction Stop
    $SaturdayTimeRange2 = New-CsOnlineTimeRange -Start $AASaturdayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AASaturdayStartTime1 -ne $null -and $AASaturdayStartTime1 -ne "none" -and $AASaturdayEndTime1 -ne "0:00 (next day)")
{
    $SaturdayTimeRange1 = New-CsOnlineTimeRange -Start $AASaturdayStartTime1 -End $AASaturdayEndTime1 -ErrorAction Stop
}
ElseIf($AASaturdayStartTime1 -ne $null -and $AASaturdayStartTime1 -ne "none" -and $AASaturdayEndTime1 -eq "0:00 (next day)")
{
    $SaturdayTimeRange1 = New-CsOnlineTimeRange -Start $AASaturdayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}

#Sunday timeranges
If(($AASundayStartTime1 -ne $null -and $AASundayStartTime1 -ne "none" -and $AASundayEndTime1 -ne "0:00 (next day)") -and ($AASundayStartTime2 -ne $null -and $AASundayStartTime2 -ne "none" -and $AASundayEndTime2 -ne "0:00 (next day)"))
{
    $SundayTimeRange1 = New-CsOnlineTimeRange -Start $AASundayStartTime1 -End $AASundayEndTime1 -ErrorAction Stop
    $SundayTimeRange2 = New-CsOnlineTimeRange -Start $AASundayStartTime2 -End $AASundayEndTime2 -ErrorAction Stop   
}
ElseIf(($AASundayStartTime1 -ne $null -and $AASundayStartTime1 -ne "none" -and $AASundayEndTime1 -ne "0:00 (next day)") -and ($AASundayStartTime2 -ne $null -and $AASundayStartTime2 -ne "none" -and $AASundayEndTime2 -eq "0:00 (next day)"))
{
    $SundayTimeRange1 = New-CsOnlineTimeRange -Start $AASundayStartTime1 -End $AASundayEndTime1 -ErrorAction Stop
    $SundayTimeRange2 = New-CsOnlineTimeRange -Start $AASundayStartTime2 -End "1.00:00:00" -ErrorAction Stop   
}
ElseIf($AASundayStartTime1 -ne $null -and $AASundayStartTime1 -ne "none" -and $AASundayEndTime1 -ne "0:00 (next day)")
{
    $SundayTimeRange1 = New-CsOnlineTimeRange -Start $AASundayStartTime1 -End $AASundayEndTime1 -ErrorAction Stop
}
ElseIf($AASundayStartTime1 -ne $null -and $AASundayStartTime1 -ne "none" -and $AASundayEndTime1 -eq "0:00 (next day)")
{
    $SundayTimeRange1 = New-CsOnlineTimeRange -Start $AASundayStartTime1 -End "1.00:00:00"-ErrorAction Stop
}


# Creating new schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($MondayTimeRange2 -ne $null)
            {
                $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -MondayHours @($MondayTimeRange1, $MondayTimeRange2) -ErrorAction Stop
            }
            ElseIf($MondayTimeRange2 -eq $null)
            {
                $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -MondayHours @($MondayTimeRange1) -ErrorAction Stop
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Tuesday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($TuesdayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -TuesdayHours @($TuesdayTimeRange1, $TuesdayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.TuesdayHours += $TuesdayTimeRange1, $TuesdayTimeRange2
                }
            }
            ElseIf($TuesdayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -TuesdayHours @($TuesdayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.TuesdayHours += $TuesdayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Wednesday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($WednesdayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -WednesdayHours @($WednesdayTimeRange1, $WednesdayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.WednesdayHours += $WednesdayTimeRange1, $WednesdayTimeRange2
                }
            }
            ElseIf($WednesdayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -WednesdayHours @($WednesdayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.WednesdayHours += $WednesdayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Thursday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($ThursdayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -ThursdayHours @($ThursdayTimeRange1, $ThursdayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.ThursdayHours += $ThursdayTimeRange1, $ThursdayTimeRange2
                }
            }
            ElseIf($ThursdayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -ThursdayHours @($ThursdayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.ThursdayHours += $ThursdayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Friday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($FridayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -FridayHours @($FridayTimeRange1, $FridayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.FridayHours += $FridayTimeRange1, $FridayTimeRange2
                }
            }
            ElseIf($FridayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -FridayHours @($FridayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.FridayHours += $FridayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Saturday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($SaturdayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -SaturdayHours @($SaturdayTimeRange1, $SaturdayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.SaturdayHours += $SaturdayTimeRange1, $SaturdayTimeRange2
                }
            }
            ElseIf($SaturdayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -SaturdayHours @($SaturdayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.SaturdayHours += $SaturdayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Adding Sunday schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($SundayTimeRange2 -ne $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -SundayHours @($SundayTimeRange1, $SundayTimeRange2) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.SundayHours += $SundayTimeRange1, $SundayTimeRange2
                }
            }
            ElseIf($SundayTimeRange2 -eq $null)
            {
                If($afterHoursSchedule -eq $null)
                {
                    $afterHoursSchedule = New-CsOnlineSchedule -Name "$($AutoAttendant.Name) After Hours Schedule" -WeeklyRecurrentSchedule -SundayHours @($SundayTimeRange1) -ErrorAction Stop
                }
                Else
                {
                    $afterHoursSchedule.WeeklyRecurrentSchedule.SundayHours += $SundayTimeRange1
                }                
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

#Updating schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            Set-CsOnlineSchedule -Instance $afterHoursSchedule
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}


# Creating new after hours call handling
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $afterHoursCallHandlingAssociation = New-CsAutoAttendantCallHandlingAssociation -Type AfterHours -ScheduleId $afterHoursSchedule.Id -CallFlowId $CallFlow.Id -ErrorAction Stop
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Setting new call handling association for after hours 
Write-Host "Adding new after hours call schedule"
$AutoAttendant.CallHandlingAssociations = @($afterHoursCallHandlingAssociation)

# Readding already configures holidays
Write-Host "Adding existing holiday schedule(s)"
foreach($item in $HolidayCallHandling){$AutoAttendant.CallHandlingAssociations += @($item)}

# Updating auto attendant object

If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            Set-CsAutoAttendant -Instance $AutoAttendant -ErrorAction Stop
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

#Cleaning up old schedule if no other AA is associated with this schedule
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            If($(Get-CsOnlineSchedule -Id $CurrentCallhandling.ScheduleId).AssociatedConfigurationIds.Count -eq 1)
            {
                Remove-CsOnlineSchedule -Id $CurrentCallHandling.ScheduleId
            }
        }
    Catch {
            $Resp = @{ "Error" = $_.Exception.Message }
            $StatusCode =  [HttpStatusCode]::BadGateway
            Write-Error $_
        }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
