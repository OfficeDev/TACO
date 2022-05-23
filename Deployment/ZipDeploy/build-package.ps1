# Use this script if you need to generate a new ZIP package
$rootfolder = "$PSScriptRoot\..\..\"

# Make sure you update and save the MicrosofttTeams module as Azure Function custom modules

Write-Host "Check if Microsoft Teams PowerShell module is installed and up-to-date"
$TeamsPSModuleVersion = $(Find-Module -Name MicrosoftTeams).Version
$TeamsPSModuleInstalled = $(Get-ChildItem -Path $($rootfolder + "FunctionApp\Modules\MicrosoftTeams"))

If($TeamsPSModuleInstalled.Name -ne $TeamsPSModuleVersion -And $TeamsPSModuleInstalled -ne $null)
{
    Write-Host "New Microsoft Teams PowerShell module found, download started"
    Remove-Item $TeamsPSModuleInstalled -Force -Con
    Save-Module -Path $($rootfolder + "FunctionApp\Modules") -Name MicrosoftTeams -Repository PSGallery -MinimumVersion 4.0.0
}
ElseIf($TeamsPSModuleInstalled -eq $null)
{
    Write-Host "Downloading Microsoft Teams PowerShell module"
    Save-Module -Path $($rootfolder + "FunctionApp\Modules") -Name MicrosoftTeams -Repository PSGallery -MinimumVersion 4.0.0
}

# List in the ZIP package all the function app you need to deploy
$packageFiles = @(
    "$($rootfolder)FunctionApp\Add-AutoAttendantHoliday",
    "$($rootfolder)FunctionApp\Remove-AutoAttendantHoliday",
    "$($rootfolder)FunctionApp\Set-AutoAttendantBusinessHours",
    "$($rootfolder)FunctionApp\Set-AutoAttendantCallRouting",
    "$($rootfolder)FunctionApp\Set-AutoAttendantGreeting",
    "$($rootfolder)FunctionApp\Set-AutoAttendantHoliday",
    "$($rootfolder)FunctionApp\Set-CallQueueAgentAlertTime", 
    "$($rootfolder)FunctionApp\Set-CallQueueGreeting",
    "$($rootfolder)FunctionApp\Set-CallQueueMusicOnHold",
    "$($rootfolder)FunctionApp\Set-CallQueueOverFlowAction",
    "$($rootfolder)FunctionApp\Set-CallQueueOverflowThreshold",
    "$($rootfolder)FunctionApp\Set-CallQueueTimeOutAction",
    "$($rootfolder)FunctionApp\Set-CallQueueTimeOutThreshold",
    "$($rootfolder)FunctionApp\Set-VoicemailPrompt",
    "$($rootfolder)FunctionApp\Modules",
    "$($rootfolder)FunctionApp\host.json",
    "$($rootfolder)FunctionApp\profile.ps1",
    "$($rootfolder)FunctionApp\requirements.psd1"
)
$destinationPath = $rootfolder + "Packages\Azure\artifact.zip"

Write-Host "Creating Azure artifact"
Compress-Archive -Path $packageFiles -DestinationPath $destinationPath -CompressionLevel optimal -Force

Write-Host "Completed creating new deployment package"