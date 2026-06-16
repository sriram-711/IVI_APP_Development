#!/bin/bash

# ==============================================================================
# AOSP HMI Auto-Deploy Script
# Compiles app on remote Linux server, downloads via SCP, and installs via ADB.
# ==============================================================================

# --- Server Configuration ---
# Using the credentials from your previous terminal logs
REMOTE_USER="pets"
REMOTE_HOST="pets-B360M-D3H" # (Change to your server's IP address if the hostname fails to resolve on Windows)
REMOTE_DIR="/mnt/cloudstorage/AndroidIVI/android_build"

# --- Build Configuration ---
# The target used to generate x86_64 APKs for your local emulator
LUNCH_TARGET="evk_8mp-userdebug" 
OUT_DEVICE="evk_8mp" # The folder name Soong generates in out/target/product/

# --- Argument Parsing ---
# Default to CarMediaApp if no argument is provided
if [ -z "$1" ] || [ "$1" == "Media" ]; then
    APP_TARGET="CarMediaApp"
elif [ "$1" == "Dialer" ]; then
    APP_TARGET="CarDialerApp"
else
    APP_TARGET="$1"
fi

echo "==================================================="
echo "🚀 INITIATING DEPLOYMENT FOR: $APP_TARGET"
echo "==================================================="

# ---------------------------------------------------------
# STEP 1: Trigger Remote SSH Build
# ---------------------------------------------------------
echo "[1/3] Compiling $APP_TARGET on remote server ($REMOTE_HOST)..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_DIR} && source build/envsetup.sh && lunch ${LUNCH_TARGET} && m ${APP_TARGET}"

# Check if the build command was successful
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Remote Soong build failed. Aborting deployment."
    exit 1
fi

# ---------------------------------------------------------
# STEP 2: Download APK via SCP
# ---------------------------------------------------------
echo ""
echo "[2/3] Downloading generated APK to Windows..."

# Create a temporary local directory to hold the downloaded APK
mkdir -p ./temp_apks
LOCAL_APK_PATH="./temp_apks/${APP_TARGET}.apk"

# Assuming the APK outputs to system/priv-app/ (Standard for Car system apps)
REMOTE_APK_PATH="${REMOTE_DIR}/out/target/product/${OUT_DEVICE}/system/priv-app/${APP_TARGET}/${APP_TARGET}.apk"

scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APK_PATH} ${LOCAL_APK_PATH}

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to download APK. The build may have placed it in a different output directory."
    exit 1
fi

# ---------------------------------------------------------
# STEP 3: Install locally via ADB
# ---------------------------------------------------------
echo ""
echo "[3/3] Pushing APK to local Android Studio Emulator..."

# ADB Flags:
# -r : Replace existing application (updates it)
# -d : Allow version code downgrade (prevents errors if NXP base is older)
# -g : Automatically grant all runtime permissions (Microphone, Bluetooth, etc.)
#adb install -r -d -g ${LOCAL_APK_PATH}
adb push ${LOCAL_APK_PATH} /product/priv-app/$APP_TARGET.apk
adb shell cmd package install-existing com.android.car.media
if [ $? -eq 0 ]; then
    echo "==================================================="
    echo "✅ SUCCESS: $APP_TARGET is live on your emulator!"
    echo "==================================================="
else
    echo "❌ ERROR: ADB installation failed. Ensure your emulator is booted and running."
fi