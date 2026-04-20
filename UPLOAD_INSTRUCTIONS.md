# 🚀 Upload Fixed Workflow to GitHub Actions

## Step-by-Step Instructions

### Option A: Via GitHub Web UI (Easiest)

1. **Go to your repository** on GitHub
   - Navigate to the repository where your original `allbackport.yml` is located

2. **Navigate to the workflows folder**
   - Click on `.github` folder → `workflows` folder
   - (If the folder doesn't exist, create it: click "Add file" → "Create new file" → type `.github/workflows/` at the start of the name)

3. **Upload the fixed workflow**
   - Click **"Add file"** → **"Upload files"**
   - Drag and drop `/app/allbackport-fixed.yml` from this environment
   - OR click **"Create new file"** and:
     - Name it: `allbackport-fixed.yml`
     - Copy the content from `/app/allbackport-fixed.yml`

4. **Commit the file**
   - Scroll down
   - Commit message: `Add fixed WiFi modules build workflow`
   - Click **"Commit changes"**

---

### Option B: Via Git CLI

```bash
# In your local repository
cd /path/to/your/repo

# Create workflows directory if it doesn't exist
mkdir -p .github/workflows

# Copy the fixed workflow
# (Download allbackport-fixed.yml from this environment first)
cp /path/to/downloaded/allbackport-fixed.yml .github/workflows/

# Commit and push
git add .github/workflows/allbackport-fixed.yml
git commit -m "Add fixed WiFi modules build workflow"
git push origin main
```

---

### Option C: Replace Existing Workflow

If you want to **replace** your current `allbackport.yml`:

1. Go to `.github/workflows/allbackport.yml` in your repo
2. Click the ✏️ **edit** button
3. **Select all content** (Ctrl+A)
4. **Delete it**
5. **Paste content** from `/app/allbackport-fixed.yml`
6. Commit changes

---

## 🎯 Running the Workflow

After uploading:

1. **Go to Actions tab** in your GitHub repository
2. **Find the workflow**: `Build Wireless Backports Modules for OP11R (FIXED)`
3. Click **"Run workflow"** (top right)
4. **Configure inputs:**
   - **manifest**: Choose `OOS16` (for OnePlus 11 with Android 14/B)
     - `OOS14` → Android 14 (oneplus_11r_u.xml)
     - `OOS15` → Android 15 (oneplus_11r_v.xml)
     - `OOS16` → Android 16 Beta (oneplus_11r_b.xml)
   - **backports_release**: `backports-6.1.97-1` (default)
   - **build_jobs**: Start with `4` (good balance)
     - Use `2` if build fails with race conditions
     - Use `6-8` for faster builds if stable
5. Click **"Run workflow"** (green button)

---

## 📊 Monitoring the Build

The build has **21 steps**. Expected timeline:

| Step | Duration | What's happening |
|------|----------|------------------|
| Setup & cleanup | 1-2 min | Installing dependencies |
| Repo init & sync | **10-15 min** | Downloading kernel source (~10GB) |
| Kernel prepare | 3-5 min | Configuring and preparing kernel |
| Backports download | 1 min | Getting backports-6.1.97-1 |
| **Backports build** | **15-25 min** | **Building all WiFi modules** |
| Verify & package | 2-3 min | Creating archives and flashable zip |
| **TOTAL** | **~35-50 min** | |

---

## ✅ Expected Success Output

When the build succeeds, you should see:

```
=== Searching for .ko files ===
Total .ko files found: 23

✓ .ko files generated:
  ./compat/compat.ko
  ./net/wireless/cfg80211.ko
  ./net/mac80211/mac80211.ko
  ./drivers/net/wireless/mediatek/mt76/mt76.ko
  ./drivers/net/wireless/mediatek/mt76/mt76-usb.ko
  ./drivers/net/wireless/mediatek/mt76/mt76-sdio.ko
  ./drivers/net/wireless/mediatek/mt76/mt7921/mt7921-common.ko
  ./drivers/net/wireless/mediatek/mt76/mt7921/mt7921u.ko
  ./drivers/net/wireless/mediatek/mt76/mt7921/mt7921e.ko
  ./drivers/net/wireless/mediatek/mt76/mt7921/mt7921s.ko
  ./drivers/net/wireless/realtek/rtl8xxxu/rtl8xxxu.ko
  ./drivers/net/wireless/realtek/rtw88/rtw88_core.ko
  ./drivers/net/wireless/realtek/rtw88/rtw88_usb.ko
  ... (more)

Checking for critical WiFi modules:
  ✓ Found: cfg80211.ko
  ✓ Found: mac80211.ko
  ✓ Found: mt76.ko
  ✓ Found: mt7921.ko
  ✓ Found: rtl8xxxu.ko
  ✓ Found: rtw88_core.ko
  ✓ Found: compat.ko
```

---

## 📦 Downloading Build Results

After successful build:

### Option 1: From Releases (Automatic)
- Go to your repo → **Releases** tab
- Look for `wifi-modules-v<run-number>`
- Download:
  - `wireless-modules-flashable-<N>.zip` ← **Flash this in TWRP**
  - `wireless-modules-op11r-<N>.zip` ← Raw modules

### Option 2: From Actions Artifacts
- Go to **Actions** tab
- Click on the completed workflow run
- Scroll to **Artifacts** section
- Download `wireless-modules-op11r-<run-number>`

---

## 🐛 If Build Fails

### Check which step failed:
1. Click on the failed run in Actions tab
2. Expand the failed step (red ❌)
3. Scroll to find error messages

### Common failures and fixes:

#### **"Disk space full"**
- Rerun with `build_jobs: 2` (lower memory usage)
- The workflow already does cleanup, but some OnePlus kernels are huge

#### **"Sync failed"**
- OnePlus GitHub may be slow/down
- Just rerun the workflow (it retries 3 times)

#### **"Build failed - undefined symbol"**
- Check if kernel prepare step completed
- Look for missing kernel config in logs
- Share the error with me for debugging

#### **"Only 1 .ko generated" (compat.ko)**
- This shouldn't happen with the fixed workflow!
- If it does, share the `backports.config` artifact with me
- I'll analyze what config is being applied

---

## 🎬 Quick Command Reference

After you upload and trigger the workflow, share back:
- The **run URL** (so I can reference it)
- Any **error messages** if it fails
- The **build summary** when it succeeds

---

## 📝 Verification Checklist

Before running:
- [ ] `allbackport-fixed.yml` is in `.github/workflows/` folder
- [ ] File was committed to main branch
- [ ] Repository has Actions enabled (Settings → Actions → Allow all actions)

During run:
- [ ] Workflow appears in Actions tab
- [ ] "Run workflow" button is available
- [ ] Inputs show manifest/backports_release/build_jobs options

After run:
- [ ] All 21 steps completed successfully (green ✓)
- [ ] Artifact `wireless-modules-op11r-<N>` is available
- [ ] Release created with flashable zip
- [ ] Build summary shows 15+ .ko files

---

**Ready to proceed!** Upload the workflow and trigger it. I'll be here to help if anything goes wrong.

📁 **File location:** `/app/allbackport-fixed.yml` (26KB)
