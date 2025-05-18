$ErrorActionPreference = "Stop"

$OPTIONS = @'
[Setup]
Lang=default
Dir=C:\Program Files\Git
Group=Git
NoIcons=0
SetupType=default
Components=gitlfs,assoc,assoc_sh,windowsterminal
Tasks=
EditorOption=VIM
CustomEditorPath=
DefaultBranchOption=main
PathOption=Cmd
SSHOption=OpenSSH
TortoiseOption=false
CURLOption=OpenSSL
CRLFOption=CRLFCommitAsIs
BashTerminalOption=MinTTY
GitPullBehaviorOption=FFOnly
UseCredentialManager=Disabled
PerformanceTweaksFSCache=Enabled
EnableSymlinks=Enabled
EnablePseudoConsoleSupport=Disabled
EnableFSMonitor=Disabled
'@

# Find the download URL for the latest release installer on GitHub.

$latest_release_data = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" | ConvertFrom-Json

$maybe_windows_download = @($latest_release_data.assets | % { If($_.name.EndsWith("-64-bit.exe")) { @{ name = $_.name; url = $_.browser_download_url } } })

if($maybe_windows_download.Length -eq 0)
{
	Write-Output "Can't find download link for Git for Windows"
	Exit 1
}
elseif($maybe_windows_download.Length -gt 1)
{
	Write-Output "Found multiple possible downloads for Git, aborting"
	Write-Output $maybe_windows_download
	Exit 1
}

# Download the installer to a temporary file and run it.

$exe = "$($Env:temp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).exe"

Write-Output "Downloading $($maybe_windows_download[0].url)"
Invoke-WebRequest $maybe_windows_download[0].url -OutFile $exe

Write-Output "Installing Git for Windows"

$ini = "$($Env:temp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).ini"
$OPTIONS | Out-File $ini

$p = Start-Process $exe -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/LOADINF=$ini" -PassThru -Wait
if($p.ExitCode -ne 0)
{
	Write-Error -Message "Failed to install Git (exit code $($p.ExitCode.ToString()))"
}

Remove-Item $ini
Remove-Item $exe

Write-Output "Git was installed successfully!"
