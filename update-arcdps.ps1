# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

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
$config = Load-Configuration (Get-Config-File)
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
# Path to store the table dll
$table_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_table.dll"
# Path to store the extras dll
$extras_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_extras.dll"
# Path to store the table dll
$table_path = Join-Path -Path $config.guildwars2_path -ChildPath "d3d9_arcdps_table.dll"

# Store the dlls in both the top level and \bin64 to make Gw2 Launch Buddy happy
$arc_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9.dll"
$templates_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_buildtemplates.dll"
$table_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_table.dll"
$extras_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_extras.dll"
$table_bin_path = Join-Path -Path $config.guildwars2_path -ChildPath "bin64\d3d9_arcdps_table.dll"

# Path to backup locations for the previous versions
$arc_backup = Join-Path -Path $config.dll_backup_path -ChildPath "arc-d3d9.dll.back"
$templates_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_buildtemplates.dll.back"
$table_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_table.dll.back"
$extras_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_extras.dll.back"
$table_backup = Join-Path -Path $config.dll_backup_path -ChildPath "extension-d3d9_arcdps_table.dll.back"

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
# URL for the table plugin for Arc DPS
$table_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll"
# URL for the MD5 sum of the table dll
$table_md5_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll.md5sum"
# URL for the table plugin for Arc DPS
$table_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll"
# URL for the MD5 sum of the table dll
$table_md5_url = "http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll.md5sum"

if ($config.experimental_arcdps -eq $true) {
    $experimental_arc_url =  "https://www.deltaconnected.com/arcdps/dev/d3d9.dll"

    $experimental_templates_url = "https://www.deltaconnected.com/arcdps/dev/d3d9_arcdps_buildtemplates.dll"

    $experimental_extras_url = "https://www.deltaconnected.com/arcdps/dev/d3d9_arcdps_extras.dll"

    # Check if the experimental d3d9.dll exists right now
    try {
        Invoke-WebRequest -URI $experimental_arc_url -UseBasicParsing -Method head

        $arc_url = $experimental_arc_url
        # The experimental build doesn't have an md5sum file currently. :(
        $arc_md5_url = $null
    } catch [System.net.WebException] {
        if ($_.Exception.Response.StatusCode -eq "NotFound") {
            Write-Host "No experimental version available. Downloading regular arcdps release"
        } else {
            throw $_.Exception
        }
    }

    # Check if the experimental templates exists right now
    try {
        Invoke-WebRequest -URI $experimental_templates_url -UseBasicParsing -Method head

        $templates_url = $experimental_templates_url
    } catch [System.net.WebException] {
        if ($_.Exception.Response.StatusCode -eq "NotFound") {
            Write-Host "No experimental version available. Downloading regular templates release"
        } else {
            throw $_.Exception
        }
    }

    # Check if the experimental extras exists right now
    try {
        Invoke-WebRequest -URI $experimental_extras_url -UseBasicParsing -Method head

        $extras_url = $experimental_extras_url
    } catch [System.net.WebException] {
        if ($_.Exception.Response.StatusCode -eq "NotFound") {
            Write-Host "No experimental extras version available. Downloading regular extras release"
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
Write-Host "Checking d3d9_arcdps_table.dll MD5 Hash for changes"
if (X-Test-Path $table_path) {
    $current_md5 = (Get-FileHash $table_path -Algorithm MD5).Hash
    Write-Host "table: Current MD5 Hash: $current_md5"
    $web_md5 = Invoke-WebRequest -URI $table_md5_url -UseBasicParsing
    # file is just the md5sum, without a filename
    $web_md5 = $web_md5.toString().trim().toUpper()
    Write-Host "table: Online MD5 Hash:  $web_md5"

    if ($current_md5 -ne $web_md5) {
        $run_update = $true
    }
} else {
    $run_update = $true
}

if ($run_update -eq $false) {
    Write-Host "Current d3d9_arcdps_table.dll version is up to date"
} else {
    # If we have a copy of the table dll, make a new backup before overwriting
    if (X-Test-Path $table_path) {
        if (X-Test-Path $table_backup) {
            Remove-Item $table_backup
        }
        Move-Item $table_path $table_backup
    }

    # Remove the copy in bin64 as well
    if (X-Test-Path $table_bin_path) {
        Remove-Item $table_bin_path
    }

    Write-Host "Downloading new d3d9_arcdps_table.dll"
    Invoke-WebRequest -Uri $table_url -UseBasicParsing -OutFile $table_path
    Copy-Item $table_path $table_bin_path
}

$run_update = $false
Write-Host "Checking d3d9_arcdps_table.dll MD5 Hash for changes"
if (X-Test-Path $table_path) {
    $current_md5 = (Get-FileHash $table_path -Algorithm MD5).Hash
    Write-Host "table: Current MD5 Hash: $current_md5"
    $web_md5 = Invoke-WebRequest -URI $table_md5_url -UseBasicParsing
    # file is just the md5sum, without a filename
    $web_md5 = $web_md5.toString().trim().toUpper()
    Write-Host "table: Online MD5 Hash:  $web_md5"

    if ($current_md5 -ne $web_md5) {
        $run_update = $true
    }
} else {
    $run_update = $true
}

if ($run_update -eq $false) {
    Write-Host "Current d3d9_arcdps_table.dll version is up to date"
} else {
    # If we have a copy of the table dll, make a new backup before overwriting
    if (X-Test-Path $table_path) {
        if (X-Test-Path $table_backup) {
            Remove-Item $table_backup
        }
        Move-Item $table_path $table_backup
    }

    # Remove the copy in bin64 as well
    if (X-Test-Path $table_bin_path) {
        Remove-Item $table_bin_path
    }

    Write-Host "Downloading new d3d9_arcdps_table.dll"
    Invoke-WebRequest -Uri $table_url -UseBasicParsing -OutFile $table_path
    Copy-Item $table_path $table_bin_path
}
# SIG # Begin signature block
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWiApjup1/JLWHbnTv3Vbim+f
# mKagggMYMIIDFDCCAfygAwIBAgIQLNFTiNzlwrtPtvlsLl9i3DANBgkqhkiG9w0B
# AQsFADAiMSAwHgYDVQQDDBdMMEctMTAxMDg2IENvZGUgU2lnbmluZzAeFw0xOTA1
# MTEwNjIxMjNaFw0yMDA1MTEwNjQxMjNaMCIxIDAeBgNVBAMMF0wwRy0xMDEwODYg
# Q29kZSBTaWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz8yX
# +U/I8mljHGNNqj3Yu5m41ibtP7vXqhoFF16AWFMVI26sCFknvKO95h8ByCyyrSJy
# KouRR+bLwYg/a8ElqBA3r3nvnefWzFuj19lYoChautae6n1Yg80/V5XuY9tXjXRs
# LLA+rDCJBDTtku0Y7ahk5KOGwnqxY520BKt8A/MOD3mQnUtxZ88C7Otr4jr+2k9k
# CM7oMD1jJsmFpZxaDinsPiYobs/NRJ4iAlTN+NgwmHrj+Tgpln5GHhCpncUbZ530
# ODbndMwYkW3T7JECjxZYLg4B6CzXFw+SDewIq0svCnIBa+NQYHzNvdwJU5xlTdG+
# n3RSRT0N1UgrUnQ/OQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwHQYDVR0OBBYEFL0r6+kPYUrlpu8rKWwyrLWuc3zNMA0GCSqG
# SIb3DQEBCwUAA4IBAQADr9YRypADuVVOiwbrKYT5GLBa+1wbDHdC9YRWf+kGtKYC
# K4RsIgCngakR6MmksUhNgYRBN6pD4qTOgkUEfxmpLSjTyEYkcslF/Y5sBwiVRqS2
# p38Ay5byGfRRb/KbjndE7vEM0DJg3XWbayiiARhe6Af0FXgg0F7n5AblnZrUuE1x
# 62I5N3lSsH8xjF8BcvtSh+jhDypIBAjyNMwzPvO8hGMoqrpNY5IjvBWrHPGzrm90
# Jju/ucR3d14J6MwoCxcisupXdRhkIE9c4MiW67tf019h4TBnUNzW8DWyoprKAIRV
# qjO6XExzBeHTPOH8olN/oYaOmqUC9c9MEolbolhRMYIB1zCCAdMCAQEwNjAiMSAw
# HgYDVQQDDBdMMEctMTAxMDg2IENvZGUgU2lnbmluZwIQLNFTiNzlwrtPtvlsLl9i
# 3DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQUxkXRObktx05JZCSSdbBmUCB+pXUwDQYJKoZIhvcN
# AQEBBQAEggEAY3usW8tygjm2xUOQlkxeLyICZuNQ21h2adfPps231rA92oBeDUZK
# 8ZK7U5mBXMxlPPJlpeWdr2mWLGi/qaj000tDpG3/ILLfhZqxJr88Qu4S54QosmUU
# tYUbVmBtL3TG6Jmc6iTzvPuKgmoDiutfW3fiq4+SD4iNZJG3cKFf6AqLRwJarnKx
# 8ilnPOeHnfvHDc43mw4w307IpAz36llVPKjVVONPXq1tvAu3U7w6TP11nDjHjSL2
# m/V1w/P2aALDnxkVMTN61YFGLx2PaXg1KXTKeTVwcXLvfjJ/rUKsLT46uuJ1e5VW
# XDv/vrzGVc9iHGhAnBIQm/1fodf4sFOHyg==
# SIG # End signature block
