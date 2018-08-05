Function Start-ProcessingUsers {
    param (
        $Configuration,
        $Options
    )
    $Script:WriteParameters = $Options.DisplayConsole

    if ($Configuration.Offboarding.Use) {
        Write-Color @Script:WriteParameters -Text '[i]', ' Running Offboarding process', ' Started' -Color Yellow, White, Red
        if ($Configuration.Offboarding.Monitoring.OU) {
            foreach ($OrganizationalUnit in $Configuration.Offboarding.Monitoring.OU) {
                $OU = Get-ADOrganizationalUnit $OrganizationalUnit
                if ($OU.ObjectClass -eq 'OrganizationalUnit') {
                    if ($Configuration.Offboarding.Settings.HideInGAL) {
                        $Properties = 'DisplayName', 'msExchHideFromAddressLists', 'MemberOf', 'Name'
                    } else {
                        $Properties = 'DisplayName', 'memberof', 'Name'
                    }
                    try {
                        $Users = Get-ADUser -SearchBase $OU.DistinguishedName -Filter * -Properties $Properties
                    } catch {
                        Write-Color @Script:WriteParameters -Text '[i]', ' One or more properties are invalid - Terminating', ' Terminating' -Color Yellow, White, Red
                        return
                    }
                    foreach ($User in $Users) {
                        if ($Configuration.Offboarding.Settings.Disable) {
                            Set-ADUserStatus -User $User -Option Disable
                        }
                        if ($Configuration.Offboarding.Settings.HideInGAL) {
                            Set-ADUserSettingGAL -User $User -Option Hide
                        }
                        if ($Configuration.Offboarding.Groups.RemoveAll) {
                            Remove-ADUserGroups -User $User
                        }
                        if ($Configuration.Offboarding.RenameUser.Use) {
                            Set-ADUserName -User $User -Option $Configuration.Offboarding.RenameUser.AddText.Where -TextToAdd $Configuration.Offboarding.RenameUser.AddText.Text
                        }
                    }
                }
            }
        }
        Write-Color @Script:WriteParameters -Text '[i]', ' Running Offboarding process', ' Ended' -Color Yellow, White, Red
    }
}

function Set-ADUserStatus {
    param (
        [parameter(Mandatory = $true)][Microsoft.ActiveDirectory.Management.ADAccount] $User,
        [parameter(Mandatory = $true)][ValidateSet("Enable", "Disable")][String] $Option
    )
    if ($Option -eq 'Enable' -and $User.Enabled -eq $false) {
        Set-ADUser -Identity $User -Enabled $true
    } elseif ($Option -eq 'Disable' -and $User.Enabled -eq $true) {
        Set-ADUser -Identity $User -Enabled $false
    }
}
function Set-ADUserName {
    param (
        [parameter(Mandatory = $true)][Microsoft.ActiveDirectory.Management.ADAccount] $User,
        [parameter(Mandatory = $true)][ValidateSet("Before", "After")][String] $Option,
        [string[]] $TextToAdd
    )
    if ($TextToAdd -and $User.DisplayName -notlike "*$TextToAdd*") {
        if ($Option -eq 'After') {
            $NewName = "$($User.DisplayName)$TextToAdd"
        } elseif ($Option -eq 'Before') {
            $NewName = "$TextToAdd$($User.DisplayName)"
        } else {
            return # future use
        }
        if ($NewName -ne $User.DisplayName) {
            Write-Color @Script:WriteParameters -Text '[i]', ' Renaming user by adding text "', $TextToAdd, '". Name will be added ', $Option, ' Display Name ', $User.DisplayName, '. New expected name: ', $NewName -Color Yellow, White, Green, White, Yellow, White, Yellow, White
            Set-ADUser -Identity $User -DisplayName $NewName #-WhatIf
            Rename-ADObject -Identity $User -NewName $NewName #-WhatIf
        }
    }
}
Function Set-ADUserSettingGAL {
    param (
        [parameter(Mandatory = $true)][Microsoft.ActiveDirectory.Management.ADAccount] $User,
        [parameter(Mandatory = $true)][ValidateSet("Hide", "Show")][String]$Option
    )
    if ($User) {
        if ($Option -eq 'Hide') {
            if (-not $User.msExchHideFromAddressLists) {
                Write-Color @Script:WriteParameters -Text '[i]', ' Hiding user ', $User.DisplayName, ' in GAL (Exchange Address Lists)' -Color Yellow, White, Green, White, Yellow
                Set-ADObject -Identity $User -Replace @{msExchHideFromAddressLists = $true}
            }
        } elseif ($Option -eq 'Show') {
            if ($User.msExchHideFromAddressLists) {
                Write-Color @Script:WriteParameters -Text '[i]', ' Unhiding user ', $User.DisplayName, ' in GAL (Exchange Address Lists)' -Color Yellow, White, Green, White, Yellow
                Set-ADObject -Identity $User -Clear msExchHideFromAddressLists
            }
        }
    }
}
function Remove-ADUserGroups {
    param(
        [parameter(Mandatory = $true)][Microsoft.ActiveDirectory.Management.ADAccount] $User
    )
    $ADgroups = Get-ADPrincipalGroupMembership -Identity $User | Where-Object {$_.Name -ne "Domain Users"}
    if ($ADgroups) {
        Write-Color @Script:WriteParameters -Text '[i]', ' Removing groups ', ($ADgroups.Name -join ', '), ' from user ', $User.DisplayName -Color Yellow, White, Green, White, Yellow
        Remove-ADPrincipalGroupMembership -Identity $User -MemberOf $ADgroups -Confirm:$false
    } else {
        #Write-Color @Script:WriteParameters -Text '[i]', ' Found no groups to remove from user ', $User.DisplayName -Color Yellow, White, Yellow
    }
}
