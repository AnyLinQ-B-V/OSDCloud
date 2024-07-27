<#
.SYNOPSIS
Deployments of Windows 11 Autopilot/Intune ready with OSDCloud

.DESCRIPTION
This script is used to deploy Windows 11 with OSDCloud.
It will automatically register the device in Autopilot (Intune).
#>

#region Prepare the environment
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host -ForegroundColor DarkMagenta "Setting display response to 1024x"
    Set-DisRes 1920
}

if (-not (Get-InstalledModule -Name 'OSD' -ErrorAction SilentlyContinue)) {
    Install-Module -Name OSD -Force
    Import-Module OSD
}
#endregion

#region Autopilot registration
Invoke-RestMethod https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/Upload-AutopilotHash.ps1 | Invoke-Expression
#endregion

#region Start-OSDCloud configuration
$OSDCloudParameters = @{
    OSVersion = "Windows 11"
    OSBuild = "23H2"
    OSEdition = "Enterprise"
    OSLanguage = "nl-nl"
    OSLicense = "Volume"
    ZTI = $true
}

#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$false
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

Start-OSDCloud @OSDCloudParameters

#region Restart Computer
Write-Host -ForegroundColor DarkMagenta "Restarting in 10 seconds..."
Start-Sleep -Seconds 10
wpeutil reboot
#endregion