variable "hostname" {
  type    = string
  default = "macos-14-build-agent"
}

variable "domain" {
  type    = string
  default = "build.solemnwarning.net"
}

variable "http_proxy_url" {
  type = string
  default = ""
}

variable "admin_username" {
  type = string
}

variable "admin_ssh_keys" {
  type = list(string)
}

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}
