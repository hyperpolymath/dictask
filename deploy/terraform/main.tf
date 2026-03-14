# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Terraform configuration for dictask cloud backup.
# Provisions: encrypted storage bucket, IAM roles, lifecycle rules.
#
# This is designed for S3-compatible storage (GCS, Backblaze B2, MinIO).
# Adjust provider block for your preferred cloud.

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the storage bucket"
  type        = string
  default     = "europe-west2"  # London
}

variable "retention_days" {
  description = "Number of days to retain encrypted audio backups"
  type        = number
  default     = 30
}

variable "bucket_name" {
  description = "Name for the audio backup bucket"
  type        = string
  default     = "dictask-audio-backup"
}

# ============================================================================
# Provider
# ============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}

# ============================================================================
# Storage Bucket — Encrypted Audio Backups
# ============================================================================

resource "google_storage_bucket" "audio_backup" {
  name     = "${var.bucket_name}-${var.project_id}"
  location = var.region

  # Encryption at rest (Google-managed, or use CMEK for stronger guarantee)
  encryption {
    default_kms_key_name = ""  # Uses Google-managed encryption by default
  }

  # Versioning for audit trail
  versioning {
    enabled = true
  }

  # Lifecycle: auto-delete after retention period
  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  # Uniform bucket-level access (no per-object ACLs)
  uniform_bucket_level_access = true

  # Labels for cost tracking
  labels = {
    project     = "dictask"
    purpose     = "audio-backup"
    environment = "production"
  }
}

# ============================================================================
# Service Account — Minimal permissions for upload
# ============================================================================

resource "google_service_account" "dictask_uploader" {
  account_id   = "dictask-uploader"
  display_name = "dictask Audio Uploader"
  description  = "Service account for dictask pipeline to upload encrypted audio backups"
}

# Only allow object creation (not read/delete) for upload
resource "google_storage_bucket_iam_member" "uploader_create" {
  bucket = google_storage_bucket.audio_backup.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.dictask_uploader.email}"
}

# Allow listing (for idempotent upload checks)
resource "google_storage_bucket_iam_member" "uploader_viewer" {
  bucket = google_storage_bucket.audio_backup.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dictask_uploader.email}"
}

# ============================================================================
# Outputs
# ============================================================================

output "bucket_name" {
  description = "The name of the audio backup bucket"
  value       = google_storage_bucket.audio_backup.name
}

output "bucket_url" {
  description = "The URL of the audio backup bucket"
  value       = google_storage_bucket.audio_backup.url
}

output "service_account_email" {
  description = "The email of the upload service account"
  value       = google_service_account.dictask_uploader.email
}
