# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# This script is used to ease the burden of generating a gw2raidar token. Feel free
# to use https://www.gw2raidar.com/api/v2/swagger instead, if you do not trust
# this script with your username and password.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# Path to JSON-formatted configuration file
$backup_file = "${config_file}.bk"

# gw2raidar_token
#
# This is the token obtained from gw2raidar's API, in connection with your account.
# It can be obtained through a webbrowser by logging into gw2raidar.com and visiting
# "https://www.gw2raidar.com/api/v2/swagger#/token"

if (X-Test-Path $backup_file) {
    Read-Host -Prompt "Please remove the backup file before running this script. Press enter to exit"
    exit
}

# Load the configuration from the default file
$config = Load-Configuration "l0g-101086-config.json"
if (-not $config) {
    exit
}

# Check if the token has already been set
if ($config.gw2raidar_token) {
    try {
        [ValidateSet('Y','N')]$continue = Read-Host -Prompt "A GW2 Raidar token appears to already be configured. Continue? (Y/N)"
    } catch {
        # Just exit on an invalid response
        exit
    }
    if ($continue -ne "Y") {
        exit
    }
}

Write-Output "Requesting GW2 Raidar username/password..."

# Request the credentials from the user
$pscreds = $Host.ui.PromptForCredential("GW2 Raidar username/password", "Please enter your gw2raidar username and password", $null, $null)

# If we don't get a credential object, the user must of clicked cancel
if ($pscreds -eq $null) {
    Write-Output "Cancelling..."
    exit
}

$netcreds = $pscreds.GetNetworkCredential()

# Request the API token from GW2 Raidar
try {
    $token_resp = Invoke-RestMethod -Uri https://www.gw2raidar.com/api/v2/token -Method post -Body @{username=$netcreds.username;password=$netcreds.password}
} catch {
    Read-Host -Prompt "Unable to obtain GW2 Raidar token. Press enter to exit"
    exit
}

if ($topen_resp.token -eq $null) {
    Read-Host -Prompt "Unable to obtain GW2 Raidar token. Press enter to exit"
    exit
}

Write-Output "Obtained token..."

# Insert it into the configuration
$config.gw2raidar_token = $token_resp.token

# Write the configuration out
Copy-Item -Path $config_file -Destination $backup_file
$config | ConvertTo-Json -Depth 10 | Out-File -Force $config_file

Read-Host -Prompt "Configured GW2 Raidar token. Press enter to exit"
exit