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
    "restsharp_path"
    "simple_arc_parse_path"
    "last_upload_file"
    "arcdps_logs"
    "upload_log_file"
    "guilds"
)

# Load the configuration from the default file (version 2)
$config = Load-Configuration (Get-Config-File) 2 $RequiredParameters
if (-not $config) {
    exit
}

# Load relevant configuration variables
$last_upload_file = $config.last_upload_file
$arcdps_logs = $config.arcdps_logs

Set-Logfile $config.upload_log_file

# Simple storage format for extra ancillary data about uploaded files
$extra_upload_data = $config.extra_upload_data
$simple_arc_parse = $config.simple_arc_parse_path

# Determine what generator to use
$valid_generators = @( "rh", "ei" )
$dps_report_generator = $config.dps_report_generator.Trim()
if ($dps_report_generator -and -not $valid_generators.Contains($dps_report_generator)) {
    Read-Host -Prompt "The dps.report generator $dps_report_generator is unknown..."
    exit
}

# Make sure RestSharp.dll exists
if (-not (X-Test-Path $config.restsharp_path)) {
    Read-Host -Prompt "The RestSharp.dll is expected to be located at '$($config.restsharp_path)', but doesn't appear to exist. Please download RestSharp.dll and update the configuration. Press enter to exit"
    exit
}

# Make sure that simpleArcParse has been correctly generated
if (-not (X-Test-Path $simple_arc_parse)) {
    Read-Host -Prompt "simpleArcParse is expected to be located at '${simple_arc_parse}', but doesn't appear to exist. Please download simpleArcParse and update the configuration. Press enter to exit"
    exit
}

# Make sure that the arcdps_logs folder exists
if (-not (X-Test-Path $arcdps_logs)) {
    Read-Host -Prompt "The arcdps.cbtlogs folder is expected to be located at '${arcdps_logs}', but doesn't appear to exist. Please update the configuration. Press enter to exit."
    exit
}

# Require a dps.report token if dps.report uploading is enabled
if ((-not $config.dps_report_token) -and ($config.upload_dps_report -ne "no")) {
    Read-Host -Prompt "Uploading to dps.report requires an authentication token. Press enter to exit"
    exit
}

# Create the startmap directory if it doesn't exist
if (-not $extra_upload_data) {
    Read-Host -Prompt "A folder to hold extra upload data must be configured. Press enter to exit"
} elseif (-not (X-Test-Path $extra_upload_data)) {
    try {
        New-Item -ItemType directory -Path $extra_upload_data
    } catch {
        Write-Exception $_
        Read-Host -Prompt "Unable to create $extra_upload_data. Press enter to exit."
        exit
    }
}

try {
    $simple_arc_version = (& $simple_arc_parse version)
} catch {
    Write-Exception $_
    Log-And-Write-Output "Unable to run simpleArcParse at '${simple_arc_parse}'"
    Log-And-Write-Output "Is it possible that antivirus software is interfering?"
    Read-Host -Prompt "Press enter to exit"
}

# Make sure that simpleArcParse version matches our expectation
if (-not (Check-SimpleArcParse-Version $simple_arc_version)) {
    Read-Host -Prompt "Press enter to exit"
    exit
}

Add-Type -Path $config.restsharp_path
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

# Determine the most recent release of ArcDPS
$arcdps_headers = (Invoke-WebRequest -UseBasicParsing -Uri https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum).Headers
$arcdps_release_date = (Get-Date -Date ($arcdps_headers['Last-Modified'])).Date

# The last upload file indicates the last time that we uploaded files. If this
# file is missing, we might attempt to upload every encounter file that the
# user has. This can lead to accidentally uploading hundreds of files.
# Prevent this by pretending that the last upload was a reasonably recent
# time ago instead.
if (Test-Path $last_upload_file) {
    $last_upload_time = Get-Content -Raw -Path $last_upload_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
} else {
    $last_upload_time = Convert-Approxidate-String $config.initial_last_event_time
}

$files = @(Get-ChildItem -Recurse -File -LiteralPath $arcdps_logs | Where-Object { ( ExtensionIs-EVTC $_.Name ) -and $_.LastWriteTime -gt $last_upload_time} | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})

$next_upload_time = Get-Date
Log-Output "~~~"
Log-Output "Uploading arcdps logs at $next_upload_time..."
Log-Output "~~~"

$total = $files.Length
$done = 0

if ($total -gt 0 ) {
    Log-And-Write-Output "Found ${total} EVTC files to upload"
}

$failed_uploads = [System.Collections.ArrayList]@()

# Main loop to generate and upload logs to dps.report
ForEach($f in $files) {
    $done++
    $name = Get-UncompressedEVTC-Name $f
    Log-Output "---"
    Log-And-Write-Output "(${done}/${total}) Saving ancillary data for ${name}..."

    $dir = Join-Path -Path $extra_upload_data -ChildPath $name
    if (X-Test-Path $dir) {
        Log-Output "Ancillary data appears to have already been created"
        If (-not (Test-Path -PathType Container -Path $dir)) {
            Log-And-Write-Output "Ancillary data path '$dir' is not a directory?"
            Log-And-Write-Output "Please move or delete '$dir' and try again."
            Write-Output "Unable to process '$dir'. See log file for more details"
            Read-Host -Prompt "Press enter to exit..."
            exit
        }
        Log-Output "Overwriting..."
        Remove-Item -Recurse -Force $dir
    }

    # Make the ancillary data directory
    try {
        New-Item -ItemType Directory -Path $dir
    } catch {
        Write-Exception $_
        Log-And-Write-Output "Unable to create extra upload directory '$dir'"
        Read-Host -Prompt "Unable to process ${f}... Press enter to exit..."
        exit
    }

    if (ExtensionIs-CompressedEVTC $f) {
        # simpleArcParse cannot deal with compressed data, so we must uncompress
        # it first, before passing the file to the simpleArcParse program
        [io.compression.zipfile]::ExtractToDirectory($f, $dir) | Out-Null
        $evtc = Join-Path -Path $dir -ChildPath $name

        # Sometimes the zip file stores the uncompressed file suffixed with .tmp
        if (-not (X-Test-Path $evtc)) {
            $evtc = Join-Path -Path $dir -ChildPath "${name}.tmp"
        }

        # Sometimes the zip file stores the uncompressed file without the .evtc
        if (-not (X-Test-Path $evtc)) {
            $evtc = Join-Path -Path $dir -ChildPath ([io.fileinfo]$name).basename
        }

        if (-not (X-Test-Path $evtc)) {
            throw "${evtc} is compressed, but does not appear to contain the correct contents"
        }
    } else {
        # if the file was not compressed originally, we don't need to copy it
        $evtc = $f
    }

    # Track encounter success
    $success = $false

    try {
        # Save the path to the original evtc file
        $f | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "evtc.json")

        $evtc_json = (& ${simple_arc_parse} json "${evtc}")
        $evtc_info = $evtc_json | ConvertFrom-Json

        if ([string]::IsNullOrEmpty($evtc_json)) {
            throw "${evtc} is not recognized as a valid .evtc file by simpleArcParse."
        }

        $evtc_info = $evtc_json | ConvertFrom-Json

        # Determine the ArcDPS release date of this encounter
        try {
            $evtc_arcdps_version = [DateTime]::ParseExact($evtc_info.header.arcdps_version, 'EVTCyyyyMMdd', $null)

            # Notify the user about when trying to upload encounters with
            # old versions of arcdps.
            if ($evtc_arcdps_version -lt $arcdps_release_date) {
                Log-Output "It appears that ${name} was recorded using an outdated ArcDPS version released on $(Get-Date -Format "MMM d, yyyy" $evtc_arcdps_version)"
                Log-Output "The most recent ArcDPS version was releasted on $(Get-Date -Format "MMM d, yyyy" $arcdps_release_date)"
            }
        } catch {
            Write-Exception $_
            Log-Output "Unable to determine the ArcDPS version used to record ${name}"
            Log-Output "EVTC ArcDPS version was '$evtc_arcdps_version'"
            Log-Output "EVTC header was '$evtc_header'"
            Log-Output "ArcDPS release date was '$arcdps_release_date'"
        }

        # Extract the accounts
        $accounts = $evtc_info.players | select -ExpandProperty account
        $boss_id = $evtc_info.boss.id

        # Determine the guild to associate with this encounter
        $guild = Determine-Guild $config.guilds $accounts $boss_id
        if (-not $guild) {
            Log-Output "No guild information matched ${f}."
        } else {
            $evtc_info | Add-Member -Name "guild" -Value $guild -MemberType NoteProperty
            Log-Output "Guild: ${guild}"
        }
        Log-Output "EVTC Version: $($evtc_info.header.arcdps_version)"
        Log-Output "Encounter: $($evtc_info.boss.name)"
        Log-Output "ID: $($evtc_info.boss.id)"

        $success = $evtc_info.boss.success
        if ($evtc_info.boss.success) {
            Log-Output "Outcome: SUCCESS"
        } else {
            Log-Output "Outcome: FAILURE"
        }

        Log-Output "Start Time: $($evtc_info.server_time.start)"

        Log-Output "Challenge Mote: $($evtc_info.boss.is_cm)"

        $evtc_info | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "evtc_info.json")
    } catch {
        Write-Exception $_

        # Remove the extra data for this object
        Remove-Item -Path $dir -Recurse

        # If we failed to parse an encounter, it is likely due to either data corruption such as invalid
        # evtc files being generated, or because the evtc file format has changed. Stop processing immediately
        # so that the user can verify what is wrong, and intervene.
        Read-Host -Prompt "Unable to process ${f}... Press enter to exit..."
        exit
    } finally {
        # If the file was originally compressed, there's no need to keep around the uncompressed copy
        if ($f -ne $evtc -and (Test-Path $evtc)) {
            Remove-Item -Path $evtc
        }
    }

    # upload to dps.report
    try {
        Maybe-UploadTo-DpsReport $config $f $dir $success
    } catch {
        Log-And-Write-Output "Upload to dps.report failed..."

        # Update the last write time so that this file will be postponed until our next upload attempt.
        (Get-Item $f).LastWriteTime = (Get-Date)

        $failed_uploads.Add($f)
    }
}

# Save the current time as
$next_upload_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $last_upload_file

if ($failed_uploads.Count -gt 0) {
    Log-And-Write-Output "The following log files failed to upload to dps.report:"


    # Log all of the failed uploads
    ForEach ($f in $failed_uploads) {
        Log-And-Write-Output "* ${f}"
    }

    Log-And-Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    Log-And-Write-Output "This may require further inspection"
    Log-And-Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    Read-Host -Prompt "Press enter to exit."
    exit
}

# SIG # Begin signature block
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAF7/2RPpDC6dWe4KepltltJd
# bZSgggMYMIIDFDCCAfygAwIBAgIQLNFTiNzlwrtPtvlsLl9i3DANBgkqhkiG9w0B
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
# FTAjBgkqhkiG9w0BCQQxFgQUbHPTieu/eY/sL+Tp4DhMOOp/e+4wDQYJKoZIhvcN
# AQEBBQAEggEAGaUxahayAoiXTu/VSzdhJNZdHTZy4Ce0Z5wDfE2ct9IaVNHEuwlz
# PkVR85ol5GPLNwG8VegXqCh8M7NwqcDhA9iMV86ThY4c+H2S2JW82GAGhlsUCoY2
# bXCl9SxU8syxwH5Ty812WpAXO6LrqhAvCVAvnuPpBLh1NdkOlTzHuGTk3N/XA3AV
# /xkWZaMWjCPJ3CMKwHsVuWmk1NgNHWn7bhyxPn9ttzhOGcctW6Hw4JHg2AXifXZN
# TK2gwpJlT6KgzMgsV4aACsFF9aPx+1KpUus9V8bQVNkLz+zYUVoP49qSHoLkeRj7
# 9JXbXKtZ4h+2O28BjhEVK8fbahfDIbFlTQ==
# SIG # End signature block
