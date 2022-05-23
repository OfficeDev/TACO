Param(
    [Parameter(Mandatory=$true,HelpMessage="You must enter function hostname with argument -hostname")][string]$hostname,
    [Parameter(Mandatory=$true,HelpMessage="You must enter function code with argument -code")][string]$code,
    [Parameter(Mandatory=$false,HelpMessage="You must enter Azure AD tenant ID with argument -tenantID")][string]$tenantID,
    [Parameter(Mandatory=$false,HelpMessage="You must enter Azure AD client ID with argument -clientID")][string]$clientID,
    [Parameter(Mandatory=$false,HelpMessage="You must enter Azure AD secret with argument -secret")][string]$secret,
    [Parameter(Mandatory=$false)][int]$workers  = 3,
    [Parameter(Mandatory=$false)][int]$maxRetry = 3
)

Write-Host "Azure Function warm-up using API call"
$echoUri = 'https://' + $hostname + '/api/Get-CsTeamsCallingPolicy'
Write-Host $echoUri

# Check if parameter to use OAuth are provided
If ([string]::IsNullOrEmpty($tenantID) -OR [string]::IsNullOrEmpty($clientID) -OR [string]::IsNullOrEmpty($secret))
{
    Write-Error "Azure AD tenantID, clientID and secret can't be empty"
    return 
}

# Get access token to query Azure Function
$uri = "https://login.microsoftonline.com/" + $tenantID + "/oauth2/v2.0/token"
$body = @{
    'client_id' = $clientID
    'scope' = 'api://azfunc-' + $clientID + '/.default'
    'client_secret' = $secret
    'grant_type' = 'client_credentials'
}
Try {
    $access_token = (Invoke-RestMethod -Uri $Uri -Method 'Post' -Body $body -ContentType "application/x-www-form-urlencoded").access_token
    $securedToken = ConvertTo-SecureString -String $access_token -AsPlainText -Force
}
Catch {
    Write-Host $_
    return
}
Write-Host "Access token request success"

function generateConfig ([string]$hostname,[string]$code,[int]$workers,$token) {
    $config = @()
    $uri = 'https://' + $hostname + '/api/Get-CsTeamsCallingPolicy?code=' + $code
    for($i = 0; $i -lt $workers; $i++){ 
        $config += New-Object -TypeName psobject -Property @{ID= $i+1; URI= $uri; token= $token}
    }  
    return $config
}

function checkStatus($jobStatus) {
    $check = $true
    foreach ($item in $jobStatus) {
        if ( ($item.StatusCode -ne 200) -OR ([string]::IsNullOrEmpty($item.StatusCode))) { 
            $check = $false
        }
    }
    Return $check
}

$retries = 0
$jobresults = @()
Do
{
    Write-Host "Function warm-up started at" $(Get-Date) "- Attempt #" ($retries+1)
    $job = generateConfig $hostname $code $workers $securedToken | ForEach-Object -ThrottleLimit $workers -Parallel { 
        $timeout = 180
        $start = Get-Date
        Try {
            $Result = Invoke-WebRequest -URI $_.URI -Method 'Get' -TimeoutSec $timeout -MaximumRetryCount 1 -Authentication OAuth -Token $_.token
        }
        Catch {
            If ($_.Exception.Message -notlike '*HttpClient.Timeout*') {
                $_.Exception.Message
            }
        }   
        $finish = Get-Date
        $duration = ($finish - $start).TotalSeconds
        $Resp = New-Object -TypeName psobject -Property @{Duration= [Math]::Round($duration,2); StatusCode= $Result.StatusCode; StatusDescription= If($duration -gt $timeout) {"Request timed out ($timeout sec)"} Else {$Result.StatusDescription};TriggerTime= (Get-Date -DisplayHint Time);WorkerId=$_.ID}
        return $Resp
    } -AsJob
    $jobresult = $job | Wait-Job -Timeout 200 | Receive-Job
    $jobresults += $jobresult

    $test = checkStatus($jobresult)
    If ($test -EQ $FALSE) {
        Write-Host "Results - Attempt #" ($retries+1)
        $jobresult | Sort-Object TriggerTime | Format-Table TriggerTime,WorkerId,Duration,StatusCode,StatusDescription
        Write-Host "Sleeping for 5 min before retrying"
        Start-Sleep -Seconds 300
    }

    $job | Remove-Job
    $retries +=1
}
until( ($test -EQ $TRUE) -OR ($retries -ge $maxRetry))

If ($retries -ge $maxRetry) {
    Write-Host "Reached max retries - Function app still not warmed up - Please restart the script or check error messages"
}
$jobresults | Sort-Object TriggerTime | Format-Table TriggerTime,WorkerId,Duration,StatusCode,StatusDescription


