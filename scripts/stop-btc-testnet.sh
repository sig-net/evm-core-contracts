#!/usr/bin/env bash

# Source common functions and variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check if docker is running
check_docker

log_info "Stopping Bitcoin testnet container..."

# Check if container is running
if ! check_container_exists; then
  log_info "No Bitcoin testnet container is currently running"
  
  # Check if container exists but is stopped
  if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing stopped container..."
    docker rm $CONTAINER_NAME || true
    log_success "Stopped container removed"
  else
    log_info "No Bitcoin testnet container found"
  fi
  
  # Clean up any other bitcoin containers
  cleanup_containers "bitcoin"
  
  exit 0
fi

# Try to shut down the Bitcoin daemon gracefully first
echo "Attempting to stop Bitcoin daemon gracefully..."
run_bitcoin_cli stop || true
sleep 5

# Stop the container
echo "Stopping container..."
docker stop $CONTAINER_NAME || true

# Remove the container
echo "Removing container..."
docker rm $CONTAINER_NAME || true

log_success "Bitcoin testnet container stopped and removed"

# Optional: list running containers to verify
docker ps | grep bitcoin || echo "No Bitcoin containers running" 