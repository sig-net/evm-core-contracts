#!/usr/bin/env bash

# Define commonly used variables and functions for Bitcoin testnet scripts

# Colors for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

# Common configuration
export CONTAINER_NAME="bitcoin-testnet"
export BITCOIN_IMAGE="ruimarinho/bitcoin-core:latest"
export RPC_USER="admin1"
export RPC_PASS="123"
export RPC_PORT="19001"

# Common functions
log_info() {
  echo -e "${YELLOW}$1${NC}"
}

log_success() {
  echo -e "${GREEN}$1${NC}"
}

log_error() {
  echo -e "${RED}$1${NC}"
}

# Check if Docker is running
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running or accessible"
    exit 1
  fi
}

# Check if container exists
check_container_exists() {
  if docker ps | grep -q $CONTAINER_NAME; then
    return 0  # Container is running
  fi
  return 1  # Container is not running
}

# Clean up containers by pattern
cleanup_containers() {
  local pattern=$1
  docker ps | grep $pattern | awk '{print $1}' | xargs -r docker stop || true
  docker ps -a | grep $pattern | awk '{print $1}' | xargs -r docker rm || true
}

# Run Bitcoin CLI command
run_bitcoin_cli() {
  docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS "$@"
} 