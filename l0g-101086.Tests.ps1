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

Describe 'Get-Discord-Players' {
    Context "show_players set to 'none'" {
        $guild = [PSCustomObject]@{
            show_players = "none"
            prefix_players_text = ""
            discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
            }
        }

        It 'returns nothing when no prefix is set' {
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @()
        }

        It 'returns the prefix' {
            $guild.prefix_players_text = "@here"
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("@here")
        }

        It 'returns nothing when show_players is set to a garbage value' {
            $guild.prefix_players_text = ""
            $guild.show_players = "garbage"
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @()
        }
    }

    Context "show_players set to 'discord_only'" {
        $guild = [PSCustomObject]@{
            show_players = "discord_only"
            prefix_players_text = ""
            discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
            }
        }

        It 'returns only discord names' {
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("Player One", "Player Two", "Jake")
        }

        It 'returns discord names sorted by the gw2 account name' {
            $guild.discord_map = @{
                "Z.0001" = "A"
                "H.0005" = "B"
                "A.0006" = "C"
            }
            $participants = Get-Discord-Players $guild @("Z.0001", "H.0005", "A.0006")
            $participants | Should -BeExactly @("C", "B", "A")
        }

        It 'returns the prefix if it is set' {
            $guild.prefix_players_text = "@everyone"
            $participants = Get-Discord-Players $guild @("Z.0001", "H.0005", "A.0006")
            $participants | Should -BeExactly @("@everyone", "C", "B", "A")
        }
    }

    Context "show_players set to 'accounts_only'" {
        $guild = [PSCustomObject]@{
            show_players = "accounts_only"
            prefix_players_text = ""
            discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
            }
        }

        It 'returns all the account names' {
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "_Player1.0001_", "_Player2.0002_", "_Serena Sedai.3064_")
        }

        It 'returns account names even if the discord map is unset' {
            $guild.discord_map = $null
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "_Player1.0001_", "_Player2.0002_", "_Serena Sedai.3064_")
        }

        It 'other account names in the discord map dont impact output' {
            $guild.discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
                "Player3.0003" = "Player Three"
            }
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "_Player1.0001_", "_Player2.0002_", "_Serena Sedai.3064_")
        }

        It 'returns the prefix if it is set' {
            $guild.prefix_players_text = "@everyone"
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("@everyone", "_A Pug.0003_", "_Another Pug.0004_", "_Player1.0001_", "_Player2.0002_", "_Serena Sedai.3064_")
        }
    }

    Context "show players set to 'discord_if_possible'" {
        $guild = [PSCustomObject]@{
            show_players = "discord_if_possible"
            prefix_players_text = ""
            discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
            }
        }

        It 'returns a mix of discord and account name' {
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "Player One", "Player Two", "Jake")
        }

        It 'returns account names even if the discord map is unset' {
            $guild.discord_map = $null
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "_Player1.0001_", "_Player2.0002_", "_Serena Sedai.3064_")
        }

        It 'other account names in the discord map dont impact output' {
            $guild.discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
                "Player3.0003" = "Player Three"
            }
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("_A Pug.0003_", "_Another Pug.0004_", "Player One", "Player Two", "Jake")
        }

        It 'returns the prefix if set' {
            $guild.discord_map = @{
                "Serena Sedai.3064" = "Jake"
                "Player1.0001" = "Player One"
                "Player2.0002" = "Player Two"
                "Player3.0003" = "Player Three"
            }
            $guild.prefix_players_text = "A Prefix"
            $participants = Get-Discord-Players $guild @("Serena Sedai.3064", "Player1.0001", "Player2.0002", "A Pug.0003", "Another Pug.0004")
            $participants | Should -BeExactly @("A Prefix", "_A Pug.0003_", "_Another Pug.0004_", "Player One", "Player Two", "Jake")
        }
    }
}
