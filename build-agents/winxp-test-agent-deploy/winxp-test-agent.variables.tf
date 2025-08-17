variable "storage_pool" {
  type = string
  default = "default"
}

variable "domain" {
  type = string
}

variable "ip_and_prefix" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dns_server" {
  type = string
}

variable "memory" {
  type = number
}

variable "vcpu" {
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
