#!/bin/bash

# ==============================================================================
# AOSP HMI Auto-Deploy Script (Supports Launcher, Media, Dialer, and Settings)
# ==============================================================================

# --- Server Configuration ---
REMOTE_USER="pets"
REMOTE_HOST="pets-B360M-D3H"
REMOTE_DIR="/mnt/cloudstorage/AndroidIVI/android_build"

# --- Build Configuration ---
LUNCH_TARGET="evk_8mp-userdebug"
OUT_DEVICE="evk_8mp"

# --- Argument Parsing ---
APP_NAME=$1
if [ -z "$APP_NAME" ] || [ "$APP_NAME" == "Launcher" ]; then
    APP_TARGET="CarLauncher"
    PKG_NAME="com.android.car.carlauncher"
    REMOTE_APK_SUBPATH="system/priv-app/CarLauncher/CarLauncher.apk"
    EMULATOR_PATH="/system/priv-app/CarLauncher/CarLauncher.apk"
    OAT_PATH="/system/priv-app/CarLauncher/oat"
elif [ "$APP_NAME" == "Media" ]; then
    APP_TARGET="CarMediaApp"
    PKG_NAME="com.android.car.media"
    REMOTE_APK_SUBPATH="system/priv-app/CarMediaApp/CarMediaApp.apk"
    EMULATOR_PATH="/system/priv-app/AAECarMediaApp/AAECarMediaApp.apk"
    OAT_PATH="/system/priv-app/AAECarMediaApp/oat"
elif [ "$APP_NAME" == "Dialer" ]; then
    APP_TARGET="CarDialerApp"
    PKG_NAME="com.android.car.dialer"
    REMOTE_APK_SUBPATH="system/priv-app/CarDialerApp/CarDialerApp.apk"
    EMULATOR_PATH="/system/priv-app/AAECarDialerApp/AAECarDialerApp.apk"
    OAT_PATH="/system/priv-app/AAECarDialerApp/oat"
elif [ "$APP_NAME" == "Settings" ]; then
    APP_TARGET="CarSettings"
    PKG_NAME="com.android.car.settings"
    REMOTE_APK_SUBPATH="system/priv-app/CarSettings/CarSettings.apk"
    EMULATOR_PATH="/system/priv-app/CarSettings/CarSettings.apk"
    OAT_PATH="/system/priv-app/CarSettings/oat"
else
    APP_TARGET="$APP_NAME"
    PKG_NAME="com.android.$APP_NAME"
    REMOTE_APK_SUBPATH="system/priv-app/$APP_TARGET/$APP_TARGET.apk"
    EMULATOR_PATH="/system/priv-app/$APP_TARGET/$APP_TARGET.apk"
    OAT_PATH="/system/priv-app/$APP_TARGET/oat"
fi

echo "==================================================="
echo "🚀 INITIATING DEPLOYMENT FOR: $APP_TARGET"
echo "==================================================="

# 0. Sync local source code to remote server
echo "[0/4] Syncing local $APP_NAME code to remote build server..."
if [ -d "$APP_NAME" ]; then
    rsync -avz --exclude='.git' --exclude='temp_apks' ${APP_NAME}/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/packages/apps/Car/${APP_NAME}/
fi

# 1. Trigger Remote SSH Build
echo "[1/4] Compiling $APP_TARGET on remote server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd '${REMOTE_DIR}' && bash -lc 'set -e; source build/envsetup.sh && lunch ${LUNCH_TARGET} && rm -rf out/soong/.intermediates/packages/apps/Car/${APP_NAME} && m ${APP_TARGET}'"
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
echo "[4/4] Injecting APK to $EMULATOR_PATH and Restarting..."
adb push ${LOCAL_APK_PATH} ${EMULATOR_PATH}
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to push APK. Ensure emulator is started with -writable-system"
    exit 1
fi

# Clear oat cache
if [ -n "$OAT_PATH" ]; then
    adb shell rm -rf ${OAT_PATH}
fi

# Remove /data/app override if it exists (hardware boards install overrides here)
echo "Removing any /data/app override for ${PKG_NAME}..."
DATA_APP_PATH=$(adb shell pm path ${PKG_NAME} 2>/dev/null | grep 'data/app' | sed 's/package://g' | tr -d '\r')
if [ -n "$DATA_APP_PATH" ]; then
    DATA_APP_DIR=$(dirname $(dirname $DATA_APP_PATH))
    echo "Found /data/app override at: $DATA_APP_DIR"
    adb shell rm -rf "$DATA_APP_DIR"
fi

# Clear app data
adb shell pm clear ${PKG_NAME}

# Full reboot for clean APK reload on hardware
echo "Rebooting device for clean APK reload..."
adb reboot
adb wait-for-device

echo "==================================================="
echo "✅ SUCCESS: $APP_TARGET flashed and device rebooting!"
echo "==================================================="
