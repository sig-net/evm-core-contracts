#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check if docker is running
check_docker

log_info "Stopping Bitcoin testnet container..."

cleanup_containers "bitcoin"

log_success "Bitcoin testnet container stopped and removed"

# Verify no Bitcoin containers are running
docker ps | grep bitcoin || log_info "No Bitcoin containers running"