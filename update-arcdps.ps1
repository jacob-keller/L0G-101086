# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Path to JSON-formatted configuration file
$config_file = "l0g-101086-config.json"

# Relevant customizable configuration fields

# guildwars2_path
#
# Path to the Guild Wars 2 installation directory

# dll_backup_path
#
# Path to a folder to store backups of the previous version of files

# Test a path for existence, safe against $null
Function X-Test-Path($path) {
    return $(try { Test-Path $path.trim() } catch { $false })
}

# Make sure the configuration file exists
if (-not (X-Test-Path $config_file)) {
    Read-Host -Prompt "Unable to locate the configuration file. Copy and edit the sample configuration? Press enter to exit"
    exit
}

$config = Get-Content -Raw -Path $config_file | ConvertFrom-Json

# Allow path configurations to contain %UserProfile%, replacing them with the environment variable
$config | Get-Member -Type NoteProperty | where { $config."$($_.Name)" -is [string] } | ForEach-Object {
    $config."$($_.Name)" = ($config."$($_.Name)").replace("%UserProfile%", $env:USERPROFILE)
}

if (-not (X-Test-Path $config.guildwars2_path)) {
    Read-Host -Prompt "The Guild Wars 2 is not configured correctly. Press enter to exit"
    exit
}

if (-not $config.dll_backup_path) {
    Read-Host -Prompt "A .dll backup directory must be configured. Press enter to exit"
    exit
} elseif (-not (X-Test-Path $config.dll_backup_path)) {
    try {
        New-Item -ItemType directory -Path $config.dll_backup_path
    } catch {
        Read-Host -Prompt "Unable to create $($.config.dll_backup_path)"
        exit
    }
}

# Path to store the Arc DPS dll
$arc_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9.dll"
# Path to store the templates dll
$templates_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_buildtemplates.dll"
# Path to store the mechanics dll
$mechanics_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_mechanics.dll"

# Store the dlls in both the top level and \bin64 to make Gw2 Launch Buddy happy
$arc_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9.dll"
$templates_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_buildtemplates.dll"
$mechanics_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_mechanics.dll"

# Path to backup locations for the previous versions
$arc_backup = Join-Path -Path $config.dll_backup_path -ChildPath "arc-d3d9.dll.back"
$templates_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_buildtemplates.dll.back"
$mechanics_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_mechanics.dll.back"

#
# URLs we need to fetch from
#

# URL for arcdps dll
$arc_url = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
# URL for the MD5 sum of arcdps dll
$arc_md5_url = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
# URL for the build templates plugin
$templates_url = "https://www.deltaconnected.com/arcdps/x64/buildtemplates/d3d9_arcdps_buildtemplates.dll"
# URL for the mechanics plugin for Arc DPS
$mechanics_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll"
# URL for the MD5 sum of the mechanics dll
$mechanics_md5_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll.md5sum"

$run_update = $false
Write-Host "Checking ArcDPS MD5 Hash for changes"
if ((X-Test-Path $arc_path) -and (X-Test-Path $templates_path)) {
    $current_md5 = (Get-FileHash $arc_path -Algorithm MD5).Hash
    Write-Host "arcdps: Current MD5 Hash: $current_md5"
    $web_md5 = Invoke-WebRequest -URI $arc_md5_url -UseBasicParsing
    # this file has the md5sum followed by a filename
    $web_md5 = $web_md5.toString().trim().split(" ")[0].toUpper()
    Write-Host "arcdps: Online MD5 Hash:  $web_md5"

    if ($current_md5 -ne $web_md5) {
        $run_update = $true
    }
} else {
    $run_update = $true
}

if ($run_update -eq $false) {
    Write-Host "Current version is up to date"
} else {
    # If we have a copy of ArcDPS, make a new backup before overwriting
    if (X-Test-Path $arc_path) {
        if (X-Test-Path $arc_backup) {
            Remove-Item $arc_backup
        }
        Move-Item $arc_path $arc_backup
    }

    # Also backup the templates plugin
    if (X-Test-Path $templates_path) {
        if (X-Test-Path $templates_backup) {
            Remove-Item $templates_backup
        }
        Move-Item $templates_path $templates_backup
    }

    # Remove the copy in bin64 as well
    if (X-Test-Path $arc_bin_path) {
        Remove-Item $arc_bin_path
    }

    Write-Host "Downloading new arcdps d3d9.dll"
    Invoke-WebRequest -Uri $arc_url -UseBasicParsing -OutFile $arc_path
    Copy-Item $arc_path $arc_bin_path
    Write-Host "Downloading new arcdps d3d9_arcdps_build_templates.dll"
    Invoke-WebRequest -Uri $templates_url -UseBasicParsing -OutFile $templates_path
    Copy-Item $templates_path $templates_bin_path
}

$run_update = $false
Write-Host "Checking d3d9_arcdps_mechanics.dll MD5 Hash for changes"
if (X-Test-Path $mechanics_path) {
    $current_md5 = (Get-FileHash $mechanics_path -Algorithm MD5).Hash
    Write-Host "mechanics: Current MD5 Hash: $current_md5"
    $web_md5 = Invoke-WebRequest -URI $mechanics_md5_url -UseBasicParsing
    # file is just the md5sum, without a filename
    $web_md5 = $web_md5.toString().trim().toUpper()
    Write-Host "mechanics: Online MD5 Hash:  $web_md5"

    if ($current_md5 -ne $web_md5) {
        $run_update = $true
    }
} else {
    $run_update = $true
}

if ($run_update -eq $false) {
    Write-Host "Current d3d9_arcdps_mechanics.dll version is up to date"
} else {
    # If we have a copy of the mechanics dll, make a new backup before overwriting
    if (X-Test-Path $mechanics_path) {
        if (X-Test-Path $mechanics_backup) {
            Remove-Item $mechanics_backup
        }
        Move-Item $mechanics_path $mechanics_backup
    }

    # Remove the copy in bin64 as well
    if (X-Test-Path $mechanics_bin_path) {
        Remove-Item $mechanics_bin_path
    }

    Write-Host "Downloading new d3d9_arcdps_mechanics.dll"
    Invoke-WebRequest -Uri $mechanics_url -UseBasicParsing -OutFile $mechanics_path
    Copy-Item $mechanics_path $mechanics_bin_path
}

Read-Host -Prompt "Press Enter to exit"
