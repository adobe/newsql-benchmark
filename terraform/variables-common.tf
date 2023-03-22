# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

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
