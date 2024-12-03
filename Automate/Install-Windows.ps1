<#
.SYNOPSIS
Deployments of Windows 11 Autopilot/Intune ready with OSDCloud

.DESCRIPTION
This script is used to deploy Windows 11 with OSDCloud.
It will automatically register the device in Autopilot (Intune).
#>

#region Prepare the environment
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Virtual environment detected."
}

if (-not (Get-InstalledModule -Name 'OSD' -ErrorAction SilentlyContinue)) {
    Install-Module -Name OSD -Force -SkipPublisherCheck
    Import-Module OSD
}
#endregion

#region Autopilot registration
#Invoke-RestMethod https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/Upload-AutopilotHash.ps1 | Invoke-Expression
Install-Script -Name Get-WindowsAutoPilotInfo -Force
Get-WindowsAutoPilotInfo -Online -GroupTag "AQ-AutoDeployedV2" -Assign
#endregion

#region Start-OSDCloud configuration
$OSDCloudParameters = @{
    OSVersion = "Windows 11"
    OSBuild = "24H2"
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
#endregion

#region [PostOS] OOBEDeploy Configuration
Write-Host -ForegroundColor Green "Create C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json"
$OOBEDeployJson = @'
{
    "AddNetFX3":  {
                      "IsPresent":  true
                  },
    "Autopilot":  {
                      "IsPresent":  false
                  },
    "RemoveAppx":  [
                    "MicrosoftTeams",
                    "Microsoft.BingWeather",
                    "Microsoft.BingNews",
                    "Microsoft.GetHelp",
                    "Microsoft.Getstarted",
                    "Microsoft.Messaging",
                    "Microsoft.MicrosoftOfficeHub",
                    "Microsoft.MicrosoftStickyNotes",
                    "Microsoft.MSPaint",
                    "Microsoft.People",
                    "Microsoft.StorePurchaseApp",
                    "Microsoft.Todos",
                    "microsoft.windowscommunicationsapps",
                    "Microsoft.WindowsFeedbackHub",
                    "Microsoft.WindowsMaps",
                    "Microsoft.WindowsSoundRecorder",
                    "Microsoft.ZuneMusic",
                    "Microsoft.ZuneVideo"
                   ],
    "UpdateDrivers":  {
                          "IsPresent":  true
                      },
    "UpdateWindows":  {
                          "IsPresent":  true
                      }
}
'@
If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}

$OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding ascii -Force
#endregion

#region [PostOS] OOBE CMD Command Line
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"
# Invoke-RestMethod https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/AP-Prereq.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\autopilotprereq.ps1' -Encoding ascii -Force
# Invoke-RestMethod https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/Start-AutopilotOOBE.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\autopilotoobe.ps1' -Encoding ascii -Force

$OOBECMD = @'
@echo off
# Execute OOBE Tasks
# start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\autopilotprereq.ps1
# start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\autopilotoobe.ps1

# Below a PS session for debug and testing in system context, # when not needed 
# start /wait powershell.exe -NoL -ExecutionPolicy Bypass

exit 
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force
#endregion

#region [PostOS] AutopilotOOBE CMD Command Line
Write-Host -ForegroundColor Green "Create C:\Windows\System32\OOBE.cmd"
$OOBECMD = @'
PowerShell -NoL -Com Set-ExecutionPolicy Bypass -Force
Set Path = %PATH%;C:\Program Files\WindowsPowerShell\Scripts
Start /Wait PowerShell -NoL -C Install-Module OSD -Force -Verbose
Start /Wait PowerShell -NoL -C Start-OOBEDeploy
Start /Wait PowerShell -NoL -C Invoke-WebPSScript https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/CleanUp.ps1
Start /Wait PowerShell -NoL -C Restart-Computer -Force
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\System32\OOBE.cmd' -Encoding ascii -Force
#endregion

#region [PostOS] SetupComplete CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Create C:\Windows\Setup\Scripts\SetupComplete.cmd"
$SetupCompleteCMD = @'
powershell.exe -Command Set-ExecutionPolicy Bypass -Force
powershell.exe -Command "& {IEX (IRM https://raw.githubusercontent.com/AnyLinQ-B-V/OSDCloud/main/Automate/oobetasks.ps1)}"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force
#endregion

#region Restart Computer
Write-Host -ForegroundColor DarkMagenta "Restarting in 10 seconds..."
Start-Sleep -Seconds 10
wpeutil reboot
#endregion
