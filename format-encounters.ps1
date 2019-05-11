# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# See l0g-101086.psm1 for descriptions of each configuration field
$RequiredParameters = @(
    "extra_upload_data"
    "last_format_file"
    "format_encounters_log"
    "arcdps_logs"
    "guilds"
)

# Load the configuration from the default file
$config = Load-Configuration (Get-Config-File) 2 $RequiredParameters
if (-not $config) {
    exit
}

Set-Logfile $config.format_encounters_log

# Check that the ancillary data folder has already been created
if (-not (X-Test-Path $config.extra_upload_data)) {
    Read-Host -Prompt "The $($config.extra_upload_data) can't be found. Try running upload-logs.ps1 first? Press enter to exit"
    exit
}

if (-not $config.discord_json_data) {
    Read-Host -Prompt "The discord JSON data directory must be configured. Press enter to exit"
    exit
} elseif (-not (X-Test-Path $config.discord_json_data)) {
    try {
        New-Item -ItemType directory -Path $config.discord_json_data
    } catch {
        Write-Exception $_
        Read-Host -Prompt "Unable to create $($config.discord_json_data). Press enter to exit"
        exit
    }
}

if (-not $config.last_format_file) {
    Read-Host -Prompt "A file to store last format time must be configured. Press enter to exit"
    exit
} elseif (-not (X-Test-Path (Split-Path $config.last_format_file))) {
    Read-Host -Prompt "The path for the last_format_file appears invalid. Press enter to exit"
    exit
}

Log-Output "~~~"
Log-Output "Formatting encounters for discord at $(Get-Date)..."
Log-Output "~~~"

# Load the last format time. If there is no file, such as the first run,
# limit the search to a reasonable default based on the initial_last_event_time.
if (X-Test-Path $config.last_format_file) {
    $last_format_time = Get-Content -Raw -Path $config.last_format_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
} else {
    $last_format_time = Convert-Approxidate-String $config.initial_last_event_time
}

$next_format_time = Get-Date

# Search the extras directory for all EVTC directories with a time newer than the last format time.
$dirs = @(Get-ChildItem -Directory -Filter "*.evtc" -LiteralPath $config.extra_upload_data | Where-Object { $_.CreationTime -gt $last_format_time} | Sort-Object -Property CreationTime | ForEach-Object {$_.Name})

if ($dirs -and $dirs.Length -gt 0) {
    Log-And-Write-Output "Found $($dirs.Length) EVTC files to format and post"

    # Load each of the evtc directories as a boss hash table
    $bosses = @()
    foreach($d in $dirs) {
        $bosses += @(Load-From-EVTC $config $d)
    }

    Format-And-Publish-All $config $bosses
}

# Update the format time
$next_format_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $config.last_format_file
# SIG # Begin signature block
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJhrAhi3EeRXz5dqCzF0OfPZ0
# +digggMYMIIDFDCCAfygAwIBAgIQLNFTiNzlwrtPtvlsLl9i3DANBgkqhkiG9w0B
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
# FTAjBgkqhkiG9w0BCQQxFgQUm5GQpg6R79kXKPiPdpkv8z0dnWQwDQYJKoZIhvcN
# AQEBBQAEggEAzm+W/lBZ49b3KbBgIo0JC/RH5s/txB7CAWwiedhw92TVYkDKADJE
# /nv2loGGwk8wrykhR27OVf43Pwp4zrkxKHSNMv6xar29F1LSTvfJRF9t7KUOXP6K
# KbX+uGtjTAAaDnZLRfRenpncz4XxGqfs15c1lBpNQFAOBgCF86VPNNMkZDbeb3fa
# 3MFtn0OscS1NR8Gns6ZZPooTgc4nXGCehyXG6d6xQlQMWkUQVfj+iR/Kl4Hc36BD
# WDYB5WmHAzkFSku9bR68VR9qGc/ojJkR820X6G7PhpscMnUliggY4eAKWk1bETaX
# BHLNob/dWYaOs2hV8mUweQbuYD01RAGeKA==
# SIG # End signature block
