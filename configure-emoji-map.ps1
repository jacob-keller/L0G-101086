# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# Path to JSON-formatted configuration file
$config_file = "l0g-101086-config.json"
$backup_file = "${config_file}.bk"

# emoji_map
#
# The emoji data is a map which stores the specific discord ID that maps to the emoji
# that you wish to display for each boss. This can be found by typing "\emoji" into
# a discord channel, and should return a link similar to <emoji123456789> which you
# need to place into a hash map keyed by the boss name.


if (X-Test-Path $backup_file) {
    Read-Host -Prompt "Please remove the backup file before running this script. Press enter to exit"
    exit
}

# Load the configuration from the default file
$config = Load-Configuration $config_file 2
if (-not $config) {
    exit
}

Write-Output "The configuration file has the following guilds:"

$config.guilds | ForEach-Object {
    Write-Output "$($_.name)"
}

$guild_name = Read-Host -Prompt "Which guild would you like to configure?"

$guild = $config.guilds | where { $_.name -eq $guild_name }

if (-not $guild) {
    Write-Output "${guild_name} is not one of the configured guilds."
    Read-Host -Prompt "Press any key to exit."
    exit
}

# Check if the token has already been set
if ($guild.emoji_map) {
    try {
        [ValidateSet('Y','N')]$continue = Read-Host -Prompt "An emoji map appears to already be configured for this guild. Comtinue? (Y/N)"
    } catch {
        # Just exit on an invalid response
        exit
    }
    if ($continue -ne "Y") {
        exit
    }
}

$emoji_map = @{"Mursaat Overseer"="";
               "Samarog"="";
               "Slothasor"="";
               "Sabetha"="";
               "Dhuum"="";
               "Gorseval"="";
               "Xera"="";
               "Soulless Horror"="";
               "Cairn"="";
               "Keep Construct"="";
               "Matthias"="";
               "Deimos"="";
               "Vale Guardian"="";
               "Conjured Amalgamate"="";
               "Largos Twins"="";
               "Qadim"="";}

Write-Output "Fill in the discord emoji id you would like to use for each boss."
Write-Output "To generate this, type \:emoji: ino a channel of your server."
Write-Output ""

$emoji_map.GetEnumerator() | Sort-Object -Property { $_.Key } | ForEach-Object {
    $emoji_map[$_.Key] = Read-Host -Prompt "$($_.Key)?"
}

# Store the new map into the configuration
$guild.emoji_map = $emoji_map

# Write the configuration file out
Write-Configuration $config $config_file $backup_file

Read-Host -Prompt "Configured the emoji map. Press enter to exit"
exit

