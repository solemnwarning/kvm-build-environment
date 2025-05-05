variable "http_proxy_url" {
  type = string
  default = ""
}

variable "admin_ssh_keys" {
  type = list(string)
}

variable "macos_admin_username" {
  type = string
}

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}

variable "copr_config" {
  type = string
  sensitive = true
}
