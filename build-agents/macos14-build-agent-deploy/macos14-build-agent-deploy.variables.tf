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

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}
