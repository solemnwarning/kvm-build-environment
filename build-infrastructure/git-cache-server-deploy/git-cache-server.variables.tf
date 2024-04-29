variable "storage_pool" {
  type = string
  default = "default"
}

variable "hostname" {
  type = string
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

variable "http_proxy_url" {
  type = string
  default = ""
}
