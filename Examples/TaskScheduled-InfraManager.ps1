Import-Module LittleInfrastructureManager -Verbose

$Options = @{
    DisplayConsole = @{
        ShowTime   = $false
        LogFile    = 'C:\Testing.log'
        TimeFormat = 'yyyy-MM-dd HH:mm:ss'
    }
    Debug          = @{
        DisplayTemplateHTML = $false
        Verbose             = $false
    }
}

$Configuration = [ordered]@{
    Offboarding = @{
        Use        = $true
        Monitoring = @{
            OU = 'OU=Users-Offboarded,OU=Production,DC=ad,DC=evotec,DC=xyz'
        }
        RenameUser = @{
            Use     = $true
            AddText = @{
                Where = 'After' # Before
                Text  = ' (offboarded)'
            }
        }
        Settings   = @{
            Disable   = $true
            HideInGAL = $true

        }
        Groups     = @{
            RemoveAll = $true
        }
    }
}

Start-ProcessingUsers -Configuration $Configuration -Options $Options