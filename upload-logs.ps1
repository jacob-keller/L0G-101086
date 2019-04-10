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
        Write-Exception $_
        Log-Output "Upload to dps.report failed..."

        # The set of files is sorted in ascending order by its last write time. This
        # means, if we exit at the first failed file, that all files with an upload time prior
        # to this file must have succeeded. Thus, we'll save the "last upload time" as the
        # last update time of this file minus a little bit to ensure we attempt re-uploading it
        # on the next run. This avoids re-uploading lots of files if we fail in the middle of
        # a large sequence.
        (Get-Item $f).LastWriteTime.AddSeconds(-1) | Select-Object -Property DateTime | ConvertTo-Json | Out-File -Force $last_upload_file
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-Output "Upload to dps.report failed"
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Read-Host -Prompt "Press enter to exit."
        exit
    }
}

# Save the current time as
$next_upload_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $last_upload_file
# SIG # Begin signature block
# MIIFZAYJKoZIhvcNAQcCoIIFVTCCBVECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6HIKMYt8oQr9iwwnNEMBgH5K
# H1qgggMCMIIC/jCCAeagAwIBAgIQFFuA0ERIe5ZFRAzvqUXg0TANBgkqhkiG9w0B
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUMZKUixdrxSYV9PCJ8MRY
# jAvwKKAwDQYJKoZIhvcNAQEBBQAEggEAWnK2CbUy4sWd1WVRnRcgfVxzHppn4Mxs
# S9PEMKMfCj6gvWvDR656x1jk1nqRUJfqHtMspRbyXp8AA8/SPB6QA1Y/s26RAxg4
# WDyLqkGBsQFD6oe6b4ErtarE23dzGmYoW/vAqkoxOgb2KAnRSSv9JSKflNDjbCcx
# PRMaBJgyFrV50Kv31He6g7wOmjjCOLuujcScbW9Tz7zChh/fbTmEC29ge6zkJOR8
# agpqLZVZQm9RfCLmG1vNGCVtXPR2Qn5QNQ9FNIMAzWqu7rdW2GAB74ESzLz8C/++
# nbAaC9hG1iMAkO+kbWGIii5HZmDQd9G8DZj6iXQ5GBWVBVcbCfojQA==
# SIG # End signature block
