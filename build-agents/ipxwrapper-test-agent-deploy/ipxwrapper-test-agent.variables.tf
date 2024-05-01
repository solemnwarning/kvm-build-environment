variable "storage_pool" {
  type = string
  default = "default"
}

variable "domain" {
  type = string
}

variable "http_proxy_url" {
  type = string
  default = ""
}

variable "buildkite_agent_token" {
  type = string
  sensitive = true
}
