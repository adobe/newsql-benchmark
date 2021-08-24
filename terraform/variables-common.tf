variable "prefix" {
  type    = string
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "private_ip_prefix" {
  type    = string
  default = "10.0.1."
}
variable "private_ip_reserved" {
  type    = number
  default = 10
}

variable "dev_ips" {
  type    = list(string)
  default = ["192.150.10.0/24"]
  #home ip = "73.189.177.216"
}

variable "admin_username" {
  type    = string
  default = "fdb"
}

variable "admin_password" {
  type    = string
  default = "Password123!"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "uisuser"
}

variable "team" {
  type    = string
  default = "uis"
}
