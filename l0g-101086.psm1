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
 .Description
  Configuration fields which are valid for a v1 configuration file. Anything
  not listed here will be excluded from the generated $config object. If one
  of the fields has an incorrect type, configuration will fail to be validated.

  If $path is set, then the configuration will allow exchanging %UserProfile%
  for the current $env:USERPROFILE value
#>
$v1ConfigurationFields =
@(
    @{
        name="config_version"
        type=[int]
    }
    @{
        name="debug_mode"
        type=[bool]
    }
    @{
        name="arcdps_logs"
        type=[string]
        path=$true
    }
    @{
        name="discord_json_data"
        type=[string]
        path=$true
    }
    @{
        name="extra_upload_data"
        type=[string]
        path=$true
    }
    @{
        name="gw2raidar_start_map"
        type=[string]
        path=$true
    }
    @{
        name="last_format_file"
        type=[string]
        path=$true
    }
    @{
        name="last_upload_file"
        type=[string]
        path=$true
    }
    @{
        name="simple_arc_parse_path"
        type=[string]
        path=$true
    }
    @{
        name="custom_tags_script"
        type=[string]
        path=$true
    }
    @{
        name="upload_log_file"
        type=[string]
        path=$true
    }
    @{
        name="guildwars2_path"
        type=[string]
        path=$true
    }
    @{
        name="dll_backup_path"
        type=[string]
        path=$true
    }
    @{
        name="gw2raidar_token"
        type=[string]
    }
    @{
        name="dps_report_token"
        type=[string]
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
 .Synopsis
  Validate a configuration object to make sure it has correct fields

 .Description
  Take a $config object, and verify that it has valid parameters with the expected
  information and types. Return the $config object on success (with updated path names)
  Return $null if the $config object is not valid.

 .Parameter config
  The configuration object to validate

 .Parameter RequiredParameters
  The parameters that are required by the invoking script
#>
Function Validate-Configuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$config,
          [Parameter(Mandatory)][int]$version,
          [Parameter(Mandatory)][AllowEmptyCollection()][array]$RequiredParameters)

    if ($version -eq 1) {
        $configurationFields = $v1ConfigurationFields
    } else {
        Read-Host -Prompt "BUG: configuration validation does not support version ${version}. Press enter to exit"
        exit
    }

    # For now, allow an empty config_version
    if (-not $config.PSObject.Properties.Match("config_version")) {
        Write-Host "Configuration file is missing config_version field. This will be required in a future update. Please set it to the value '1'"
        $config.config_version = 1
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

    # Select only the known properties, ignoring unknown properties
    $config = $config | Select-Object -Property ($configurationFields | ForEach-Object { $_.name } | where { $config."$_" -ne $null })

    $invalid = $false
    foreach ($field in $ConfigurationFields) {
        # Make sure required parameters are available
        if (-not (Get-Member -InputObject $config -Name $field.name)) {
            if ($field.name -in $RequiredParameters) {
                Write-Host "$($field.name) is a required parameter for this script."
                $invalid = $true
            }
            continue
        }

        # Make sure that the field has the expected type
        if ($config."$($field.name)" -isnot $field.type) {
            Write-Host "$($field.name) has an unexpected type [$($config."$($field.name)".GetType().name)]"
            $invalid = $true
        }

        # Handle %UserProfile% in path fields
        if ($field.path) {
            $config."$($field.name)" = $config."$($field.name)".replace("%UserProfile%", $env:USERPROFILE)
        }
    }

    if ($invalid) {
        Read-Host -Prompt "Configuration file has invalid parameters. Press enter to exit"
        return
    }

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
          [int]$version = 1,
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
        Write-Host "Unable to read the configuration file: $($_.Exception.Message)"
        Read-Host -Prompt "Press enter to exit"
        return
    }

    $config = (Validate-Configuration $config $version $RequiredParameters)
    if (-not $config) {
        return
    }

    return $config
}
