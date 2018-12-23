# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot "l0g-101086.psm1")

Describe 'Load-Configuration' {
    # Prevent the "Read-Host" prompts from being displayed during tests
    Mock Read-Host {}

    It 'l0g-101086-config.sample.json is loadable' {
        $config = Load-Configuration 'l0g-101086-config.sample.json' 2
        $config | Should -Not -BeNullOrEmpty

        # TODO: verify expected output object??
    }

    It 'l0g-101086-config.multipleguilds.json is loadable' {
        $config = Load-Configuration 'l0g-101086-config.multipleguilds.json' 2
        $config | Should -Not -BeNullOrEmpty

        # TODO: verify expected output object??
    }

    # Also verify that the l0g-101086-config.json is loadable if it exists
    if (Test-Path "l0g-101086-config.json" ) {
        It 'l0g-101086-config.json is loadable' {
            $config = Load-Configuration 'l0g-101086-config.json' 2
            $config | Should -Not -BeNullOrEmpty
        }
    }
}
