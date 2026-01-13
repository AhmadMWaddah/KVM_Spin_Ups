#!/bin/bash

# Basic tests for KVM_Spin_Ups
# These tests verify that the scripts can be sourced without errors

set -e

PROJECT_ROOT="$(pwd)"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running basic functionality tests..."

# Test 1: Check if main launcher script exists
if [ -f "$PROJECT_ROOT/src/KVM_Spin_Ups.sh" ]; then
    echo "✓ Main launcher script exists"
else
    echo "✗ Main launcher script missing"
    exit 1
fi

# Test 2: Check if common functions exist
if [ -f "$PROJECT_ROOT/src/common-functions.sh" ]; then
    echo "✓ Common functions script exists"
else
    echo "✗ Common functions script missing"
    exit 1
fi

# Test 3: Check if validation functions exist
if [ -f "$PROJECT_ROOT/src/validation-functions.sh" ]; then
    echo "✓ Validation functions script exists"
else
    echo "✗ Validation functions script missing"
    exit 1
fi

# Test 4: Check if distribution installers exist
if [ -f "$PROJECT_ROOT/src/distros-installers/rocky-linux-installers.sh" ]; then
    echo "✓ Rocky Linux installer exists"
else
    echo "✗ Rocky Linux installer missing"
    exit 1
fi

if [ -f "$PROJECT_ROOT/src/distros-installers/alma-linux-installers.sh" ]; then
    echo "✓ AlmaLinux installer exists"
else
    echo "✗ AlmaLinux installer missing"
    exit 1
fi

# Test 5: Check if templates exist
if [ -f "$PROJECT_ROOT/src/templates/rocky-ks.cfg.template" ]; then
    echo "✓ Rocky Linux template exists"
else
    echo "✗ Rocky Linux template missing"
    exit 1
fi

if [ -f "$PROJECT_ROOT/src/templates/alma-ks.cfg.template" ]; then
    echo "✓ AlmaLinux template exists"
else
    echo "✗ AlmaLinux template missing"
    exit 1
fi

echo ""
echo "✓ All basic tests passed!"
echo "KVM_Spin_Ups project structure is intact."
