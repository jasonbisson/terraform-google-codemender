output "vpc_network_id" {
  description = "The fully qualified ID of the created VPC network."
  value       = google_compute_network.vpc.id
}

output "subnetwork_id" {
  description = "The fully qualified ID of the created subnetwork."
  value       = google_compute_subnetwork.subnet.id
}

output "psc_endpoint_ip" {
  description = "The static internal IP address allocated for the Private Service Connect (PSC) endpoint."
  value       = google_compute_global_address.psc_ip.address
}

output "private_dns_zone_name" {
  description = "The Cloud DNS private managed zone routing Google API traffic to the PSC endpoint."
  value       = google_dns_managed_zone.googleapis_zone.name
}

output "test_vm_name" {
  description = "The name of the isolated CLI host instance (if created)."
  value       = var.create_test_vm ? google_compute_instance.test_vm[0].name : null
}

output "test_vm_internal_ip" {
  description = "The internal IP address of the isolated CLI host instance."
  value       = var.create_test_vm ? google_compute_instance.test_vm[0].network_interface[0].network_ip : null
}

output "iap_ssh_command" {
  description = "gcloud CLI command to securely log into the isolated CLI host using Cloud IAP."
  value       = var.create_test_vm ? "gcloud compute ssh ${google_compute_instance.test_vm[0].name} --zone=${var.zone} --project=${module.project.project_id} --tunnel-through-iap" : null
}

output "iap_scp_command" {
  description = "gcloud CLI command to securely copy the CodeMender CLI package to the isolated CLI host using Cloud IAP."
  value       = var.create_test_vm ? "gcloud compute scp ~/cm-linux ${google_compute_instance.test_vm[0].name}:~ --zone=${var.zone} --project=${module.project.project_id} --tunnel-through-iap" : null
}

output "verification_curl_command" {
  description = "Test curl command to execute inside the VM to verify PSC routing to Google APIs."
  value       = "curl -v https://storage.googleapis.com"
}

output "secure_web_proxy_ip" {
  description = "The internal IP address allocated for the Secure Web Proxy (SWP)."
  value       = var.enable_secure_web_proxy ? google_compute_address.swp_ip[0].address : null
}

output "secure_web_proxy_export_commands" {
  description = "Shell export statements to use the Secure Web Proxy inside the VM for HTTP/HTTPS requests."
  value       = var.enable_secure_web_proxy ? "export http_proxy=http://${google_compute_address.swp_ip[0].address}:80 && export https_proxy=http://${google_compute_address.swp_ip[0].address}:443" : null
}

output "secure_web_proxy_apt_config_command" {
  description = "Command to persistently configure APT and Git to use the Secure Web Proxy inside the VM."
  value       = var.enable_secure_web_proxy ? "sudo tee /etc/apt/apt.conf.d/99proxy << 'EOF'\nAcquire::http::Proxy \"http://${google_compute_address.swp_ip[0].address}:80\";\nAcquire::https::Proxy \"http://${google_compute_address.swp_ip[0].address}:443\";\nEOF\ngit config --global http.proxy http://${google_compute_address.swp_ip[0].address}:80 && git config --global https.proxy http://${google_compute_address.swp_ip[0].address}:443" : null
}


output "project_id" {
  description = "The ID of the created GCP project."
  value       = module.project.project_id
}

output "zone" {
  description = "The Google Cloud zone where compute resources are deployed."
  value       = var.zone
}

