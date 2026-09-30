#!/bin/bash

# ==============================================================================
# AOSP Launcher Auto-Deploy Script
# ==============================================================================

# --- Server Configuration ---
REMOTE_USER="pets"
REMOTE_HOST="pets-B360M-D3H"
REMOTE_DIR="/mnt/cloudstorage/AndroidIVI/android_build"

# --- Build Configuration ---
LUNCH_TARGET="evk_8mp-userdebug"
OUT_DEVICE="evk_8mp"
APP_TARGET="CarLauncher"
PKG_NAME="com.android.car.carlauncher"
REMOTE_APK_SUBPATH="system/priv-app/CarLauncher/CarLauncher.apk"
EMULATOR_PATH="/system/priv-app/GASCarLauncher/GASCarLauncher.apk"
OAT_PATH="/system/priv-app/GASCarLauncher/oat"

echo "==================================================="
echo "🚀 INITIATING DEPLOYMENT FOR: $APP_TARGET"
echo "==================================================="

# 0. Sync Local changes to Remote Server
echo "[0/4] Syncing local changes to remote server..."
rsync -avz --exclude='.git' --exclude='temp_apks' /home/petlap037/Desktop/IVI_App_Development/Launcher/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/packages/apps/Car/Launcher/
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to sync files to remote server."
    exit 1
fi

# 1. Trigger Remote SSH Build
echo "[1/4] Compiling $APP_TARGET on remote server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd '${REMOTE_DIR}' && bash -lc 'set -e; source build/envsetup.sh && lunch ${LUNCH_TARGET} && rm -rf out/soong/.intermediates/packages/apps/Car/Launcher && m ${APP_TARGET}'"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Remote Soong build failed."
    exit 1
fi

# 2. Download APK
echo "[2/4] Downloading generated APK..."
mkdir -p ./temp_apks
LOCAL_APK_PATH="./temp_apks/${APP_TARGET}.apk"
REMOTE_APK_PATH="${REMOTE_DIR}/out/target/product/${OUT_DEVICE}/${REMOTE_APK_SUBPATH}"

scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APK_PATH} ${LOCAL_APK_PATH}

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to download APK from $REMOTE_APK_PATH"
    exit 1
fi

# 3. Prepare Emulator
echo "[3/4] Preparing Emulator (Root & Remount)..."
adb root
adb wait-for-device
adb remount

# 4. Inject APK and Restart
echo "[4/4] Injecting APK and Restarting UI..."
adb push ${LOCAL_APK_PATH} ${EMULATOR_PATH}
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to push APK. Ensure emulator is started with -writable-system"
    exit 1
fi

if [ -n "$OAT_PATH" ]; then
    adb shell rm -rf ${OAT_PATH}
fi

adb shell pm clear ${PKG_NAME}
adb shell stop
adb shell start

echo "==================================================="
echo "✅ SUCCESS: $APP_TARGET is now live!"
echo "==================================================="
