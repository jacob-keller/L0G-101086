# Path to the RestSharp dll
#
# This script depends on RestSharp (http://restsharp.org/) to setup it's Rest APIs, as the
# "Invoke-WebRequest" builtin isn't quite powerful enough.
#
# Set this to the complete path where you have downloaded RestSharp.
$restsharp_path = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\RestSharp.dll"

# Path to a file containing timestamp of the last time we uploaded
# This is used to prevent re-uploading old files every time this
# script is run.
$last_upload_file = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\last_upload_time.json"

# Path to the directory containing ArcDPS evtc log files
$arcdps_logs = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\arcdps.cbtlogs"

# gw2raidar API token
#
# This script connects to gw2raidar to obtain a recent encounter list. To
# authenticate properly, you need to setup this token. You can obtain it
# by logging into gw2raidar.com and going to "https://www.gw2raidar.com/api/v2/swagger#/token"
# This site should be able to generate a token for you which you can place in this string.
$gw2raidar_token = ''

# dps.report API token
#
# Currently, this can be anything you want, though this may change in the future
# Set this to a unique string so that you can find your uploads using the API,
# incase of future updates.
$dpsreport_user_token = ''

# path to log file
#
# Output is stored in a simple log file
$logfile = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\upload_log.txt"

# Folder for storing extra data about uploaded files. This data is extracted
# from evtc files using simpleArcParse, a provided C++ utility to extract
# data such as player account names and the server start time.
# Additionally this will be where we store the dps.report link when we upload it.
#
# This must be set to the same value as in the format-encounters.ps1 script, otherwise
# things will not function correctly.
$upload_extras = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\arcdps.uploadextras"

# The dps.report API returns the permalink immediately after the upload as part of its response.
# However, gw2raidar does not. Instead, gw2raidar expects you to use the API to obtain encounter
# information. Unfortunately, this makes it tricky to map gw2raidar links to the dps.report links
# and other information.
#
# In the encounters API for gw2raidar, we *are* given the server start time of the encounter.
# Since it is unlikely that you will have multiple enounters start at the same time, we use this
# as a key.
#
# This script stores a folder named after the start time of the file, which contains a JSON file
# showing the evtc local file name. This is used by format-encounters.ps1 to correlate the
# gw2raidar links back to the local storage, and thus back to the dps.report links.
#
# This must be set to the same value as in the upload-logs.ps1 script, otherwise
# things will not function correctly
$start_map = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\arcdps.startmap"

# In order to extract data from the evtc files, we use a custom simpleArcParse C++ utility
# which can extract the necessary data from uncompressed evtc files. This utility
# is provided along with upload-logs.ps1 and format-encounters.ps1
# Note that you must compile it. A CodeBlocks (http://www.codeblocks.org/) project file
# is provided, or you can use the MinGW suite or any other C++ compile tool chain, it should
# not be dependent on anything special.
#
# Set this to the path of the compiled binary
$simple_arc_parse = "C:\Users\Administrator\Documents\Guild Wars 2\addons\arcdps\simpleArcParse\bin\Release\simpleArcParse.exe"

# gw2raidar URL
$gw2raidar_url = "https://www.gw2raidar.com"
# dps.report URL
$dpsreport_url = "https://dps.report"

# Load extra libraries we need, including RestSharp
Add-Type -Path $restsharp_path
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

# Output a string to the log file
Function Log-Output ($string) {
    Write-Output $string | Out-File -Append $logfile
}

# If we have a last upload file, we want to limit our scan to all files since
# the last time that we uploaded.
#
# This invocation is a bit complicated, but essentially we recurse through all folders within
# the $arcdps_logs directory and find all files which end in *.evtc.zip. We store them by the
# last write time, and then we return the full path of that file.
if (Test-Path $last_upload_file) {
    $last_upload_time = Get-Content -Raw -Path $last_upload_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
    $files = @(Get-ChildItem -Recurse -File -Include "*.evtc.zip" -LiteralPath $arcdps_logs | Where-Object { $_.LastWriteTime -gt $last_upload_time} | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
} else {
    $files = @(Get-ChildItem -Recurse -File -Include "*.evtc.zip" -LiteralPath $arcdps_logs | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
}

$next_upload_time = Get-Date
Log-Output "~~~"
Log-Output "Uploading arcdps logs at $next_upload_time..."
Log-Output "~~~"

# Main loop to generate and upload gw2raidar and dps.report files
ForEach($f in $files) {
    $name = [io.path]::GetFileNameWithoutExtension($f)
    Log-Output "Saving ancillary data for ${name}..."

    $dir = Join-Path -Path $upload_extras -ChildPath $name
    if (Test-Path -Path $dir) {
        Log-Output "Ancillary data appears to have already been created... skipping"
    } else {
        # Make the ancillary data directory
        New-Item -ItemType Directory -Path $dir

        # simpleArcParse cannot deal with compressed data, so we must extract it
        [io.compression.zipfile]::ExtractToDirectory($f, $dir) | Out-Null

        $evtc = Join-Path -Path $dir -ChildPath $name

        # Parse the evtc file and extract account names
        $player_data = (& $simple_arc_parse players "${evtc}")
        $players = $player_data.Split([Environment]::NewLine)
        $players | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "accounts.json")

        # Parse the evtc header file and get the encounter name
        $evtc_header_data = (& $simple_arc_parse header "${evtc}")
        $evtc_header = ($evtc_header_data.Split([Environment]::NewLine))
        $evtc_header[0] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "version.json")
        $evtc_header[1] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "encounter.json")

        # Parse the evtc combat events to determine SUCCESS/FAILURE status
        $evtc_success = (& $simple_arc_parse success "${evtc}")
        $evtc_success | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "success.json")

        # Parse the evtc combat events to determine the server start time
        $start_time = (& $simple_arc_parse start_time "${evtc}")

        # Generate a map between start time and the evtc file name
        $map_dir = Join-Path -Path $start_map -ChildPath $start_time
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

        # Don't keep uncompressed data around
        Remove-Item -Path $evtc
    }

    # First, upload to gw2raidar, because it returns immediately and processes in the background
    Log-Output "Uploading ${name} to gw2raidar..."
    try {
        $client = New-Object RestSharp.RestClient($gw2raidar_url)
        $req = New-Object RestSharp.RestRequest("/api/v2/encounters/new")
        $req.AddHeader("Authorization", "Token $token") | Out-Null
        $req.Method = [RestSharp.Method]::PUT

        $req.AddFile("file", $f) | Out-Null

        $day = (Get-Item $f).LastWriteTime.DayOfWeek
        $time = (Get-Item $f).LastWriteTime.TimeOfDay

        # You can add tags using the following code
        #
        #  $req.AddParameter("tags", $tags) | Out-Null
        #
        # For example, you could check the server time and add tags based on
        # when the encounter occurred. Or you could check who was in the
        # encounter, and tag it based on that.
        #
        # You can also set the category using similar code
        #
        #  $req.AddParameter("category", "1") | Out-Null
        #
        # The possible options can be looked up on the gw2raidar API

        # Exceute this request
        $resp = $client.Execute($req)

        if ($resp.ResponseStatus -ne [RestSharp.ResponseStatus]::Completed) {
            throw "Request was not completed"
        }

        # Comment this out if you want to log the entire response content
        # even on successful runs
        # Log-Output $resp.Content

        if ($resp.StatusCode -ne "OK") {
            Log-Output $resp.Content
            throw "Request failed with status $resp.StatusCode"
        }
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
