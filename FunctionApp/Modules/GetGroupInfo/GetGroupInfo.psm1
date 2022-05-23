function Get-GroupObjectInfo
{
    param ($Token,$DisplayName,$ObjectId)

    #$FilePath = "/audio prompts/$FileName"

    If($Displayname -ne $null)
    {
	    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$DisplayName')"
	    $ObjectId = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get

	    Return $ObjectId
    }
    ElseIf($ObjectId -ne $null)
    {
	    Write-Host "Getting ObjectId: $ObjectId"
	    $uri = "https://graph.microsoft.com/v1.0/groups/$ObjectId"
	    $DisplayName = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get

	    Return $Displayname
    }
}