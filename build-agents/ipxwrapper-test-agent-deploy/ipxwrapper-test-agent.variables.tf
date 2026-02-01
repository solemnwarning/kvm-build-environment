variable "hostname_suffix" {
  type = string
  default = ""
}

variable "domain" {
  type = string
}

variable "memory" {
  type = number
}

variable "vcpu" {
  type = number
}

variable "spawn" {
  type = number
}

variable "http_proxy_url" {
  type = string
  default = ""
}

variable "admin_ssh_keys" {
  type = list(string)
}

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}

variable "template_dir" {
  type = string
}
