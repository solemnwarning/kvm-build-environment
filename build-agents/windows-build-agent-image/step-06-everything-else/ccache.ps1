$ErrorActionPreference = "Stop"

$INSTDIR = "C:\Program Files\Ccache"

# Find the download URL for the x64 Windows zip of the latest Ccache release on GitHub.

$latest_release_data = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/ccache/ccache/releases/latest" | ConvertFrom-Json

$maybe_windows_download = @($latest_release_data.assets | % { If($_.name.EndsWith("windows-x86_64.zip")) { @{ name = $_.name; url = $_.browser_download_url } } })

if($maybe_windows_download.Length -eq 0)
{
	Write-Output "Can't find download link for ccache"
	Exit 1
}
elseif($maybe_windows_download.Length -gt 1)
{
	Write-Output "Found multiple possible downloads for ccache, aborting"
	Write-Output $maybe_windows_download
	Exit 1
}

# Download the zip to a temporary file and extract it to a temporary directory.
#
# We can't use the built-in temporary file stuff because it can't create directories or files with
# chosen extensions (Expand-Archive chokes if the filename doesn't end in .zip), so we instead have
# our own dumb racy implementation.

$zip = "$($Env:temp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).zip"

Write-Output "Downloading $($maybe_windows_download[0].url)"
Invoke-WebRequest $maybe_windows_download[0].url -OutFile $zip

$tmpdir = "$($Env:temp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).tmp"
New-Item -ItemType Directory -Path $tmpdir | Out-Null

Write-Output "Extracting..."

Expand-Archive -Path $zip -DestinationPath $tmpdir

# Copy the files from the extracted archive to the install destination, stripping off the outer
# directory (assuming there is one).

$copy_source = $tmpdir

$zip_root_files = Get-ChildItem -Path $tmpdir
if($zip_root_files.Length -eq 1)
{
	$copy_source = "${copy_source}\$($zip_root_files[0].Name)";
}

Write-Output "Installing Ccache to $INSTDIR"

New-Item -ItemType Directory -Path $INSTDIR -Force | Out-Null

Copy-Item -Path "${copy_source}\*" -Recurse -Destination $INSTDIR

New-Item -ItemType Directory -Path "${INSTDIR}\bin" -Force | Out-Null
Move-Item -Path "${INSTDIR}\ccache.exe" -Destination "${INSTDIR}\bin\ccache.exe" -Force

New-Item -ItemType Directory -Path "${INSTDIR}\cbin" -Force | Out-Null

New-Item -Path "${INSTDIR}\cbin\cc.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null
New-Item -Path "${INSTDIR}\cbin\cl.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null
New-Item -Path "${INSTDIR}\cbin\clang.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null
New-Item -Path "${INSTDIR}\cbin\clang++.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null
New-Item -Path "${INSTDIR}\cbin\clang-cl.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null
New-Item -Path "${INSTDIR}\cbin\gcc.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force| Out-Null
New-Item -Path "${INSTDIR}\cbin\g++.exe" -ItemType SymbolicLink -Value "${INSTDIR}\bin\ccache.exe" -Force | Out-Null

# Clean up the temporary files.

Remove-Item $tmpdir -Recurse -Force
Remove-Item $zip

Write-Output ""
Write-Output "Ccache was installed successfully!"
Write-Output "The ccache.exe executable is at $INSTDIR\bin\ccache.exe"
Write-Output "Symlinks for common compilers have been created in $INSTDIR\cbin - add this to your PATH to use Ccache"
