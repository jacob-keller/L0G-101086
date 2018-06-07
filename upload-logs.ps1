# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# See l0g-101086.psm1 for descriptions of each configuration field
$RequiredParameters = @(
    "extra_upload_data"
    "gw2raidar_start_map"
    "restsharp_path"
    "simple_arc_parse_path"
    "last_upload_file"
    "arcdps_logs"
    "upload_log_file"
    "gw2raidar_token"
    "dps_report_token"
    "guilds"
)

# Load the configuration from the default file (version 2)
$config = Load-Configuration "l0g-101086-config.json" 2 $RequiredParameters
if (-not $config) {
    exit
}

# Load relevant configuration variables
$last_upload_file = $config.last_upload_file
$arcdps_logs = $config.arcdps_logs
$gw2raidar_token = $config.gw2raidar_token
$dpsreport_token = $config.dps_report_token
$logfile = $config.upload_log_file

# Simple storage format for extra ancillary data about uploaded files
$extra_upload_data = $config.extra_upload_data
$gw2raidar_start_map = $config.gw2raidar_start_map
$simple_arc_parse = $config.simple_arc_parse_path

# Make sure RestSharp.dll exists
if (-not (X-Test-Path $config.restsharp_path)) {
    Read-Host -Prompt "This script requires RestSharp to be installed. Press enter to exit"
    exit
}

# Make sure that simpleArcParse has been correctly generated
if (-not (X-Test-Path $simple_arc_parse)) {
    Read-Host -Prompt "simpleArcParse must be installed for this script to work. Press enter to exit"
    exit
}

# Make sure that the arcdps_logs folder exists
if (-not (X-Test-Path $arcdps_logs)) {
    Read-Host -Prompt "Can't locate $arcdp_logs. Press enter to exit."
    exit
}

# We absolutely require a gw2raidar token
if (-not $config.gw2raidar_token) {
    Read-Host -Prompt "This script requires a gw2raidar authentication token. Press enter to exit"
    exit
}

# Require a dps.report token
if (-not $config.dps_report_token) {
    Read-Host -Prompt "This script requires a dps.report authentication token. Press enter to exit"
    exit
}

# Create the startmap directory if it doesn't exist
if (-not $gw2raidar_start_map) {
    Read-Host -Prompt "A gw2raidar start map directory must be configured. Press enter to exit"
    exit
} elseif (-not (X-Test-Path $gw2raidar_start_map)) {
    try {
        New-Item -ItemType directory -Path $gw2raidar_start_map
    } catch {
        Read-Host -Prompt "Unable to create $gw2raidar_start_map. Press enter to exit"
        exit
    }
}

# Create the startmap directory if it doesn't exist
if (-not $extra_upload_data) {
    Read-Host -Prompt "A folder to hold extra upload data must be configured. Press enter to exit"
} elseif (-not (X-Test-Path $extra_upload_data)) {
    try {
        New-Item -ItemType directory -Path $extra_upload_data
    } catch {
        Read-Host -Prompt "Unable to create $extra_upload_data. Press enter to exit."
        exit
    }
}

# Make sure that simpleArcParse version matches our expectation
$expected_simple_arc_version = "v0.12"
$simple_arc_version = (& $simple_arc_parse version)
if ($simple_arc_version -eq "") {
    Write-Host "Unable to determine the version of simpleArcParse"
    Read-Host -Prompt "Please use version ${expected_simple_arc_version}. Press enter to exit"
    exit
} elseif ($simple_arc_version -ne $expected_simple_arc_version) {
    Write-Host "simpleArcParse version ${simple_arc_version} is not compatible with this script"
    Read-Host -Prompt "Please use version ${expected_simple_arc_version} instead. Press enter to exit"
    exit
}

$gw2raidar_url = "https://www.gw2raidar.com"
$dpsreport_url = "https://dps.report"

Add-Type -Path $config.restsharp_path
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

function Log-Output ($string) {
    if ($config.debug_mode) {
        Write-Output $string
    } else {
        Write-Output $string | Out-File -Append $logfile
    }
}

# Determine the most recent release of ArcDPS
$arcdps_headers = (Invoke-WebRequest -UseBasicParsing -Uri https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum).Headers
$arcdps_release_date = (Get-Date -Date ($arcdps_headers['Last-Modified'])).Date

# If we have a last upload file, we want to limit our scan to all files since
# the last time that we uploaded.
#
# This invocation is a bit complicated, but essentially we recurse through all folders within
# the $arcdps_logs directory and find all files which end in *.evtc.zip. We store them by the
# last write time, and then we return the full path of that file.
if (Test-Path $last_upload_file) {
    $last_upload_time = Get-Content -Raw -Path $last_upload_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
    $files = @(Get-ChildItem -Recurse -File -Include @(".evtc.zip", "*.evtc") -LiteralPath $arcdps_logs | Where-Object { $_.LastWriteTime -gt $last_upload_time} | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
} else {
    $files = @(Get-ChildItem -Recurse -File -Include @(".evtc.zip", "*.evtc") -LiteralPath $arcdps_logs | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
}

$next_upload_time = Get-Date
Log-Output "~~~"
Log-Output "Uploading arcdps logs at $next_upload_time..."
Log-Output "~~~"

# Main loop to generate and upload gw2raidar and dps.report files
ForEach($f in $files) {
    $name = [io.path]::GetFileNameWithoutExtension($f)
    Log-Output "Saving ancillary data for ${name}..."

    $dir = Join-Path -Path $extra_upload_data -ChildPath $name
    if (Test-Path -Path $dir) {
        Log-Output "Ancillary data appears to have already been created... Overwriting"
        Remove-Item -Recurse -Force $dir
    }

    # Make the ancillary data directory
    New-Item -ItemType Directory -Path $dir

    if ($f -Like "*.evtc.zip") {
        # simpleArcParse cannot deal with compressed data, so we must uncompress
        # it first, before passing the file to the simpleArcParse program
        [io.compression.zipfile]::ExtractToDirectory($f, $dir) | Out-Null
        $evtc = Join-Path -Path $dir -ChildPath $name
    } else {
        # if the file was not compressed originally, we don't need to copy it
        $evtc = $f
    }

    try {
        # Parse the evtc file and extract account names
        $player_data = (& $simple_arc_parse players "${evtc}")
        $players = $player_data.Split([Environment]::NewLine)

        # Parse the evtc header file and get the encounter name and id
        $evtc_header_data = (& $simple_arc_parse header "${evtc}")
        $evtc_header = ($evtc_header_data.Split([Environment]::NewLine))

        # Determine the ArcDPS release date of this encounter
        try {
            $evtc_arcpds_version = [DateTime]::ParseExact($evtc_header[0], 'EVTCyyyyMMdd', $null)

            # gw2raidar is extremely picky about uploading new encounters, and will generally
            # only parse the most recent release of ArcDPS. Warn the user if the version of
            # for this encounter is out of date. We'll still try to upload to gw2raidar, but
            # at least the user will be aware that the links may not be generated.
            if ($evtc_arcpds_version -lt $arcdps_release_date) {
                Log-Output "It appears that ${name} was recorded using an outdated ArcDPS version released on $(Get-Date -Format "MMM d, yyyy" $evtc_arcdps_version)"
                Log-Output "The most recent ArcDPS version was releasted on $(Get-Date -Format "MMM d, yyyy" $arcdps_release_date)"
                Log-Output "gw2raidar is unlikely to accept this encounter, so you might not see a link for it in the formatted encounters list"
                Log-Output "It is recommended that you update ArcDPS to avoid this issue."
            }
        } catch {
            Log-Output "$PSItem"
            Log-Output "Unable to determine the ArcDPS version used to record ${name}"
        }



        # Determine the guild to associate with this encounter
        $guild = Determine-Guild $config.guilds $players $evtc_header[2]
        if (-not $guild) {
            throw "No guilds matched this encounter"
        }

        $guild | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "guild.json")

        $players | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "accounts.json")

        $evtc_header[0] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "version.json")
        $evtc_header[1] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "encounter.json")
        $evtc_header[2] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "id.json")

        # Parse the evtc combat events to determine SUCCESS/FAILURE status
        $evtc_success = (& $simple_arc_parse success "${evtc}")
        $evtc_success | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "success.json")

        # Parse the evtc combat events to determine the server start time
        $start_time = (& $simple_arc_parse start_time "${evtc}")
        $start_time | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "servertime.json")

        # Generate a map between start time and the evtc file name
        $map_dir = Join-Path -Path $gw2raidar_start_map -ChildPath $start_time
        if (Test-Path -Path $map_dir) {
            $recorded_name = Get-Content -Raw -Path (Join-Path -Path $map_dir -ChildPath "evtc.json") | ConvertFrom-Json
            if ($recorded_name -ne $name) {
                Log-Output "$recorded_name was already mapped to this start time...!"
            }
        } else {
            # Make the mapping directory
            New-Item -ItemType Directory -Path $map_dir

            $name | ConvertTo-Json | Out-File -FilePath (Join-Path $map_dir -ChildPath "evtc.json")
        }
    } catch {
        Log-Output "$PSItem"

        # Remove the extra data for this object
        Remove-Item -Path $dir -Recurse

        # Don't upload this encounter
        continue
    } finally {
        # If the file was originally compressed, there's no need to keep around the uncompressed copy
        if ($f -ne $evtc -and (Test-Path $evtc)) {
            Remove-Item -Path $evtc
        }
    }

    # First, upload to gw2raidar, because it returns immediately and processes in the background
    Log-Output "Uploading ${name} to gw2raidar..."
    try {
        $client = New-Object RestSharp.RestClient($gw2raidar_url)
        $req = New-Object RestSharp.RestRequest("/api/v2/encounters/new")
        $req.AddHeader("Authorization", "Token $gw2raidar_token") | Out-Null
        $req.Method = [RestSharp.Method]::PUT

        $req.AddFile("file", $f) | Out-Null

        # Determine the tag used to upload
        $tag = $config.guilds | where { $_.name -eq $guild } | ForEach-Object { $_.gw2raidar_tag }
        $category = $config.guilds | where { $_.name -eq $guild } | ForEach-Object { $_.gw2raidar_category }

        $req.AddParameter("tags", $tag) | Out-Null
        $req.AddParameter("category", $category) | Out-Null

        $resp = $client.Execute($req)

        if ($resp.ResponseStatus -ne [RestSharp.ResponseStatus]::Completed) {
            throw "Request was not completed"
        }

        if ($resp.StatusCode -ne "OK") {
            Log-Output $resp.Content
            throw "Request failed with status $resp.StatusCode"
        }

        # Store the response data so we can use it in potential future gw2raidar APIs
        $resp.Content | Out-File -FilePath (Join-Path $dir -ChildPath "gw2raidar.json")

        Log-Output "Upload successful..."
    } catch {
        Log-Output $_.Exception.Message
        Log-Output "Upload to gw2raidar failed..."

        # The set of files is sorted in ascending order by its last write time. This
        # means, if we exit at the first failed file, that all files with an upload time prior
        # to this file must have succeeded. Thus, we'll save the "last upload time" as the
        # last update time of this file minus a little bit to ensure we attempt re-uploading it
        # on the next run. This avoids re-uploading lots of files if we fail in the middle of
        # a large sequence.
        (Get-Item $f).LastWriteTime.AddSeconds(-1) | Select-Object -Property DateTime | ConvertTo-Json | Out-File -Force $last_upload_file
        exit
    }

    # We opted to only upload successful logs to dps.report, but all logs to gw2raidar.
    # You could remove this code if you want dps.report links for all encounters.
    $status = Get-Content -Raw -Path (Join-Path -Path $dir -ChildPath "success.json") | ConvertFrom-Json
    if ($status -ne "SUCCESS") {
        continue
    }

    Log-Output "Uploading ${name} to dps.report..."
    try {
        $client = New-Object RestSharp.RestClient($dpsreport_url)
        $req = New-Object RestSharp.RestRequest("/uploadContent")
        $req.Method = [RestSharp.Method]::POST

        # This depends on the json output being enabled
        $req.AddParameter("json", "1") | Out-Null
        # We wanted weapon rotations, but you can disable this if you like
        $req.AddParameter("rotation_weap", "1") | Out-Null
        # Include the dps.report user token
        $req.AddParameter("userToken", $dpsreport_token)

        $req.AddFile("file", $f) | Out-Null

        $resp = $client.Execute($req)

        if ($resp.ResponseStatus -ne [RestSharp.ResponseStatus]::Completed) {
            throw "Request was not completed"
        }

        if ($resp.StatusCode -ne "OK") {
            $json_resp = ConvertFrom-Json $resp.Content
            Log-Output $json_resp.error
            throw "Request failed with status $resp.StatusCode"
        }

        $resp.Content | Out-File -FilePath (Join-Path $dir -ChildPath "dpsreport.json")

        Log-Output "Upload successful..."
    } catch {
        Log-Output $_.Exeception.Message
        Log-Output "Upload to dps.report failed..."

        # The set of files is sorted in ascending order by its last write time. This
        # means, if we exit at the first failed file, that all files with an upload time prior
        # to this file must have succeeded. Thus, we'll save the "last upload time" as the
        # last update time of this file minus a little bit to ensure we attempt re-uploading it
        # on the next run. This avoids re-uploading lots of files if we fail in the middle of
        # a large sequence.
        (Get-Item $f).LastWriteTime.AddSeconds(-1) | Select-Object -Property DateTime | ConvertTo-Json | Out-File -Force $last_upload_file
        exit
    }
}

# Save the current time as
$next_upload_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $last_upload_file
