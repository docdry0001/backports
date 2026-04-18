#!/bin/bash
# Diagnostic Script for WiFi Module Build Issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo ""
log_info "====================================="
log_info "WiFi Module Build Diagnostic Script"
log_info "====================================="
echo ""

# Check 1: Kernel source
log_info "Checking kernel source..."
if [ -d "OP11R/kernel_platform/msm-kernel" ]; then
    log_success "Kernel source found"
    KERNEL_VER=$(cd OP11R/kernel_platform/msm-kernel && make kernelversion 2>/dev/null || echo "Unknown")
    log_info "Kernel version: $KERNEL_VER"
else
    log_error "Kernel source not found at OP11R/kernel_platform/msm-kernel"
    log_info "You need to sync kernel source first"
fi

# Check 2: Backports source
log_info "Checking backports source..."
if [ -d "backports-stable" ]; then
    log_success "Backports source found"
    if [ -f "backports-stable/.config" ]; then
        log_success "Backports configuration exists"
        CONFIG_COUNT=$(grep -c "=m" backports-stable/.config || echo "0")
        log_info "Configured modules: $CONFIG_COUNT"
    else
        log_warning "No backports configuration found"
    fi
else
    log_warning "Backports source not found at backports-stable/"
fi

# Check 3: Toolchain
log_info "Checking toolchain..."
if command -v clang &> /dev/null; then
    CLANG_VER=$(clang --version | head -1)
    log_success "Clang found: $CLANG_VER"
else
    log_error "Clang not found"
fi

if command -v aarch64-linux-gnu-gcc &> /dev/null; then
    log_success "ARM64 cross-compiler found"
else
    log_warning "ARM64 cross-compiler not found (might use prebuilt)"
fi

# Check 4: Built modules
log_info "Checking for built modules..."
if [ -d "backports-stable" ]; then
    KO_COUNT=$(find backports-stable -name "*.ko" 2>/dev/null | wc -l)
    if [ $KO_COUNT -gt 0 ]; then
        log_success "Found $KO_COUNT .ko files"
        echo ""
        log_info "Module list:"
        find backports-stable -name "*.ko" | sort | while read ko; do
            size=$(du -h "$ko" | cut -f1)
            echo "  [$size] $(basename $ko)"
        done
    else
        log_warning "No .ko files found (not built yet or build failed)"
    fi
fi

if [ -d "wifi-modules-output" ]; then
    OUTPUT_COUNT=$(ls -1 wifi-modules-output/*.ko 2>/dev/null | wc -l)
    if [ $OUTPUT_COUNT -gt 0 ]; then
        log_success "Found $OUTPUT_COUNT modules in output directory"
    fi
fi

# Check 5: Build logs
log_info "Checking build logs..."
if [ -f "backports-build.log" ]; then
    log_success "Build log found: backports-build.log"
    ERROR_COUNT=$(grep -c "error:" backports-build.log 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "warning:" backports-build.log 2>/dev/null || echo "0")
    log_info "Errors: $ERROR_COUNT, Warnings: $WARNING_COUNT"
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo ""
        log_error "Recent errors from build log:"
        grep "error:" backports-build.log | tail -10
    fi
else
    log_warning "No build log found"
fi

# Check 6: Dependencies
log_info "Checking system dependencies..."
DEPS=("make" "gcc" "flex" "bison" "bc")
MISSING_DEPS=()

for dep in "${DEPS[@]}"; do
    if ! command -v $dep &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    log_success "All key dependencies installed"
else
    log_warning "Missing dependencies: ${MISSING_DEPS[*]}"
    log_info "Install with: sudo apt-get install ${MISSING_DEPS[*]}"
fi

# Summary
echo ""
log_info "====================================="
log_info "Diagnostic Summary"
log_info "====================================="
echo ""

if [ -d "OP11R/kernel_platform/msm-kernel" ] && [ -d "backports-stable" ] && command -v clang &> /dev/null; then
    log_success "Environment looks good for building"
    echo ""
    log_info "Next steps:"
    echo "  1. Run: chmod +x build-wifi-modules.sh"
    echo "  2. Run: ./build-wifi-modules.sh"
else
    log_warning "Environment needs setup:"
    [ ! -d "OP11R/kernel_platform/msm-kernel" ] && echo "  - Sync kernel source"
    [ ! -d "backports-stable" ] && echo "  - Download backports"
    ! command -v clang &> /dev/null && echo "  - Install clang"
fi

echo ""
