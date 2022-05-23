function Get-AuthenticationToken
{
    param ($Scope)

    #If parameter "Scope" has not been provided, we assume that graph.microsoft.com is the target resource
    If (!$Scope) 
    {
        $Scope = "https://graph.microsoft.com"
    }
    
    $tokenAuthUri = $env:IDENTITY_ENDPOINT + "?resource=$Scope&api-version=2019-08-01"
    $response = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthUri -UseBasicParsing
    $accessToken = $response.access_token

    $authHeader = @{    
    'Content-Type'='application/json'
    'Authorization'='Bearer ' +  $accessToken
    }

    Return $authHeader
}