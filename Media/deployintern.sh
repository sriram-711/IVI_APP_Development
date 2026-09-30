#!/bin/bash

# ==============================================================================
# AOSP HMI Auto-Deploy Script (Windows Git Bash)
# ==============================================================================

error_trap() {
    echo ""
    echo "❌ SCRIPT CRASHED DETECTED!"
    echo ""
    read -p "Press [Enter] to close..."
}
trap 'error_trap' ERR

set -e

# ------------------------------------------------------------------------------
# Prevent Git Bash path conversion
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
# Determine App Target
# ------------------------------------------------------------------------------

if [ -z "$1" ] || [ "$1" == "Media" ]; then
    APP_TARGET="CarMediaApp"
    REMOTE_APK_PATH="${REMOTE_DIR}/out/target/product/${OUT_DEVICE}/system/priv-app/CarMediaApp/CarMediaApp.apk"
    EMULATOR_APK_PATH="/system/priv-app/AAECarMediaApp/AAECarMediaApp.apk"
else
    APP_TARGET="$1"
fi

echo "==================================================="
echo "🚀 Deploying ${APP_TARGET}"
echo "==================================================="

###############################################################################
# STEP 1 : BUILD
###############################################################################

echo ""
echo "[1/3] Building..."

ssh "${REMOTE_USER}@${REMOTE_HOST}" "
cd ${REMOTE_DIR} &&
source build/envsetup.sh &&
lunch ${LUNCH_TARGET} &&
rm -rf out/soong/.intermediates/packages/apps/Car/Media &&
m ${APP_TARGET}
"

echo ""
echo "✅ Remote build completed."

###############################################################################
# STEP 2 : DOWNLOAD APK
###############################################################################

echo ""
echo "[2/3] Downloading APK..."

mkdir -p ./temp_apks

LOCAL_APK_PATH="./temp_apks/${APP_TARGET}.apk"

scp "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APK_PATH}" "${LOCAL_APK_PATH}"

test -f "${LOCAL_APK_PATH}"

echo "✅ APK downloaded."

###############################################################################
# STEP 3 : DEPLOY
###############################################################################

echo ""
echo "[3/3] Deploying..."

adb root
adb wait-for-device

echo ""
echo "Checking remount status..."

REMOUNT_OUTPUT=$(adb remount 2>&1 || true)

echo "$REMOUNT_OUTPUT"

###########################################################################
# First-time verity disable
###########################################################################

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

echo ""
echo "Pushing APK..."

adb push "${LOCAL_APK_PATH}" "${EMULATOR_APK_PATH}"

echo ""
echo "Removing oat cache..."

adb shell rm -rf /system/priv-app/AAECarMediaApp/oat

adb shell sync

echo ""
echo "Rebooting..."

adb reboot

echo ""
echo "==================================================="
echo "✅ Deployment completed successfully."
echo "==================================================="

read -p "Press [Enter] to close..."