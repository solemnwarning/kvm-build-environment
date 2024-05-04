variable "storage_pool" {
  type = string
  default = "default"
}

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

variable "http_proxy_url" {
  type = string
  default = ""
}

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}
