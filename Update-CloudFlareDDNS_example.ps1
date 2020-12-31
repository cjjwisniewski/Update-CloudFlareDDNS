<#--------------------------
Name: Update-CloudFlareDDNS.ps1
Author: Cameron Wisniewski
Date: 12/30/20
Version: 1.1
Comment: For use with a scheduled task to regularly update the IP associated with an A record in CloudFlare
Notes: N/A
Link: https://api.cloudflare.com/
--------------------------#>

#Define required information
$CFEmailAddress = "email@email.tld"
$CFAPIKey = "<INSERT API KEY FROM WEBUI>"
$CFDomainName = "<INSERT DOMAIN NAME>"
$CFARecords = @(
    "example.com"
    "subdomain.example.com"
)

#__________DON'T CHANGE ANYTHING BELOW THIS LINE_________

#First run tasks
if(!(Test-Path -Path "$PSScriptRoot\ip.txt")) {
    New-Item -Path "$PSScriptRoot" -Name "ip.txt"
}

#Retrieve current IP
$CurrentIP = Invoke-RestMethod -Method Get -Uri "https://api.ipify.org" 
if((Get-Content -Path "$PSScriptRoot\ip.txt") -eq $CurrentIP) {
    #Exit script if there's been no change
    exit
} elseif((Get-Content -Path "$PSScriptRoot\ip.txt") -ne $CurrentIP) {
    #Update ip.txt if the IP has changed
    Set-Content -Path "$PSScriptRoot\ip.txt" -Value $CurrentIP
}

#Define request headers
$RequestHeader = @{
    "X-Auth-Email" = "$CFEmailAddress";
    "X-Auth-Key" = "$CFAPIKey";
    "Content-Type" = "application/json"
}

#Retrieve zone ID
$CFZoneID = (Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones?name=$CFDomainName" -Headers $RequestHeader).Result.id

#Act on each defined A record
$CFARecords | ForEach-Object {
    #Retrieve record ID
    $CurrentRecordName = $_
    $CurrentRecord = (Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones/$CFZoneID/dns_records?type=A&name=$CurrentRecordName" -Headers $RequestHeader).Result

    #Define record update request body
    $RequestBody = @{
        "id" = "$CFZoneID"
        "type" = "A"
        "name" = "$CurrentRecordName"
        "content" = "$CurrentIP"
        "proxied" = $CurrentRecord.proxied
    }
    $RequestBody = $RequestBody | ConvertTo-Json

    #Set record information
    Invoke-RestMethod -Method Put -Uri "https://api.cloudflare.com/client/v4/zones/$CFZoneID/dns_records/$($CurrentRecord.id)" -Headers $RequestHeader -Body $RequestBody
}