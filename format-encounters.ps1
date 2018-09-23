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
    "simple_arc_parse_path"
    "last_upload_file"
    "format_encounters_log"
    "arcdps_logs"
    "upload_log_file"
    "gw2raidar_token"
    "dps_report_token"
    "guilds"
)

# Load the configuration from the default file
$config = Load-Configuration "l0g-101086-config.json" 2
if (-not $config) {
    exit
}

$logfile = $config.format_encounters_log

# Check that the start map folder has already been created
if (-not (X-Test-Path $config.gw2raidar_start_map)) {
    Read-Host -Prompt "The $($config.gw2raidar_start_map) can't be found. Try running upload-logs.ps1 first? Press enter to exit"
    exit
}

# Check that the ancillary data folder has already been created
if (-not (X-Test-Path $config.extra_upload_data)) {
    Read-Host -Prompt "The $($config.extra_upload_data) can't be found. Try running upload-logs.ps1 first? Press enter to exit"
    exit
}

# We absolutely require a gw2raidar token
if (-not $config.gw2raidar_token) {
    Read-Host -Prompt "This script requires a gw2raidar authentication token. Press enter to exit"
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

Function Log-Output ($string) {
    if ($config.debug_mode) {
        Write-Output $string
    } else {
        Write-Output $string | Out-File -Append $logfile
    }
}

# Loads account names from the local data directory
Function Get-Local-Players ($guild, $boss) {
    $names = @()

    if (!$boss.evtc) {
        return $names
    }

    $accounts = Get-Content -Raw -Path ([io.path]::combine($config.extra_upload_data, $boss.evtc, "accounts.json")) | ConvertFrom-Json
    ForEach ($account in ($accounts | Sort)) {
        if ($guild.discord_map."$account") {
            $names += @($guild.discord_map."$account")
        } elseif ($account -ne "") {
            $names += @("_${account}_")
        }
    }

    return $names
}

# Loads dps.report link from the local data directory
Function Get-Local-DpsReport ($boss) {
    if (!$boss.evtc) {
        return ""
    }

    $dpsreport_json = [io.path]::combine($config.extra_upload_data, $boss.evtc, "dpsreport.json")

    if (!(Test-Path -Path $dpsreport_json)) {
        return ""
    }

    $dps_report = Get-Content -Raw -Path $dpsreport_json | ConvertFrom-Json
    return $dps_report.permalink
}

Log-Output "~~~"
Log-Output "Formatting encounters for discord at $(Get-Date)..."
Log-Output "~~~"

$gw2raidar_url = "https://gw2raidar.com"
$complete = $false

$nameToId = @{}

# Main data structure tracking information about bosses as we discover it
$bosses = @(@{name="Vale Guardian";wing=1},
            @{name="Gorseval";wing=1},
            @{name="Sabetha";wing=1},
            @{name="Slothasor";wing=2},
            @{name="Matthias";wing=2},
            @{name="Keep Construct";wing=3},
            @{name="Xera";wing=3},
            @{name="Cairn";wing=4},
            @{name="Mursaat Overseer";wing=4},
            @{name="Samarog";wing=4},
            @{name="Deimos";wing=4},
            @{name="Soulless Horror";wing=5},
            @{name="Dhuum";wing=5},
            @{name="Conjured Amalgamate";wing=6},
            @{name="Nikare";wing=6},
            @{name="Kenut";wing=6},
            @{name="Qadim";wing=6})

$fractals = @(@{name="MAMA (CM)";wing="99cm"}
              @{name="Siax (CM)";wing="99cm"}
              @{name="Ensolyss (CM)";wing="99cm"}
              @{name="Skorvald (CM)";wing="100cm"}
              @{name="Artsariiv (CM)";wing="100cm"}
              @{name="Arkk (CM)";wing="100cm"})

try {
    $areasResp = Invoke-RestMethod -Uri "${gw2raidar_url}/api/v2/areas" -Method Get -Headers @{"Authorization" = "Token $($config.gw2raidar_token)"}
} catch {
    Write-Exception $_
    Read-Host -Prompt "Areas request Failed, press Enter to exit"
    exit
}

ForEach($area in $areasResp.results) {
    # Raid CMs have bits 16-23 all set. We want to treat CMs the same as normal runs
    # so we'll just ignore these
    if ($area.id -band 0xFF0000) {
        continue
    }

    # GW2 Raidar uses the long name for Skorvald, and we want the short one
    if ($area.name -eq "Skorvald the Shattered (CM)") {
        $nameToId.Set_Item("Skorvald (CM)", $area.id)
    } else {
        # Store the area name and id mapping
        $nameToId.Set_Item($area.name, $area.id)
    }
}

# Hack in the wing6 IDs until gw2raidar updates
$nameToId.Set_Item("Conjured Amalgamate", 43974);
$nameToId.Set_Item("Nikare", 21105);
$nameToId.Set_Item("Kenut", 21089);
$nameToId.Set_Item("Qadim", 20934);

# Insert IDs
$bosses | ForEach-Object { $name = $_.name; $_.Set_Item("id", $nameToId.$name) }
$fractals | ForEach-Object { $name = $_.name; $_.Set_Item("id", $nameToId.$name) }

# The fractal and raid boss data need to be deep copied, otherwise the pointers
# end up being shared between guilds. To avoid this, we convert to JSON and then back
$bosses_json = $bosses | ConvertTo-Json -Depth 10
$fractals_json = $fractals | ConvertTo-Json -Depth 10

$guild_data = @{}
ForEach ($guild in $config.guilds) {
    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer
    $parser.MaxJsonLength = $bosses_json.Length + $fractals_json.Length

    $guild_data[$guild.name] = @{
        guild = $guild
        bosses = $parser.Deserialize($bosses_json, @().GetType())
        fractals = $parser.Deserialize($fractals_json, @().GetType())
    }
}

# Load the last upload time, or go back forever if we can't find it
if ((-not $config.debug_mode) -and (X-Test-Path $config.last_format_file)) {
    $last_format_time = Get-Content -Raw -Path $config.last_format_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
    $since = ConvertTo-UnixDate ((Get-Date -Date $last_format_time).ToUniversalTime())
} else {
    $last_format_time = $null
    $since = 0
}

Log-Output "Searching gw2raidar for encounters..."

# Limit ourselves to 15 encounters at a time
$request = "/api/v2/encounters?success=true&limit=15&since=${since}"

# Attempt to find local data for a given start time and area id
Function Locate-Local-EVTC-Data ($area_id, $start_time) {
    # In some cases, the gw2raidar server time may not exactly match the time
    # recorded in our local file. This should only happen if another user
    # happens to upload a different record of the same encounter. To avoid this,
    # we'll check start times within 2 seconds either direction, preferring times closer
    # to the start than not.
    $map_times = @($start_time, ($start_time - 1), ($start_time + 1), ($start_time - 2), ($start_time + 2))

    ForEach ($time in $map_times) {
        # If the map dir doeesn't exist, try the next time in the list
        $map_dir = Join-Path -Path $config.gw2raidar_start_map -ChildPath $time
        if (-not (X-Test-Path $map_dir)) {
            continue
        }

        # If the EVTC local directory doesn't exist, try the next time on the list
        $evtc_name = Get-Content -Raw -Path (Join-Path -Path $map_dir -ChildPath "evtc.json") | ConvertFrom-Json
        $evtc_dir = Join-Path -Path $config.extra_upload_data -ChildPath $evtc_name
        if (-not (X-Test-Path $evtc_dir)) {
            continue
        }

        # If the recorded area_id doesn't match, try the next item in the list
        $local_id = Get-Content -Raw -Path (Join-Path -Path $evtc_dir -ChildPath "id.json") | ConvertFrom-Json
        if ($local_id -ne $area_id) {
            continue
        }

        return $evtc_name

    }
    return $null
}

# Main loop for getting gw2raidar links
Do {
    $areasResp = Invoke-RestMethod -Uri "${gw2raidar_url}/api/v2/areas" -Method Get -Headers @{"Authorization" = "Token $($config.gw2raidar_token)"}

    try {
        $data = Invoke-RestMethod -Uri "${gw2raidar_url}${request}" -Method Get -Headers @{"Authorization" = "Token $($config.gw2raidar_token)"}
    } catch {
        Write-Exception $_
        Read-Host -Prompt "Request Failed, press Enter to exit"
        exit
    }

    # When we get no further results, break the loop
    if (!($data.results)) {
        break
    }

    # Parse each encounter from the results
    ForEach($encounter in $data.results) {
        # Extract the area id minus the upper bits indicating challenge mode
        $area_id = $encounter.area_id -band 0xFFFF
        $url_id = $encounter.url_id
        $gw2r_url = "${gw2raidar_url}/encounter/${url_id}"
        $time = ConvertFrom-UnixDate $encounter.started_at

        ForEach ($iter in $guild_data.GetEnumerator()) {
            $tag = ($iter.value.guild).gw2raidar_tag
            if (-not $tag) {
                continue
            }
            if ($encounter.tags.Contains($tag)) {
                $guild_tag = $iter.name
                break;
            }
        }

        # See if we have matching local data for this encounter.
        # Local data is accessed from the extra_upload_data folder, by using
        # the gw2raidar_start_map as a mapping between encounter start time
        # and the local evtc file data that we created using upload-logs.ps1
        $evtc_name = Locate-Local-EVTC-Data $area_id $encounter.started_at
        if ($evtc_name) {
            $guild_json = [io.path]::combine($config.extra_upload_data, $evtc_name, "guild.json")
            if (X-Test-Path $guild_json) {
                $guild_name = Get-Content -Raw -Path $guild_json | ConvertFrom-Json
            }
        } else {
            Log-Output "Unable to locate local map data $($encounter.started_at) for boss id ${area_id}"
        }

        if (-not $guild_tag -and -not $guild_name) {
            # this encounter has no guild information at all!
            continue
        } elseif (-not $guild_name) {
            # If we didn't have a local configuration, use the gw2raidar tag we found
            $guild_name = $guild_tag
        }

        # Make sure we actually have guild data first
        if (-not $guild_data.ContainsKey($guild_name)) {
            continue
        }

        # Insert the url and other data into the boss list
        #
        # Note that we search in *reverse* (newest first), so as soon as we find
        # a url for a particular encounter we will not overwrite it.
        $guild_data[$guild_name].bosses | where { -not $_.ContainsKey("gw2r_url") -and ($_.id -eq $area_id) } | ForEach-Object { $_.Set_Item("gw2r_url", $gw2r_url);
                                                                                                                                 $_.Set_Item("time", $time);
                                                                                                                                 $_.Set_Item("evtc", $evtc_name);
                                                                                                                                 $_.Set_Item("server_time", $encounter.started_at) }

        $guild_data[$guild_name].fractals | where { -not $_.ContainsKey("gw2r_url") -and ($_.id -eq $area_id) } | ForEach-Object { $_.Set_Item("gw2r_url", $gw2r_url);
                                                                                                                                   $_.Set_Item("time", $time);
                                                                                                                                   $_.Set_Item("evtc", $evtc_name);
                                                                                                                                   $_.Set_Item("server_time", $encounter.started_at) }

    }

    $missing_encounters = $false

    # We want to make sure that we keep looking for encounters unless *every* guild is full
    ForEach ($iter in $guild_data.GetEnumerator()) {
        if ( $iter.value.bosses | where { -not $_.ContainsKey("gw2r_url") } ) {
            $missing_encounters = $true
        }
        if ( $iter.value.fractals | where { -not $_.ContainsKey("gw2r_url") } ) {
            $missing_encounters = $true
        }
    }

    # If we're not missing any encounters, then we are complete, and can stop looping backwards
    if (-not $missing_encounters) {
        $complete = $true
    }

    # If the gw2raidar API gave us a $next url, then we still have encounters
    # available to check. If not, we're complete and should stop here
    if ($data.next) {
        $request = $data.next -replace $gw2raidar_url, ""
    } else {
        $complete = $true
    }

} Until($complete)

# We're going to lookup dps.report URLs and include them into the boss report. In some cases
# we'll find the exact match. In other cases, we might find a newer dps.report link which
# invalidates the older encounter found from gw2 raidar
if ($last_format_time) {
    $start_dirs = @(Get-ChildItem -LiteralPath $config.gw2raidar_start_map | Where-Object { $_.LastWriteTime -gt $last_format_time } | Sort-Object -Property LastWriteTime -Descending | ForEach-Object {$_.FullName})
} else {
    $start_dirs = @(Get-ChildItem -LiteralPath $config.gw2raidar_start_map | Sort-Object -Property LastWriteTime -Descending | ForEach-Object {$_.FullName})
}

# obtain the evtc upload directory
Function Get-Evtc-Name ($start) {
    $path = Join-Path -Path $start -ChildPath "evtc.json"
    if (-not (X-Test-Path $path)) {
        return $null
    }
    return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

Function Get-Evtc-Dir ($start) {
    $evtc_name = Get-Evtc-Name $start
    $evtc_dir = Join-Path -Path $config.extra_upload_data -ChildPath $evtc_name
    if (-not (X-Test-Path $evtc_dir)) {
        return $null
    }
    return $evtc_dir
}

# Get the boss name, given evtc upload directory
Function Get-Boss-Id ($dir) {
    $path = Join-Path -Path $dir -ChildPath "id.json"
    if (-not (X-Test-Path $path)) {
        return $null
    }
    return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

# Get the guild for this encounter, given evtc upload directory
Function Get-Guild-Name ($dir) {
    $path = Join-Path -Path $dir -ChildPath "guild.json"
    if (-not (X-Test-Path $path)) {
        return $null
    }
    return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

Function Has-Dps-Report ($dir) {
    $path = Join-Path -Path $dir -ChildPath "dpsreport.json"
    return X-Test-Path $path
}

Function Is-Matching-Encounter($start, $guild, $boss) {
    $dir = Get-Evtc-Dir $start

    # Make sure we actually have an EVTC dir
    if (-not $dir) {
        return $false
    }

    # Make sure the boss id matches
    if ((Get-Boss-Id $dir) -ne $boss.id) {
        return $false
    }

    # Make sure this is for the correct guild
    if ((Get-Guild-Name $dir) -ne $guild.name) {
        return $false
    }

    # Make sure this encounter has a dps.report link
    if (-not (Has-Dps-Report $dir)) {
        return $false
    }

    return $true
}

Function Publish-Encounters($guild, $bosses, $encounterText) {

    Log-Output "$($guild.name): searching local evtc data for dps.report links..."

    $bosses | ForEach-Object {
        $boss = $_

        if ($boss.server_time) {
            $evtc_dirs = @($start_dirs | where { [int](Split-Path -Leaf $_) -ge [int]$boss.server_time })
        } else {
            $evtc_dirs = $start_dirs
        }

        # Find matching start_map directories. Make sure we only check those which actually have a dps.report link
        $matching_dirs = @($evtc_dirs | where { Is-Matching-Encounter $_ $guild $boss })

        # If we didn't find anything, there's nothing to update
        if (-not $matching_dirs) {
            return
        }

        # Use the newest data available
        $newest_data = $matching_dirs[0]
        $evtc_name = Get-Evtc-Name $newest_data

        # If the EVTC names don't match, this means our local data does not match the expected data
        # based on the gw2 raidar URL. Thus, prefer local data, and remove the gw2 raidar URL.
        if ($boss.evtc -ne $evtc_name) {
            if ($boss.evtc) {
                Log-Output "$($guild.name): $($boss.evtc) is not the newest encounter data for $($boss.name). Removing the GW2 Raidar data"
            } else {
                Log-Output "$($guild.name): Couldn't find local data for $($boss.name) using GW2 Raidar unix time. Removing the GW2 Raidar data"
            }
            $boss.Remove("gw2r_url") | Out-Null
            $boss.Remove("evtc") | Out-Null
        }

        # Now, if we have no evtc data, use our latest local data instead
        if (-not $boss.evtc) {
            Log-Output "$($guild.name): Using ${evtc_name} as the only source of data for $($boss.name)"

            # Set the time data
            $server_time = [int](Split-Path -Leaf $newest_data)
            $time = ConvertFrom-UnixDate $server_time
            $boss.Set_Item("server_time", (Split-Path -Leaf $server_time))
            $boss.Set_Item("time", $time)

            # Store this evtc data directory
            $evtc_name = Split-Path -Leaf (Get-Evtc-Dir $newest_data)
            $boss.Set_Item("evtc", $evtc_name)
        }
    }

    # If we didn't find any evtc data, this means that we didn't find any valid local data
    # to upload against. We might have found just a gw2 raidar URL, but this is unlikely
    # to be one of the files we uploaded via the upload-logs.ps1
    if (-not ( $bosses | where { ($_.ContainsKey("evtc")) -or ($_.ContainsKey("gw2r_url")) } ) ) {
        Log-Output "$($guild.name): no new ${encounterText} to publish."
        return
    }

    $boss_per_date = @{}

    $datestamp = Get-Date -Date $this_format_time -Format "yyyyMMdd-HHmmss"

    # We show a set of encounters based on the day that they occurred, so if you
    # run some encounters on one day, and some on another, you could run this script
    # only on the second day and it would publish two separate pages for each
    # day.
    $bosses | ForEach-Object {
        # Skip bosses which weren't found
        if ((-not $_.ContainsKey("evtc")) -and (-not $_.ContainsKey("gw2r_url"))) {
            return
        }

        if (-not $boss_per_date.ContainsKey($_.time.Date)) {
            $boss_per_date[$_.time.Date] = @()
        }
        $boss_per_date[$_.time.Date] += ,@($_)
    }

    # object holding the thumbnail URL
    if ($guild.thumbnail) {
        $thumbnail = [PSCustomObject]@{
            url = $guild.thumbnail
        }
    } else {
        $thumbnail = $null
    }

    $data = @()

    Log-Output "$($guild.name): generating discord report..."

    $boss_per_date.GetEnumerator() | Sort-Object -Property {$_.Key.DayOfWeek}, key | ForEach-Object {
        $date = $_.key
        $some_bosses = $_.value
        $players = @()
        $fields = @()

        # We sort the bosses based on server start time
        ForEach ($boss in $some_bosses | Sort-Object -Property {$_.time}) {
            if ((-not $boss.ContainsKey("evtc")) -and (-not $boss.ContainsKey("gw2r_url"))) {
                continue
            }

            $name = $boss.name
            $emoji = $guild.emoji_map."$name"

            $players += Get-Local-Players $guild $boss
            $dps_report = Get-Local-DpsReport $boss

            $gw2r_url = $boss.gw2r_url

            # If we don't have at least one of these URLs, then we
            # have nothing to post
            if ((-not $gw2r_url) -and (-not $dps_report)) {
                continue
            }

            # For each boss, we add a field object to the embed
            #
            # Note that PowerShell's default ConvertTo-Jsom does not handle unicode
            # characters very well, so we use @NAME@ replacement strings to represent
            # these characters, which we'll replace after calling ConvertTo-Json
            # See Convert-Payload for more details
            #
            # In some cases, we might reach here without a valid dps.report url. This
            # may occur because gw2raidar might return a URL which we don't have local
            # data for. In this case, just show the gw2raidar link alone.
            $boss_field = [PSCustomObject]@{
                    # Each boss is just an emoji followed by the full name
                    name = "${emoji} **${name}**"
                    inline = $true
            }

            # At this point, we know that we have at least one of a dps.report or gw2raidar URL
            if (-not $dps_report) {
                $boss_field | Add-Member @{value="[gw2raidar](${gw2r_url} `"${gw2r_url}`")`r`n@UNICODE-ZWS@"}
            } elseif (-not $gw2r_url) {
                $boss_field | Add-Member @{value="[dps.report](${dps_report} `"${dps_report}`")`r`n@UNICODE-ZWS@"}
            } else {
                # We put both the dps.report link and gw2raidar link here. We separate them by a MIDDLE DOT
                # unicode character, and we use markdown to format the URLs to include the URL as part of the
                # hover-over text.
                #
                # Discord eats extra spaces, but doesn't recognize the "zero width" space character, so we
                # insert that on an extra line in order to provide more spacing between elements
                $boss_field | Add-Member @{value="[dps.report](${dps_report} `"${dps_report}`") @MIDDLEDOT@ [gw2raidar](${gw2r_url} `"${gw2r_url}`")`r`n@UNICODE-ZWS@"}
            }

            # Insert the boss field into the array
            $fields += $boss_field
        }

        # Create a participants list separated by MIDDLE DOT unicode characters
        $participants = ($players | Select-Object -Unique) -join " @MIDDLEDOT@ "

        # Add a final field as the set of players.
        if ($participants) {
            $fields += [PSCustomObject]@{
                name = "@EMDASH@ Raiders @EMDASH@"
                value = "${participants}"
            }
        }

        # Determine which wings we did
        $wings = $($some_bosses | Sort-Object -Property {$_.time} | ForEach-Object {$_.wing} | Get-Unique) -join ", "

        $date = Get-Date -Format "MMM d, yyyy" -Date $date

        # Create the data object for this date, and add it to the list
        $data_object = [PSCustomObject]@{
            title = "$($guild.name) ${encounterText}: ${wings} | ${date}"
            color = 0xf9a825
            fields = $fields
	    footer = [PSCustomObject]@{ text = "Created by /u/platinummyr" }
        }
        if ($thumbnail) {
            $data_object | Add-Member @{thumbnail=$thumbnail}
        }
        $data += $data_object
    }

    # Create the payload object
    $payload = [PSCustomObject]@{
        embeds = @($data)
    }

    # ConvertTo-JSON doesn't handle unicode characters very well, but we want to
    # insert a zero-width space. To do so, we'll implement a variant that replaces
    # a magic string with the expected value
    #
    # More strings can be added here if necessary. The initial string should be
    # something innocuous which won't be generated as part of any URL or other
    # generated text, and is unlikely to appear on accident
    Function Convert-Payload($payload) {
        # Convert the object into a JSON string, using an increased
        # depth so that the ConvertTo-Json will completely convert
        # the layered object into JSON.
        $json = ($payload | ConvertTo-Json -Depth 10)

        $unicode_map = @{"@UNICODE-ZWS@"="\u200b";
                         "@BOXDASH@"="\u2500";
                         "@EMDASH@"="\u2014";
                         "@MIDDLEDOT@"="\u00B7"}

        # Because ConvertTo-Json doesn't really handle all of the
        # unicode characters, we need to insert these after the fact.
        $unicode_map.GetEnumerator() | ForEach-Object {
            $json = $json.replace($_.key, $_.value)
        }
        return $json
    }

    if ($config.debug_mode) {
        (Convert-Payload $payload) | Write-Output
    } elseif (X-Test-Path $config.discord_json_data) {
        # Store the complete JSON we generated for later debugging
        $discord_json_file = Join-Path -Path $config.discord_json_data -ChildPath "discord-webhook-${datestamp}.txt"
        (Convert-Payload $payload) | Out-File $discord_json_file
    }

    Log-Output "$($guild.name): publishing discord report..."

    # Send this request to the discord webhook
    Invoke-RestMethod -Uri $guild.webhook_url -Method Post -Body (Convert-Payload $payload)
}

$this_format_time = Get-Date


ForEach ($iter in $guild_data.GetEnumerator()) {
    $guild = $iter.value.guild
    $bosses = $iter.value.bosses
    $fractals = $iter.value.fractals

    Publish-Encounters $guild $fractals "Fractals"
    Publish-Encounters $guild $bosses "Wings"
}

# Update the last_format_file with the new format time, so that
# future runs won't repost old links
if ((-not $config.debug_mode) -and ($config.last_format_file)) {
    $this_format_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $config.last_format_file
}
