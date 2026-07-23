#!/bin/bash

# Firebase Emulator Quick-Start Script for MixVy Permission Testing
# Usage: ./tools/run_emulator_tests.sh
# Status: Production-ready

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Firebase Emulator Testing Suite - Room Join Permissions          ║${NC}"
echo -e "${BLUE}║  MixVy v2 - 2026-07-03                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Java installation
echo -e "${YELLOW}[1/5] Checking Java installation...${NC}"
if ! command -v java &> /dev/null; then
    echo -e "${RED}✗ Java not found. Install Java 21+${NC}"
    exit 1
fi
JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[^"]*')
echo -e "${GREEN}✓ Java ${JAVA_VERSION} found${NC}"

# Check Firebase CLI
echo -e "${YELLOW}[2/5] Checking Firebase CLI...${NC}"
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}✗ Firebase CLI not found. Run: npm install -g firebase-tools${NC}"
    exit 1
fi
FIREBASE_VERSION=$(firebase --version)
echo -e "${GREEN}✓ Firebase ${FIREBASE_VERSION} found${NC}"

# Verify firestore.rules exists
echo -e "${YELLOW}[3/5] Verifying firestore.rules...${NC}"
if [ ! -f "firestore.rules" ]; then
    echo -e "${RED}✗ firestore.rules not found in current directory${NC}"
    exit 1
fi
RULE_COUNT=$(grep -c "function\|match" firestore.rules || true)
echo -e "${GREEN}✓ firestore.rules validated (${RULE_COUNT} rules/functions)${NC}"

# Kill existing emulator processes
echo -e "${YELLOW}[4/5] Cleaning up existing processes...${NC}"
pkill -f "firebase emulators" || true
sleep 2
echo -e "${GREEN}✓ Previous emulator instances stopped${NC}"

# Start emulators
echo -e "${YELLOW}[5/5] Starting Firebase Emulator Suite...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Emulator Dashboard: http://localhost:4000${NC}"
echo -e "${YELLOW}Firestore Emulator: 127.0.0.1:8085${NC}"
echo -e "${YELLOW}Auth Emulator: 127.0.0.1:9099${NC}"
echo ""
echo -e "${BLUE}Starting in ${YELLOW}TEST MODE${BLUE}...${NC}"
echo ""

firebase emulators:start \
  --project=mixvy-rules-test \
  --only=firestore,auth \
  --import=./emulator-backup 2>/dev/null || \
firebase emulators:start \
  --project=mixvy-rules-test \
  --only=firestore,auth

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Emulator Suite Ready${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Open: http://localhost:4000 (Emulator Dashboard)"
echo "2. Copy test commands from FIREBASE_EMULATOR_TEST_PLAN_2026-07-03.md"
echo "3. Paste into browser console to run permission tests"
echo "4. Monitor Firestore collection: rooms → {roomId} → participants"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop emulator${NC}"
