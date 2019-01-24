# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot "l0g-101086.psm1")

Describe 'Load-Configuration' {
    # Prevent the "Read-Host" prompts from being displayed during tests
    Mock Read-Host {}

    Context 'Verify configuration files are valid' {

        It 'l0g-101086-config.sample.json is loadable' {
            $config = Load-Configuration 'l0g-101086-config.sample.json' 2
            $config | Should -Not -BeNullOrEmpty
        }

        It 'l0g-101086-config.multipleguilds.json is loadable' {
            $config = Load-Configuration 'l0g-101086-config.multipleguilds.json' 2
            $config | Should -Not -BeNullOrEmpty
        }

        # Also verify that the l0g-101086-config.json is loadable if it exists
        if (Test-Path "l0g-101086-config.json" ) {
            It 'l0g-101086-config.json is loadable' {
                $config = Load-Configuration 'l0g-101086-config.json' 2
                $config | Should -Not -BeNullOrEmpty
            }
        }
    }

    $testConfig = "TestDrive:\config.json"

    Context 'Basic configuration file' {
        Set-Content $testConfig -Value @"
{
    "config_version":  2,
    "debug_mode":  false,
    "experimental_arcdps": false,
    "arcdps_logs":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.cbtlogs",
    "discord_json_data":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.webhook_posts",
    "extra_upload_data":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.uploadextras",
    "last_format_file":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\format_encounters_time.json",
    "last_upload_file":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\upload_logs_time.json",
    "simple_arc_parse_path":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\simpleArcParse\\bin\\Release\\simpleArcParse.exe",
    "upload_log_file":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\upload_log.txt",
    "format_encounters_log":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\format_encounters_log.txt",
    "guildwars2_path":  "C:\\Program Files (x86)\\Guild Wars 2",
    "launchbuddy_path":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\gw2launchbuddy\\Gw2.Launchbuddy.exe",
    "dll_backup_path":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.dllbackups",
    "restsharp_path":  "%UserProfile%\\Documents\\Guild Wars 2\\addons\\arcdps\\RestSharp.dll",
    "dps_report_token":  "",
    "dps_report_generator":  "ei",
    "upload_dps_report": "successful",
    "guilds":  [
                   {
                       "name":  "[guild]",
                       "priority":  1,
                       "webhook_url":  "",
                       "threshold":  0,
                       "thumbnail":  "",
                       "raids":  true,
                       "fractals":  false,
                       "discord_map":  {
                                           "Serena Sedai.3064":  "\u003c@119167866103791621\u003e"
                                       },
                       "show_players":  "discord_if_possible",
                       "prefix_players_text":  "",
                       "emoji_map":  {
                                         "Mursaat Overseer":  "\u003c:mo:311579053486243841\u003e",
                                         "Samarog":  "\u003c:sam:311578871214637057\u003e",
                                         "Slothasor":  "\u003c:sloth:311578871206117376\u003e",
                                         "Sabetha":  "\u003c:sab:311578871122231296\u003e",
                                         "Dhuum":  "\u003c:dhuum:399610319464431627\u003e",
                                         "Gorseval":  "\u003c:gors:311578871013310474\u003e",
                                         "Xera":  "\u003c:xera:311578871277289472\u003e",
                                         "Soulless Horror":  "\u003c:horror:386645168289480715\u003e",
                                         "Cairn":  "\u003c:cairn:311578870954590208\u003e",
                                         "Keep Construct":  "\u003c:kc:311578870686023682\u003e",
                                         "Matthias":  "\u003c:matt:311578871105454080\u003e",
                                         "Deimos":  "\u003c:deimos:311578870761652225\u003e",
                                         "Vale Guardian":  "\u003c:vg:311578870933356545\u003e",
                                         "Conjured Amalgamate":  ":ca:",
                                         "Largos Twins":  ":twins:",
                                         "Qadim":  ":qadim:"
                                     }
                   }
               ]
}
"@
        It 'loads the basic config file properly' {
            $config = Load-Configuration $testConfig 2
            $config | Should -Not -BeNullOrEmpty
        }
    }

    Context 'config_version 2 sets default values' {
        Set-Content -Force $testConfig -Value @"
{ "config_version": 2 }
"@

        It 'loads config version 2, and sets defaults for optional/default fields' {
            $config = Load-Configuration $testConfig 2
            $config | Should -Not -BeNullOrEmpty
            $config.config_version | Should -BeExactly 2
            $config.upload_dps_report | Should -BeExactly "successful"
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

Describe 'Split-Bosses' {
    $bosses = @( @{ a=1; b=1 }, @{ a=1; b=2; }, @{ a=2; b=3 }, @{ a=3; b=4; }, @{ a=1; b=5 } )

    It 'correctly splits bosses into sections' {
        $split = Split-Bosses $bosses "a"
        $split.Keys | sort | Should -BeExactly @( 1, 2, 3 )
        $split[1] | Should -BeExactly @( $bosses[0], $bosses[1], $bosses[4] )
        $split[2] | Should -BeExactly @( $bosses[2] )
        $split[3] | Should -BeExactly @( $bosses[3] )
    }
}