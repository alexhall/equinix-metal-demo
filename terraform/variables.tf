variable "organization_id" {
  type        = string
  description = "Organization UUID to deploy to"
  default     = "2a49d29d-201e-44f1-a5bb-5b497c9dd75b"  
}

variable "server_metro" {
  type = string
  description = "Metro to deploy the server in"
  default = "DC"
}

variable "server_plan" {
  type = string
  description = "Type of server plan to deploy"
  default = "c3.small.x86"
}