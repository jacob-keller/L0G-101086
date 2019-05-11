# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

Set-Logfile "update-arcdps.log"

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

$files = @(
    @{
        dll = 'd3d9.dll'
        backup = 'arc-d3d9.dll.back'
        url = 'https://www.deltaconnected.com/arcdps/x64/d3d9.dll'
        md5_url = 'https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum'
    },
    @{
        dll = 'd3d9_arcdps_extras.dll'
        backup = 'extension-d3d9_arcdps_extras.dll.back'
        url = 'https://www.deltaconnected.com/arcdps/x64/extras/d3d9_arcdps_extras.dll'
        updatewith = 'ArcDPS'
    },
    @{
        dll = 'd3d9_arcdps_buildtemplates.dll'
        backup = 'extension-d3d9_arcdps_buildtemplates.dll.back'
        url = 'https://www.deltaconnected.com/arcdps/x64/buildtemplates/d3d9_arcdps_buildtemplates.dll'
        updatewith = 'ArcDPS'
    },
    @{
        dll = 'd3d9_arcdps_mechanics.dll'
        backup = 'extension-d3d9_arcdps_mechanics.dll.back'
        url = 'http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll'
        md5_url = 'http://martionlabs.com/wp-content/uploads/d3d9_arcdps_mechanics.dll.md5sum'
    },
    @{
        dll = 'd3d9_arcdps_table.dll'
        backup = 'extension-d3d9_arcdps_table.dll.back'
        url = 'http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll'
        md5_url = 'http://martionlabs.com/wp-content/uploads/d3d9_arcdps_table.dll.md5sum'
    }
)

Log-And-Write-Output "Checking for updates..."

# First, check to see what we should update in a loop. Because the ArcDs
# extras and buildtemplates plugins do not have their own MD5 sum file,
# this must be done up front before we loop to actually download the file
ForEach ($f in $files) {
    $f.full_path = [io.path]::combine($config.guildwars2_path, $f.dll)
    $f.bin_path = [io.path]::combine($config.guildwars2_path, "bin64", $f.dll)
    $f.backup_path = [io.path]::combine($config.dll_backup_path, $f.backup)

    if (-not (X-Test-Path $f.full_path)) {
        Log-And-Write-Output "$($f.dll): not yet downloaded"
        $f.update = $true
        continue
    }

    # Some of the extensions don't have their own MD5 hash file
    if (-not $f.md5_url) {
        continue
    }

    $current_md5 = (Get-FileHash $f.full_path -Algorithm MD5).Hash
    $web_md5 = ((Invoke-WebRequest -URI $f.md5_url -UseBasicParsing).toString().trim().toUpper() -split '\s+')[0]

    Log-And-Write-Output "$($f.dll): Current MD5 Sum -- $current_md5"
    Log-And-Write-Output "$($f.dll): Latest MD5 Sum -- $web_md5"

    if ($web_md5.StartsWith($current_md5)) {
        Log-And-Write-Output "$($f.dll): up to date"
    } else {
        Log-And-Write-Output "$($f.dll): needs to be updated"
        $f.update = $true

        ForEach ($child in $files.where($_.updatewith -eq $f.dll)) {
            Log-And-Write-Output "$($child.dll): needs to be updated"
            $child.update = $true
        }
    }
}

ForEach ($f in $files.where{$_.update -eq $true}) {
    Log-And-Write-Output "$($f.dll): downloading new copy"

    # Make a back up of the current dll before overwriting it
    if (X-Test-Path $f.full_path) {
        if (X-Test-Path $f.backup_path) {
            Remove-Item $f.backup_path
        }
        Move-Item $f.full_path $f.backup_path
    }

    # Remove the bin64 copy
    if (X-Test-Path $f.bin_path) {
        Remove-Item $f.bin_path
    }

    Invoke-WebRequest -Uri $f.url -UseBasicParsing -OutFile $f.full_path
    Copy-Item $f.full_path $f.bin_path
}

# SIG # Begin signature block
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/WHtgB76zfLP5NhL9xqB27Es
# B1agggMYMIIDFDCCAfygAwIBAgIQLNFTiNzlwrtPtvlsLl9i3DANBgkqhkiG9w0B
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
# FTAjBgkqhkiG9w0BCQQxFgQUSpaI1Glwsi6nMUUFbYnVfoNpvIUwDQYJKoZIhvcN
# AQEBBQAEggEAXnv+srr12zs63NEO8p1Y4xO3Ohji05GXE0fuCce6VL9HPjHmH74k
# s3Bo9406awZ/23wRrv+Pm2cJY7Z7CQcrlb/Va/emPHL4SSgyCSbMSgx0yRMCQOkq
# UR/SpQuUGA3/Yme0+FFmtCQA/Ooof1Qxfxu1MElbCsrlKllmbYeF16KOmqUnKVHi
# BDBKSb7Jz791G6ANh2u1+wSPS61bLVOS1kSTpxfMsle4MQ20CD3rF3ledpgIAywo
# QsjZV1Dh6RYmgNmeu3NlDvHlU/DDCBTLoOZGewmsWBmagZe5LDuo+fGdf9aGBurI
# 2Di8/puLnOWgKTYYHYC34egYid32OpeuqA==
# SIG # End signature block
