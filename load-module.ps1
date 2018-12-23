# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Load the shared module file, and a config object.
# Intended to be used with a shortcut that starts a powershell console with -noexit
# i.e.
#  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -noexit -file "load-module.ps1"
#
# This is useful to load a console that already has the module functions
# and $config available, for debugging or manual uploading, etc.

# Load the shared module]
Write-Host -ForegroundColor DarkYellow "Loading the l0g-101086.psm1 module file"
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# Load the configuration from the default file
Write-Host -ForegroundColor DarkYellow "Loading the config from l0g-101086-config.json"
$config = Load-Configuration "l0g-101086-config.json"

Write-Host -ForegroundColor Yellow "You can now access the `$config object and module functions"