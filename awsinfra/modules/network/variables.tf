variable "prefix" {
  type = string
  
}
variable "vpc_cidr_range" {
  type = string
}

variable "private_subnet_info" {
  type = map(object({
    cidr_range  = string
    az          = string
    public_ip   = bool
    tags    = map(string)
  }))
}

variable "public_subnet_info" {
  type = map(object({
    cidr_range  = string
    az          = string
    public_ip   = bool
    tags    = map(string)
  }))
}

variable "natgateway_public_subnet_name" {
 type = string  
}

# variable "tags" { type = map(string) }