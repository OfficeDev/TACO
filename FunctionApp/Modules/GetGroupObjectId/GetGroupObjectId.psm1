function Get-GroupObjectId
{
    param ($Token,$DisplayName)

    $FilePath = "/audio prompts/$FileName"

    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$DisplayName')"
    $ObjectId = Invoke-RestMethod -Uri $uri -Headers $Token -Method Get

    Return $ObjectId
}