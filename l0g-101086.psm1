# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# This module contains several functions which are shared between the scripts
# related to uploading and formatting GW2 ArcDPS log files. It contains some
# general purpose utility functions, as well as functions related to managing
# the configuration file

<#
 .Synopsis
  Tests whether a path exists

 .Description
  Tests wither a given path exists. It is safe to pass a $null value to this
  function, as it will return $false in that case.

 .Parameter Path
  The path to test
#>
Function X-Test-Path {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$path)
    try {
        return Test-Path $path.trim()
    } catch {
        return $false
    }
}

<#
 .Synopsis
  Print output to the log file, or console.

 .Description
  Print output to the log file if it has been specified. Otherwise, output
  will be displayed to the screen.

 .Parameter string
  The string to log
#>
Function Log-Output {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$string)

    if ($script:logfile) {
        Write-Output $string | Out-File -Append $script:logfile
    } else {
        Write-Output $string
    }
}

<#
 .Synopsis
  Print output to the log file and the console.

 .Description
  Print output to the log file if it has been specified.

  Also display output to the console screen as well.

 .Parameter string
  The string to log
#>
Function Log-And-Write-Output {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$string)

    if ($script:logfile) {
        Write-Output $string | Out-File -Append $script:logfile
    }

    Write-Output $string
}

<#
 .Synopsis
  Set the log file used by Log-Output

 .Description
  Set the log file used by the Log-Output function. If the log file has been
  set, then Log-Output will log to the file. Otherwise it will log to the screen.
  To clear the log file, set it to $null

 .Parameter file
  The file name to set for the log file (or $null to clear it)
#>
Function Set-Logfile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$file)

    $script:logfile = $file
}

<#
 .Synopsis
  Convert UTC time to the local timezone

 .Description
  Take a UTC date time object containing a UTC time and convert it to the
  local time zone

 .Parameter Time
  The UTC time value to convert
#>
Function ConvertFrom-UTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][DateTime]$time)
    [TimeZone]::CurrentTimeZone.ToLocalTime($time)
}

<#
 .Synopsis
  Convert a Unix timestamp to a DateTime object

 .Description
  Given a Unix timestamp (integer containing seconds since the Unix Epoch),
  convert it to a DateTime object representing the same time.

 .Parameter UnixDate
  The Unix timestamp to convert
#>
Function ConvertFrom-UnixDate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$UnixDate)
    ConvertFrom-UTC ([DateTime]'1/1/1970').AddSeconds($UnixDate)
}

<#
 .Synopsis
  Convert DateTime object into a Unix timestamp

 .Description
  Given a DateTime object, convert it to an integer representing seconds since
  the Unix Epoch.

 .Parameter Date
  The DateTime object to convert
#>
Function ConvertTo-UnixDate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][DateTime]$Date)
    $UnixEpoch = [DateTime]'1/1/1970'
    (New-TimeSpan -Start $UnixEpoch -End $Date).TotalSeconds
}


<#
 .Synopsis
  Check if an EVTC filename is expected to be compressed

 .Description
  Return $true if the filename matches known compressed EVTC file extensions,
  false otherwise.

 Similar to ExtensionIs-EVTC, but checks for only compressed filenames

 .Parameter filename
  The filename to check the extension of
#>
Function ExtensionIs-CompressedEVTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$filename)
    return ($filename -Like "*.evtc.zip" -or $filename -Like "*.zevtc")
}

<#
 .Synopsis
  Check if an EVTC filename is expected to be compressed

 .Description
  Return $true if the filename matches known uncompressed EVTC extension

 Similar to ExtensionIs-CompressedEVTC, but checks for only uncompressed filenames

 .Parameter filename
  The filename to check the extension of
#>
Function ExtensionIs-UncompressedEVTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$filename)
    return ($filename -Like "*.evtc")
}

<#
 .Synopsis
  Check if a filename extension is for a (un)compressed EVTC file

 .Description
  Return $true if the given filename matches one of the known EVTC file
  extensions for compressed or uncompressed EVTC log files.

 .Parameter filename
  The filename to check the extension of
#>
Function ExtensionIs-EVTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$filename)
    return ((ExtensionIs-UncompressedEVTC $filename) -or (ExtensionIs-CompressedEVTC $filename))
}

<#
 .Synopsis
  Given the EVTC file name, determine the uncompressed EVTC name

 .Description
  Determine the uncompressed name of the EVTC file, based on the file name.

 .Parameter filename
  The EVTC file to determine the uncompressed name of
#>
Function Get-UncompressedEVTC-Name {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$filename)

    if ($filename -Like "*.evtc") {
        # This filename is already correct, so just strip the directory
        return [io.path]::GetFileName($filename)
    } elseif ($filename -Like "*.evtc.zip") {
        # We have two extensions, so only remove the first one
        return [io.path]::GetFileNameWithoutExtension($filename)
    } elseif ($filename -Like "*.zevtc") {
        # Strip the ".zevtc", and add back ".evtc"
        $name = [io.path]::GetFileNameWithoutExtension($filename)
        return "${name}.evtc"
    } else {
        throw "${filename} has an unrecognized extension"
    }
}

<#
 .Synopsis
  Check simpleArcParse version to ensure it is compatible with the script

 .Description
  Given the version string reported by simpleArcParse, check if it is expected
  to be compatible with this version of the script.

  A simpleArcParse version is considered compatible if it has the correct major
  and minor version. The patch version is ignored for these purposes. This assumes
  that the versioning of simpleArcParse follows the Semantic Versioning outlined at
  https://semver.org/

  As of v1.2.0, the first version to have 3 digits, this should be the case.

  Returns $true if the version is compatible, $false otherwise

 .Parameter version
  The version string, as reported by "(& $simple_arc_parse version)"
#>
Function Check-SimpleArcParse-Version {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$version)

    $expected_major_ver = 1
    $expected_minor_ver = 4
    $expected_patch_ver = 0

    $expected_version = "v${expected_major_ver}.${expected_minor_ver}.${expected_patch_ver}"

    if ($version -eq "") {
        Write-Host "Unable to determine the version of simpleArcParse"
        Write-Host "Please use the $expected_version release of simpleArcParse"
        return $false
    }

    $found = $version -match 'v(\d+)\.(\d+)\.(\d+)'
    if (-not $found) {
        Write-Host "simpleArcParse version '${verison}' doesn't make any sense"
        Write-Host "Please use the $expected_version release of simpleArcParse"
        return $false
    }

    # Extract the actual major.minor.patch numbers
    $actual_major_ver = [int]($matches[1])
    $actual_minor_ver = [int]($matches[2])
    $actual_patch_ver = [int]($matches[3])

    # The major version is bumped when there are incompatibilities between the scripts
    # and the simpleArcParse output. If the major versions are not an exact match,
    # then assume we cannot possibly work.
    if ($actual_major_ver -ne $expected_major_ver) {
        Write-Host "simpleArcParse has major version ${actual_major_ver}, but we expected major version ${expected_major_ver}"
        Write-Host "Please upgrade to the $expected_version release of simpleArcParse"
        return $false
    }

    # Ok, we know the major version is an exact match, check the minor version

    # If the minor version is *less* than the required minor version, we cannot run as we will miss a newly added feature
    if ($actual_minor_ver -lt $expected_minor_ver) {
        Log-And-Write-Output "simpleArcParse has minor version ${actual_minor_ver}, but we expected at least minor version ${expected_minor_ver}"
        Log-And-Write-Output "Please upgrade to the $expected_version release of simpleArcParse"
        return $false
    } elseif ($actual_minor_ver -gt $expected_minor_ver) {
        # Log non-fatal messages to the output file instead of the console
        Log-And-Write-Output "simpleArcParse $version is newer than the expected $expected_version"
        return $true
    }

    # At this point, we know that the minor version is an exact match too. Check the patch version to log a warning only
    if ($actual_patch_ver -lt $expected_patch_ver) {
        Log-And-Write-Output "You are using simpleArcParse ${version}, but ${expected_version} has been released, with possible bug fixes. You may want to upgrade."
    } elseif ($actual_patch_ver -gt $expected_patch_ver) {
        Log-And-Write-Output "simpleArcParse $version is newer than the expected $expected_version"
    }

    return $true
}

<#
 .Synopsis
  Returns the NoteProperties of a PSCustomObject

 .Description
  Given a PSCustomObject, return the names of each NoteProperty in the object

 .Parameter obj
  The PSCustomObject to match
#>
Function Keys {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$obj)

    return @($obj | Get-Member -MemberType NoteProperty | % Name)
}

<#
 .Description
  Configuration fields which are valid for multiple versions of the
  configuration file. Currently this is shared between the v1 and v2
  formats, as they share a common base of configuration fields.

  If path is set, then the configuration will allow exchanging %UserProfile%
  for the current $env:USERPROFILE value

  If validFields is set to an array if fields, then the subfield will be
  recursively validated. If arrayFields is set, then the field will be treated as
  an array of objects and each object in the array will be recursively validated.

  Path, validFields, and arrayFields are mutually exclusive
#>
$commonConfigurationFields =
@(
    @{
        # Version indicating the format of the configuration file
        name="config_version"
        type=[int]
    }
    @{
        # Setting debug_mode to true will modify some script behaviors
        name="debug_mode"
        type=[bool]
    }
    @{
        # Setting experimental_arcdps will cause update-arcdps.ps1 to
        # download the experimental version of ArcDPS instead of the
        # stable version
        name="experimental_arcdps"
        type=[bool]
    }
    @{
        # Path to the EVTC combat logs generated by ArcDPS
        name="arcdps_logs"
        type=[string]
        path=$true
    }
    @{
        # Path to a folder for storing the JSON we send to a discord webhook
        # Intended for debugging if the logs do not format correctly. If
        # this is set to a non-existent directory, then the discord webhooks
        # will not be saved.
        name="discord_json_data"
        type=[string]
        path=$true
    }
    @{
        # Path to folder to store extra data about local EVTC encounter files
        # Will contain files in the JSON format which have data exracted
        # from the EVTC log file using simpleArcParse.
        name="extra_upload_data"
        type=[string]
        path=$true
    }
    @{
        # Deprecated configuration for path to store a "database" mapping encounter start
        # times to the local EVTC extra upload data. This is no longer used as the
        # functionality has been replaced with a better process.
        name="gw2raidar_start_map"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which stores the last time that we formatted logs to discord
        # Used to ensure that we don't re-post old logs. Disabled if debug_mode is true
        name="last_format_file"
        type=[string]
        path=$true
    }
    @{
        # Path to file to store the last time that we uploaded logs to gw2raidar and dps.report
        # This is *not* disabled when debug_mode is true, because we don't want to spam
        # the uploads of old encounters.
        name="last_upload_file"
        type=[string]
        path=$true
    }
    @{
        # Path to the compiled binary for the simpleArcParse program
        name="simple_arc_parse_path"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which logs actions and data generated while uploading logs
        name="upload_log_file"
        type=[string]
        path=$true
    }
    @{
        # Path to a file which logs actions and data generated while formatting to discord
        name="format_encounters_log"
        type=[string]
        path=$true
    }
    @{
        # Path to the GW2 installation directory
        name="guildwars2_path"
        type=[string]
        path=$true
    }
    @{
        # Path to Launch Buddy program (used by launcher.ps1)
        name="launchbuddy_path"
        type=[string]
        path=$true
    }
    @{
        # Path to a folder which holds backups of DLLs for arcdps, and related plugins
        name="dll_backup_path"
        type=[string]
        path=$true
    }
    @{
        # Path to the RestSharp DLL used for contacting gw2raidar and dps.report
        name="restsharp_path"
        type=[string]
        path=$true
    }
    @{
        # The gw2raidar API token used with your account. Used to upload encounters to
        # gw2raidar, as well as look up previously uploaded encounter data.
        name="gw2raidar_token"
        type=[string]
    }
    @{
        # An API token used by dps.report. Not currently required by dps.report but
        # may be used in a future API update to allow searching for previously uploaded
        # logs.
        name="dps_report_token"
        type=[string]
    }
    @{
        # dps.report allows using alternative generators besides raid heros. This parameter
        # is used to configure the generator used by the site, and must match a valid value
        # from their API. Currently "rh" means RaidHeros, "ei" means EliteInsights, and
        # leaving it blank will use the current default generator.
        name="dps_report_generator"
        type=[string]
    }
    @{
        # If set, configures whether and how to upload to dps.report
        # "no" disables uploading to dps.report entirely
        # "successful" causes only successful encounters to be uploaded
        # "all" causes all encounters to be uploaded.
        # The default is "successful"
        name="upload_dps_report"
        type=[string]
        validStrings=@("no", "successful", "all")
        alternativeStrings=@{"none"="no"; "yes"="all"}
        default="successful"
    }
    @{
        # If set, configures whether and how to upload to gw2raidar
        # "no" disables uploading to gw2raidar entirely
        # "successful" causes only successful encounters to be uploaded
        # "all" causes all encounters to be uploaded.
        # The default is "successful"
        name="upload_gw2raidar"
        type=[string]
        validStrings=@("no", "successful", "all")
        alternativeStrings=@{"none"="no"; "yes"="all"}
        default="successful"
    }
)

<#
 .Description
  Configuration fields which are valid for a v1 configuration file. Anything
  not listed here will be excluded from the generated $config object. If one
  of the fields has an incorrect type, configuration will fail to be validated.

  Fields which are common to many versions of the configuration file are stored
  in $commonConfigurationFields
#>
$v1ConfigurationFields = $commonConfigurationFields +
@(
    @{
        name="custom_tags_script"
        type=[string]
        path=$true
    }
    @{
        name="discord_webhook"
        type=[string]
    }
    @{
        name="guild_thumbnail"
        type=[string]
    }
    @{
        name="gw2raidar_tag_glob"
        type=[string]
    }
    @{
        name="guild_text"
        type=[string]
    }
    @{
        name="discord_map"
        type=[PSCustomObject]
    }
    @{
        name="emoji_map"
        type=[PSCustomObject]
    }
    @{
        name="publish_fractals"
        type=[bool]
    }
)

<#
 .Description
  Configuration fields which are valid for a v2 configuration file. Anything
  not listed here will be excluded from the generated $config object. If one
  of the fields has an incorrect type, configuration will fail to be validated.

  Fields which are common to many versions of the configuration file are stored
  in $commonConfigurationFields
#>
$v2ValidGuildFields =
@(
    @{
        # The name of this guild
        name="name"
        type=[string]
    }
    @{
        # Priority for determining which guild ran an encounter if there are
        # conflicts. Lower numbers win ties.
        name="priority"
        type=[int]
    }
    @{
        # Tag to add when uploading to gw2raidar.
        name="gw2raidar_tag"
        type=[string]
    }
    @{
        # Category to use when uploading to gw2raidar.
        # 1: Guild/ Static
        # 2: Training
        # 3: PUG
        # 4: Low Man / Sells
        name="gw2raidar_category"
        type=[int]
    }
    @{
        # Minimum number of players required for an encounter to be considered
        # a guild run. 0 indicates any encounter can be considered if there is
        # no better guild available
        name="threshold"
        type=[int]
    }
    @{
        # The discord webhook URL for this guild
        name="webhook_url"
        type=[string]
    }
    @{
        # URL to a thumbnail image for this guild
        name="thumbnail"
        type=[string]
    }
    @{
        # Set this to true if this guild should be considered for fractal
        # challenge motes. If set to false, fractals will never be posted
        # to this guild.
        name="fractals"
        type=[bool]
    }
    @{
        # Set this to true if the guild should be considered for raid encounters.
        # If set to false, raid encounters will never be posted to this guild.
        # Defaults to true if not specified
        name="raids"
        type=[bool]
        optional=$true
        default=$true
    }
    @{
        # Set of gw2 account names associated with this guild, mapped to
        # their discord account ids. Used as the primary mechanism to determine
        # which guild the encounter was run by, as well as for posting player pings
        # to the discord webhook.
        name="discord_map"
        type=[PSCustomObject]
    }
    @{
        # Determines how the list of players is displayed.
        # "none" disables showing any gw2 accounts or discord pings
        # "discord_only" will show only discord mapped names. Other accounts will not be displayed
        # "accounts_only" will show the list using only account names, without discord pings
        # "discord_if_possible" will show the discord map if possible, and the account name otherwise
        name="show_players"
        type=[string]
        validStrings=@("none", "discord_only", "accounts_only", "discord_if_possible")
        default="discord_if_possible"
    }
    @{
        # Set this to any extra text you want to prefix the player account list. For example
        # you can set it to "\u003c@526255792958078987\u003e" to add an @here ping
        name="prefix_players_text"
        type=[string]
        optional=$true
    }
    @{
        # emoji IDs used to provide pictures for each boss. Due to limitations of
        # the webhook API, we can't use normal image URLs, but only emojis
        # Each boss can have one emoji associated. If the map is empty for that boss
        # then only the boss name will appear, without any emoji icon.
        name="emoji_map"
        type=[PSCustomObject]
    }
    @{
        # If set to true, format-encounters will publish every post to this guilds
        # discord. If unset or if set to false, only the encounters which match
        # this guild will be published to the guild's discord.
        name="everything"
        type=[bool]
        optional=$true
        default=$false
    }
    @{
        # If set to true, format-encounters will show the approximate duration that
        # the encounter took as part of the link line. If set to false, this duration
        # will not be displayed. Defaults to true.
        name="show_duration"
        type=[bool]
        optional=$true
        default=$true
    }
)

$v2ConfigurationFields = $commonConfigurationFields +
@(
    @{
        name="guilds"
        type=[Object[]]
        arrayFields=$v2ValidGuildFields
    }
)

<#
 .Description
 An enumeration defining methods for converting path-like fields

 This enumeration defines the methods of converting path-like strings, which
 support reading %UserProfile% as the $env.UserProfile environment variable.

 FromUserProfile will allow converting the %UserProfile% string to the
 UserProfile environment variable when reading the config in from disk.

 ToUserProfile will allow converting the value of the UserProfile environment
 variable into %UserProfile% when writing back out to disk.
#>
Add-Type -TypeDefinition @"
    public enum PathConversion
    {
        FromUserProfile,
        ToUserProfile,
    }
"@

<#
 .Synopsis
  Validate fields of an object

 .Description
  Given a set of field definitions, validate that the given object has fields
  of the correct type, possibly recursively.

  Return the object on success, with updated path data if necessary. Unknown fields
  will be removed from the returned object.

  Return $null if the object has invalid fields or is missing required fields.

 .Parameter object
  The object to validate

 .Parameter fields
  The field definition

 .Parameter RequiredFields
  Specifies which fiels are required to exist. If a required field is missing, an error is
  generated.

 .Parameter conversion using the PathConversion enum
  Optional parameter specifying how to convert path-like configuration values. The
  default mode is to convert from %UserProfile% to the environment value for UserProfile
#>
Function Validate-Object-Fields {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Object,
          [Parameter(Mandatory)][array]$Fields,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$RequiredFields,
          [PathConversion]$conversion = [PathConversion]::FromUserProfile)

    # Make sure all the required parameters are actually valid
    ForEach ($parameter in $RequiredFields) {
        if ($parameter -notin ($Fields | ForEach-Object { $_.name })) {
            Read-Host -Prompt "BUG: $parameter is not a valid parameter. Press enter to exit"
            exit
        }
    }

    # Select only the known properties, ignoring unknown properties
    $Object = $Object | Select-Object -Property ($Fields | ForEach-Object { $_.name } | where { $Object."$_" -ne $null })

    $invalid = $false
    foreach ($field in $Fields) {
        # Make sure required parameters are available
        if (-not (Get-Member -InputObject $Object -Name $field.name)) {
            # optional fields with a default value are never required. If not present, set their default value
            if ($field.optional -or $field.default) {
                $Object | Add-Member -Name $field.name -Value $field.default -MemberType NoteProperty
            } elseif ($field.name -in $RequiredFields) {
                Write-Host "$($field.name) is a required parameter for this script."
                $invalid = $true
            }
            continue
        }

        # Make sure that the field has the expected type
        if ($Object."$($field.name)" -isnot $field.type) {
            Write-Host "$($field.name) has an unexpected type [$($Object."$($field.name)".GetType().name)]"
            $invalid = $true
            continue;
        }

        if ($field.path) {
            # Handle %UserProfile% in path fields
            switch ($conversion) {
                "FromUserProfile" {
                    $Object."$($field.name)" = $Object."$($field.name)".replace("%UserProfile%", $env:USERPROFILE)
                }
                "ToUserProfile" {
                    $Object."$($field.name)" = $Object."$($field.name)".replace($env:USERPROFILE, "%UserProfile%")
                }
            }
        } elseif ($field.validFields) {
            # Recursively validate subfields. All fields not explicitly marked "optional" must be present
            $Object."$($field.name)" = Validate-Object-Fields $Object."$($field.name)" $field.validFields ($field.validFields | where { -not ( $_.optional -eq $true ) } | ForEach-Object { $_.name } )
        } elseif ($field.arrayFields) {
            # Recursively validate subfields of an array of objects. All fields not explicitly marked "optional" must be present
            $ValidatedSubObjects = @()

            $arrayObjectInvalid = $false

            ForEach ($SubObject in $Object."$($field.name)") {
                $SubObject = Validate-Object-Fields $SubObject $field.arrayFields ($field.arrayFields | where { -not ( $_.optional -eq $true ) } | ForEach-Object { $_.name } )
                if (-not $SubObject) {
                    $arrayObjectInvalid = $true
                    break;
                }
                $ValidatedSubObjects += $SubObject
            }
            # If any of the sub fields was invalid, the whole array is invalid
            if ($arrayObjectInvalid) {
                $Object."$($field.name)" = $null
            } else {
                $Object."$($field.name)" = $ValidatedSubObjects
            }
        } elseif ($field.validStrings) {
            # First, canonicalize strings
            $fieldname = $field.name
            $raw_value = $Object."$fieldname"

            if ($field.alternativeStrings -and $field.alternativeStrings.Contains($raw_value)) {
                $value = $field.alternativeStrings[$raw_value]

                # Update the Object value to match the canonical representation
                $Object."$fieldname" = $value
            } else {
                $value = $raw_value
            }

            if (-not $field.validStrings.Contains($value)) {
                Write-Host "${raw_value} is not a valid value for $fieldname"

                $invalid = $true
            }
        }

        # If the subfield is now null, then the recursive validation failed, and this whole field is invalid
        if ($Object."$($field.name)" -eq $null) {
            $invalid = $true
        }
    }

    if ($invalid) {
        Read-Host -Prompt "Configuration file has invalid parameters. Press enter to exit"
        return
    }

    return $Object
}

<#
 .Synopsis
  Validate a configuration object to make sure it has correct fields

 .Description
  Take a $config object, and verify that it has valid parameters with the expected
  information and types. Return the $config object on success (with updated path names)
  Return $null if the $config object is not valid.

 .Parameter config
  The configuration object to validate

 .Parameter version
  The expected configuration version, used to ensure that the config object matches
  the configuration version used by the script requesting it.

 .Parameter RequiredParameters
  The parameters that are required by the invoking script

 .Parameter conversion using the PathConversion enum
  Optional parameter specifying how to convert path-like configuration values. The
  default mode is to convert from %UserProfile% to the environment value for UserProfile
#>
Function Validate-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][int]$version,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$RequiredParameters,
          [PathConversion]$conversion = [PathConversion]::FromUserProfile)

    if ($version -eq 1) {
        $configurationFields = $v1ConfigurationFields
    } elseif ($version -eq 2) {
        $configurationFields = $v2ConfigurationFields
    } else {
        Read-Host -Prompt "BUG: configuration validation does not support version ${version}. Press enter to exit"
        exit
    }

    # Make sure the config_version is set to 1. This should only be bumped if
    # the expected configuration names change. New fields should not cause a
    # bump in this version, but only removal or change of fields.
    #
    # Scripts should be resilient against new parameters not being configured.
    if ($config.config_version -ne $version) {
        Read-Host -Prompt "This script only knows how to understand config_version=${version}. Press enter to exit"
        return
    }

    $config = Validate-Object-Fields $config $configurationFields $RequiredParameters $conversion

    return $config
}

<#
 .Synopsis
  Load the configuration file and return a configuration object

 .Description
  Load the specified configuration file and return a valid configuration
  object. Will ignore unknown fields in the configuration JSON, and will
  convert magic path strings in path-like fields

 .Parameter ConfigFile
  The configuration file to load

 .Parameter version
  The version of the config file we expect, defaults to 1 currently.

 .Parameter RequiredParameters
  An array of parameters required by the script. Will ensure that the generated
  config object has non-null values for the specified paramters. Defaults to
  an empty array, meaning no parameters are required.
#>
Function Load-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigFile,
          [int]$version = 2,
          [AllowEmptyCollection()][array]$RequiredParameters = @())

    # Check that the configuration file path is valid
    if (-not (X-Test-Path $ConfigFile)) {
        Read-Host -Prompt "Unable to locate the configuration file. Press enter to exit"
        return
    }

    # Parse the configuration file and convert it from JSON
    try {
        $config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
    } catch {
        Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
        Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
        Write-Host "Unable to read the configuration file"
        Read-Host -Prompt "Press enter to exit"
        return
    }

    $config = (Validate-Configuration $config $version $RequiredParameters FromUserProfile)
    if (-not $config) {
        return
    }

    return $config
}

<#
 .Synopsis
  Return true if this is a fractal id, false otherise

 .Parameter id
  The ArcDPS EVTC encounter id
#>
Function Is-Fractal-Encounter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$id)

    # 99CM and 100CM encounter IDs
    $FractalIds = @(0x427d, 0x4284, 0x4234, 0x44e0, 0x461d, 0x455f)

    return [bool]($id -in $FractalIds)
}

<#
 .Synopsis
  Determine which guild "ran" this encounter.

 .Description
  Given a list of players and an encounter id, determine which guild ran this
  encounter. We determine which guild the encounter belongs to by picking
  the guild who has the most players involved. If there is a tie, we break it
  by the priority.

  If the encounter is a fractal, then only guilds  who have fractals set to
  true will be considered. Thus, even if one guild has more members in the
  encounter, but does not have have fractals set to true, the encounter
  may be associated with the smaller guild in this case.

 .Parameter guilds
  The array of guilds to consider

 .Parameter players
  An array of players who were involved in this encounter

 .Parameter id
  The encounter id, used to determine whether this was a fractal
#>
Function Determine-Guild {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Object[]]$Guilds,
          [Parameter(Mandatory)][array]$Players,
          [Parameter(Mandatory)][int]$id)

    # First remove any non-fractal guilds
    if (Is-Fractal-Encounter $id) {
        $AvailableGuilds = $Guilds | where { $_.fractals }
    } else {
        $AvailableGuilds = $Guilds | where { $_.raids }
    }

    $GuildData = $AvailableGuilds | ForEach-Object {
        $guild = $_
        $activeMembers = @($players | where {(Keys $guild.discord_map) -Contains $_}).Length

        # Only consider this guild if it meets the player threshold
        if ($activeMembers -lt $guild.threshold) {
            return
        }

        # Return a data object indicating the name, priority, and number of
        # active members in this encounter
        return [PSCustomObject]@{
            name = $guild.name
            priority = $guild.priority
            activeMembers = $activeMembers
        }
    }

    # No suitable guild was found
    if ($GuildData.Length -eq 0) {
        return
    }

    # Return the name of the most eligible guild
    return @($GuildData | Sort-Object @{Expression="activeMembers";Descending=$true},priority)[0].name
}

<#
 .Synopsis
  Print out details about an exception that occurred.

 .Description
  Write out details about an exception that was caught.

 .Parameter e
  The exception object to dump.
#>
Function Write-Exception {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Object]$e)

    # Combine the exception and invocation parameters together into a single list
    $info = $e.InvocationInfo | Select *
    $e.Exception | Get-Member -MemberType Property | ForEach-Object {
        $info | Add-Member -MemberType NoteProperty -Name $_.Name -Value ( $e.Exception | Select-Object -ExpandProperty $_.Name )
    }

    Write-Error ( $info | Format-List -Force | Out-String) -ErrorAction Continue
}

<#
 .Synopsis
  Write configuration object back out to a file

 .Description
  Writes the given configuration object back out to a file. It will also convert the profile
  directory back to %UserProfile% so that the config is more easily re-usable.

 .Parameter config
  The config object to print out

 .Parameter file
  The path to the configuration file
#>
Function Write-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Config,
          [Parameter(Mandatory)][string]$ConfigFile,
          [Parameter(Mandatory)][string]$BackupFile)

    if (X-Test-Path $ConfigFile) {
        if (X-Test-Path $BackupFile) {
            throw "The backup file must be deleted prior to writing out the configuration file"
        }
        Move-Item $ConfigFile $BackupFile
    }

    # Make sure any changes are valid. Convert the UserProfile path back to %UserProfile%.
    $writeConfig = (Validate-Configuration $Config $Config.config_version @() ToUserProfile)
    if (-not $writeConfig) {
        throw "The configuration object is not valid."
    }

    # Write out the configuration to disk
    $writeConfig | ConvertTo-Json -Depth 10 | Out-File -Force $ConfigFile
}

# ConvertTo-JSON doesn't handle unicode characters very well, but we want to
# insert a zero-width space. To do so, we'll implement a variant that replaces
# a magic string with the expected value
#
# More strings can be added here if necessary. The initial string should be
# something innocuous which won't be generated as part of any URL or other
# generated text, and is unlikely to appear on accident
<#
 .Synopsis
  Convert encounter payload to a JSON string, converting some magic strings
  to unicode

 .Description
  ConvertTo-JSON doesn't handle some unicode characters very well, and by
  default doesn't have a depth large enough to convert the encounter structures
  into JSON.

  To handle this, Convert-Payload will convert the given payload data for a webhook
  into JSON using -Depth 10. Additionally it will convert some magic strings which
  represent unicode characters, so that we can insert the unicode characters properly.

 .Parameter payload
  The payload custom object to convert.
#>
Function Convert-Payload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$payload)

    # Convert the object into a JSON string, using an increased
    # depth so that the ConvertTo-Json will completely convert
    # the layered object into JSON.
    $json = ($payload | ConvertTo-Json -Depth 10)

    # Map some custom strings to their unicode equivalents. If we need
    # to use other unicode characters, they should be added here.
    $unicode_map = @{"@UNICODE-ZWS@"="\u200b";
                     "@BOXDASH@"="\u2500";
                     "@EMDASH@"="\u2014";
                     "@MIDDLEDOT@"="\u00B7"}

    # Because ConvertTo-Json doesn't really handle all of the
    # unicode characters, we need to insert these after the fact by
    # replacing the magic strings with unicode escape sequences.
    $unicode_map.GetEnumerator() | ForEach-Object {
        $json = $json.replace($_.key, $_.value)
    }
    return $json
}

<#
 .Synopsis
  Look up the guild object based on the name

 .Description
  Find the first matching guild object from configuration based on the
  guild name. Returns $null if no guilds by that name exist in configuration

 .Parameter config
  The configuration object

 .Parameter guild_name
  The guild name to lookup
#>

Function Lookup-Guild {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$guild_name)

    ForEach ($guild in $config.guilds) {
        if ($guild.name -eq $guild_name) {
            return $guild
        }
    }

    return $null
}

<#
 .Synopsis
  Convert GuildWars 2 account names to discord users

 .Description
  Given an array of GuildWars 2 account names, convert to a list of players
  based on their discord name.

  If the guild has configured show_players to "none", this will return an
  empty array.

  If the guild has configured show_players to "discord_only", then only
  the discord mapped names will be returned. Other account names will be
  discarded.

  If the guild has configured show_players to "accounts_only", then only
  the account names will be returned, without discord pings.

  If the guild has configured show_players to "discord_if_possible" (the
  default), then discord mapped names will be preferred, but account
  names will be returned if no discord map is configured.

  Account names are returned with italic markdown.

 .Parameter guild
  The guild object to use for checking discord mappings

 .Parameter accounts
  The accounts to convert
#>
Function Get-Discord-Players {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$guild,
          [Parameter(Mandatory)][array]$accounts)

    $names = @()

    # Add the prefix string to the front of the array
    if ($guild.prefix_players_text) {
        $names += $($guild.prefix_players_text)
    }

    # Return nothing if show_players is set to "none
    if ($guild.show_players -eq "none") {
        return $names
    }

    $show_discord = ($guild.show_players -in @("discord_only", "discord_if_possible"))
    $show_accounts = ($guild.show_players -in @("accounts_only", "discord_if_possible"))

    ForEach ($account in ($accounts | where {$_.trim() } | Sort)) {
        if ($show_discord -and $guild.discord_map."$account") {
            $names += @($guild.discord_map."$account")
        } elseif ($show_accounts) {
            $names += @("_${account}_")
        }
    }

    return $names
}

<#
 .Synopsis
  Given a boss name, look up the associated raid wing or fractal CM

 .Description
  Convert the boss name into the equivalent wing. Additionally, convert the
  fractal bosses into their respective CMs as well.

 .Parameter boss_name
  The boss name to lookup
#>
Function Convert-Boss-To-Wing {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$boss_name)

    $wings = @{"Vale Guardian"=1;
               "Gorseval"=1;
               "Sabetha"=1;
               "Slothasor"=2;
               "Matthias"=2;
               "Keep Construct"=3;
               "Xera"=3;
               "Cairn"=4;
               "Mursaat Overseer"=4;
               "Samarog"=4;
               "Deimos"=4;
               "Soulless Horror"=5;
               "Dhuum"=5;
               "Conjured Amalgamate"=6;
               "Largos Twins"=6;
               "Qadim"=6;
               "MAMA (CM)"="99cm";
               "Siax (CM)"="99cm";
               "Ensolyss (CM)"="99cm";
               "Skorvald (CM)"="100cm";
               "Artsariiv (CM)"="100cm";
               "Arkk (CM)"="100cm";}

    try {
        return $wings[$boss_name];
    } catch {
        return $null
    }
}

<#
 .Synopsis
  Get the abbreviated name for a boss, if there is one

 .Description
  Some boss names are a bit too long when displayed in an embed, and result in
  unwanted spacing of multiple bosses when viewed in the desktop view. To fix this
  we abbreviate some of them to a shorter version that doesn't cause the embeds to
  have awkward spacing.

 .Parameter boss_name
  The boss name to abbreviate
#>
Function Get-Abbreviated-Name {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$boss_name)

    if ($boss_name -eq "Conjured Amalgamate") {
        return "Amalgamate"
    }

    if ($boss_name -eq "Skorvald the Shattered (CM)") {
        return "Skorvald (CM)"
    }

    # Currently no other boss has an abbreviation, so just return the full name
    return $boss_name
}

<#
 .Synopsis
  Create a boss hashtable from a local EVTC folder

 .Description
  Given the EVTC name, lookup the local data created by upload-logs.ps1 and
  generate a boss hash table for use with Format-And-Publish functions.

 .Parameter config
  The config object

 .Parameter evtc
  The EVTC local folder to read from
#>
Function Load-From-EVTC {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$evtc)

    $boss = @{}

    # Look up the extras data generated by upload-logs.ps1, and keep track of it
    $extras_path = [io.path]::combine($config.extra_upload_data, $evtc)
    if (-not (X-Test-Path $extras_path)) {
        throw "Unable to locate extras data for $evtc"
    }
    $boss["extras_path"] = $extras_path

    # Get the dps.report link
    $dpsreport_json = [io.path]::combine($extras_path, "dpsreport.json")
    if (X-Test-Path $dpsreport_json) {
        $boss["dps_report"] = (Get-Content -Raw -Path $dpsreport_json | ConvertFrom-Json).permalink
    }

    # Get the gw2raidar link if it exists (gw2raidar.json contains upload data, not the permalink!)
    $gw2raidar_json = [io.path]::combine($extras_path, "gw2raidar_permalink.json")
    if (X-Test-Path $gw2raidar_json) {
        $boss["gw2raidar"] = (Get-Content -Raw -Path $gw2raidar_json | ConvertFrom-Json)
    }

    # Get the player account information
    $accounts_json = [io.path]::combine($extras_path, "accounts.json")
    if (-not (X-Test-Path $accounts_json)) {
        throw "$evtc doesn't appear to have accounts data associated with it"
    }
    $boss["players"] = (Get-Content -Raw -Path $accounts_json | ConvertFrom-Json)

    # Get the guild information
    $guild_json = [io.path]::combine($extras_path, "guild.json")
    if (-not (X-Test-Path $guild_json)) {
        throw "$evtc doesn't appear to have guild information associated with it"
    }
    $boss["guild"] = (Get-Content -Raw -Path $guild_json | ConvertFrom-Json)

    # Get the server start time
    $servertime_json = [io.path]::combine($extras_path, "servertime.json")
    if (-not (X-Test-Path $servertime_json)) {
        throw "$evtc doesn't appear to have server start time associated with it"
    }
    $servertime = (Get-Content -Raw -Path $servertime_json | ConvertFrom-Json)
    $boss["servertime"] = [int]$servertime
    $boss["time"] = ConvertFrom-UnixDate $servertime

    $precise_duration_json = [io.path]::combine($extras_path, "precise_duration.json")
    if (X-Test-Path $precise_duration_json) {
        $precise_duration = (Get-Content -Raw -Path $precise_duration_json | ConvertFrom-Json)
        $boss["duration"] = [int]($precise_duration / 1000)
        $span = [TimeSpan]::FromMilliseconds($precise_duration)
        $minutes = New-TimeSpan -Minutes ([math]::floor($span.TotalMinutes))
        $millis = $span - $minutes
        $duration_string = "$($minutes.Minutes)m $(($millis.TotalMilliseconds / 1000).ToString("00.00"))s"
        $boss["duration_string"] = $duration_string
    } else {
        # Get the encounter duration (in difference of unix timestamps)
        $duration_json = [io.path]::combine($extras_path, "duration.json")
        if (X-Test-Path $duration_json) {
            $duration = (Get-Content -Raw -Path $duration_json | ConvertFrom-Json)
            $boss["duration"] = [int]$duration
            $span = New-TimeSpan -Seconds $duration
            $duration_string = "$([math]::floor($span.TotalMinutes))m $($span.Seconds.ToString("00"))s"
            $boss["duration_string"] = $duration_string
        }
    }

    # Get the encounter name
    $encounter_json = [io.path]::combine($extras_path, "encounter.json")
    if (-not (X-Test-Path $encounter_json)) {
        throw "$evtc doesn't appear to have an encounter name associated with it"
    }
    $boss["name"] = (Get-Content -Raw -Path $encounter_json | ConvertFrom-Json)

    # Get an abbreviated name, if there is one
    $boss["shortname"] = Get-Abbreviated-Name $boss["name"]

    # Get the wing for this encounter
    $boss["wing"] = Convert-Boss-To-Wing $boss["name"]

    # Get whether this encounter is a fracal
    $id_json = [io.path]::combine($extras_path, "id.json")
    if (-not (X-Test-Path $id_json)) {
        throw "$evtc doesn't appear to have an encounter id associated with it"
    }
    $boss["id"] = (Get-Content -Raw -Path $id_json | ConvertFrom-Json)
    $boss["is_fractal"] = Is-Fractal-Encounter $boss["id"]

    # Get success status of this encounter
    $success_json = [io.path]::combine($extras_path, "success.json")
    if (-not (X-Test-Path $success_json)) {
        throw "$evtc doesn't appear to have success data associated with it"
    }
    $boss["success"] = ((Get-Content -Raw -Path $success_json | ConvertFrom-Json) -eq "SUCCESS")

    # Get the path to the evtc file
    $evtc_json = [io.path]::combine($extras_path, "evtc.json")
    if (X-Test-Path $evtc_json) {
        $boss["evtc"] = (Get-Content -Raw -Path $evtc_json | ConvertFrom-Json)
    }

    # Get whether the encounter was a challenge mote
    $is_cm_json = [io.path]::combine($extras_path, "is_cm.json")
    if (X-Test-Path $is_cm_json) {
        $is_cm = (Get-Content -Raw -Path $is_cm_json | ConvertFrom-Json)
        if ($is_cm -eq "YES") {
            $boss["is_cm"] = $true
        }
    }

    return $boss
}

<#
 .Synopsis
  Publish a discord embed to a webhook url

 .Description
  Take a JSON string representing a discord webhook embed and publish it to a
  specified discord webhook URL

 .Parameter guild
  The guild to publish to

 .Parameter embed_string
  The discord webhook embed string
#>
Function Publish-Discord-Embed {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$guild,
          [Parameter(Mandatory)][string]$embed_string)

    # Send this request to the discord webhook
    Invoke-RestMethod -Uri $guild.webhook_url -Method Post -Body $embed_string
}

<#
 .Synopsis
  Format and publish a guild's encounters for the day

 .Description
  Format and publish a series of raid encounters to a particular guild's
  discord webhook. Note, this function assumes that the array of bosses
  all take place on the same day, and are run by the same guild. See
  Format-And-Publish-All for a function which can handle arbitrary series
  of boss encounters.

 .Parameter config
  The config object

 .Parameter some_bosses
  An array of boss objects which contain the necessary information to publish.
  Note: assumes that the bosses all take place on a single day with a single guild.

 .Parameter guild
  The guild object of the publishing guild
#>
Function Format-And-Publish-Some {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][array]$some_bosses,
          [Parameter(Mandatory)][object]$guild)

    # List of players who partake in any boss for this day+guild
    $players = @()

    # List of webhook fields for this day+guild
    $fields = @()

    $emoji_map = $guild.emoji_map

    Log-And-Write-Output "Publishing $($some_bosses.Length) encounters to $($guild.name)'s discord"

    # We sort the bosses based on server start time
    ForEach ($boss in $some_bosses | Sort-Object -Property {$_.time}) {
        # Use the shortened name
        $name = $boss.shortname

        # Use the full name first, if that's not found, try the short name
        $emoji = $emoji_map."$($boss.name)"
        if (-not $emoji) {
            $emoji = $emoji_map."$($boss.shortname)"
        }

        if ($boss.is_cm -eq $true) {
            $name += " (CM)"
        }

        $players += $boss.players
        $dps_report = $boss.dps_report
        $gw2raidar = $boss.gw2raidar

        # For each boss, we add a field object to the embed
        #
        # Note that PowerShell's default ConvertTo-Jsom does not handle unicode
        # characters very well, so we use @NAME@ replacement strings to represent
        # these characters, which we'll replace after calling ConvertTo-Json
        # See Convert-Payload for more details
        $boss_field = [PSCustomObject]@{
                # Each boss is just an emoji followed by the full name
                name = "${emoji} **${name}**"
                inline = $true
        }



        if ($dps_report -and $gw2raidar) {
            # We put both the dps.report and gw2raidar link here,  separated by a MIDDLE DOT character
            $link_string = "[dps.report](${dps_report} `"${dps_report}`") @MIDDLEDOT@ [gw2raidar](${gw2raidar} `"${gw2raidar}`")"
        } elseif ($dps_report) {
            $link_string = "[dps.report](${dps_report} `"${dps_report}`")"
        } elseif ($gw2raidar) {
            $link_string = "[gw2raidar](${gw2raidar} `"${gw2raidar}`")"
        } else {
            # In the rare case we somehow end up here with no link, just put "N/A"
            $link_string = "N/A"
        }

        # Determine if we want to add durations. By default we will, unless they are
        # explicitely disabled in the guild configuration.
        if ($guild.add_duration -eq $true -or $guild.add_duration -eq $null) {
            $add_duration = $true
        } else {
            $add_duration = $false
        }

        # If we have a duration string, add it to the end of the links
        # However, show "(FAILED)" for encounters which are failures instead
        # of showing a duration.
        if (-not $boss.success) {
            $link_string += " (FAILED)"
        } elseif ($add_duration -and $boss.duration_string) {
            $link_string += " ($($boss.duration_string))"
        }

        # Add a new line and a zero-width space, to trick discord into adding extra padding
        $link_string += "`r`n@UNICODE-ZWS@"

        $boss_field | Add-Member @{value=$link_string}

        # Insert the boss field into the array
        $fields += $boss_field
    }

    # Create a participants list separated by MIDDLE DOT unicode characters
    $participants = (Get-Discord-Players $guild $players | Sort | Select-Object -Unique) -join " @MIDDLEDOT@ "

    # Add a final field as the set of players.
    if ($participants) {
        $fields += [PSCustomObject]@{
            name = "@EMDASH@ Raiders @EMDASH@"
            value = "${participants}"
        }
    }

    # Determine which wings we did
    $wings = $($some_bosses | Sort-Object -Property {$_.time} | ForEach-Object {$_.wing} | Get-Unique) -join ", "

    # Get the date based on the first boss in the list, since we assume all bosses were run on the same date
    $date = Get-Date -Format "MMM d, yyyy" -Date $some_bosses[0].time

    # Get the running guild based on the first boss in the list, since we assume all bosses were run by the same guild
    $running_guild = Lookup-Guild $config $some_bosses[0].guild

    # Print "Fractals" if this is a set of fractals, otherwise print "Wings", determined from the first encounter
    if ($some_bosses[0].is_fractal) {
        $prefix = "Fractals"
    } else {
        $prefix = "Wings"
    }

    # Create the data object
    $data_object = [PSCustomObject]@{
        title = "$($running_guild.name) ${prefix}: ${wings} | ${date}"
        color = 0xf9a825
        fields = $fields
	footer = [PSCustomObject]@{ text = "Created by /u/platinummyr" }
    }
    if ($running_guild.thumbnail) {
        $thumbnail = [PSCustomObject]@{
            url = $guild.thumbnail
        }
        $data_object | Add-Member @{thumbnail=$thumbnail}
    }

    # Create the payload object
    $payload = [PSCustomObject]@{
        embeds = @($data_object)
    }

    # Convert the payload to JSON suitable for the discord webhook API
    $payload_content = (Convert-Payload $payload)

    # if debug_mode is enabled, dump the embed contents to the console output
    if ($config.debug_mode) {
        $payload_content | Write-Output
    }

    # Use the current time to get a somewhat unique name for the recorded
    # file. This way we can easily re-use older encounters. Alternatively
    # we could try to find some unique way to hash the contents, so that re-posts
    # would use the same time as before..? But whatever method needs to produce
    # a unique string so that each published encounter is saved to a separate file
    $datestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if (X-Test-Path $config.discord_json_data) {
        # Use the running and publishing guilds in the name, but strip out the
        # [] characters, as they can confuse io.path as wildcard characters.
        $found = $running_guild.name -match '^\[.*\]$'
        if ($found) {
            $short_runner = $matches[1]
        } else {
            $short_runner = $running_guild.name
        }
        $found = $guild.name -match '^\[.*\]$'
        if ($found) {
            $short_publisher = $matches[1]
        } else {
            $short_publisher = $guild.name
        }

        # Store the complete JSON we generated for later debugging
        $discord_json_file = [io.path]::combine($config.discord_json_data, "discord-webhook-$short_runner-$datestamp-published-on-$short_publisher.txt")
        $payload_content | Out-File $discord_json_file
    }

    Publish-Discord-Embed $guild $payload_content
}

<#
 .Synopsis
  Get the sub element of a nested hash/array table

 .Description
  Given a hash table, get the sub element for a given key. If the key
  is not yet contained by the hash table, then add a sub element using
  the specified default value.

  Used to extract and build up nested hashes, essentially creating
  multi-dimensional hash tables.

 .Parameter hash
  The hash to grab a sub element from

 .Parameter key
  The key to find the sub element for

 .Parameter default
  The default value for a non-existent sub element.
#>
Function Get-SubHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][HashTable]$hash,
          [Parameter(Mandatory)][object]$key)

    if (-not $hash.ContainsKey($key)) {
        $hash[$key] = @{}
    }

    return $hash[$key]
}

<#
 .Synopsis
  Split a collection of encounters into a nested hash

 .Description
  Take an array of bosses and split it into a nested hash keyed first
  by the date the encounter was run, followed by the guild which ran the
  encounter, and finally followed by whether it is a fractal or a raid.
  This allows us to group together similar sets of encounters and post
  them by the date they were run.

 .Parameter bosses
  The array of bosses to split
#>
Function Split-Bosses {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$bosses)

    $per_date = @{}

    foreach ($b in $bosses) {
        # Get the per_guild hash for this date
        $per_guild = Get-SubHash $per_date $b.time.Date

        # Get the per_type hash for this guild+date
        $per_type = Get-SubHash $per_guild $b.guild

        # Add this boss to the list of bosses in this type+guild+date
        if (-not $per_type.ContainsKey($b.is_fractal)) {
            $per_type[$b.is_fractal] = @()
        }
        $per_type[$b.is_fractal] += @($b)
    }

    return $per_date
}

<#
 .Synopsis
  Format and publish a series of bosses to their respective discord channels

 .Description
  Publish a series of raid encounters to the discord channel configured for each guild.

  The encounters are first split by the date and then by the guild. Each combination of
  date and guild and type are then formatted and published to the respective guild's
  webhook url.

  In addition, the encounter may be published to other guild channels marked as "everything"

 .Parameter config
  The config object

 .Parameter bosses
  An array of boss objects which contain the necessary information to publish
#>
Function Format-And-Publish-All {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$bosses)

    # Split the bosses into a set of nested hashes
    $per_date = Split-Bosses $bosses


    # For each date that encounters were run...
    $per_date.GetEnumerator() | Sort-Object -Property {$_.Key}, key | ForEach-Object {
        $per_guild = $_.Value

        # .. and for each guild that ran encounters that day...
        $per_guild.GetEnumerator() | Sort-Object -Property {$_.Key}, key | ForEach-Object {
            $per_type = $_.Value

            $guild = Lookup-Guild $config $_.Key

            # ... and for each type of encounter (fractal or raids)...
            $per_type.GetEnumerator() | Sort-Object -Property {$_.Key}, key | ForEach-Object {
                $some_bosses = $_.Value

                # ... Format and publish this guild's encounters for the day to the guild's channel
                Format-And-Publish-Some $config $some_bosses $guild

                # Also publish it to other guilds marked with "everything" and which have a different webhook URL
                ForEach ($extra_guild in ( $config.guilds | where { ( $_.everything -eq $true ) -and ( $_.webhook_url -ne $guild.webhook_url ) } ) ) {
                    Format-And-Publish-Some $config $some_bosses $extra_guild
                }
            }
        }
    }
}

<#
 .Synopsis
  Maybe upload a file to dps.report

 .Description
  Upload a file to the dps.report website, and store the returned contents
  of the upload. This includes the dps.report permalink.

  If upload_dps_report is configured "all" then all encounters will be
  uploaded. If it is "successful" then only the successful encounters will be
  uploaded. If it is "no", then this function will return immediately and will not
  upload any encounter to dps.report

  If you wish to manually force upload of specific encounters, ignoring the
  configuration, use UploadTo-DpsReport instead.

 .Parameter config
  The configuration object

 .Parameter file
  The file to upload to dps.report

 .Parameter extras_dir
  The path to the extras directory for storing extra data about this file

 .Parameter success
  True if the encounter was a success, false otherwise
#>
Function Maybe-UploadTo-DpsReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$file,
          [Parameter(Mandatory)][string]$extras_dir,
          [Parameter(Mandatory)][bool]$success)

    $upload = $config.upload_dps_report
    if (-not $upload) {
        $upload = "successful"
    }

    if ($upload -eq "no") {
        return
    } elseif ($upload -eq "successful") {
        if (-not $success) {
            return
        }
    } elseif ($upload -eq "all") {
        # Upload everything
    } else {
        # We verify the config value is already valid so this should never happen
        throw "Invalid configuration value for upload_dps_report"
    }

    Log-And-Write-Output "Uploading ${file} to dps.report..."

    UploadTo-DpsReport $config $file $extras_dir
}

<#
 .Synopsis
  Maybe upload a file to dps.report

 .Description
  Upload a file to the dps.report website, and store the returned contents
  of the upload. This includes the dps.report permalink.

  This function always uploads to dps.report regardless of the configuration.
  Use Maybe-UploadTo-DpsReport if you wish to honor the configuration settings
  for uploading.

 .Parameter config
  The configuration object

 .Parameter file
  The file to upload to dps.report

 .Parameter extras_dir
  The path to the extras directory for storing extra data about this file
#>
Function UploadTo-DpsReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$file,
          [Parameter(Mandatory)][string]$extras_dir)

    # Make sure that RestSharp is loaded
    Add-Type -Path $config.restsharp_path

    # Determine what generator to use
    $valid_generators = @( "rh", "ei" )
    $dps_report_generator = $config.dps_report_generator.Trim()
    if ($dps_report_generator -and -not $valid_generators.Contains($dps_report_generator)) {
        throw "Unknown dps.report generator $dps_report_generator"
    }

    $client = New-Object RestSharp.RestClient("https://dps.report")
    $req = New-Object RestSharp.RestRequest("/uploadContent")
    $req.Method = [RestSharp.Method]::POST

    # This depends on the json output being enabled
    $req.AddParameter("json", "1") | Out-Null

    # Enable weapon rotations if using raid heros
    if ($dps_report_generator -eq "rh") {
        $req.AddParameter("rotation_weap", "1") | Out-Null
    }

    # Include the dps.report user token
    $req.AddParameter("userToken", $config.dpsreport_token)

    # Set the generator if it was configured
    if ($dps_report_generator) {
        $req.AddParameter("generator", $dps_report_generator) | Out-Null
    }

    # Increase the default timeout, otherwise we might cancel before the upload finishes
    $req.Timeout = 300000

    $req.AddFile("file", $file) | Out-Null

    $resp = $client.Execute($req)

    if ($resp.ResponseStatus -ne [RestSharp.ResponseStatus]::Completed) {
        throw "Request was not completed"
    }

    if ($resp.StatusCode -ne "OK") {
        $json_resp = ConvertFrom-Json $resp.Content
        Log-And-Write-Output $json_resp.error
        throw "Request failed with status $($resp.StatusCode)"
    }

    $resp.Content | Out-File -FilePath (Join-Path $extras_dir -ChildPath "dpsreport.json")

    Log-And-Write-Output "Upload successful..."
}

<#
 .Synopsis
  Maybe upload a file to Gw2 Raidar

 .Description
  Maybe upload a file to the gw2raidar website, including tag information. Store the
  reported upload id into the extras directory. For now, this does not include
  obtaining the permalink, due to the way that gw2raidar processes encounters.

  If upload_gw2raidar is configured "all" then all encounters will be
  uploaded. If it is "successful" then only the successful encounters will be
  uploaded. If it is "no", then this function will return immediately and will not
  upload any encounter to gw2raidar

  If you wish to manually force upload of specific encounters, ignoring the
  configuration, use UploadTo-Gw2Raidar instead.

 .Parameter config
  The configuration object

 .Parameter file
  The file to upload to gw2raidar

 .Parameter guild
  The guild which ran this encounter, used to determine what tags to insert

 .Parameter extras_dir
  The path to the extras directory for storing extra data about this file

 .Parameter success
  True if the encounter was a success, false otherwise.
#>
Function Maybe-UploadTo-Gw2Raidar {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$file,
          [Parameter(Mandatory)][string]$guild,
          [Parameter(Mandatory)][string]$extras_dir,
          [Parameter(Mandatory)][bool]$success)

    $upload = $config.upload_gw2raidar
    if (-not $upload) {
        $upload = "all"
    }

    if ($upload -eq "no") {
        return
    } elseif ($upload -eq "successful") {
        if (-not $success) {
            return
        }
    } elseif ($upload -eq "all") {
        # Upload everything
    } else {
        # We verify the config value is already valid so this should never happen
        throw "Invalid configuration value for upload_gw2raidar"
    }

    Log-And-Write-Output "Uploading ${file} to gw2raidar..."

    UploadTo-Gw2Raidar $config $file $guild $extras_dir
}

<#
 .Synopsis
  Upload a file to Gw2 Raidar

 .Description
  Upload a file to the gw2raidar website, including tag information. Store the
  reported upload id into the extras directory. For now, this does not include
  obtaining the permalink, due to the way that gw2raidar processes encounters.

  This function always uploads to gw2raidar regardless of the configuration.
  Use Maybe-UploadTo-Gw2Raidar if you wish to honor the configuration settings
  for uploading.

 .Parameter config
  The configuration object

 .Parameter file
  The file to upload to gw2raidar

 .Parameter guild
  The guild which ran this encounter, used to determine what tags to insert

 .Parameter extras_dir
  The path to the extras directory for storing extra data about this file
#>
Function UploadTo-Gw2Raidar {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][string]$file,
          [Parameter(Mandatory)][string]$guild,
          [Parameter(Mandatory)][string]$extras_dir)

    # Make sure that RestSharp is loaded
    Add-Type -Path $config.restsharp_path

    $client = New-Object RestSharp.RestClient("https://www.gw2raidar.com")
    $req = New-Object RestSharp.RestRequest("/api/v2/encounters/new")
    $req.AddHeader("Authorization", "Token $($config.gw2raidar_token)") | Out-Null
    $req.Method = [RestSharp.Method]::PUT

    $req.AddFile("file", $file) | Out-Null

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
        Log-And-Write-Output $resp.Content
        throw "Request failed with status $($resp.StatusCode)"
    }

    # Store the response data so we can use it in potential future gw2raidar APIs
    $resp.Content | Out-File -FilePath (Join-Path $extras_dir -ChildPath "gw2raidar.json")

    Log-And-Write-Output "Upload successful..."
}

<#
 .Synopsis
  Search for the compressed evtc file of a boss hash table and save its path

 .Description
  Given a boss hash table, attempt to locate the compressed EVTC file within
  the uploaded logs. If we find it, store the link as a json file in the
  upload extras folder. Additionally update the boss hash table with this info

 .Parameter config
  The config object

 .Parameter boss
  A boss hash table to update
#>
Function SearchFor-EVTC-File {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][HashTable]$boss)

    # Get the evtc name from the extras path
    $evtc_name = Split-Path -Leaf $boss["extras_path"]

    # Try to find the file, searching for both compressed and uncompressed files
    $files = @(Get-ChildItem -Recurse -File -LiteralPath $config.arcdps_logs | Where-Object { $_.Name -eq "${evtc_name}" -or $_.Name -eq "${evtc_name}.zip" } | ForEach-Object {$_.FullName})

    # Throw an error if we didn't find the file
    if ($files.Count -eq 0) {
        throw "Unable to find the EVTC log file for ${evtc_name}."
    }

    # Throw an error if we found too many files
    if ($files.Count -gt 1) {
        throw "Found the following potential compressed EVTC files fore ${evtc_name}: $($files -join ',')"
    }

    # We found exactly one file, so this must have been the EVTC file
    $files[0] | ConvertTo-Json | Out-File -FilePath (Join-Path $boss["extras_path"] -ChildPath "evtc.json")
    $boss["evtc"] = $files[0]
}

<#
 .Synopsis
  Upload a boss to dps.report

 .Description
  Given a boss hash table, check and see if it was previously uploaded
  to dps.report. If not, upload it, save the permalink, and update
  the boss hash table to reflect the new permalink.

  Used to enable easily uploading an individual encounter, possibly even if
  it didn't succeed before.

 .Parameter config
  The config object

 .Parameter boss
  The boss hash table to upload
#>
Function Complete-UploadTo-DpsReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][HashTable]$boss)


    # First, check if we already have a dps_report link
    if ($boss.Contains("dps_report")) {
        return
    }

    # Some older versions of upload-logs.ps1 would not save the
    # path to the evtc. If this is an old encounter, attempt to search
    # for and find this data now
    if (-not $boss.Contains("evtc")) {
        SearchFor-EVTC-File $config $boss
    }

    # It wasn't previously uploaded, so lets do that now
    UploadTo-DpsReport $config $boss["evtc"] $boss["extras_path"]

    # After the upload, update the hash table to include the new dps.report link
    $dpsreport_json = [io.path]::combine($boss["extras_path"], "dpsreport.json")
    if (X-Test-Path $dpsreport_json) {
        $boss["dps_report"] = (Get-Content -Raw -Path $dpsreport_json | ConvertFrom-Json).permalink
    }
}

<#
 .Synopsis
  Obtain a list of gw2raidar encounters

 .Description
  Fetch the list of gw2raidar encounters via the HTTP REST API. Create and
  return a hash object which connects gw2raidar permalinks to the server
  start times.

 .Parameter config
  The config object

 .Parameter since
  Unix timestamp of earliest encoutner to return
#>
Function Get-GW2-Raidar-Links {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][int]$since)

    # Initial request URL
    $raidar_url = "https://gw2raidar.com"
    $request = "$raidar_url/api/v2/encounters?since=${since}&limit=25"
    $max_link_count = 100

    # TODO: should this be inlined directly with the missing data code, in
    # order to avoid the hash from growing out of bounds? Right now the code
    # is limited to 100 encounters, which means that we can't individually
    # find the link for a gw2raidar encounter which is too old. In practice
    # this isn't a problem now, but could be if we want to find the link
    # for a really old, possibly failed encounter. Ultimately this is due to
    # the nature of gw2raidar API...

    # Hash object for storing encounter permalinks based on their server start time
    $raidar_links = @{}

    do {
        # Get some encounters
        $data = Invoke-RestMethod -Uri $request -Method Get -Headers @{"Authorization" = "Token $($config.gw2raidar_token)"}

        ForEach ($encounter in $data.results) {
            # Store the permalink for this server start time
            $raidar_links[$encounter.started_at] = "$raidar_url/encounter/$($encounter.url_id)"
        }

        # Sanity check to avoid attempting to grab too many links
        if ($raidar_links.count -ge $max_link_count) {
            throw "Attempted to obtain more than $max_link_count gw2raidar links..."
        }

        $request = $data.next
    } while ($request)

    return $raidar_links
}

<#
 .Synopsis
  Given a set of boss objects, save gw2raidar permalinks

 .Description
  For each boss object, find the associated gw2raidar permalink and save it
  in the extras folder.

 .Parameter config
  The config object

 .Parameter bosses
  Array of boss objects
#>
Function Save-Gw2-Raidar-Links {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$bosses)

    $missing = ($bosses | where { -not $_.gw2raidar } | Sort-Object -Property time)

    # If there are no encounters missing data, then we're done!
    if ($missing.count -eq 0) {
        return
    }

    # Get the earliest servertime for a missing encounter
    $since = $missing[0].servertime

    # Obtain gw2raidar links mapped to their start time
    $raidar_links = Get-GW2-Raidar-Links $config $since

    ForEach ($boss in $missing) {
        if ($raidar_links.Contains($boss.servertime)) {
            # Store this link in the hash table
            $boss["gw2raidar"] = $raidar_links[$boss.servertime]

            $extras_path = $boss["extras_path"]

            # Also write this link out to disk for future reference
            $gw2raidar_json = [io.path]::combine($extras_path, "gw2raidar_permalink.json")
            if (X-Test-Path $gw2raidar_json) {
                throw "gw2raidar data has already been saved for this encounter..?"
            }

            $boss["gw2raidar"] | ConvertTo-Json | Out-File -FilePath $gw2raidar_json
        }
    }
}
# SIG # Begin signature block
# MIIFZAYJKoZIhvcNAQcCoIIFVTCCBVECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2ENkKCcKRHblBpoDIsy9kft+
# 56agggMCMIIC/jCCAeagAwIBAgIQFFuA0ERIe5ZFRAzvqUXg0TANBgkqhkiG9w0B
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8uEnAH2UxqxkwYF3soS+
# EOue8pIwDQYJKoZIhvcNAQEBBQAEggEAOT7qyFPp9dlRQxeWSRAD3xFtSNAzsMuF
# oGNQqnm+AV/O9JwOxWgnR9I3w7dyTZJ9Ng24rUkjgNbSc+qhzlTz8hyZ3Dv4kAZd
# JxiizirofRfvas3rZCB2arKFGz4aCt+PY9ARdwZyu7sedCFzPeo2MOtqtEug5+ya
# 5Ph/lzfH+XKHuUfWSIn4NVtKfMZOcnNjLHxxQWSISTsoZ2UqeIPFbKz6UfwDFz6X
# n4g4kvK2EcHzOEhG4kbKiyNhGpQY5tHI+SRJUfe25gbcVABgv4NKp+JMUb2vhrv9
# AM+p5YjgYJ4CHYfpMALyEx6qTAYOwYLRZ/a4lZ90m9JxHldoMhMyVA==
# SIG # End signature block
