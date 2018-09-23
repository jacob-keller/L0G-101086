# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot "l0g-101086.psm1")

$RequiredParameters = @("simple_arc_parse_path")

$test_data_dir = 'l0g-101086-test-data'

# Load the configuration from the default file
# Load the configuration from the default file
$config = Load-Configuration (Join-Path $test_data_dir "simpleArcParse.json") -Version 1 -RequiredParameters $RequiredParameters
if (-not $config) {
    exit
}

# Path to simpleArcParse program
$simpleArcParse = $config.simple_arc_parse_path


describe 'simpleArcParse version' {
    $version = (& $simpleArcParse version)

    it 'version should be v0.11' {
        $version | Should BeExactly 'v0.13'
    }
}

Function ParseHeader($file) {
    (& $simpleArcParse header $file).Split([Environment]::NewLine)
}

Function ParsePlayers($file) {
    (& $simpleArcParse players $file).Split([Environment]::NewLine)
}

$testEncounters = @(
    @{
        name='dhuum-test-log-1.evtc'
        version='EVTC20180508'
        boss_name='Dhuum'
        boss_id=19450
        players=@('Mr Hinky.2159','Serena Sedai.3064','AsianBagels.8413','Draykrah.1980',
                  'diefour.1632','Hiredhit.4190','miniusboye.3840','Mithos.5182',
                  'That Guy.5704','Dreggon.6598')
        success='FAILURE'
        start_time=1526264306
    }
    @{
        name='siax-cm100-test-log-1.evtc'
        version='EVTC20180508'
        boss_name='Siax (CM)'
        boss_id=17028
        players=@('reapex.8546','Serena Sedai.3064','Hexus.8207',
                  'Draykrah.1980','grimfare.4319')
        success='SUCCESS'
        start_time=1527740549
    }
    @{
        name='matthias-test-log-1.evtc'
        version='EVTC20180508'
        boss_name='Matthias'
        boss_id='16115'
        players=@('Mr Hinky.2159','Serena Sedai.3064','Draykrah.1980',
                  'diefour.1632','miniusboye.3840','That Guy.5704',
                  'Master of Swag.1402','professor.6342',
                  'AndyJo.8794','AureliaSilvati.6049')
        success='SUCCESS'
        start_time=1527733808
    }
)

ForEach ($encounter in $testEncounters) {
    describe "$($encounter.name) header" {
        $result = ParseHeader(Join-Path $test_data_dir $encounter.name)

        it "EVTC version should be $($encounter.version)" {
            $result[0] = $encounter.version
        }
        it "boss name should be $($encounter.boss_name)" {
            $result[1] | Should BeExactly $encounter.boss_name
        }
        it "boss id should be $($encounter.boss_id)" {
            $result[2] | Should BeExactly $encounter.boss_id
        }
    }

    describe "$($encounter.name) players" {
        $actualPlayers = ParsePlayers(Join-Path $test_data_dir $encounter.name)

        it "has correct player list" {
            Compare-Object $actualPlayers $encounter.players | Should be $null
        }
    }
    
    describe "$($encounter.name) success" {
        $success = (& $simpleArcParse success (Join-Path $test_data_dir $encounter.name))

        it "should extract encounter failure" {
            $success | Should BeExactly $encounter.success
        }
    }

    describe "$($encounter.name) start_time" {
        $success = (& $simpleArcParse start_time (Join-Path $test_data_dir $encounter.name))

        it "should extract encounter failure" {
            $success | Should BeExactly $encounter.start_time
        }
    }
}
