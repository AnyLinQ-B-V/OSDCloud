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
#endregion

Write-Host -ForegroundColor Green "Create C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json"
$OOBEDeployJson = @'
{
    "Autopilot":  {
                      "IsPresent":  false
                  },
    "AddNetFX3":  {
                      "IsPresent":  true
                    },                     
    "RemoveAppx":  [
                        "Microsoft.549981C3F5F10",
                        "Microsoft.BingWeather",
                        "Microsoft.GetHelp",
                        "Microsoft.Getstarted",
                        "Microsoft.Microsoft3DViewer",
                        "Microsoft.MicrosoftOfficeHub",
                        "Microsoft.MixedReality.Portal",
                        "Microsoft.People",
                        "Microsoft.SkypeApp",
                        "Microsoft.Wallet",
                        "microsoft.windowscommunicationsapps",
                        "Microsoft.WindowsFeedbackHub",
                        "Microsoft.WindowsMaps",
                        "Microsoft.Xbox.TCUI",
                        "Microsoft.XboxApp",
                        "Microsoft.XboxGameOverlay",
                        "Microsoft.XboxGamingOverlay",
                        "Microsoft.XboxIdentityProvider",
                        "Microsoft.XboxSpeechToTextOverlay",
                        "Microsoft.YourPhone",
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

Write-Host -ForegroundColor Green "Create C:\Windows\System32\OOBE.cmd"
$OOBECMD = @'
PowerShell -NoL -Com Set-ExecutionPolicy RemoteSigned -Force
Set Path = %PATH%;C:\Program Files\WindowsPowerShell\Scripts
Start /Wait PowerShell -NoL -C Start-OOBEDeploy
Start /Wait PowerShell -NoL -C Restart-Computer -Force
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\System32\OOBE.cmd' -Encoding ascii -Force

#region Restart Computer
Write-Host -ForegroundColor DarkMagenta "Restarting in 10 seconds..."
Start-Sleep -Seconds 10
wpeutil reboot
#endregion