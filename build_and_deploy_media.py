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
REMOTE_MEDIA_DIR = "/mnt/cloudstorage/AndroidIVI/android_build/packages/apps/Car/Media"
LUNCH_TARGET = "evk_8mp-userdebug"
OUT_DEVICE = "evk_8mp"
APP_TARGET = "CarMediaApp"
PKG_NAME = "com.android.car.media"

LOCAL_WORKSPACE = "/home/petlap037/Desktop/IVI_App_Development"
LOCAL_MEDIA_DIR = os.path.join(LOCAL_WORKSPACE, "Media")
LOCAL_APK_PATH = os.path.join(LOCAL_MEDIA_DIR, "temp_apks", "CarMediaApp.apk")
REMOTE_APK_PATH = f"{REMOTE_AOSP_DIR}/out/target/product/{OUT_DEVICE}/system/priv-app/{APP_TARGET}/{APP_TARGET}.apk"
EMULATOR_APK_PATH = "/system/priv-app/AAECarMediaApp/AAECarMediaApp.apk"
ADB_BIN = "/home/petlap037/Android/Sdk/platform-tools/adb"

EXCLUDE_DIRS = {".git", ".idea", "temp_apks", "__pycache__", "dialer_decoded"}
EXCLUDE_EXTS = {".tar.gz", ".apk", ".log", ".tmp"}

def run_adb(args):
    cmd = [ADB_BIN] + args
    print(f"  [ADB] {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.stdout.strip():
        print(f"    stdout: {res.stdout.strip()}")
    if res.stderr.strip():
        print(f"    stderr: {res.stderr.strip()}")
    return res

def sftp_sync_dir(sftp, local_dir, remote_dir):
    print(f"[1/4] Syncing local files from {local_dir} to remote {remote_dir}...")
    count = 0
    for root, dirs, files in os.walk(local_dir):
        # Exclude specific directories
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        rel_path = os.path.relpath(root, local_dir)
        if rel_path == ".":
            r_target_dir = remote_dir
        else:
            r_target_dir = os.path.join(remote_dir, rel_path).replace("\\", "/")

        try:
            sftp.stat(r_target_dir)
        except IOError:
            print(f"  Creating remote dir: {r_target_dir}")
            # Ensure parent directories exist
            parts = r_target_dir.split('/')
            cur = ""
            for p in parts:
                if not p:
                    cur = "/"
                    continue
                cur = os.path.join(cur, p).replace("\\", "/")
                try:
                    sftp.stat(cur)
                except IOError:
                    sftp.mkdir(cur)

        for f in files:
            if any(f.endswith(ext) for ext in EXCLUDE_EXTS):
                continue
            local_file = os.path.join(root, f)
            remote_file = os.path.join(r_target_dir, f).replace("\\", "/")
            
            # Check if file needs uploading
            local_stat = os.stat(local_file)
            upload_needed = True
            try:
                remote_stat = sftp.stat(remote_file)
                if remote_stat.st_size == local_stat.st_size and int(remote_stat.st_mtime) >= int(local_stat.st_mtime):
                    upload_needed = False
            except IOError:
                upload_needed = True

            if upload_needed:
                print(f"  Uploading: {os.path.relpath(local_file, local_dir)} -> {remote_file}")
                sftp.put(local_file, remote_file)
                count += 1

    print(f"  Synced {count} files successfully.")

def main():
    print("===================================================")
    print(f"🚀 BUILDING & DEPLOYING {APP_TARGET}")
    print("===================================================")

    # 1. Connect SSH
    print(f"Connecting to {REMOTE_USER}@{REMOTE_HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(REMOTE_HOST, username=REMOTE_USER, password=REMOTE_PASSWORD, timeout=15)
    print("SSH connection established.")

    # 2. Sync Files
    sftp = ssh.open_sftp()
    sftp_sync_dir(sftp, LOCAL_MEDIA_DIR, REMOTE_MEDIA_DIR)
    sftp.close()

    # 3. Trigger Remote Build
    print(f"\n[2/4] Triggering AOSP Soong build for {APP_TARGET}...")
    build_cmd = (
        f"cd {REMOTE_AOSP_DIR} && bash -lc '"
        f"source build/envsetup.sh && "
        f"lunch {LUNCH_TARGET} && "
        f"rm -rf out/soong/.intermediates/packages/apps/Car/Media && "
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

    # 4. Download APK
    print(f"\n[3/4] Downloading {APP_TARGET}.apk from remote server...")
    os.makedirs(os.path.dirname(LOCAL_APK_PATH), exist_ok=True)
    os.makedirs(os.path.join(LOCAL_WORKSPACE, "temp_apks"), exist_ok=True)
    
    with SCPClient(ssh.get_transport()) as scp:
        scp.get(REMOTE_APK_PATH, LOCAL_APK_PATH)
        # Also copy to root temp_apks
        root_apk = os.path.join(LOCAL_WORKSPACE, "temp_apks", "CarMediaApp.apk")
        scp.get(REMOTE_APK_PATH, root_apk)

    if not os.path.exists(LOCAL_APK_PATH) or os.path.getsize(LOCAL_APK_PATH) == 0:
        print(f"❌ ERROR: Downloaded APK is missing or empty at {LOCAL_APK_PATH}")
        ssh.close()
        sys.exit(1)
    
    apk_size_mb = os.path.getsize(LOCAL_APK_PATH) / (1024 * 1024)
    print(f"✅ APK downloaded ({apk_size_mb:.2f} MB): {LOCAL_APK_PATH}")
    ssh.close()

    # 5. Flash to Emulator
    print("\n[4/4] Flashing APK to Emulator...")
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
    print("Pushing APK to emulator...")
    push_res = run_adb(["push", LOCAL_APK_PATH, EMULATOR_APK_PATH])
    if push_res.returncode != 0:
        print(f"❌ Failed to push APK to {EMULATOR_APK_PATH}")
        sys.exit(1)

    # Remove oat cache
    print("Clearing oat cache...")
    run_adb(["shell", "rm", "-rf", "/system/priv-app/AAECarMediaApp/oat"])

    # Disable interfering overlays
    print("Disabling conflicting Google Car UI overlays...")
    run_adb(["shell", "cmd", "overlay", "disable", "com.android.car.media.googlecarui.rro"])
    run_adb(["shell", "cmd", "overlay", "disable", "com.android.car.media.googlecarui.theme.orange.rro"])
    run_adb(["shell", "cmd", "overlay", "disable", "com.android.car.media.googlecarui.theme.pink.rro"])

    # Clear app data and launch
    print("Clearing app state and launching...")
    run_adb(["shell", "pm", "clear", PKG_NAME])
    run_adb(["shell", "am", "force-stop", PKG_NAME])
    run_adb(["shell", "am", "start", "-n", f"{PKG_NAME}/.MediaActivity"])

    # Sync filesystem
    run_adb(["shell", "sync"])

    print("\n===================================================")
    print(f"🎉 SUCCESS: {APP_TARGET} built and deployed to emulator!")
    print("===================================================")

if __name__ == "__main__":
    main()
