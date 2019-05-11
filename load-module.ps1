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
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzUH0Rsc1sEY2GRbbXpLCwO75
# rz+gggMYMIIDFDCCAfygAwIBAgIQLNFTiNzlwrtPtvlsLl9i3DANBgkqhkiG9w0B
# AQsFADAiMSAwHgYDVQQDDBdMMEctMTAxMDg2IENvZGUgU2lnbmluZzAeFw0xOTA1
# MTEwNjIxMjNaFw0yMDA1MTEwNjQxMjNaMCIxIDAeBgNVBAMMF0wwRy0xMDEwODYg
# Q29kZSBTaWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz8yX
# +U/I8mljHGNNqj3Yu5m41ibtP7vXqhoFF16AWFMVI26sCFknvKO95h8ByCyyrSJy
# KouRR+bLwYg/a8ElqBA3r3nvnefWzFuj19lYoChautae6n1Yg80/V5XuY9tXjXRs
# LLA+rDCJBDTtku0Y7ahk5KOGwnqxY520BKt8A/MOD3mQnUtxZ88C7Otr4jr+2k9k
# CM7oMD1jJsmFpZxaDinsPiYobs/NRJ4iAlTN+NgwmHrj+Tgpln5GHhCpncUbZ530
# ODbndMwYkW3T7JECjxZYLg4B6CzXFw+SDewIq0svCnIBa+NQYHzNvdwJU5xlTdG+
# n3RSRT0N1UgrUnQ/OQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwHQYDVR0OBBYEFL0r6+kPYUrlpu8rKWwyrLWuc3zNMA0GCSqG
# SIb3DQEBCwUAA4IBAQADr9YRypADuVVOiwbrKYT5GLBa+1wbDHdC9YRWf+kGtKYC
# K4RsIgCngakR6MmksUhNgYRBN6pD4qTOgkUEfxmpLSjTyEYkcslF/Y5sBwiVRqS2
# p38Ay5byGfRRb/KbjndE7vEM0DJg3XWbayiiARhe6Af0FXgg0F7n5AblnZrUuE1x
# 62I5N3lSsH8xjF8BcvtSh+jhDypIBAjyNMwzPvO8hGMoqrpNY5IjvBWrHPGzrm90
# Jju/ucR3d14J6MwoCxcisupXdRhkIE9c4MiW67tf019h4TBnUNzW8DWyoprKAIRV
# qjO6XExzBeHTPOH8olN/oYaOmqUC9c9MEolbolhRMYIB1zCCAdMCAQEwNjAiMSAw
# HgYDVQQDDBdMMEctMTAxMDg2IENvZGUgU2lnbmluZwIQLNFTiNzlwrtPtvlsLl9i
# 3DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQU3t8uZNXwQRe8p6amWDaPGNINOfMwDQYJKoZIhvcN
# AQEBBQAEggEAR25v2/abHwYCASLOTcFjRc6ZksXA1kDego51/46RABBlzLQJsEtH
# fKX7XrjQSC9skG0iC8DJif4o42XhZj/67M+1+KQ7o2D60zLNA4/Og2Kt0dTnJY4j
# XQRl85EVdeN0L+1t/KyIzlTyjgoIzAfdyBaFY0P7WzWZKuu3iWJ6KnbkebEhVwsE
# 8KTU05UR0pdpqs5WQWaytJ5/QNofnRn4ibCsELiwPtC7pi9NUdNX2n93oaPa4ClB
# 3me+cNsP7VopCYbtlfIyzZLtWng0QsDmRJSGjfO6w0539iU44wnFlKk7pK0LSv6S
# w+hEIF+5gplbbA9RSR1HD6y9ER+oQ6dMsA==
# SIG # End signature block
