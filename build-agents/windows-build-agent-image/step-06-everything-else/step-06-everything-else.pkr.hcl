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

variable "base_image_version" {
  type    = string
}

locals {
  base_image = "../step-05-install-msys2/builds/${var.base_image_version}/step-05-install-msys2.qcow2"
  base_image_checksum = "file:../step-05-install-msys2/builds/${var.base_image_version}/SHA256SUMS"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type    = string
  default = "windows-build-agent.qcow2"
}

variable "jq_exe_url" {
  type    = string
  default = "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe"
}

variable "nsis_installer_url" {
  type    = string
  default = "https://downloads.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11-setup.exe"
}

variable "stunnel_installer_url" {
  type    = string
  default = "https://www.stunnel.org/downloads/stunnel-latest-win64-installer.exe"
}

build {
  sources = ["source.qemu.step-06-everything-else"]

  # Install jq.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Invoke-WebRequest -UseBasicParsing -uri '${ var.jq_exe_url }' -OutFile \"$($Env:SystemRoot)\\\\jq.exe\"",
    ]

    timeout = "5m"
  }

  # Install ccache.

  provisioner "powershell" {
    script = "ccache.ps1"
    timeout = "5m"
  }

  provisioner "powershell" {
    inline = [
      "[Environment]::SetEnvironmentVariable('CCACHE_REMOTE_STORAGE', 'http://127.0.0.1:86/', [EnvironmentVariableTarget]::Machine)",
    ]
  }

  # Install stunnel.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Invoke-WebRequest -UseBasicParsing -uri '${ var.stunnel_installer_url }' -OutFile \"stunnel-setup.exe\"",

      "$p = Start-Process 'stunnel-setup.exe' -ArgumentList '/S' -PassThru -Wait",
      "if($p.ExitCode -ne 0) { Write-Error -Message \"Failed to install stunnel (exit code $($p.ExitCode.ToString()))\" }",

      "Remove-Item stunnel-setup.exe",
    ]

    timeout = "5m"
  }

  provisioner "file" {
    source      = "stunnel.conf"
    destination = "C:\\Program Files (x86)\\stunnel\\config\\stunnel.conf"
  }

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "$p = Start-Process 'C:\\Program Files (x86)\\stunnel\\bin\\stunnel.exe' -ArgumentList '-install', '-quiet' -WorkingDirectory 'C:\\Program Files (x86)\\stunnel\\config' -PassThru -Wait",
      "if($p.ExitCode -ne 0) { Write-Error -Message \"Failed to register stunnel service (exit code $($p.ExitCode.ToString()))\" }",
    ]

    timeout = "5m"
  }

  # Install Git for Windows.

  provisioner "powershell" {
    script = "git.ps1"
    timeout = "5m"
  }

  provisioner "file" {
    source      = "gitconfig"
    destination = "C:\\TEMP\\gitconfig"
  }

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Get-Content -Path 'C:\\TEMP\\gitconfig' | Add-Content -Path 'C:\\Program Files\\Git\\etc\\gitconfig'",
      "Remove-Item 'C:\\TEMP\\gitconfig'",
    ]

    timeout = "5m"
  }

  provisioner "powershell" {
    script = "htmlhelp.ps1"
    timeout = "1h"
  }

  # Install Buildkite Agent

  provisioner "file" {
    sources = [
      "Get-RandomPassword.ps1",
      "Set-UserRights.ps1",
      "Add-FSAccessRule.ps1",
    ]

    destination = "C:\\TEMP\\"
  }

  provisioner "powershell" {
    environment_vars = [
      "buildkiteAgentToken=${var.buildkite_agent_token}",
    ]

    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/buildkite/agent/main/install.ps1'))",

      "New-Item -ItemType directory -Path C:\\buildkite-agent\\hooks | Out-Null",

      # Create a user with a random password to run the buildkite-agent service.
      "$buildkite_user_password = C:\\TEMP\\Get-RandomPassword.ps1 -Length 16",
      "$buildkite_user_password_ss = ConvertTo-SecureString $buildkite_user_password -AsPlainText -Force",
      "New-LocalUser -AccountNeverExpires -Description 'Buildkite service user' -Name 'buildkite-agent' -Password $buildkite_user_password_ss -PasswordNeverExpires",

      # Grant the buildkite-agent user permission to shut down the system.
      "C:\\TEMP\\Set-UserRights.ps1 -AddRight -Username \"$${env:COMPUTERNAME}\\buildkite-agent\" -UserRight SeShutdownPrivilege",

      # The buildkite-agent install script configures the permissions on C:\buildkite-agent as
      # read/write for SYSTEM/Administrators and no access for anyone else, with no inheritance,
      # which works fine when the agent is running as such an account as any newly created files
      # will be owned by such an account and have similar permissions.
      #
      # We want to run the agent as an unprivileged user, so firstly we need to add read/execute
      # permissions to C:\buildkite-agent and any subdirectories for that user, we also update the
      # permissions created by the buildkite-agent setup script to include inheritance so that
      # administrators can access the builds subdirectory and anything within created by the service
      # user.

      "C:\\TEMP\\Add-FSAccessRule.ps1 -Path 'C:\\buildkite-agent' -Identity 'NT AUTHORITY\\SYSTEM'    -Rights 'FullControl'    -AllowAccess $true",
      "C:\\TEMP\\Add-FSAccessRule.ps1 -Path 'C:\\buildkite-agent' -Identity 'BUILTIN\\Administrators' -Rights 'FullControl'    -AllowAccess $true",
      "C:\\TEMP\\Add-FSAccessRule.ps1 -Path 'C:\\buildkite-agent' -Identity 'buildkite-agent'         -Rights 'ReadAndExecute' -AllowAccess $true",

      # Create the builds directory and give the buildkite-agent user write access.

      "New-Item -ItemType directory -Path C:\\buildkite-agent\\builds | Out-Null",
      "C:\\TEMP\\Add-FSAccessRule.ps1 -Path 'C:\\buildkite-agent\\builds' -Identity 'buildkite-agent' -Rights 'FullControl' -AllowAccess $true",

      "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'nssm-2.24.zip'",
      "Expand-Archive -Path nssm-2.24.zip -DestinationPath nssm-2.24",
      "Remove-Item nssm-2.24.zip",

      "Copy-Item nssm-2.24\\nssm-2.24\\win64\\nssm.exe C:\\Windows\\system32\\nssm.exe",
      "Remove-Item nssm-2.24 -Force -Recurse -ErrorAction SilentlyContinue",

      "nssm install 'Buildkite Agent' 'C:\\buildkite-agent\\buildkite-agent-run.bat'",
      "nssm set 'Buildkite Agent' ObjectName \"$${env:COMPUTERNAME}\\buildkite-agent\" \"$${buildkite_user_password}\"",
      "nssm set 'Buildkite Agent' Start SERVICE_DEMAND_START",
      "nssm set 'Buildkite Agent' AppExit Default Restart",
      "nssm set 'Buildkite Agent' AppExit 0 Exit",

      # Write output from the agent to log files.

      "New-Item -ItemType directory -Path C:\\buildkite-agent\\logs | Out-Null",
      "C:\\TEMP\\Add-FSAccessRule.ps1 -Path 'C:\\buildkite-agent\\logs' -Identity 'buildkite-agent' -Rights 'FullControl' -AllowAccess $true",

      "nssm set 'Buildkite Agent' AppStdout C:\\buildkite-agent\\logs\\buildkite-agent.log",
      "nssm set 'Buildkite Agent' AppStderr C:\\buildkite-agent\\logs\\buildkite-agent.log",

      "Remove-Item -Path 'C:\\TEMP\\Get-RandomPassword.ps1'",
      "Remove-Item -Path 'C:\\TEMP\\Set-UserRights.ps1'",
      "Remove-Item -Path 'C:\\TEMP\\Add-FSAccessRule.ps1'",
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

  # Download and install NSIS
  provisioner "powershell" {
    inline = [
      # Spoof a wget User-Agent header so SourceForge doesn't serve the fucking
      # download-and-look-at-our-ads page in place of the actual file.
      "Invoke-WebRequest -Uri '${var.nsis_installer_url}' -OutFile 'nsis-setup.exe' -UserAgent 'Wget/1.0'",

      "$p = Start-Process 'nsis-setup.exe' -ArgumentList '/S' -PassThru -Wait",
      "if($p.ExitCode -ne 0) { Write-Error -Message \"Failed to install NSIS (exit code $($p.ExitCode.ToString()))\" }",

      "Remove-Item nsis-setup.exe",

      "$env:PATH = 'C:\\Program Files (x86)\\NSIS\\Bin;' + $env:PATH",
      "[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)",
    ]
  }

  # Download and install 7-Zip
  provisioner "powershell" {
    script = "7zip.ps1"
    timeout = "5m"
  }


  provisioner "file" {
    source = "configure-machine.bat"
    destination = "C:\\"
  }

  provisioner "powershell" {
    inline = [
      "nssm install 'Machine configuration script' 'C:\\configure-machine.bat'",
      "nssm set 'Machine configuration script' AppExit Default Exit",
      "nssm set 'Machine configuration script' AppExit 0 Ignore",
    ]
  }

  # Update the stored password used for auto logon at the console.
  provisioner "powershell" {
    environment_vars = [
      "ADMINISTRATOR_PASSWORD=${var.administrator_password}",
    ]

    script = "autologon.ps1"
  }

  provisioner "powershell" {
    script = "../packer-Win2022/scripts/cleanup.ps1"
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
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}

source qemu "step-06-everything-else" {
  iso_url      = local.base_image
  iso_checksum = local.base_image_checksum
  disk_image   = true

  # Create a full copy of the base image
  use_backing_file = false

  cpus        = 4
  memory      = 4096
  disk_size   = "120G"
  accelerator = "kvm"

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
  output_directory = var.output_dir
  vm_name          = var.output_name
}
