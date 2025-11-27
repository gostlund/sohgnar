#Speedtest CLI for PS - Post to Teams - Updated for use with PowerAutomate flows
# By Gavin Ostlund - June 1 2021, updated November 27, 2025
#Based on the work of Michael Stants - June 1 2021

##############################
# Variables you need to set  #
##############################

# Webhook URL
$Webhook = "WEBHOOK URL HERE"

# Working Directory (with a trailing \)
$WorkingDir = "C:\System\"

## DO NOT MODIFY ANYTHING BELOW!
## Seriously - You could break stuff. :D

# Get system hostname

$hostname = $env:computername

# Check for System Folder in C:\ and create it if there isn't one. 
$path = $WorkingDir
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
      Write-Host "Created system folder for installers"
} ELSE {
      Write-Host "System Folder exists already."
}

# Check for speedtest in $WorkingDir
$speedtestPath = $WorkingDir + "speedtest\speedtest.exe"
$SpeedtestExecutable = Test-Path -Path $speedtestPath

If ($SpeedtestExecutable){
Write-Host "Speedtest application exists - Skipping download"
} ELSE {
Write-Host "Downloading Speedtest"
$SpeedtestDestinationPath = $WorkingDir + "speedtest\"
$ZipPath = $WorkingDir + "speedtest.zip"
Invoke-WebRequest -UseBasicParsing -Uri "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip" -OutFile $ZipPath
Expand-Archive $ZipPath -DestinationPath $SpeedtestDestinationPath -Force
Remove-Item $ZipPath
}
Write-Host "Running Speedtest"

$SpeedtestResults = powershell $speedtestPath --accept-license --format=json --progress=no | ConvertFrom-Json

$speedtestResultImage = $SpeedtestResults.result.url + ".png"
$speedtestISP = $SpeedtestResults.isp
$speedtestExtIP = $SpeedtestResults.interface.externalIp
$speedtestIntIP = $SpeedtestResults.interface.internalIp
$speedtestDLspd = [math]::Round($SpeedtestResults.download.bandwidth / 1000000 * 8, 2)
$speedtestULspd = [math]::Round($SpeedtestResults.upload.bandwidth / 1000000 * 8, 2)
$speedtestPL = [math]::Round($SpeedtestResults.packetLoss)
$speedtestPing = [math]::Round($SpeedtestResults.ping.latency)
$speedtestServer = $SpeedtestResults.server.host

Write-Host "Sending to Results to Teams"


$ContentType= 'application/json'
$TeamsPayload = @"
{
    "hostname": "$hostname",
    "speedtestISP": "$speedtestISP",
    "speedtestIntIP": "$speedtestIntIP",
    "speedtestExtIP": "$speedtestExtIP",
    "speedtestResultImage": "$speedtestResultImage",
    "speedtestPing": "$speedtestPing",
    "speedtestPL": "$speedtestPL",
    "speedtestDLspd": "$speedtestDLspd",
    "speedtestULspd": "$speedtestULspd",
    "speedtestServer": "$speedtestServer"
}
"@

Invoke-RestMethod -uri $Webhook -Method Post -body $TeamsPayload -ContentType $ContentType

<#
/* Inputs to Compose in Power Automate
 */

{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "size": "Medium",
      "weight": "Bolder",
      "text": "**Speedtest Completed**"
    },
    {
      "type": "ColumnSet",
      "columns": [
        {
          "type": "Column",
          "items": [
            {
              "type": "Image",
              "style": "Person",
              "url": "https://github.com/librespeed/speedtest/raw/master/.logo/icon_huge.png",
              "altText": "Speedtest Icon",
              "size": "Small"
            }
          ],
          "width": "auto"
        },
        {
          "type": "Column",
          "items": [
            {
              "type": "TextBlock",
              "weight": "Bolder",
              "text": "**@{triggerBody()?['hostname']}** - *@{triggerBody()?['speedtestIntIP']}*",
              "wrap": true
            },
            {
              "type": "TextBlock",
              "spacing": "None",
              "text": "@{triggerBody()?['speedtestExtIP']} - *@{triggerBody()?['speedtestISP']}*",
              "isSubtle": true,
              "wrap": true
            }
          ],
          "width": "stretch"
        }
      ]
    },
    {
      "type": "Image",
      "url": "@{triggerBody()?['speedtestResultImage']}"
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "Ping:",
          "value": "@{triggerBody()?['speedtestPing']}"
        },
        {
          "title": "Download:",
          "value": "@{triggerBody()?['speedtestDLspd']}"
        },
        {
          "title": "Upload:",
          "value": "@{triggerBody()?['speedtestULspd']}"
        },
        {
          "title": "Server:",
          "value": "@{triggerBody()?['speedtestServer']}"
        }
      ],
      "$data": "${facts}"
    },
    {
      "type": "TextBlock",
      "text": "This message was created by an automated workflow. Do not reply.",
      "wrap": true,
      "size": "Small"
    }
  ],
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.5"
}

/*
 * Then feed to a
 * Post card in chat or channel
 * Post as: Flow bot
 * Post in: Channel
 * Team: $yourTeam
 * Channel: $yourChannel
 * Adaptive Card: Compose:Outputs
 * Code View:

{
  "type": "OpenApiConnection",
  "inputs": {
    "parameters": {
      "poster": "Flow bot",
      "location": "Channel",
      "body/recipient/groupId": "lulNo",
      "body/recipient/channelId": "alsoNo",
      "body/messageBody": "@outputs('Compose')"
    },
    "host": {
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_teams",
      "connection": "shared_teams",
      "operationId": "PostCardToConversation"
    }
  },
  "runAfter": {
    "Compose": [
      "Succeeded"
    ]
  }
}

 */
#>

