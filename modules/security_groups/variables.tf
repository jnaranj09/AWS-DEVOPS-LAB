variable "name_suffix" {
    description = "name suffix"
    type = string
    default = ""
  
}

variable "vpc_id" {
    description = "name suffix"
    type = string
    default = ""
  
}

variable "tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default     = {}
}