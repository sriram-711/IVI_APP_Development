#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import paramiko
from scp import SCPClient

REMOTE_USER = "pets"
REMOTE_HOST = "pets-B360M-D3H"
REMOTE_PASSWORD = "pets"
REMOTE_AOSP_DIR = "/mnt/cloudstorage/AndroidIVI/android_build"
REMOTE_LAUNCHER_DIR = "/mnt/cloudstorage/AndroidIVI/android_build/packages/apps/Car/Launcher"
LUNCH_TARGET = "evk_8mp-userdebug"
OUT_DEVICE = "evk_8mp"
APP_TARGET = "CarLauncher"
PKG_NAME = "com.android.car.carlauncher"

LOCAL_WORKSPACE = "/home/petlap037/Desktop/IVI_App_Development"
LOCAL_LAUNCHER_DIR = os.path.join(LOCAL_WORKSPACE, "Launcher")
LOCAL_APK_PATH = os.path.join(LOCAL_LAUNCHER_DIR, "temp_apks", "CarLauncher.apk")
REMOTE_APK_PATH = f"{REMOTE_AOSP_DIR}/out/target/product/{OUT_DEVICE}/system/priv-app/{APP_TARGET}/{APP_TARGET}.apk"
EMULATOR_APK_PATH = "/system/priv-app/GASCarLauncher/GASCarLauncher.apk"
ADB_BIN = "/home/petlap037/Android/Sdk/platform-tools/adb"

def run_adb(args):
    cmd = [ADB_BIN] + args
    print(f"  [ADB] {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.stdout.strip():
        print(f"    stdout: {res.stdout.strip()}")
    if res.stderr.strip():
        print(f"    stderr: {res.stderr.strip()}")
    return res

def sftp_sync_from_remote(sftp, remote_dir, local_dir):
    print(f"Syncing remote {remote_dir} to local {local_dir}...")
    for item in sftp.listdir_attr(remote_dir):
        if item.filename in [".git", "temp_apks", "build.log"]:
            continue
        r_path = f"{remote_dir}/{item.filename}"
        l_path = os.path.join(local_dir, item.filename)
        
        # Check if directory (mode & 0o040000)
        import stat
        if stat.S_ISDIR(item.st_mode):
            os.makedirs(l_path, exist_ok=True)
            sftp_sync_from_remote(sftp, r_path, l_path)
        else:
            sftp.get(r_path, l_path)

def main():
    print("===================================================")
    print(f"🚀 RESTORING, BUILDING & DEPLOYING {APP_TARGET}")
    print("===================================================")

    # 1. Connect SSH
    print(f"Connecting to {REMOTE_USER}@{REMOTE_HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(REMOTE_HOST, username=REMOTE_USER, password=REMOTE_PASSWORD, timeout=15)
    print("SSH connection established.")

    # 2. Restore pristine git state on remote server for Launcher
    print("\n[1/5] Restoring pristine AOSP Launcher files (with full grid & AppGridActivity)...")
    restore_cmd = f"cd {REMOTE_LAUNCHER_DIR} && git restore . && git clean -fd"
    stdin, stdout, stderr = ssh.exec_command(restore_cmd)
    stdout.channel.recv_exit_status()
    print("Remote Launcher restored to original state.")

    # 3. Sync restored files back to local workspace
    print("\n[2/5] Updating local Launcher codebase with restored files...")
    sftp = ssh.open_sftp()
    sftp_sync_from_remote(sftp, REMOTE_LAUNCHER_DIR, LOCAL_LAUNCHER_DIR)
    sftp.close()
    print("Local Launcher workspace synchronized.")

    # 4. Trigger Remote Build
    print(f"\n[3/5] Triggering AOSP Soong build for {APP_TARGET}...")
    build_cmd = (
        f"cd {REMOTE_AOSP_DIR} && bash -lc '"
        f"source build/envsetup.sh && "
        f"lunch {LUNCH_TARGET} && "
        f"rm -rf out/soong/.intermediates/packages/apps/Car/Launcher && "
        f"m {APP_TARGET}'"
    )
    print(f"Running build command on {REMOTE_HOST}...")
    stdin, stdout, stderr = ssh.exec_command(build_cmd, get_pty=True)
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    exit_status = stdout.channel.recv_exit_status()
    if exit_status != 0:
        print(f"\n❌ ERROR: Remote build failed with exit status {exit_status}")
        ssh.close()
        sys.exit(1)
    print("\n✅ Remote build completed successfully.")

    # 5. Download APK
    print(f"\n[4/5] Downloading {APP_TARGET}.apk from remote server...")
    os.makedirs(os.path.dirname(LOCAL_APK_PATH), exist_ok=True)
    os.makedirs(os.path.join(LOCAL_WORKSPACE, "temp_apks"), exist_ok=True)
    
    with SCPClient(ssh.get_transport()) as scp:
        scp.get(REMOTE_APK_PATH, LOCAL_APK_PATH)
        root_apk = os.path.join(LOCAL_WORKSPACE, "temp_apks", "CarLauncher.apk")
        scp.get(REMOTE_APK_PATH, root_apk)

    if not os.path.exists(LOCAL_APK_PATH) or os.path.getsize(LOCAL_APK_PATH) == 0:
        print(f"❌ ERROR: Downloaded APK is missing or empty at {LOCAL_APK_PATH}")
        ssh.close()
        sys.exit(1)
    
    apk_size_mb = os.path.getsize(LOCAL_APK_PATH) / (1024 * 1024)
    print(f"✅ APK downloaded ({apk_size_mb:.2f} MB): {LOCAL_APK_PATH}")
    ssh.close()

    # 6. Flash to Emulator
    print("\n[5/5] Flashing APK to Emulator...")
    run_adb(["root"])
    run_adb(["wait-for-device"])
    
    remount_res = run_adb(["remount"])
    if "Now reboot your device" in remount_res.stdout:
        print("Reboot required after disabling verity. Rebooting...")
        run_adb(["reboot"])
        run_adb(["wait-for-device"])
        time.sleep(5)
        run_adb(["root"])
        run_adb(["wait-for-device"])
        run_adb(["remount"])

    # Push APK
    print(f"Pushing APK to {EMULATOR_APK_PATH}...")
    push_res = run_adb(["push", LOCAL_APK_PATH, EMULATOR_APK_PATH])
    if push_res.returncode != 0:
        print(f"❌ Failed to push APK to {EMULATOR_APK_PATH}")
        sys.exit(1)

    # Remove oat cache
    print("Clearing oat cache...")
    run_adb(["shell", "rm", "-rf", "/system/priv-app/GASCarLauncher/oat"])

    # Clear app data and launch
    print("Clearing app state and launching...")
    run_adb(["shell", "pm", "clear", PKG_NAME])
    run_adb(["shell", "am", "force-stop", PKG_NAME])
    run_adb(["shell", "am", "start", "-n", f"{PKG_NAME}/.CarLauncher"])

    # Sync filesystem
    run_adb(["shell", "sync"])

    print("\n===================================================")
    print(f"🎉 SUCCESS: {APP_TARGET} built with full grid & deployed to emulator!")
    print("===================================================")

if __name__ == "__main__":
    main()
