# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot "l0g-101086.psm1")

$RequiredParameters = @("simple_arc_parse_path")

$test_data_dir = 'l0g-101086-test-data'

# Load the configuration from the default file
$config = Load-Configuration (Join-Path $test_data_dir "simpleArcParse.json") -Version 2 -RequiredParameters $RequiredParameters
if (-not $config) {
    exit
}

# Path to simpleArcParse program
$simpleArcParse = $config.simple_arc_parse_path


describe 'simpleArcParse version' {
    $version = (& $simpleArcParse version)

    it 'version should be v2.3.0' {
        $version | Should BeExactly 'v2.3.0'
    }
}

$testEncounters = @(
    @{
        name='dhuum-test-log-1.evtc'
        version='EVTC20180508'
        boss_name='Dhuum'
        boss_id=19450
        boss_maxhealth=40000000
        is_cm="YES"
        players=@('Mr Hinky.2159', 'Serena Sedai.3064', 'AsianBagels.8413',
	          'Draykrah.1980', 'diefour.1632', 'Hiredhit.4190',
		  'miniusboye.3840', 'Mithos.5182', 'That Guy.5704',
		  'Dreggon.6598')
        success=$false
        start_time=1526264306
        end_time=1526264944
        local_start_time=414457824
        local_end_time=415095613
        local_reward_time=$null
        local_log_end=415095613
        local_last_event=415095613
        duration=637789
    }
    @{
        name='siax-cm100-test-log-1.evtc'
        version='EVTC20180526'
        boss_name='Siax (CM)'
        boss_id=17028
        boss_maxhealth=6138797
        is_cm="NO"
        players=@('reapex.8546','Serena Sedai.3064','Hexus.8207',
                  'Draykrah.1980','grimfare.4319')
        success=$true
        start_time=1527740549
        end_time=1527740762
        local_start_time=933570140
        local_end_time=933767156
        local_reward_time=933767156
        local_log_end=933782346
        local_last_event=933782346
        duration=197016
    }
    @{
        name='matthias-test-log-1.evtc'
        version='EVTC20180526'
        boss_name='Matthias'
        boss_id='16115'
        boss_maxhealth=25953840
        is_cm="NO"
        players=@('Mr Hinky.2159','Serena Sedai.3064','Draykrah.1980',
                  'diefour.1632','miniusboye.3840','That Guy.5704',
                  'Master of Swag.1402','professor.6342',
                  'AndyJo.8794','AureliaSilvati.6049')
        success=$true
        start_time=1527733808
        end_time=1527734099
        local_start_time=926829216
        local_end_time=927111359
        local_reward_time=927111359
        local_log_end=927120470
        local_last_event=927120470
        duration=282143
    }
    @{
        name='test-log-revision-1.evtc'
        version='EVTC20181002'
        boss_name='Vale Guardian'
        boss_id='15438'
        boss_maxhealth=22021440
        is_cm="NO"
        players=@('AureliaSilvati.6049', 'AndyJo.8794', 'diefour.1632',
                  'Mr Hinky.2159', 'Draykrah.1980', 'miniusboye.3840',
                  'Carilyra.6152', 'Serena Sedai.3064', 'That Guy.5704',
                  'Agvir.9502')
        success=$true
        start_time=1538615095
        end_time=1538615342
        local_start_time=1799427731
        local_end_time=1799664644
        local_reward_time=1799664644
        local_log_end=1799675028
        local_last_event=1799675028
        duration=236913
    }
    @{
        name='freezie.evtc'
        version='EVTC20181214'
        boss_name='Freezie'
        boss_id='21333'
        boss_maxhealth=5898600
        is_cm="NO"
        players=@('Red Chrysanthemum.2759', 'cozzybob.9175', 'Lumelien.1580',
                  'Hogfather.1028', 'eli.7123', 'Yorick.8390',
                  'Cat Whisperer J.2170', 'Shazbot.4328', 'Serena Sedai.3064',
                  'Draykrah.1980')
        success=$true
        start_time=1545111706
        end_time=1545112098
        local_start_time=360257790
        local_end_time=360645304
        local_reward_time=360645304
        local_log_end=360649569
        local_last_event=360649569
        duration=387514
    }
    @{
        name='invalid-precise-duration.evtc'
        version='EVTC20190103'
        boss_name='Artsariiv (CM)'
        boss_id='17949'
        boss_maxhealth=5962266
        is_cm="NO"
        players=@('Jerry Charrcia.7068', 'nightfally.2187', 'Serena Sedai.3064', 'Ryiah.9546', 'eMJay.3154')
        success=$false
        start_time=1546579480
        end_time=0 # This file has no log-end event
        local_start_time=1286303413
        local_end_time=1286580006
        local_reward_time=$null
        local_log_end=$null
        local_last_event=1286580006
        duration=276593
    }
    @{
        name='training-golem-guilds.evtc'
        version='EVTC20190329'
        boss_name='Standard Kitty Golem (1m HP)'
        boss_id=16199
        boss_maxhealth=1000000
        is_cm="NO"
        players=@('Serena Sedai.3064')
        success=$false
        start_time=1554020677
        end_time=1554020713
        local_start_time=1552980697
        local_end_time=1553016887
        local_reward_time=$null
        local_log_end=1553016887
        local_last_event=1553016887
        duration=36190
    }
    @{
        name='20200113-205726-twisted-castle.evtc'
        version='EVTC20200109'
        boss_name='Twisted Castle'
        boss_id=16247
        boss_maxhealth=1892880
        is_cm="NO"
        players=@('Hobo.8563', 'Guaka.7853', 'noobism.8420', 'Serena Sedai.3064', 'HiggsBoson.2648', 'rasputyn.8316', 'vanRijn.8749', 'Phyrekios.7945', 'Nil.6289', 'mrflea.5739')
        success=$true
        start_time=1578977692
        end_time=1578977844
        local_start_time=11409796
        local_end_time=11557012
        local_reward_time=11557012
        local_log_end=11561702
        local_last_event=11561702
        duration=147216
    }
)

ForEach ($encounter in $testEncounters) {
    describe "$($encounter.name) data" {
        $data = (& $simpleArcParse json (Join-Path $test_data_dir $encounter.name)) | ConvertFrom-Json

        describe "header info" {
            it "EVTC version should be $($encounter.version)" {
                $data.header.arcdps_version | Should BeExactly $encounter.version
            }
            # TODO: record the revision for each test file
        }

        describe "boss info" {
            it "boss name should be $($encounter.boss_name)" {
                $data.boss.name | Should BeExactly $encounter.boss_name
            }
            it "boss id should be $($encounter.boss_id)" {
                $data.boss.id | Should BeExactly $encounter.boss_id
            }
            it "should extract encounter success/failure" {
                $data.boss.success | Should BeExactly $encounter.success
            }
            it "should extract encounter duration" {
                $data.boss.duration | Should BeExactly $encounter.duration
            }
            it "should extract Challenge Mote status" {
                $data.boss.is_cm | Should BeExactly $encounter.is_cm
            }
            it "should extract boss maximum health" {
                $data.boss.maxhealth | Should BeExactly $encounter.boss_maxhealth
            }
        }

        describe "local time" {
            $start = $data.local_time.start
            $end = $data.local_time.end

            it "should extract local start time" {
                $start | Should BeExactly $encounter.local_start_time
            }
            it "should extract local end time" {
                $end | Should BeExactly $encounter.local_end_time
            }

            $diff = $end - $start
            it "start minus end should equal duration" {
                $diff | Should BeExactly $encounter.duration
            }

            it "should extract local reward time" {
                $data.local_time.reward | Should BeExactly $encounter.local_reward_time
            }

            it "should extract local log end time" {
                $data.local_time.log_end | Should BeExactly $encounter.local_log_end
            }

            it "should extract local last event time" {
                $data.local_time.last_event | Should BeExactly $encounter.local_last_event
            }
        }

        describe "server time" {
            it "should extract server start time" {
                $data.server_time.start | Should BeExactly $encounter.start_time
            }
            it "should extract local end time" {
                $data.server_time.end | Should BeExactly $encounter.end_time
            }
        }

        describe "player account names" {
            $players = @()

            foreach ($p in $data.players) {
                $players += $p.account
            }

            it "has correct account list" {
                Compare-Object $players $encounter.players | Should be $null
            }
            # TODO: record player character and subgroups for each test file
            # This is a bit tricky due to essentially wanting to compare hashes...

            # For now, manually compare the guild data for one encounter
            if ($encounter.name -eq 'training-golem-guilds.evtc') {
                it "should extract the account name properly" {
                    $data.players[0].account | Should BeExactly 'Serena Sedai.3064'
                }
                it "should extract the character name properly" {
                    $data.players[0].character | Should BeExactly 'Serena Erhardt'
                }
                it "should extract the guild UID properly" {
                    $data.players[0].guid | Should BeExactly '340D2005-59DD-4618-A87B-FAB5FA96D4B3'
                }
                it "should extract the subgroup properly" {
                    $data.players[0].subgroup | Should BeExactly '1'
                }
            }
        }
    }
}
