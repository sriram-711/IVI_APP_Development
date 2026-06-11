# Figma Design Requirements: IVI Media Player
**Target Device Profile**: 10-inch Center Display (Landscape)
**Resolution**: 1200 x 800 px (Aspect Ratio 3:2)

---

## 1. Global Layout Parameters & Safe Zones

* **Driver Reach (Safe Zone)**: Primary interactive controls (play/pause, source tabs, search, back button) should favor the driver’s side of the screen (typically left-aligned for LHD or right-aligned for RHD).
* **Base Margins**: Standard horizontal padding should be at least **48px** to keep touch targets clear of the physical screen bezels.
* **Touch Target Size**: A minimum of **76 x 76px** (physical target of 9–10mm) for driving safety.
* **Color System (Theme Option 2 Prep)**: Define a semantic design token palette instead of hardcoded colors:
  * `--color-bg-primary` (Background)
  * `--color-text-primary` (Titles)
  * `--color-text-secondary` (Subtitles/Labels)
  * `--color-accent` (Progress bar, active tabs, buttons)
  * `--color-surface` (Card backgrounds, list items)

---

## 2. Screen 1: Browse & Content Discovery (Browsing Mode)

This screen manages folders, tabs, search, and navigation.

```
+-----------------------------------------------------------+
| [Back]   [Tab 1]   [Tab 2]   [Tab 3]          [App Selector] |  <- App Bar / Toolbar
+-----------------------------------------------------------+
|                                                           |
|  [Grid/List Item]   [Grid/List Item]   [Grid/List Item]   |  <- Content Area
|  (Playlists, Albums, Folders, Songs)                      |
|                                                           |
+-----------------------------------------------------------+
| [Art] Song Title - Artist                  [Play] [Next]  |  <- Minimized Playback Bar
+-----------------------------------------------------------+
```

### Required UI Components:
1. **App Bar / Toolbar**:
   * **Back Navigation Button** (visible when nested inside browse folders or when searching).
   * **Horizontal Navigation Tabs** (used when the media source has multiple categories like *Library*, *Browse*, *Favorites*).
   * **App Selector / Settings Icon** (allows switching active media sources e.g., Bluetooth, USB, Spotify).
   * **Search Trigger Button** (opens standard wide-screen keyboard input).
2. **Content Area** (Dynamic grid/list container):
   * **List View Layout**: Item title, optional subtitle, circular or rounded square album art/thumbnail, chevron/right arrow indicating folders.
   * **Grid View Layout**: Standard square card layout, larger artwork, item title underneath.
   * **Headers / Subheaders**: Category title separators.
3. **Minimized Playback Control Bar**:
   * Statically anchored to the bottom of the browse interface when music is playing.
   * Elements: Small rounded album art (e.g., 64x64px), track title, artist name, mini-play/pause button, skip next button.

---

## 3. Screen 2: Fullscreen Playback Screen (Playback Mode)

The main player screen showing active song metadata, progress, and primary controls.

```
+-----------------------------------------------------------+
| [Collapse/Down]             Media App Logo     [Queue Btn]|  <- Top Action Bar
+-----------------------------------------------------------+
|                                                           |
|  +-------+   Track Title (2 lines max)                    |  <- Album Art & Text
|  |       |   Artist Name                                  |
|  |  Art  |   Album Title                                  |
|  +-------+   02:15 -------------------------- 04:30       |  <- Progress Slider
|                                                           |
|          [Shuffle] [Prev]   [Play/Pause]   [Next] [Repeat]|  <- Control Panel
+-----------------------------------------------------------+
```

### Required UI Components:
1. **Top Action Bar**:
   * **Collapse/Minimize Button** (down-chevron to return to Browse mode).
   * **Active Media App Logo** (e.g., Spotify, USB Media center branding icon).
   * **Queue Toggle Button** (opens the side/overlay play queue).
2. **Metadata & Artwork Card**:
   * **Album Art View**: Large prominent image (e.g., 280x280px or 320x320px) with customizable corner radius.
   * **Song Title**: Bold, high-hierarchy typography supporting text wrapping (up to 2 lines).
   * **Artist & Album Name**: Secondary typography, medium contrast.
3. **Progress / Seek Bar**:
   * Linear slider with a visible progress line, background track, and a circular thumb control for dragging/seeking.
   * **Time Stamps**: Current playback time (left) and total track duration (right).
4. **Playback Control Panel** (5-button block):
   * **Center Action**: Play/Pause button (largest target, e.g., 96x96px or 110x110px).
   * **Secondary Actions**: Skip Previous, Skip Next.
   * **Tertiary Actions / Custom Buttons**: Shuffle, Repeat, Like/Thumbs-up (dynamic depending on the active app).

---

## 4. Screen 3: Play Queue (Queue Overlay Mode)

Toggled from the Playback screen. Typically slides or overlays the artwork/metadata section.

```
+-----------------------------------------------------------+
| [Collapse/Down]             Media App Logo     [Queue Act]|
+-----------------------------------------------------------+
|  +---------------------+  +----------------------------+  |
|  | Queue List Items:   |  | Playback Controls:         |  |
|  | [Eq] Song 1 (Playing)|  | Track Title                |  |
|  | [Art] Song 2        |  | Artist                     |  |
|  | [Art] Song 3        |  |                            |  |
|  +---------------------+  | [Prev] [Play] [Next]       |  |
|                           +----------------------------+  |
+-----------------------------------------------------------+
```

### Required UI Components:
* **List View**: Vertical scrollable queue list.
* **Queue Row Details**:
  * Rounded thumbnail (optional).
  * Title and Subtitle.
  * **Now Playing Indicator**: Equalizer animation or distinct accent color highlighting the currently active queue row.
  * Active time/duration display inline.

---

## 5. Screen 4: Error & Disconnected States (Fatal Error Mode)

```
+-----------------------------------------------------------+
|                                                           |
|                       [Illustration]                      |
|                                                           |
|                 "Cannot connect to the app"               |
|                                                           |
|                       [Select App]                        |
|                                                           |
+-----------------------------------------------------------+
```

### Required UI Components:
* **Vector Illustration / Icon**: Clean graphic for connection issues or empty states.
* **Error Message**: Prominent user-friendly copy (e.g. "Nothing playing", "Connection timeout").
* **Action Button**: Primary buttons such as "Retry Connection" or "Select Another Media Source".

---

## 6. Figma Typography & Token Blueprint

To support dynamic in-app skins, define the following variables in Figma:

| Token Name | Default (Dark) | Sport Theme | Classic Theme | Modern/Neon Theme |
|---|---|---|---|---|
| `--font-primary` | Inter | Roboto Condensed | Outfit | Space Grotesk |
| `--font-size-title` | 32sp | 34sp (Semi-Bold) | 30sp (Regular) | 36sp (Medium) |
| `--color-accent` | `#00E5FF` | `#FF1744` (Sport Red) | `#D4AF37` (Gold) | `#E040FB` (Neon Violet) |
| `--border-radius` | 16px | 4px (Angular) | 24px (Soft) | 32px (Pill) |
| `--scrim-opacity` | 60% | 85% (High Contrast) | 40% (Soft shadow) | 70% (Glassmorphic) |
