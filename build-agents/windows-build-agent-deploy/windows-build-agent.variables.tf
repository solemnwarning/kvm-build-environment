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

variable "spawn" {
  type = number
}

variable "extra_tags" {
  type = string
  default = "NONE"
}
