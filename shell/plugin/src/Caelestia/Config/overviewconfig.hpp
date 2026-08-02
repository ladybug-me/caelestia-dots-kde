#pragma once

#include "configobject.hpp"

namespace caelestia::config {

class OverviewConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, disableWallpaperBlur, true)
    CONFIG_PROPERTY(bool, enableOverviewBlur, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 30)
    CONFIG_PROPERTY(int, hoverThickness, 20)
    CONFIG_PROPERTY(bool, hoverTopLeft, false)
    CONFIG_PROPERTY(bool, hoverTopRight, true)
    CONFIG_PROPERTY(bool, hoverBottomLeft, false)
    CONFIG_PROPERTY(bool, hoverBottomRight, false)

    CONFIG_PROPERTY(int, baseDuration, 300)
    CONFIG_PROPERTY(qreal, blobScaleSpeed, 1.0)
    CONFIG_PROPERTY(qreal, wallpaperFadeSpeed, 1.0)
    CONFIG_PROPERTY(qreal, gridFadeSpeed, 1.0)
    CONFIG_PROPERTY(int, easingType, 2) // Easing.OutQuad
    CONFIG_PROPERTY(int, layoutType, 1) // 0: KDE, 1: GNOME

public:
    explicit OverviewConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
