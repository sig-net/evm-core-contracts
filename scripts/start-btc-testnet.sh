#!/usr/bin/env bash

# Source common functions and variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Starting Bitcoin testnet container..."

# Check if Docker is running
check_docker

# Check if container is already running
if check_container_exists; then
  log_success "Bitcoin testnet container is already running"
  
  # Set transaction fee settings even if already running
  echo "Updating transaction fee settings..."
  run_bitcoin_cli settxfee 0.00001 || true
  log_success "Transaction fee settings updated"
  
  exit 0
fi

# Check if container exists but is stopped
if docker ps -a | grep -q $CONTAINER_NAME; then
  echo "Removing existing stopped container..."
  docker rm $CONTAINER_NAME || true
fi

echo "Creating new Bitcoin testnet container..."
# Run the container with a specific name for easier reference
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

# Wait for the container to start up
echo "Waiting for Bitcoin RPC service to start (this may take a few seconds)..."
sleep 10

# Verify container is running
if ! check_container_exists; then
  log_error "Container failed to start"
  
  # Show container logs
  echo "Container logs:"
  docker logs $CONTAINER_NAME 2>&1 || true
  
  # Remove the failed container
  docker rm $CONTAINER_NAME || true
  
  exit 1
fi

# Get container info
echo "Container info:"
docker ps | grep $CONTAINER_NAME

# Wait a bit more to ensure bitcoind is fully initialized
sleep 5

# Generate initial blocks for testing
echo "Creating wallet and generating initial blocks..."
run_bitcoin_cli createwallet default 2>/dev/null || true
run_bitcoin_cli loadwallet default 2>/dev/null || true

# Generate address and blocks
ADDRESS=$(run_bitcoin_cli getnewaddress)
# Make sure address was returned
if [ -z "$ADDRESS" ]; then
  log_error "Failed to generate address"
  docker logs $CONTAINER_NAME
  exit 1
fi

echo "Mining 101 blocks to make coins spendable"
run_bitcoin_cli generatetoaddress 101 "$ADDRESS"

# Verify container is functioning correctly
echo "Verifying Bitcoin testnet setup..."
if run_bitcoin_cli getblockchaininfo; then
  log_success "Bitcoin testnet ready for testing!"
  echo "RPC endpoint: http://localhost:${RPC_PORT}"
  echo "Username: $RPC_USER"
  echo "Password: $RPC_PASS"
  exit 0
else
  log_error "Failed to verify Bitcoin testnet setup"
  exit 1
fi