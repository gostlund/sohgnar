#Speedtest CLI for PS - Post to Teams
# By Gavin Ostlund - June 1 2021
#Based on the work of Michael Stants - June 1 2021

##############################
# Variables you need to set  #
##############################

# Teams Webhook URL
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
	Invoke-WebRequest -UseBasicParsing -Uri "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip" -OutFile $ZipPath
	Add-Type -assembly “system.io.compression.filesystem”
	[IO.Compression.ZipFile]::ExtractToDirectory($ZipPath,$SpeedtestDestinationPath)
	Remove-Item $ZipPath
}
Write-Host "Running Speedtest"
$SpeedtestDir = $WorkingDir + "speedtest"

$PreviousResults = if (test-path "$($SpeedtestDir)\LastResults.txt") { get-content "$($SpeedtestDir)\LastResults.txt" | ConvertFrom-Json }

$SpeedtestResults = powershell $speedtestPath --accept-license --format=json --progress=no
$SpeedtestResults | Out-File "$($SpeedtestDir)\LastResults.txt" -Force
$SpeedtestResults = $SpeedtestResults | ConvertFrom-Json

$speedtestResultImage = $SpeedtestResults.result.url + ".png"
$speedtestISP = $SpeedtestResults.isp
$speedtestExtIP = $SpeedtestResults.interface.externalIp
$speedtestIntIP = $SpeedtestResults.interface.internalIp
$speedtestDLspd = [math]::Round($SpeedtestResults.download.bandwidth / 1000000 * 8, 2)
$speedtestULspd = [math]::Round($SpeedtestResults.upload.bandwidth / 1000000 * 8, 2)
$speedtestPL = [math]::Round($SpeedtestResults.packetLoss)
$speedtestPing = [math]::Round($SpeedtestResults.ping.latency)
$speedtestServer = $SpeedtestResults.server.host

if ($PreviousResults) {
	$speedtestDLmsg = "$speedtestDLspd Mbps (Previous test: " + [math]::Round($PreviousResults.download.bandwidth / 1000000 * 8, 2) + " Mbps)"
	$speedtestULmsg = "$speedtestULspd Mbps (Previous test: " + [math]::Round($PreviousResults.upload.bandwidth / 1000000 * 8, 2) + " Mbps)"
} else {
	$speedtestDLmsg = "$speedtestDLspd Mbps"
	$speedtestULmsg = "$speedtestULspd Mbps"
}

Write-Host "Sending to Results to Teams"


$ContentType= 'application/json'
$slackPayload = @"
{
	"@type": "MessageCard",
	"@context": "https://schema.org/extensions",
	"summary": "Speedtest Completed",
	"themeColor": "000000",
	"sections": [
		{
			"heroImage": {
				"image": "$speedtestResultImage"
			}
		},
		{
			"startGroup": true,
			"title": "**Speedtest Completed**",
			"activityImage": "https://github.com/librespeed/speedtest/raw/master/.logo/icon_huge.png",
			"activityTitle": "$speedtestIntIP - *$hostname*",
			"activitySubtitle": "$speedtestExtIP - *$speedtestISP*",
			"facts": [
				{
					"name": "Ping:",
					"value": "$speedtestPing ms"
				},
				{
					"name": "Download:",
					"value": "$speedtestDLmsg"
				},
				{
					"name": "Upload:",
					"value": "$speedtestULmsg"
				},
				{
					"name": "Server:",
					"value": "$speedtestServer"
				}
			]
		},
		{
			"startGroup": true,
			"activitySubtitle": "This message was created by an automated workflow. Do not reply."
		}
	]
}
"@
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-RestMethod -uri $Webhook -Method Post -body $slackPayload -ContentType $ContentType
