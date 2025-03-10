#!/usr/bin/env bash

# Source common functions and variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Starting Bitcoin testnet container..."

# Remove existing stopped container if it exists
if docker ps -a | grep -q $CONTAINER_NAME; then
  log_info "Removing existing stopped container..."
  docker rm $CONTAINER_NAME || true
fi

log_info "Creating new Bitcoin testnet container..."
# Run the container
docker run -d --name $CONTAINER_NAME \
  -p ${RPC_PORT}:18443 \
  -e BITCOIN_RPC_USER=$RPC_USER \
  -e BITCOIN_RPC_PASSWORD=$RPC_PASS \
  -e BITCOIN_RPC_ALLOW_IP=0.0.0.0/0 \
  $BITCOIN_IMAGE \
  -regtest=1 \
  -rpcbind=0.0.0.0 \
  -rpcallowip=0.0.0.0/0 \
  -rpcuser=$RPC_USER \
  -rpcpassword=$RPC_PASS \
  -fallbackfee=0.0001 \
  -maxtxfee=1.0 \
  -txconfirmtarget=1

log_info "Waiting for Bitcoin RPC service to start..."
sleep 10

# Verify container is running
if ! check_container_exists; then
  log_error "Container failed to start"
  
  # Show container logs
  log_info "Container logs:"
  docker logs $CONTAINER_NAME 2>&1 || true
  
  # Remove the failed container
  docker rm $CONTAINER_NAME || true
  
  exit 1
fi

log_info "Container info:"
docker ps | grep $CONTAINER_NAME

# Wait for bitcoind initialization
sleep 5

# Setup wallet
log_info "Creating wallet and generating initial blocks..."
run_bitcoin_cli createwallet default 2>/dev/null || true
run_bitcoin_cli loadwallet default 2>/dev/null || true

# Generate address and blocks
ADDRESS=$(run_bitcoin_cli getnewaddress)
if [ -z "$ADDRESS" ]; then
  log_error "Failed to generate address"
  docker logs $CONTAINER_NAME
  exit 1
fi

log_info "Mining 101 blocks to make coins spendable"
run_bitcoin_cli generatetoaddress 101 "$ADDRESS"

# Verify setup
log_info "Verifying Bitcoin testnet setup..."
if run_bitcoin_cli getblockchaininfo; then
  log_success "Bitcoin testnet ready for testing!"
  log_info "RPC endpoint: http://localhost:${RPC_PORT}"
  log_info "Username: $RPC_USER"
  log_info "Password: $RPC_PASS"
  exit 0
else
  log_error "Failed to verify Bitcoin testnet setup"
  exit 1
fi