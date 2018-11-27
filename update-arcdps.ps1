# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# Relevant customizable configuration fields

# guildwars2_path
#
# Path to the Guild Wars 2 installation directory

# dll_backup_path
#
# Path to a folder to store backups of the previous version of files

# Load the configuration from the default file
$config = Load-Configuration "l0g-101086-config.json"
if (-not $config) {
    exit
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
        Write-Exception $_
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
# Path to store the extras dll
$extras_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_extras.dll"

# Store the dlls in both the top level and \bin64 to make Gw2 Launch Buddy happy
$arc_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9.dll"
$templates_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_buildtemplates.dll"
$mechanics_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_mechanics.dll"
$extras_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_extras.dll"

# Path to backup locations for the previous versions
$arc_backup = Join-Path -Path $config.dll_backup_path -ChildPath "arc-d3d9.dll.back"
$templates_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_buildtemplates.dll.back"
$mechanics_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_mechanics.dll.back"
$extras_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_extras.dll.back"
#
# URLs we need to fetch from
#

# URL for arcdps dll
$arc_url = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
# URL for the MD5 sum of arcdps dll
$arc_md5_url = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
# URL for the build templates plugin
$templates_url = "https://www.deltaconnected.com/arcdps/x64/buildtemplates/d3d9_arcdps_buildtemplates.dll"
# URL for arc extras
$extras_url = "https://www.deltaconnected.com/arcdps/x64/extras/d3d9_arcdps_extras.dll"
# URL for the mechanics plugin for Arc DPS
$mechanics_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll"
# URL for the MD5 sum of the mechanics dll
$mechanics_md5_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll.md5sum"

if ($config.experimental_arcdps -eq $true) {
    $experimental_arc_url =  "https://www.deltaconnected.com/arcdps/dev/d3d9.dll"

    # Check if the experimental build exists right now
    try {
        Invoke-WebRequest -URI $experimental_arc_url -UseBasicParsing -Method head

        $arc_url = $experimental_arc_url
        $templates_url = "https://www.deltaconnected.com/arcdps/dev/d3d9_arcdps_buildtemplates.dll"
        $extras_url = "https://www.deltaconnected.com/arcdps/dev/d3d9_arcdps_extras.dll"
        # The experimental build doesn't have an md5sum file currently. :(
        $arc_md5_url = $null
    } catch [System.net.WebException] {
        if ($_.Exception.Response.StatusCode -eq "NotFound") {
            Write-Host "No experimental version available. Downloading regular arcdps release"
        } else {
            throw $_.Exception
        }
    }
}

$run_update = $false
if (($arc_md5_url -ne $null) -and (X-Test-Path $arc_path) -and (X-Test-Path $templates_path) -and (X-Test-Path $extras_path)) {
    Write-Host "Checking ArcDPS MD5 Hash for changes"

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

    # Also backup extras
    if (X-Test-Path $extras_path) {
        if (X-Test-Path $extras_backup) {
            Remove-Item $extras_backup
        }
        Move-Item $extras_path $extras_backup
    }

    # Remove the copy in bin64 as well
    if (X-Test-Path $arc_bin_path) {
        Remove-Item $arc_bin_path
    }
    if (X-Test-Path $templates_bin_path) {
        Remove-Item $templates_bin_path
    }
    if (X-Test-Path $extras_bin_path) {
        Remove-Item $extras_bin_path
    }

    Write-Host "Downloading new arcdps d3d9.dll"
    Invoke-WebRequest -Uri $arc_url -UseBasicParsing -OutFile $arc_path
    Copy-Item $arc_path $arc_bin_path
    Write-Host "Downloading new arcdps d3d9_arcdps_build_templates.dll"
    Invoke-WebRequest -Uri $templates_url -UseBasicParsing -OutFile $templates_path
    Copy-Item $templates_path $templates_bin_path
    Write-Host "Downloading new arcdps d3d9_arcdps_extras.dll"
    Invoke-WebRequest -Uri $extras_url -UseBasicParsing -OutFile $extras_path
    Copy-Item $extras_path $extras_bin_path
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
# SIG # Begin signature block
# MIIFZAYJKoZIhvcNAQcCoIIFVTCCBVECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5O3ScXzRFeRonjH8+1QGD0w7
# K3agggMCMIIC/jCCAeagAwIBAgIQFFuA0ERIe5ZFRAzvqUXg0TANBgkqhkiG9w0B
# AQsFADAXMRUwEwYDVQQDDAxKYWNvYiBLZWxsZXIwHhcNMTgxMDI4MDU1MzQzWhcN
# MTkxMDI4MDYxMzQzWjAXMRUwEwYDVQQDDAxKYWNvYiBLZWxsZXIwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDXGkNeGuDBzVQwrOwaZx8ovS5BfaSsG5xx
# 3qaOK7YDsvpcebJMVK6eyjVO8X49bu4Q23ESyAmyD6udo+nGow2HmBaadmx3XtTY
# BDJrlf0dvf3j6HKsY/L9PQ1qa2lASDRoGUTZygflijc+Q9JJo7EG/QefwLrKF1Bw
# vF7eg6remPiJmT9JwhmEDy2H8jZn32B8+AAaaoYxP62+1kayn/smhHYLHBlzPSN3
# c8M74jGwIVLWHcy+3GS5cLQ2TgRiqLjTQujKn7t5EasGjsUZLNl/1mMUae4kt35E
# l+IThauMio4vm2ooB169X1hKS9/cd83bxzGkmxHbNYBdLsQK6USlAgMBAAGjRjBE
# MA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU
# tKQNud96B8lWJUbI02sltSDIExkwDQYJKoZIhvcNAQELBQADggEBAIC17zjVumO0
# kgo+Qn/bmePqejGCZl5ajfYhNLMEBCnK1wqZBtV/7sAgK8HNBDuVJWRShGCJle6T
# XQrt5MaVqE5RMOxRMkSBTHHw1n+y63kfSUgL/7/m1VMlpUHFqnC5nnkzQNpDABwz
# irro884sMu9rwzOn2GqoRfA9iFjdd3+6o1PTh0ms6rGP+U40cWXwLia/gHYS9Nfj
# SJtrPmWejpWCRGaEimyDZoK+KZNGGecphrbU20vgNUaKVz2ukESa4bdpaAbaG51Z
# 3wmtVSFveRwVuhDPTkRSp2h9sMGqfK3KJZW/CPRYYE/UwpXTNttMfftJ83btibZ3
# j/LuvKgyF94xggHMMIIByAIBATArMBcxFTATBgNVBAMMDEphY29iIEtlbGxlcgIQ
# FFuA0ERIe5ZFRAzvqUXg0TAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUGa/SrvBjyx/8XNft0od/
# 76eUBTkwDQYJKoZIhvcNAQEBBQAEggEAWyb7Dr0lk7bi5Sv/Lr0YYJuyyGfG0vV3
# rjFT1l6IBjZFGgJy7porSgCCnBslrWz8EIIqp8JFoe+2fxGZK7BI/gIC6YKFMPve
# c7nVmXi+t277TQoMsAME6TgvaFPkk91GDsRGCsbXfCIFfPbmA1m/ISbN8xMwRhxp
# fR6bafwfUb+JRW96zT1dClnzqM5HM29/9QSxC32mP4DWuVpsz54gf6MLKJM7Am+J
# tFyWu7GIUdPD8mLtIERMkAr2IQkwpa3h+K9pDl0YPMvNsazkvB7J8lGMIDxcfbhG
# jDBr8gE0BIBXNkTwWJZ4p6CQ4acWZrSHD4ybL9fyCLfPsvZyArO2eg==
# SIG # End signature block
