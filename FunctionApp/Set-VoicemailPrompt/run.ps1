using namespace System.Net

# Input bindings are passed in via param block
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#Import the PS modules
$AuthentionModuleLocation = ".\Modules\GetAuthenticationToken\GetAuthenticationToken.psd1"
Import-Module $AuthentionModuleLocation

$AudioPromptModuleLocation = ".\Modules\UploadAudioPrompt\UploadAudioPrompt.psd1"
Import-Module $AudioPromptModuleLocation

$authHeader = Get-AuthenticationToken
#$audioPrompt = Upload-AudioPrompt -Token $authHeader -FileName "IT_helpdesk_call_queue_music on hold_MSFT_Backbeats.mp3" -Type HuntGroup
#Write-Output "Audioprompt: $audioPrompt"
#Get-ChildTem $env:temp

$site = "Teamsvoicemanagement"

$uri = "https://graph.microsoft.com/v1.0/sites/root:/sites/$site"
$SiteIdResults = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
$SiteId = $SiteIdResults.id.Split(",")[1]

$uri = "https://graph.microsoft.com/v1.0/sites/$SiteId/drive/root:$filepath"

write-host $uri
<#
$FileName = "IT_helpdesk_call_queue_greeting_MSFT_Backbeats.mp3"
$FilePath = "/audio%20prompts/$($FileName.Replace(`" `", `"%20`"))"

$uri = "https://graph.microsoft.com/v1.0/sites/a6cc22e2-0eca-446c-8662-0518dabc00a3/drive/root:$filepath"
$FileId = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get

write-output $FileId.id
$destinationFilePath = "$($env:temp)\$FileName"
$uri = "https://graph.microsoft.com/v1.0/sites/a6cc22e2-0eca-446c-8662-0518dabc00a3/drive/items/$($FileId.id)/content"
$FileId = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get -OutFile $destinationFilePath

Get-ChildItem $env:temp
#>

#Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get

#$result = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get -ResponseHeadersVariable RES).value
If ($result) {
    $body = $result
    $StatusCode = '200'

    $response = ConvertFrom-Json $body

    $response|gm
    #$uri = "https://graph.microsoft.com/v1.0/groups/38588088-9f70-4cc3-b3c0-62fbda69582f/drive/items/014DIZVLQFDZKR3PHZ2BA3F2O5LIYYUK5E/content"
}
Else {
    $body = $RES
    $StatusCode = '400'}

Write-Output "Results: $result"
# Associate values to output bindings by calling 'Push-OutputBinding'
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $body
})