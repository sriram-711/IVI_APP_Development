#!/bin/bash

# ==============================================================================
# AAOS Auto Deploy Script (Windows Git Bash)
# Deploys ClusterOsDouble to Android Automotive Emulator
# ==============================================================================

###############################################################################
# Error Handling
###############################################################################

error_trap() {
    echo ""
    echo "❌ SCRIPT CRASH DETECTED!"
    echo ""
    read -p "Press [Enter] to close..."
}

trap 'error_trap' ERR

set -e

# ------------------------------------------------------------------------------
# Prevent Git Bash from converting Linux paths
# ------------------------------------------------------------------------------
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

# ------------------------------------------------------------------------------
# Remote Server Configuration
# ------------------------------------------------------------------------------
REMOTE_USER="pets"
REMOTE_HOST="pets-B360M-D3H"
REMOTE_DIR="/mnt/cloudstorage/AndroidIVI/android_build"

# ------------------------------------------------------------------------------
# Build Configuration
# ------------------------------------------------------------------------------
LUNCH_TARGET="evk_8mp-userdebug"
OUT_DEVICE="evk_8mp"

# ------------------------------------------------------------------------------
# Cluster App Configuration
# ------------------------------------------------------------------------------
APP_TARGET="ClusterOsDouble"
PKG_NAME="com.android.car.cluster.osdouble"

REMOTE_APK_PATH="${REMOTE_DIR}/out/target/product/${OUT_DEVICE}/system/app/ClusterOsDouble/ClusterOsDouble.apk"
LOCAL_APK_PATH="./temp_apks/ClusterOsDouble.apk"

EMULATOR_APK_PATH="/system/app/ClusterOsDouble/ClusterOsDouble.apk"

echo "==================================================="
echo "🚀 Deploying ${APP_TARGET}"
echo "==================================================="

###############################################################################
# STEP 1 : BUILD
###############################################################################

echo ""
echo "[1/4] Building..."

ssh "${REMOTE_USER}@${REMOTE_HOST}" "
cd ${REMOTE_DIR} &&
source build/envsetup.sh &&
lunch ${LUNCH_TARGET} &&
m ${APP_TARGET}
"

echo ""
echo "✅ Remote build completed."

###############################################################################
# STEP 2 : DOWNLOAD APK
###############################################################################

echo ""
echo "[2/4] Downloading APK..."

mkdir -p ./temp_apks

scp "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APK_PATH}" "${LOCAL_APK_PATH}"

test -f "${LOCAL_APK_PATH}"

echo "✅ APK downloaded."

###############################################################################
# STEP 3 : PREPARE EMULATOR
###############################################################################

echo ""
echo "[3/4] Preparing emulator..."

adb root
adb wait-for-device

echo ""
echo "Checking remount status..."

REMOUNT_OUTPUT=$(adb remount 2>&1 || true)

echo "$REMOUNT_OUTPUT"

###############################################################################
# First-time verity disable handling
###############################################################################

if echo "$REMOUNT_OUTPUT" | grep -q "Now reboot your device"; then

    echo ""
    echo "System requested reboot after disabling verity."
    echo "Rebooting emulator..."

    adb reboot

    echo ""
    echo "Waiting for emulator..."

    adb wait-for-device

    echo "Waiting for Android boot..."

    until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]
    do
        sleep 2
    done

    adb root
    adb wait-for-device

    echo ""
    echo "Running remount again..."

    adb remount
    adb wait-for-device
fi

###############################################################################
# STEP 4 : DEPLOY
###############################################################################

echo ""
echo "[4/4] Deploying..."

echo ""
echo "Pushing APK..."

adb push "${LOCAL_APK_PATH}" "${EMULATOR_APK_PATH}"

echo ""
echo "Clearing app data..."

adb shell pm clear "${PKG_NAME}"

echo ""
echo "Restarting Android framework..."

adb shell stop
adb shell start

echo ""
echo "==================================================="
echo "✅ ClusterOsDouble deployed successfully."
echo "==================================================="

read -p "Press [Enter] to close..."