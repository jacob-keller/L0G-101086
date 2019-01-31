# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.
# vim: et:ts=4:sw=4

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
$config_file = Get-Config-File
Write-Host -ForegroundColor DarkYellow "Loading the config from ${config_file}"
$config = Load-Configuration $config_file

Write-Host -ForegroundColor Yellow "You can now access the `$config object and module functions"
# SIG # Begin signature block
# MIIFZAYJKoZIhvcNAQcCoIIFVTCCBVECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvpPrN9LT6Chz1Sty7rMfzwZb
# jomgggMCMIIC/jCCAeagAwIBAgIQFFuA0ERIe5ZFRAzvqUXg0TANBgkqhkiG9w0B
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUftrXUMTWQ8paipUvUZB5
# 5lPNsKowDQYJKoZIhvcNAQEBBQAEggEAO+qouhBDD6SYwUrMQkZPUU+c1Nxjl5W+
# ziK0Vy4lA6u0bM8qYqG3tVkzS0bZ6hAD9MN1Nbppdi7AJKVTnaaswvlpqbnGpRvk
# r+Hcix58jng8ee28sZyzzPa2zwRy5dOmxV6gij49Wk3kN05hKCLTnIWFC3ZYQF6q
# wqoEia+fTEJgutMq2P+TFc6rYeBy/l8MFlECcG08Va4ndUOwMXgnzhD6IPa2Z0pT
# F8FmifFVX2IWsxOmZNtlLL3fswRFq0d9csUnb2mJuR1ZCU8XjZ8L+eRKPj3WqAjK
# 9yJEtX6a+zOaQwcc7eJi72wO4gmfQFkaduKOKXNq8ote8FUbT8b8ZQ==
# SIG # End signature block
