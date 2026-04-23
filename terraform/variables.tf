variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "hf_token" {
  description = "Hugging Face Access Token"
  type        = string
  default     = "dummy"
}

variable "kaggle_username" {
  description = "Kaggle Username"
  type        = string
  default     = ""
}

variable "kaggle_key" {
  description = "Kaggle API Key"
  type        = string
  default     = ""
  sensitive   = true
}