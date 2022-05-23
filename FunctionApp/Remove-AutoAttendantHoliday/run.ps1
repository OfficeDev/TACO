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

# Retrieving holiday information
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $Holiday= $(Get-CsOnlineSchedule -ErrorAction Stop| Where-Object {$_.Name -eq $AAHolidayName}) 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Removing holiday call handling associations
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
        $AutoAttendant.CallHandlingAssociations.Remove(($AutoAttendant.CallHandlingAssociations | where-object {$_.ScheduleId -eq $($Holiday.Id)})) 
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Removing holiday call flow
If ($StatusCode -eq [HttpStatusCode]::OK) {
    Try {
            $AutoAttendant.CallFlows.Remove(($AutoAttendant.CallFlows | where-object {$_.Name -eq $AAHolidayName}))
        }
    Catch {
        $CallFlow = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
}

# Reconfiguring auto attendant
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