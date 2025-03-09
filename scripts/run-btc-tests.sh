#!/usr/bin/env bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine if cleanup is requested
CLEANUP=0
AUTO_CLEANUP=0

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=1
      shift
      ;;
    --auto-cleanup)
      AUTO_CLEANUP=1
      shift
      ;;
    *)
      # Unknown option
      shift
      ;;
  esac
done

# Function to cleanup if requested or on error
cleanup() {
  if [[ $CLEANUP -eq 1 || $AUTO_CLEANUP -eq 1 ]]; then
    echo -e "${YELLOW}Cleaning up Bitcoin testnet container...${NC}"
    ./scripts/stop-btc-testnet.sh
  else
    echo -e "${YELLOW}Bitcoin testnet container left running.${NC}"
    echo "Run './scripts/stop-btc-testnet.sh' when you're done testing."
  fi
}

# Set trap for cleanup on script exit if auto-cleanup is enabled
if [[ $AUTO_CLEANUP -eq 1 ]]; then
  trap cleanup EXIT
fi

echo -e "${YELLOW}Starting Bitcoin testnet and running integration tests...${NC}"

# First ensure Bitcoin testnet is running
if ! ./scripts/start-btc-testnet.sh; then
  echo -e "${RED}Failed to start Bitcoin testnet container${NC}"
  exit 1
fi

# Now run the tests
echo -e "${YELLOW}Running Bitcoin transaction builder tests...${NC}"
pnpm hardhat test test/BTCTxBuilder.integration.test.ts
TEST_RESULT=$?

if [[ $TEST_RESULT -eq 0 ]]; then
  echo -e "${GREEN}Tests completed successfully!${NC}"
else
  echo -e "${RED}Tests failed with exit code: $TEST_RESULT${NC}"
fi

# Cleanup if requested
if [[ $CLEANUP -eq 1 ]]; then
  cleanup
else
  echo "You can stop the Bitcoin testnet with: ./scripts/stop-btc-testnet.sh"
fi

exit $TEST_RESULT 