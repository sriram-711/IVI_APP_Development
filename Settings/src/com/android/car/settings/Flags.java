package com.android.car.settings;

/**
 * Simplified feature flag provider for environments without aconfig support.
 *
 * This file is a minimal stub that enables builds in older Soong environments
 * by providing the expected class and symbols directly in source.
 */
public final class Flags {
    public static final int FLAG_CAMERA_PRIVACY_ALLOWLIST = 0;
    public static final int FLAG_MICROPHONE_PRIVACY_UPDATES = 0;
    public static final int FLAG_HOTSPOT_UI_SPEED_UPDATE = 0;
    public static final int FLAG_UPDATE_DATE_AND_TIME_PAGE = 0;

    private Flags() {
    }

    public static boolean uiThemeToggle() {
        return false;
    }

    public static boolean requiredInfotainmentAppsSettingsPage() {
        return false;
    }

    public static boolean microphonePrivacyUpdates() {
        return false;
    }

    public static boolean hotspotUiSpeedUpdate() {
        return false;
    }

    public static boolean updateDateAndTimePage() {
        return false;
    }

    public static boolean newFragmentForIntents() {
        return false;
    }

    public static boolean workProfileApiSplit() {
        return false;
    }

    public static boolean areaIdConfigAccess() {
        return false;
    }

    public static boolean carAudioDynamicDevices() {
        return false;
    }

    public static boolean persistApSettings() {
        return false;
    }

    public static boolean supportsSecurePassengerUsers() {
        return false;
    }

    public static boolean cameraPrivacyAllowlist() {
        return false;
    }
}
