function Upload-AudioPrompt
{
    param ($Token, $Site, $Path, $FileName, $Type )

    Write-Host "Uploading audio prompt"
    $Path = $Path.Replace(" ", "%20")
	$FileName = $FileName.Replace(" ", "%20")
    Write-Host $FileName
    $FilePath = "/audio%20prompts/$Path/$FileName"
    
    Write-Host "Using Graph API to find site id"
    
    $site = $Site
    Write-Host "Site: $site"
    $uri = "https://graph.microsoft.com/v1.0/sites/root:/sites/$site"
    $SiteIdResults = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get
    $SiteId = $SiteIdResults.id.Split(",")[1]

    Write-Host $FilePath
    Write-Host "Using Graph API to find file id"
    $uri = "https://graph.microsoft.com/v1.0/sites/$SiteId/drive/root:/$filepath"
    $FileId = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get
    
    Write-Host "FileID: $FileId"
    
    #$FileId = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get
    
    Write-Host "Uploading file"
    $uri = "https://graph.microsoft.com/v1.0/sites/$SiteId/drive/items/$($FileId.id)/content"
    $destinationFilePath = "$($env:temp)\$FileName"
    $FileId = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get -OutFile $destinationFilePath
    
    $content = Get-Content $destinationFilePath -AsByteStream -ReadCount 0
    $audioFile = Import-CsOnlineAudioFile -ApplicationId $Type -FileName $FileName -Content $content

    Return $audioFile
}