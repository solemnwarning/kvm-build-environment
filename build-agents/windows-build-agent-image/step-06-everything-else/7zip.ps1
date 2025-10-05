$ErrorActionPreference = "Stop"

# Find the download URL for the latest release installer on GitHub.

$latest_release_data = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/ip7z/7zip/releases/latest" | ConvertFrom-Json

$maybe_windows_download = @($latest_release_data.assets | % { If($_.name.EndsWith("-x64.exe")) { @{ name = $_.name; url = $_.browser_download_url } } })

if($maybe_windows_download.Length -eq 0)
{
	Write-Output "Can't find download link for 7-Zip"
	Exit 1
}
elseif($maybe_windows_download.Length -gt 1)
{
	Write-Output "Found multiple possible downloads for 7-Zip, aborting"
	Write-Output $maybe_windows_download
	Exit 1
}

# Download the installer to a temporary file and run it.

$exe = "$($Env:temp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).exe"

Write-Output "Downloading $($maybe_windows_download[0].url)"
Invoke-WebRequest $maybe_windows_download[0].url -OutFile $exe

Write-Output "Installing 7-Zip"

$p = Start-Process $exe -ArgumentList "/S" -PassThru -Wait
if($p.ExitCode -ne 0)
{
	Write-Error -Message "Failed to install 7-Zip (exit code $($p.ExitCode.ToString()))"
}

Remove-Item $exe

# Add to default PATH.

$env:PATH = 'C:\\Program Files\\7-Zip;' + $env:PATH
[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)

Write-Output "7-Zip was installed successfully!"
