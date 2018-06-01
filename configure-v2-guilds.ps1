# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# This script updates the configuration file from v1 to v2. The new v2 format
# stores data about separate guilds in their own guild array.


# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# Location to store the backup of configuration
$config_file = "l0g-101086-config.json"
$backup_file = "${config_file}.bk"

if (X-Test-Path $backup_file) {
    Read-Host -Prompt "Please remove the backup file before running this script. Press enter to exit"
    exit
}

# Load the configuration from the default file
$config = Load-Configuration $config_file 1
if (-not $config) {
    exit
}

# The v1 configuration file has lots of data about guilds and discord servers,
# including the discord map, emoji map, the guild thumbnail, the discord
# webhook, and the guild text and tag values.
#
# In order to add the ability to upload to different discords depending on
# who was involved in an encounters, we want to correlate this information
# about guilds into its own subsection.
#
# The v2 configuration does this by migrating data from the global config space
# into an array of guilds, which correlate this data together.

$guild_data = [PSCustomObject]@{
    name = $config.guild_text
    priority = 1
    webhook_url = $config.discord_webhook
    tag = $config.gw2raidar_tag_glob.trim("*")
    thumbnail = $config.guild_thumbnail
    fractals = $config.publish_fractals
    discord_map = $config.discord_map
    emoji_map = $config.emoji_map
}

# Remove the now unused fields
$config.PSObject.Properties.Remove('discord_webhook')
$config.PSObject.Properties.Remove('guild_thumbnail')
$config.PSObject.Properties.Remove('gw2raidar_tag_glob')
$config.PSObject.Properties.Remove('guild_text')
$config.PSObject.Properties.Remove('publish_fractals')
$config.PSObject.Properties.Remove('discord_map')
$config.PSObject.Properties.Remove('emoji_map')

# Remove custom tags script, as this will be superseded
$config.PSObject.Properties.Remove('custom_tags_script')

# Add the guild data in as an array
Add-Member -InputObject $config -NotePropertyName guilds -NotePropertyValue @($guild_data)

# Update the config_version field
$config.config_version = 2

# Write the configuration file out
Copy-Item -Path $config_file -Destination $backup_file
$config | ConvertTo-Json -Depth 10 | Out-File -Force $config_file

Read-Host -Prompt "Configured the discord account map. Press enter to exit"
exit
