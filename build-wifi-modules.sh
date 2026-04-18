#!/bin/bash
# WiFi Modules Backport Build Script for OnePlus 11R
# Builds MediaTek MT7921 and Realtek RTL8XXX WiFi drivers

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE="${WORKSPACE:-$(pwd)}"
MODEL="${MODEL:-OP11R}"
SOC="${SOC:-waipio}"
CONFIG="${CONFIG:-OP11R}"
BRANCH="${BRANCH:-oneplus/sm8475}"
MANIFEST="${MANIFEST:-oneplus_11r_b.xml}"
BACKPORTS_VERSION="${BACKPORTS_VERSION:-backports-6.1.97-1}"
JOBS="${JOBS:-4}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Step 1: Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    for dep in git curl wget tar make gcc clang python3; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=($dep)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing dependencies..."
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends \
            git curl ca-certificates build-essential clang lld flex bison \
            libelf-dev libssl-dev libncurses-dev zlib1g-dev liblz4-tool \
            libxml2-utils rsync unzip dwarves file python3 ccache wget patch jq \
            coccinelle kmod bc perl xz-utils zip device-tree-compiler \
            python3-dev python-is-python3
    fi
    
    log_success "All dependencies are available"
}

# Step 2: Setup kernel source (if not already done)
setup_kernel_source() {
    local kernel_dir="$WORKSPACE/$CONFIG/kernel_platform/msm-kernel"
    
    if [ -d "$kernel_dir" ]; then
        log_success "Kernel source already exists at: $kernel_dir"
        return 0
    fi
    
    log_info "Kernel source not found. You need to sync it using repo tool."
    log_info "Run the following commands manually:"
    echo ""
    echo "  mkdir -p $WORKSPACE/$CONFIG"
    echo "  cd $WORKSPACE/$CONFIG"
    echo "  repo init -u https://github.com/OnePlusOSS/kernel_manifest.git -b $BRANCH -m $MANIFEST --depth=1"
    echo "  repo sync -c --no-clone-bundle --no-tags -j\$(nproc)"
    echo ""
    log_error "Please sync kernel source first, then re-run this script"
    exit 1
}

# Step 3: Prepare kernel
prepare_kernel() {
    log_info "Preparing kernel build environment..."
    
    local msm_dir="$WORKSPACE/$CONFIG/kernel_platform/msm-kernel"
    local out_dir="$msm_dir/out"
    
    cd "$msm_dir"
    
    # Detect kernel version
    VERSION=$(grep '^VERSION *=' Makefile | awk '{print $3}')
    PATCHLEVEL=$(grep '^PATCHLEVEL *=' Makefile | awk '{print $3}')
    SUBLEVEL=$(grep '^SUBLEVEL *=' Makefile | awk '{print $3}')
    KERNEL_VER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"
    
    log_info "Kernel version: $KERNEL_VER"
    
    # Clean and prepare
    make ARCH=arm64 mrproper || true
    mkdir -p "$out_dir"
    
    # Find clang
    if [ -z "$CLANG_BIN" ]; then
        # Try to find prebuilt clang
        for search_dir in "$msm_dir/../prebuilts-master/clang/host/linux-x86" \
                          "$msm_dir/../common/prebuilts-master/clang/host/linux-x86" \
                          "$WORKSPACE/$CONFIG/prebuilts-master/clang/host/linux-x86"; do
            if [ -d "$search_dir" ]; then
                local latest=$(find "$search_dir" -maxdepth 1 -type d -name "clang-r*" | sort -V | tail -n1)
                if [ -n "$latest" ] && [ -x "$latest/bin/clang" ]; then
                    export CLANG_BIN="$latest/bin"
                    log_success "Found clang at: $CLANG_BIN"
                    break
                fi
            fi
        done
        
        if [ -z "$CLANG_BIN" ]; then
            export CLANG_BIN=$(dirname $(command -v clang))
            log_warning "Using system clang at: $CLANG_BIN"
        fi
    fi
    
    export PATH="${CLANG_BIN}:$PATH"
    
    # Setup make flags
    export MAKE_FLAGS=(
        LLVM=1
        LLVM_IAS=1
        ARCH=arm64
        SUBARCH=arm64
        CLANG_TRIPLE=aarch64-linux-gnu-
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LD=ld.lld
        AR=llvm-ar
        NM=llvm-nm
        OBJCOPY=llvm-objcopy
        OBJDUMP=llvm-objdump
        STRIP=llvm-strip
        CC=clang
        HOSTCC=clang
        HOSTCXX=clang++
    )
    
    # Merge configs
    log_info "Merging kernel configs..."
    ./scripts/kconfig/merge_config.sh -O "$out_dir" -m \
        arch/arm64/configs/gki_defconfig \
        arch/arm64/configs/vendor/${SOC}_GKI.config || {
        log_warning "Config merge had warnings, continuing..."
    }
    
    cp "$out_dir/.config" arch/arm64/configs/gki_defconfig
    make O="$out_dir" "${MAKE_FLAGS[@]}" olddefconfig > /dev/null
    
    # Configure WiFi as modules
    log_info "Configuring WiFi drivers as modules..."
    if [ -x ./scripts/config ]; then
        ./scripts/config --file "$out_dir/.config" --set-val CONFIG_CFG80211 m
        ./scripts/config --file "$out_dir/.config" --set-val CONFIG_MAC80211 m
        ./scripts/config --file "$out_dir/.config" --set-val CONFIG_WLAN m
        ./scripts/config --file "$out_dir/.config" --enable CONFIG_WIRELESS
        ./scripts/config --file "$out_dir/.config" --enable CONFIG_WIRELESS_EXT
        ./scripts/config --file "$out_dir/.config" --enable CONFIG_WEXT_PRIV
    fi
    
    # Disable problematic features for backports
    log_info "Disabling incompatible kernel features..."
    if [ -x ./scripts/config ]; then
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_CFI
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_CFI_CLANG
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_LTO_CLANG
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_LTO_CLANG_THIN
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_SHADOW_CALL_STACK
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_KASAN
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_KASAN_SW_TAGS
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_KASAN_HW_TAGS
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_UBSAN
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_UBSAN_TRAP
        ./scripts/config --file "$out_dir/.config" --disable CONFIG_UBSAN_BOUNDS
    fi
    
    # Prepare kernel
    log_info "Running kernel prepare and modules_prepare..."
    make O="$out_dir" "${MAKE_FLAGS[@]}" olddefconfig > /dev/null
    make O="$out_dir" "${MAKE_FLAGS[@]}" prepare > /dev/null
    make O="$out_dir" "${MAKE_FLAGS[@]}" modules_prepare > /dev/null
    
    log_success "Kernel preparation complete"
}

# Step 4: Download and setup backports
setup_backports() {
    log_info "Setting up backports..."
    
    local backports_dir="$WORKSPACE/backports-stable"
    
    if [ -d "$backports_dir" ]; then
        log_warning "Backports directory exists, cleaning..."
        rm -rf "$backports_dir"
    fi
    
    # Download backports
    log_info "Downloading $BACKPORTS_VERSION..."
    wget -q --show-progress -O "$WORKSPACE/backports.tar.xz" \
        "https://cdn.kernel.org/pub/linux/kernel/projects/backports/stable/v6.1.97/${BACKPORTS_VERSION}.tar.xz"
    
    log_info "Extracting backports..."
    tar -xf "$WORKSPACE/backports.tar.xz" -C "$WORKSPACE"
    mv "$WORKSPACE/$BACKPORTS_VERSION" "$backports_dir"
    rm "$WORKSPACE/backports.tar.xz"
    
    log_success "Backports extracted to: $backports_dir"
}

# Step 5: Patch backports for CFI compatibility
patch_backports() {
    log_info "Applying CFI compatibility patches..."
    
    local backports_dir="$WORKSPACE/backports-stable"
    cd "$backports_dir"
    
    # Patch CFI in module.h
    local module_h="backport-include/linux/module.h"
    if [ -f "$module_h" ]; then
        sed -i 's/__CFI_ADDRESSABLE(init_module, __initdata)/__CFI_ADDRESSABLE(init_module)/g' "$module_h"
        sed -i 's/__CFI_ADDRESSABLE(cleanup_module, __exitdata)/__CFI_ADDRESSABLE(cleanup_module)/g' "$module_h"
        log_success "CFI patch applied to $module_h"
    fi
    
    log_success "Backports patched successfully"
}

# Step 6: Configure backports with proper driver selection
configure_backports() {
    log_info "Configuring backports for MediaTek and Realtek drivers..."
    
    local backports_dir="$WORKSPACE/backports-stable"
    local kernel_build="$WORKSPACE/$CONFIG/kernel_platform/msm-kernel/out"
    
    cd "$backports_dir"
    
    # Create comprehensive backports config
    cat > .config <<'CONFIGEOF'
# Core wireless stack
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_CFG80211_WEXT=y
CONFIG_MAC80211_RC_MINSTREL=y
CONFIG_MAC80211_LEDS=y

# Wireless extensions
CONFIG_WIRELESS_EXT=y
CONFIG_WEXT_PRIV=y
CONFIG_WEXT_CORE=y
CONFIG_WEXT_PROC=y
CONFIG_WEXT_SPY=y

# MediaTek MT76 Core
CONFIG_MT76_CORE=m
CONFIG_MT76_LEDS=y
CONFIG_MT76_USB=m
CONFIG_MT76_MMIO=m
CONFIG_MT76_SDIO=m

# MediaTek MT7921 (USB/PCIe/SDIO)
CONFIG_MT7921_COMMON=m
CONFIG_MT7921U=m
CONFIG_MT7921E=m
CONFIG_MT7921S=m

# MediaTek MT7615
CONFIG_MT7615_COMMON=m
CONFIG_MT7615E=m

# MediaTek MT7663
CONFIG_MT7663_USB_SDIO_COMMON=m
CONFIG_MT7663U=m
CONFIG_MT7663S=m

# Realtek RTL8XXXU (USB)
CONFIG_RTL8XXXU=m
CONFIG_RTL8XXXU_UNTESTED=y

# Realtek RTL8188EU
CONFIG_RTL8188EU=m

# Realtek RTL8192EU
CONFIG_RTL8192EU=m

# Realtek RTL8723BU
CONFIG_RTL8723BU=m

# Realtek RTL8723CU
CONFIG_RTL8723CU=m

# Realtek RTL8821CU
CONFIG_RTL8821CU=m

# Realtek RTW88 Core
CONFIG_RTW88=m
CONFIG_RTW88_CORE=m
CONFIG_RTW88_USB=m
CONFIG_RTW88_SDIO=m
CONFIG_RTW88_8822B=m
CONFIG_RTW88_8822C=m
CONFIG_RTW88_8723D=m
CONFIG_RTW88_8821C=m

# Realtek RTW89 (newer)
CONFIG_RTW89=m
CONFIG_RTW89_CORE=m
CONFIG_RTW89_8852AE=m
CONFIG_RTW89_8852BE=m
CONFIG_RTW89_8852CE=m

# Disable Intel and other non-needed drivers
CONFIG_IWLWIFI=n
CONFIG_IWLMVM=n
CONFIG_IWLDVM=n
CONFIG_ATH10K=n
CONFIG_ATH11K=n
CONFIG_ATH9K=n
CONFIG_BRCMFMAC=n
CONFIG_MWIFIEX=n

# Enable debug (optional, can be disabled for production)
# CONFIG_MAC80211_DEBUG_MENU=y
# CONFIG_CFG80211_DEVELOPER_WARNINGS=y
CONFIGEOF

    log_success "Backports config created"
    
    # Run gentree to generate the backport tree
    log_info "Generating backport tree..."
    make KLIB="$kernel_build" KLIB_BUILD="$kernel_build" defconfig-wifi || {
        log_warning "defconfig-wifi not available, using custom config"
    }
    
    # Apply our config
    log_info "Applying custom configuration..."
    export PATH="${CLANG_BIN}:$PATH"
    
    # Use yes to accept defaults for new options
    yes "" | make "${MAKE_FLAGS[@]}" \
        KLIB="$kernel_build" \
        KLIB_BUILD="$kernel_build" \
        oldconfig 2>&1 | tail -20
    
    log_success "Backports configured successfully"
    
    # Verify config
    log_info "Verifying critical config options..."
    grep "CONFIG_MT7921" .config || log_warning "MT7921 config not found!"
    grep "CONFIG_RTL8XXXU" .config || log_warning "RTL8XXXU config not found!"
    grep "CONFIG_RTW88" .config || log_warning "RTW88 config not found!"
}

# Step 7: Build backports modules
build_backports() {
    log_info "Building backports modules..."
    
    local backports_dir="$WORKSPACE/backports-stable"
    local kernel_build="$WORKSPACE/$CONFIG/kernel_platform/msm-kernel/out"
    local build_log="$WORKSPACE/backports-build.log"
    
    cd "$backports_dir"
    
    # Clean previous builds
    log_info "Cleaning previous build artifacts..."
    make clean 2>/dev/null || true
    find . -name "*.o" -delete 2>/dev/null || true
    find . -name "*.ko" -delete 2>/dev/null || true
    find . -name ".tmp_versions" -type d -exec rm -rf {} + 2>/dev/null || true
    
    export PATH="${CLANG_BIN}:$PATH"
    export CCACHE_DIR="$WORKSPACE/.ccache"
    mkdir -p "$CCACHE_DIR"
    
    log_info "Starting build (this may take several minutes)..."
    log_info "Build output will be logged to: $build_log"
    
    # Build with moderate parallelism to avoid symbol resolution issues
    make -j${JOBS} \
        "${MAKE_FLAGS[@]}" \
        KLIB="$kernel_build" \
        KLIB_BUILD="$kernel_build" \
        V=1 \
        2>&1 | tee "$build_log"
    
    local build_exit=$?
    
    if [ $build_exit -ne 0 ]; then
        log_error "Build failed with exit code $build_exit"
        log_info "Last 100 lines of build log:"
        tail -100 "$build_log"
        return 1
    fi
    
    log_success "Build completed successfully!"
}

# Step 8: Verify and collect modules
verify_and_collect_modules() {
    log_info "Verifying generated .ko files..."
    
    local backports_dir="$WORKSPACE/backports-stable"
    local output_dir="$WORKSPACE/wifi-modules-output"
    
    cd "$backports_dir"
    
    # Find all .ko files
    KO_FILES=$(find . -name "*.ko" -type f 2>/dev/null)
    KO_COUNT=$(echo "$KO_FILES" | grep -c '\.ko$' || true)
    
    log_info "Total .ko files found: $KO_COUNT"
    
    if [ "$KO_COUNT" -eq 0 ]; then
        log_error "CRITICAL: No .ko files generated!"
        log_info "Checking build log for errors..."
        grep -i "error\|undefined\|failed" "$WORKSPACE/backports-build.log" | head -30
        return 1
    fi
    
    echo ""
    log_success ".ko files generated:"
    echo "$KO_FILES" | sort | while read ko; do
        if [ -n "$ko" ]; then
            size=$(du -h "$ko" | cut -f1)
            printf "  [%s] %s\n" "$size" "$ko"
        fi
    done
    
    # Create output directory
    mkdir -p "$output_dir"
    rm -rf "$output_dir"/*
    
    # Copy all .ko files
    log_info "Copying modules to output directory..."
    find . -name "*.ko" -type f -exec cp -v {} "$output_dir/" \;
    
    # List what we got
    echo ""
    log_success "Modules in output directory:"
    ls -lh "$output_dir"/*.ko 2>/dev/null || log_warning "No modules copied!"
    
    # Check for specific drivers
    echo ""
    log_info "Checking for specific WiFi drivers:"
    
    check_module() {
        local module_name=$1
        if ls "$output_dir"/${module_name}*.ko 1> /dev/null 2>&1; then
            log_success "Found: ${module_name}"
        else
            log_warning "Missing: ${module_name}"
        fi
    }
    
    check_module "cfg80211"
    check_module "mac80211"
    check_module "mt76"
    check_module "mt7921"
    check_module "rtl8xxxu"
    check_module "rtw88"
    check_module "compat"
    
    log_success "Module verification complete"
}

# Step 9: Create flashable package
create_flashable_package() {
    log_info "Creating flashable module package..."
    
    local output_dir="$WORKSPACE/wifi-modules-output"
    local package_dir="$WORKSPACE/wifi-modules-package"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local archive_name="wifi-modules-op11r-${timestamp}.zip"
    
    mkdir -p "$package_dir/system/lib/modules"
    
    # Copy modules
    cp "$output_dir"/*.ko "$package_dir/system/lib/modules/" 2>/dev/null || {
        log_error "No modules to package!"
        return 1
    }
    
    # Create installation script
    cat > "$package_dir/install.sh" <<'INSTALLEOF'
#!/system/bin/sh
# WiFi Modules Installation Script

MODPATH="/system/lib/modules"
MODULES=(
    "compat.ko"
    "cfg80211.ko"
    "mac80211.ko"
    "mt76.ko"
    "mt76-usb.ko"
    "mt76-sdio.ko"
    "mt7921-common.ko"
    "mt7921u.ko"
    "mt7921e.ko"
    "mt7921s.ko"
    "rtl8xxxu.ko"
    "rtw88_core.ko"
    "rtw88_usb.ko"
)

echo "Installing WiFi modules..."

for module in "${MODULES[@]}"; do
    if [ -f "$MODPATH/$module" ]; then
        echo "Loading $module..."
        insmod "$MODPATH/$module" || echo "Warning: Failed to load $module"
    fi
done

echo "WiFi modules installation complete!"
INSTALLEOF

    chmod +x "$package_dir/install.sh"
    
    # Create README
    cat > "$package_dir/README.txt" <<README
WiFi Modules Package for OnePlus 11R
=====================================

This package contains backported WiFi drivers:
- MediaTek MT7921 (USB/PCIe/SDIO)
- Realtek RTL8XXXU
- Realtek RTW88

Installation:
1. Extract this package
2. Copy modules to /system/lib/modules/
3. Run install.sh to load modules
4. Or manually load with: insmod /system/lib/modules/<module>.ko

Build Date: $(date)
Kernel Version: $KERNEL_VER (if available)
Backports Version: $BACKPORTS_VERSION

For more information, visit:
https://wireless.wiki.kernel.org/en/users/drivers
README

    # Create archive
    cd "$package_dir"
    zip -r "$WORKSPACE/$archive_name" * > /dev/null
    
    log_success "Flashable package created: $archive_name"
    log_info "Package location: $WORKSPACE/$archive_name"
    log_info "Package size: $(du -h "$WORKSPACE/$archive_name" | cut -f1)"
    
    # Also create a simple tar.gz for easier extraction
    tar -czf "$WORKSPACE/wifi-modules-op11r-${timestamp}.tar.gz" -C "$output_dir" .
    log_success "Also created: wifi-modules-op11r-${timestamp}.tar.gz"
}

# Step 10: Generate build report
generate_report() {
    log_info "Generating build report..."
    
    local report_file="$WORKSPACE/BUILD_REPORT.txt"
    
    cat > "$report_file" <<REPORTEOF
WiFi Modules Build Report
=========================
Build Date: $(date)
Model: $MODEL
SOC: $SOC
Branch: $BRANCH
Manifest: $MANIFEST
Backports Version: $BACKPORTS_VERSION

Kernel Information:
-------------------
$(cd "$WORKSPACE/$CONFIG/kernel_platform/msm-kernel" && make kernelversion 2>/dev/null || echo "Unknown")

Build Configuration:
--------------------
Jobs: $JOBS
Clang: $CLANG_BIN

Modules Generated:
------------------
$(ls -lh "$WORKSPACE/wifi-modules-output"/*.ko 2>/dev/null || echo "No modules found")

Module Count: $(ls -1 "$WORKSPACE/wifi-modules-output"/*.ko 2>/dev/null | wc -l)

Packages Created:
-----------------
$(ls -lh "$WORKSPACE"/*.zip "$WORKSPACE"/*.tar.gz 2>/dev/null || echo "No packages created")

Build Logs:
-----------
Full build log: $WORKSPACE/backports-build.log

Build Status: SUCCESS
REPORTEOF

    log_success "Build report saved to: $report_file"
    cat "$report_file"
}

# Main execution
main() {
    echo ""
    log_info "==================================="
    log_info "WiFi Modules Backport Build Script"
    log_info "==================================="
    echo ""
    
    check_dependencies
    setup_kernel_source
    prepare_kernel
    setup_backports
    patch_backports
    configure_backports
    build_backports
    verify_and_collect_modules
    create_flashable_package
    generate_report
    
    echo ""
    log_success "==================================="
    log_success "Build completed successfully!"
    log_success "==================================="
    echo ""
    log_info "Output files:"
    log_info "  - Modules: $WORKSPACE/wifi-modules-output/"
    log_info "  - Packages: $WORKSPACE/*.zip, *.tar.gz"
    log_info "  - Report: $WORKSPACE/BUILD_REPORT.txt"
    echo ""
}

# Run main function
main "$@"
