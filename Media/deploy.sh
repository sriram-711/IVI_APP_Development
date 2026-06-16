#!/bin/bash

# ==============================================================================
# AOSP HMI Auto-Deploy Script
# ==============================================================================

# --- Server Configuration ---
REMOTE_USER="pets"
REMOTE_HOST="pets-B360M-D3H"
REMOTE_DIR="/mnt/cloudstorage/AndroidIVI/android_build"

# --- Build Configuration ---
LUNCH_TARGET="evk_8mp-userdebug"
OUT_DEVICE="evk_8mp"

# --- Argument Parsing ---
if [ -z "$1" ] || [ "$1" == "Media" ]; then
    APP_TARGET="CarMediaApp"
    PKG_NAME="com.android.car.media"
    EMULATOR_PATH="/system/priv-app/AAECarMediaApp/AAECarMediaApp.apk"
elif [ "$1" == "Dialer" ]; then
    APP_TARGET="CarDialerApp"
    PKG_NAME="com.android.car.dialer"
    EMULATOR_PATH="/system/priv-app/CarDialerApp/CarDialerApp.apk"
else
    APP_TARGET="$1"
    PKG_NAME="com.android.$1"
    EMULATOR_PATH="/system/priv-app/$APP_TARGET/$APP_TARGET.apk"
fi

echo "==================================================="
echo "🚀 INITIATING DEPLOYMENT FOR: $APP_TARGET"
echo "==================================================="

# 1. Trigger Remote SSH Build
echo "[1/4] Compiling $APP_TARGET on remote server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_DIR} && source build/envsetup.sh && lunch ${LUNCH_TARGET} && m ${APP_TARGET}"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Remote Soong build failed."
    exit 1
fi

# 2. Download APK
echo "[2/4] Downloading generated APK..."
mkdir -p ./temp_apks
LOCAL_APK_PATH="./temp_apks/${APP_TARGET}.apk"
REMOTE_APK_PATH="${REMOTE_DIR}/out/target/product/${OUT_DEVICE}/system/priv-app/${APP_TARGET}/${APP_TARGET}.apk"

scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APK_PATH} ${LOCAL_APK_PATH}

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to download APK."
    exit 1
fi

# 3. Prepare Emulator
echo "[3/4] Preparing Emulator..."
adb root
adb remount
# Disable Overlays
adb shell cmd overlay disable com.android.car.media.googlecarui.rro > /dev/null 2>&1
adb shell cmd overlay disable com.android.car.media.googlecarui.theme.orange.rro > /dev/null 2>&1
adb shell cmd overlay disable com.android.car.media.googlecarui.theme.pink.rro > /dev/null 2>&1

# 4. Inject APK and Restart
echo "[4/4] Injecting APK and Restarting UI..."
adb push ${LOCAL_APK_PATH} ${EMULATOR_PATH}
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to push APK. Check if emulator is started with -writable-system"
    exit 1
fi

adb shell pm clear ${PKG_NAME}
adb shell stop
adb shell start

echo "==================================================="
echo "✅ SUCCESS: $APP_TARGET is now live!"
echo "==================================================="
