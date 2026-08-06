variable "project_id" {
  type        = string
  description = "The Google Cloud project ID (or name) to be created by the project factory."
}

variable "region" {
  type        = string
  description = "The Google Cloud region for deploying the subnetwork and regional resources."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The Google Cloud zone for deploying compute instances."
  default     = "us-central1-a"
}

variable "network_name" {
  type        = string
  description = "The name of the custom VPC network hosting the CodeMender CLI environment."
  default     = "codemender-vpc"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnetwork with Private Google Access enabled."
  default     = "codemender-subnet"
}

variable "subnet_ip_cidr_range" {
  type        = string
  description = "The primary IPv4 CIDR block for the CodeMender CLI execution subnetwork."
  default     = "10.0.0.0/24"
}

variable "psc_endpoint_name" {
  type        = string
  description = "The name of the Global Private Service Connect (PSC) endpoint forwarding rule (must be 1-20 lowercase alphanumeric characters)."
  default     = "codemenderpsc"
}

variable "psc_ip_address" {
  type        = string
  description = "The static internal IP address allocated for the Global PSC endpoint (All Google Cloud APIs)."
  default     = "10.128.0.50"
}

variable "create_test_vm" {
  type        = bool
  description = "Whether to create an isolated compute instance to verify CodeMender CLI connectivity via PSC."
  default     = true
}

variable "vm_name" {
  type        = string
  description = "The name of the isolated Compute Engine instance hosting the CodeMender CLI."
  default     = "codemender-cli-host"
}

variable "vm_machine_type" {
  type        = string
  description = "The machine type for the isolated Compute Engine instance."
  default     = "e2-micro"
}

variable "gcp_service_list" {
  type        = list(string)
  description = "The list of Google Cloud APIs required for the CodeMender PSC infrastructure deployment."
  default = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "certificatemanager.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com"
  ]
}

variable "billing_account" {
  type        = string
  description = "The alphanumeric ID of the billing account to associate with the new project."
}

variable "org_id" {
  type        = string
  description = "The numeric ID of the organization where the project will be created (if applicable)."
  default     = null
}

variable "folder_id" {
  type        = string
  description = "The numeric ID of the folder where the project will be created (if applicable)."
  default     = null
}

variable "random_project_id" {
  type        = bool
  description = "Whether to append a random suffix to the project_id to ensure global uniqueness."
  default     = false
}

variable "enable_secure_web_proxy" {
  type        = bool
  description = "Whether to deploy Google Cloud Secure Web Proxy (SWP) to allow VM access to Debian package repositories and GitHub."
  default     = false
}

variable "proxy_subnet_ip_cidr_range" {
  type        = string
  description = "The IPv4 CIDR block for the regional proxy-only subnetwork required by Secure Web Proxy."
  default     = "10.10.0.0/24"
}

variable "deletion_policy" {
  description = "The deletion policy for the project."
  type        = string
  default     = "DELETE"
}

