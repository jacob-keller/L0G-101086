# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 cptnfool <cptnfool@gmail.com>
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# See l0g-101086.psm1 for descriptions of each configuration field
$RequiredParameters = @(
    "launchbuddy_path"
)

# Load the configuration from the default file (version 2)
$config = Load-Configuration "l0g-101086-config.json" 2 $RequiredParameters
if (-not $config) {
    exit
}

& .\update-arcdps.ps1
Start-Process -FilePath $config.launchbuddy_path