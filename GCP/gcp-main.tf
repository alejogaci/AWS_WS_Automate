terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "storage_bucket" {
  description = "GCS bucket containing installation scripts"
  type        = string
}

variable "tag_filter" {
  description = "Instance label filter (use 'NONE' for no filtering, or 'key:value' format)"
  type        = string
  default     = "NONE"
}

locals {
  service_name = "trendmicro-agent-service"
}

resource "google_storage_bucket_object" "scan_function_source" {
  name   = "scan-instances-function.zip"
  bucket = var.storage_bucket
  source = "./functions/scan-instances.zip"
}

resource "google_storage_bucket_object" "install_function_source" {
  name   = "install-agent-function.zip"
  bucket = var.storage_bucket
  source = "./functions/install-agent.zip"
}

resource "google_cloudfunctions2_function" "scan_instances" {
  name        = "${local.service_name}-scan-instances"
  location    = var.region
  description = "Scans all GCE instances and triggers agent installation"

  build_config {
    runtime     = "python312"
    entry_point = "scan_instances"
    source {
      storage_source {
        bucket = var.storage_bucket
        object = google_storage_bucket_object.scan_function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512M"
    timeout_seconds    = 300
    environment_variables = {
      STORAGE_BUCKET = var.storage_bucket
      TAG_FILTER     = var.tag_filter
      PROJECT_ID     = var.project_id
    }
    service_account_email = google_service_account.function_sa.email
  }
}

resource "google_cloudfunctions2_function" "install_agent" {
  name        = "${local.service_name}-install-agent"
  location    = var.region
  description = "Installs Trend Micro agent on GCE instances"

  build_config {
    runtime     = "python312"
    entry_point = "install_agent"
    source {
      storage_source {
        bucket = var.storage_bucket
        object = google_storage_bucket_object.install_function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    available_memory   = "256M"
    timeout_seconds    = 120
    environment_variables = {
      STORAGE_BUCKET = var.storage_bucket
      PROJECT_ID     = var.project_id
    }
    service_account_email = google_service_account.function_sa.email
  }
}

resource "google_service_account" "function_sa" {
  account_id   = "${local.service_name}-sa"
  display_name = "Trend Micro Agent Service Account"
  description  = "Service account for Trend Micro agent installation functions"
}

resource "google_project_iam_member" "function_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "function_compute_osadmin" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "function_storage_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_cloud_scheduler_job" "scan_trigger" {
  name             = "${local.service_name}-scan-trigger"
  description      = "Triggers initial scan of GCE instances"
  schedule         = "0 2 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.scan_instances.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.function_sa.email
    }
  }
}

resource "google_eventarc_trigger" "instance_created" {
  name     = "${local.service_name}-instance-created"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }

  matching_criteria {
    attribute = "serviceName"
    value     = "compute.googleapis.com"
  }

  matching_criteria {
    attribute = "methodName"
    value     = "v1.compute.instances.insert"
  }

  destination {
    cloud_function = google_cloudfunctions2_function.install_agent.id
  }

  service_account = google_service_account.eventarc_sa.email
}

resource "google_service_account" "eventarc_sa" {
  account_id   = "${local.service_name}-eventarc"
  display_name = "Trend Micro Eventarc Service Account"
}

resource "google_project_iam_member" "eventarc_eventreceiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc_sa.email}"
}

resource "google_project_iam_member" "eventarc_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.eventarc_sa.email}"
}

output "scan_function_url" {
  value       = google_cloudfunctions2_function.scan_instances.service_config[0].uri
  description = "URL of the scan instances function"
}

output "install_function_url" {
  value       = google_cloudfunctions2_function.install_agent.service_config[0].uri
  description = "URL of the install agent function"
}

output "service_account_email" {
  value       = google_service_account.function_sa.email
  description = "Service account email for functions"
}
