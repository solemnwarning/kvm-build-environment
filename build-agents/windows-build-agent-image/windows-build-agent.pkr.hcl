packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "buildkite_agent_token" {
  sensitive = true
}

variable "administrator_password" {
  sensitive = true
}

variable "output_dir" {
  type    = string
  default = "output"
}

# variable "vs_tools_installer" {
#   type    = string
#   default = "https://aka.ms/vs/17/release/vs_buildtools.exe"
# }

variable "jq_exe_url" {
  type    = string
  default = "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe"
}

build {
  sources = ["source.qemu.windows"]

  # Disable automatic updates.
  # This is a transient VM image so we don't want to waste bandwidh downloading updates and CPU
  # time installing them when they'll be discarded anyway.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Set-ItemProperty -Path \"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU\" -Name NoAutoUpdate -Value 1",
    ]
  }

  # Install the Visual Studio Build Tools.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      # "Invoke-WebRequest -UseBasicParsing -uri '${var.vs_tools_installer}' -OutFile 'vs_buildtools.exe'",

      # "$p = Start-Process 'vs_buildtools.exe' -ArgumentList '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended;includeOptional' -Wait -PassThru",
      # "if($p.ExitCode -ne 0) { Write-Error -Message \"vs_buildtools.exe failed (exit code $($p.ExitCode.ToString()))\" }",

      # "Remove-Item vs_buildtools.exe",

      # The drive with the Visual Studio Build Tools installer previously prepared by
      # msvc-build-tools.pkr.hcl isn't initially "Online" under Windows server, so we enable any
      # offline disks we can find.
      "Get-Disk |",
      "  Where IsOffline -eq $True |",
      "  Set-Disk -IsOffline $False",

      "$vs_tools_drive = Get-Volume -FileSystemLabel 'Visual Studio Build Tools'",
      "$vs_tools_drive = $vs_tools_drive.DriveLetter",

      "$p = Start-Process \"$${vs_tools_drive}:\\vs_buildtools.exe\" -ArgumentList '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended;includeOptional' -Wait -PassThru",
      "if($p.ExitCode -ne 0) { throw \"vs_buildtools.exe failed (exit code $($p.ExitCode.ToString()))\" }",
    ]

    timeout = "1h"
  }

  # Install MSYS/MinGW and any required packages.
  # Based on Docker installation instructions from https://www.msys2.org/docs/ci/

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Invoke-WebRequest -UseBasicParsing -uri 'https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-base-x86_64-latest.sfx.exe' -OutFile msys2.exe",
      ".\\msys2.exe -y -oC:\\",
      "Remove-Item msys2.exe",

      "function msys() { C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; }",
      "msys ' '",
      "msys 'pacman --noconfirm -Syuu'",
      "msys 'pacman --noconfirm -Syuu'",
      "msys 'pacman --noconfirm -S base-devel git p7zip mingw-w64-x86_64-{toolchain,wxWidgets3.2,jansson,capstone,jbigkit,lua,lua-luarocks,libbotan,libunistring}'",

      # Need the "msys" GCC for compiling Template Toolkit...
      "msys 'pacman --noconfirm -S gcc libxcrypt libxcrypt-devel perl-Mozilla-CA'",
      "msys 'PERL_MM_USE_DEFAULT=1 perl -MCPAN -e ''install Template'' '",

      "msys 'pacman --noconfirm -Scc'",

      # "function mingw32() { $env:MSYSTEM = 'MINGW32'; C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; Remove-Item Env:\\MSYSTEM }",
      "function mingw64() { $env:MSYSTEM = 'MINGW64'; C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; Remove-Item Env:\\MSYSTEM }",

      # Work around https://github.com/msys2/MINGW-packages/pull/12002
      "msys 'mkdir -p C:/msys64/mingw{32,64}/lib/luarocks/rocks-5.4/luafilesystem/1.8.0-1/{conf,lib}'",
      "mingw64 'luarocks install luafilesystem'",

      "mingw64 'luarocks install busted'",
    ]

    timeout = "1h"
  }

  # Install jq.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Invoke-WebRequest -UseBasicParsing -uri '${ var.jq_exe_url }' -OutFile \"$($Env:SystemRoot)\\\\jq.exe\"",
    ]

    timeout = "5m"
  }

  # Git doesn't pick up on the "HTTP_CONFIG" environment variable set in the
  # buildkite-agent environment, and there doesn't appear to be a way to set
  # "http_proxy" (lowercase) from batch, because environment variables on
  # Windows are supposed to be case-insensitive, so we have to stick the proxy
  # configuration into the global Git config instead.

  provisioner "file" {
    source      = "gitconfig"
    destination = "C:\\msys64\\etc\\gitconfig"
  }

  provisioner "powershell" {
    script = "htmlhelp.ps1"
    timeout = "1h"
  }

  # Install Buildkite Agent

  provisioner "powershell" {
    environment_vars = [
      "buildkiteAgentToken=${var.buildkite_agent_token}",
    ]

    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/buildkite/agent/main/install.ps1'))",

      "New-Item -ItemType directory -Path C:\\buildkite-agent\\hooks",

      "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'nssm-2.24.zip'",
      "Expand-Archive -Path nssm-2.24.zip -DestinationPath nssm-2.24",
      "Remove-Item nssm-2.24.zip",

      "Copy-Item nssm-2.24\\nssm-2.24\\win64\\nssm.exe C:\\buildkite-agent\\bin\\nssm.exe",
      "Remove-Item nssm-2.24 -Force -Recurse -ErrorAction SilentlyContinue",

      "C:\\buildkite-agent\\bin\\nssm.exe install 'Buildkite Agent' 'C:\\buildkite-agent\\buildkite-agent-run.bat'",
    ]

    timeout = "1h"
  }

  provisioner "file" {
    source      = "buildkite-environment-hook.bat"
    destination = "C:\\buildkite-agent\\hooks\\environment.bat"
  }

  provisioner "file" {
    source      = "buildkite-command-hook.bat"
    destination = "C:\\buildkite-agent\\hooks\\command.bat"
  }

  provisioner "file" {
    source      = "buildkite-agent-run.bat"
    destination = "C:\\buildkite-agent\\buildkite-agent-run.bat"
  }

  # Update the stored password used for auto logon at the console.
  provisioner "powershell" {
    environment_vars = [
      "ADMINISTRATOR_PASSWORD=${var.administrator_password}",
    ]

    script = "autologon.ps1"
  }

  provisioner "powershell" {
    script = "packer-Win2022/scripts/cleanup.ps1"
  }

  provisioner "powershell" {
    inline = [
      "Optimize-Volume -DriveLetter C -ReTrim -Verbose",
    ]
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum windows-build-agent.qcow2 > SHA256SUMS",
    ]
  }
}

source qemu "windows" {
  # iso_url      = "file:${abspath(path.root)}/../../packer-Win2022/output-qemu/Win2022_20324.qcow2"
  # iso_checksum = "4667988148ff5275dbf296f741f9a6358daa1c7787b50a9d332fa5615f80f4a3"
  iso_url      = "packer-Win2022/output-qemu/Win2022_20324.qcow2"
  iso_checksum = "none"
  disk_image   = true

  # Create a full copy of the base image
  use_backing_file = false

  cpus        = 4
  memory      = 4096
  disk_size   = "120G"
  accelerator = "kvm"

  qemuargs = [
    [ "-drive", "file=${var.output_dir}/windows-build-agent.qcow2,if=virtio,cache=unsafe,discard=unmap,format=qcow2,detect-zeroes=unmap" ],
    [ "-drive", "file=msvc-build-tools/msvc-build-tools.qcow2,if=virtio,format=qcow2,readonly" ],
  ]

  headless = true
  # vnc_bind_address = "0.0.0.0"

  communicator = "winrm"
  winrm_username = "Administrator"
  winrm_password = "packer"
  winrm_use_ssl = true
  winrm_insecure = true
  winrm_timeout = "4h"

  shutdown_command = "NET USER \"Administrator\" \"${var.administrator_password}\" && shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout = "30m"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "windows-build-agent.qcow2"
}
