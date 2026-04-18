# WiFi Kernel Modules Build for OnePlus 11R

## Overview

This repository contains scripts and configurations to build backported WiFi kernel modules for the OnePlus 11R.

### Included Drivers

- **MediaTek MT7921** (USB/PCIe/SDIO)
- **Realtek RTL8XXXU** - Unified USB driver
- **Realtek RTW88** - Next-gen driver

## Quick Start

### Method 1: Automated Build Script

```bash
chmod +x build-wifi-modules.sh
./build-wifi-modules.sh
```

### Method 2: GitHub Actions

1. Upload `allbackport-fixed.yml` to `.github/workflows/`
2. Trigger workflow from Actions tab
3. Download artifacts from Releases

## What Was Fixed

### Original Issue
Only `compat.ko` was generated instead of all WiFi modules.

### Root Causes
1. Incomplete backports configuration
2. Missing core module dependencies (MT76_CORE, RTW88_CORE)
3. Kernel features incompatibility (CFI, LTO)

### Fixes Applied

1. **Comprehensive Configuration**:
   - Added all required core modules
   - Enabled proper dependency chain

2. **Kernel Preparation**:
   - Disabled CFI/LTO
   - Enabled CONFIG_CFG80211 and CONFIG_MAC80211 as modules

3. **Enhanced Verification**:
   - Check for specific modules after build
   - Better error reporting

## Expected Output

Successful build should generate **15-25 .ko files**:

**Core:**
- compat.ko, cfg80211.ko, mac80211.ko

**MediaTek:**
- mt76.ko, mt76-usb.ko, mt7921-common.ko, mt7921u.ko, etc.

**Realtek:**
- rtl8xxxu.ko, rtw88_core.ko, rtw88_usb.ko, etc.

## Installation

### Via Recovery (Easiest)
1. Flash `wireless-modules-flashable-*.zip` in TWRP
2. Reboot

### Manual
```bash
adb root && adb remount
adb push *.ko /system/lib/modules/
adb shell chmod 644 /system/lib/modules/*.ko
# Load modules in order (see module load order)
```

## Troubleshooting

Run diagnostic:
```bash
chmod +x diagnose-build.sh
./diagnose-build.sh
```

See TROUBLESHOOTING.md for detailed solutions.

## Files

- `build-wifi-modules.sh` - Main build script
- `allbackport-fixed.yml` - Fixed GitHub Actions workflow  
- `diagnose-build.sh` - Diagnostic tool
- `TROUBLESHOOTING.md` - Troubleshooting guide

---

**Target:** OnePlus 11R (SM8475)
**Kernel:** 5.10.236
**Backports:** 6.1.97-1
