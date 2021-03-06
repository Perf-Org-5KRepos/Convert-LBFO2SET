Describe 'OSValidation' -Tag PreValidation {
    Context HostOS {
        $NodeOS = Get-CimInstance -ClassName 'Win32_OperatingSystem'
        
        # detect the version of Windows
        $osBldVer = [System.Environment]::OSVersion.Version.Build

        ### Verify the Host is sufficient version
        It "${env:ComputerName}`: Must be Windows Server 2016, or Server 2019" {
            $NodeOS.Caption | Should be ($NodeOS.Caption -like '*Windows Server 2016*' -or $NodeOS.Caption -like '*Windows Server 2019*')
        }

        It "${env:ComputerName}`: Must NOT be a SAC release" {
            # 14393 defines Server 2016 RS1
            # 17763 defines Server 2019 RS5
            $osBldVer | Should -BeIn @(14393, 17763)
        }

        $HyperVInstallation = (Get-WindowsFeature -Name Hyper-V -ComputerName $env:ComputerName -ErrorAction SilentlyContinue).InstallState

        It "${env:ComputerName}`: Must have Hyper-V installed" {
            $HyperVInstallation | Should be 'Installed'
        }

        It "${env:ComputerName}`: LBFO Team [$LBFOTeam] must already exist" {
            $configData.NetLBFOTeam | Should Not BeNullOrEmpty
        }

        It "${env:ComputerName}`: Teaming mode for LBFO team [$LBFOTeam] must not be LACP" {
            $configData.NetLBFOTeam.TeamingMode | Should Not Be 'LACP'
        }

        If ($AllowOutage -eq $false) {
            It "${env:ComputerName} $LBFOTeam`: Must have at least two adapters when -AllowOutage is not set" {
                $configData.NetLBFOTeam.Members.Count | Should BeGreaterThan 1
            }
        }

        # [DONE]TODO: LBFO team should be attached to a vSwitch
        $vSwitch = Get-VMSwitch -ErrorAction SilentlyContinue
        $netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -in $vSwitch.NetAdapterInterfaceDescriptions -and $_.Name -eq $LBFOTeam }

        It "${env:ComputerName}`: LBFO Team [$LBFOTeam] must be attached to a vSwitch" {
            $netAdapter.Name | Should be $LBFOTeam
        }

        $vSwitchExists = $vSwitch | Where-Object Name -eq $SETTeam

        #TODO: Add to Test condition
        If ($vSwitchExists) {
            It "${env:ComputerName}`: The existing SET Team [$SETTeam] must have teaming enabled" {
                $vSwitchExists.EmbeddedTeamingEnabled | Should be $true
            }
        }

        $VmsBinary = Get-Item "$here\helpers\$nicReconnBin" -ErrorAction SilentlyContinue
        It "${env:ComputerName}`: Must have $nicReconnBin in $here\helpers." {
            $VmsBinary.Name | Should be $nicReconnBin
        }
    }
}


Describe 'SETTeam' {
    Context SETTeam {

        It "The virtual switch [$VirtualSwitch] should have SR-IOV enabled" {
            $VMSwitch.IovEnabled | Should be $true
        }

        It "The virtual switch [$VirtualSwitch] SR-IOV Support Reasons property should be empty" {
            (Get-VMSwitch).IovSupportReasons | Should be $null
        }
    }
}
