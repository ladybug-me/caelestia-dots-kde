#pragma once

#include <QJsonObject>
#include <QString>

namespace caelestia::config {

inline QJsonObject defaultKeybinds() {
    return QJsonObject{ { "nexus", "" }, { "showall", "" }, { "dashboard", "" }, { "screenshot", "Meta+Shift+S" },
        { "overview", "Meta+Tab" }, { "googleLens", "Meta+Shift+A" }, { "screenRecording", "Meta+Ctrl+S" }, { "lock", "Meta+L" },
        { "session", "Ctrl+Alt+Delete" }, { "launcher", "Meta+Space; Meta" }, { "launcherInterrupt", "" },
        { "sidebar", "Meta+B" }, { "aiAssistant", "" }, { "utilities", "" }, { "emoji", "Meta+Shift+V" },
        { "clipboard", "Meta+V" }, { "windowSwitcher", "Alt+Tab" }, { "windowSwitcherReverse", "Alt+Shift+Tab" },
        { "wallpaper", "Meta+Ctrl+T" }, { "keybinds", "Meta+/" }, { "foot", "Meta+Return" }, { "firefox", "Meta+W" },
        { "code", "Meta+C" }, { "github-desktop", "Meta+G" }, { "nemo", "Meta+Alt+E" },
        { "kcolorpicker", "Meta+Shift+C" }, { "krohnkiteFocusUp", "Meta+Up" }, { "krohnkiteFocusDown", "Meta+Down" },
        { "krohnkiteFocusLeft", "Meta+Left" }, { "krohnkiteFocusRight", "Meta+Right" },
        { "krohnkiteShiftUp", "Meta+Shift+Up" }, { "krohnkiteShiftDown", "Meta+Shift+Down" },
        { "krohnkiteShiftLeft", "Meta+Shift+Left" }, { "krohnkiteShiftRight", "Meta+Shift+Right" },
        { "krohnkiteCloseWindow", "Meta+Q" }, { "krohnkiteFocusNext", "" }, { "krohnkiteFocusPrev", "" },
        { "krohnkiteSetMaster", "" }, { "krohnkiteNextLayout", "" }, { "krohnkitePreviousLayout", "" },
        { "krohnkiteBTreeLayout", "" }, { "krohnkiteMonocleLayout", "" }, { "krohnkiteFloatingLayout", "" },
        { "krohnkiteQuarterLayout", "" }, { "krohnkiteSpreadLayout", "" }, { "krohnkiteStackedLayout", "" },
        { "krohnkiteStairLayout", "" }, { "krohnkiteColumnsLayout", "" }, { "krohnkiteThreeColumnLayout", "" },
        { "krohnkiteSpiralLayout", "" }, { "krohnkiteTileLayout", "" }, { "krohnkiteGrowHeight", "" },
        { "krohnkiteShrinkHeight", "" }, { "krohnkiteGrowWidth", "" }, { "krohnkiteShrinkWidth", "" },
        { "krohnkiteIncreaseMaster", "" }, { "krohnkiteDecreaseMaster", "" }, { "krohnkiteToggleFloat", "" },
        { "krohnkiteFloatAll", "" }, { "krohnkiteRotate", "" }, { "krohnkiteRotatePart", "" },
        { "krohnkiteToggleDock", "" }, { "screenshotFreeze", "" }, { "screenshotClip", "" },
        { "screenshotFreezeClip", "" }, { "unlock", "" }, { "regionScreenshot", "" }, { "regionSearch", "" },
        { "regionOcr", "" }, { "regionRecord", "" }, { "regionRecordWithSound", "" }, { "brightnessUp", "" },
        { "brightnessDown", "" }, { "refreshDevices", "" }, { "mediaToggle", "" }, { "mediaPrev", "" },
        { "mediaNext", "" }, { "mediaStop", "" }, { "clearNotifs", "" }, { "workspace1", "Meta+1" },
        { "workspace2", "Meta+2" }, { "workspace3", "Meta+3" }, { "workspace4", "Meta+4" }, { "workspace5", "Meta+5" },
        { "workspace6", "Meta+6" }, { "workspace7", "Meta+7" }, { "workspace8", "Meta+8" }, { "workspace9", "Meta+9" },
        { "workspace10", "Meta+0" } };
}

} // namespace caelestia::config
