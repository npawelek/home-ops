# Folders were created via the Grafana MCP during initial dashboard setup.
# Import blocks bring them into Terraform state without recreation.

import {
  to = grafana_folder.observability
  id = "observability"
}

import {
  to = grafana_folder.infrastructure
  id = "infrastructure"
}

import {
  to = grafana_folder.storage
  id = "storage"
}

import {
  to = grafana_folder.platform
  id = "platform"
}

import {
  to = grafana_folder.auth
  id = "auth"
}

resource "grafana_folder" "observability" {
  uid   = "observability"
  title = "Observability"
}

resource "grafana_folder" "infrastructure" {
  uid   = "infrastructure"
  title = "Infrastructure"
}

resource "grafana_folder" "storage" {
  uid   = "storage"
  title = "Storage"
}

resource "grafana_folder" "platform" {
  uid   = "platform"
  title = "Platform"
}

resource "grafana_folder" "auth" {
  uid   = "auth"
  title = "Auth"
}
