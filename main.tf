# ==============================================================================
# Google Cloud Project Factory
# ==============================================================================

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 17.0"

  providers = {
    google      = google.project_creation
    google-beta = google.project_creation
  }

  name              = var.project_id
  random_project_id = var.random_project_id
  org_id            = var.org_id
  folder_id         = var.folder_id
  billing_account   = var.billing_account
  activate_apis     = var.gcp_service_list

  disable_services_on_destroy = false
  disable_dependent_services  = false
}

# ==============================================================================
# VPC Network & Subnetwork Configuration
# ==============================================================================

resource "google_compute_network" "vpc" {
  project                 = module.project.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Custom VPC network for CodeMender CLI execution environment"
}

resource "google_compute_subnetwork" "subnet" {
  project                  = module.project.project_id
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_ip_cidr_range
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  description              = "Subnetwork with Private Google Access enabled for CodeMender CLI instances"
}

# ==============================================================================
# Private Service Connect (PSC) Config
# ==============================================================================

resource "google_compute_global_address" "psc_ip" {
  project      = module.project.project_id
  name         = "${var.psc_endpoint_name}-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc.id
  address      = var.psc_ip_address
  description  = "Static internal IP address for Private Service Connect (PSC) endpoint"
}

resource "google_compute_global_forwarding_rule" "psc_endpoint" {
  project               = module.project.project_id
  name                  = var.psc_endpoint_name
  target                = "all-apis"
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_global_address.psc_ip.id
  load_balancing_scheme = ""
  description           = "Global Private Service Connect endpoint routing traffic to All Google Cloud APIs"
}

# ==============================================================================
# Private DNS Override for Google APIs
# ==============================================================================

resource "google_dns_managed_zone" "googleapis_zone" {
  project     = module.project.project_id
  name        = "psc-googleapis-zone"
  dns_name    = "googleapis.com."
  description = "Private Cloud DNS zone routing googleapis.com requests to the internal PSC endpoint"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "googleapis_a" {
  project      = module.project.project_id
  name         = "googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc_ip.address]
}

resource "google_dns_record_set" "googleapis_cname" {
  project      = module.project.project_id
  name         = "*.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_zone.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["googleapis.com."]
}

# ==============================================================================
# Firewall Rules
# ==============================================================================

resource "google_compute_firewall" "allow_psc_egress" {
  project   = module.project.project_id
  name      = "allow-internal-and-psc-egress"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["${google_compute_global_address.psc_ip.address}/32"]
  target_tags        = ["isolated-vm"]

  description = "Permit HTTPS egress traffic exclusively to the Private Service Connect endpoint IP address"
}

resource "google_compute_firewall" "deny_internet_egress" {
  project   = module.project.project_id
  name      = "deny-internet-egress"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 1000

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["isolated-vm"]

  description = "Deny all general public internet egress traffic for isolated CLI instances"
}

resource "google_compute_firewall" "allow_iap_ssh" {
  project   = module.project.project_id
  name      = "allow-ssh-ingress-from-iap"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]

  description = "Allow secure SSH administration access from Google Cloud Identity-Aware Proxy (IAP)"
}

# ==============================================================================
# Compute Engine & Service Account
# ==============================================================================

resource "google_service_account" "vm_sa" {
  count        = var.create_test_vm ? 1 : 0
  project      = module.project.project_id
  account_id   = "codemender-vm-sa"
  display_name = "CodeMender CLI Execution Service Account"
}

resource "google_compute_instance" "test_vm" {
  count        = var.create_test_vm ? 1 : 0
  project      = module.project.project_id
  name         = var.vm_name
  machine_type = var.vm_machine_type
  zone         = var.zone

  tags = ["isolated-vm", "allow-iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      type  = "pd-balanced"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  service_account {
    email  = google_service_account.vm_sa[0].email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  description = "Isolated validation VM for testing CodeMender CLI over Private Service Connect"
}

# ==============================================================================
# Secure Web Proxy (SWP) Configuration (Optional)
# ==============================================================================

resource "google_compute_subnetwork" "proxy_subnet" {
  count         = var.enable_secure_web_proxy ? 1 : 0
  project       = module.project.project_id
  name          = "codemender-proxy-subnet"
  ip_cidr_range = var.proxy_subnet_ip_cidr_range
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_address" "swp_ip" {
  count        = var.enable_secure_web_proxy ? 1 : 0
  project      = module.project.project_id
  name         = "codemender-swp-ip"
  subnetwork   = google_compute_subnetwork.subnet.id
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_network_security_gateway_security_policy" "swp_policy" {
  count    = var.enable_secure_web_proxy ? 1 : 0
  project  = module.project.project_id
  name     = "codemender-swp-policy"
  location = var.region
}

resource "google_network_security_gateway_security_policy_rule" "allow_debian" {
  count                   = var.enable_secure_web_proxy ? 1 : 0
  project                 = module.project.project_id
  name                    = "allow-debian"
  location                = var.region
  gateway_security_policy = google_network_security_gateway_security_policy.swp_policy[0].name
  enabled                 = true
  priority                = 100
  session_matcher         = "host().endsWith('.debian.org') || host() == 'debian.org'"
  basic_profile           = "ALLOW"
}

resource "google_network_services_gateway" "swp" {
  count                                = var.enable_secure_web_proxy ? 1 : 0
  project                              = module.project.project_id
  name                                 = "codemender-swp"
  location                             = var.region
  type                                 = "SECURE_WEB_GATEWAY"
  ports                                = [80, 443]
  gateway_security_policy              = google_network_security_gateway_security_policy.swp_policy[0].id
  network                              = google_compute_network.vpc.id
  subnetwork                           = google_compute_subnetwork.subnet.id
  addresses                            = [google_compute_address.swp_ip[0].address]
  delete_swg_autogen_router_on_destroy = true

  depends_on = [
    google_compute_subnetwork.proxy_subnet
  ]
}

resource "google_compute_firewall" "allow_swp_egress" {
  count     = var.enable_secure_web_proxy ? 1 : 0
  project   = module.project.project_id
  name      = "allow-swp-egress"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  destination_ranges = ["${google_compute_address.swp_ip[0].address}/32"]
  target_tags        = ["isolated-vm"]

  description = "Permit HTTP and HTTPS egress traffic to the Secure Web Proxy IP address"
}

