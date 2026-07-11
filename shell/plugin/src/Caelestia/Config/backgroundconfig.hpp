#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace caelestia::config {

class DesktopClockBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)

public:
    explicit DesktopClockBackground(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockShadow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)

public:
    explicit DesktopClockShadow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-right"))
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)

public:
    explicit DesktopClock(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopClockBackground(this))
        , m_shadow(new DesktopClockShadow(this)) {}
};

class BackgroundVisualiser : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)

public:
    explicit BackgroundVisualiser(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopLyricsBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)

public:
    explicit DesktopLyricsBackground(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopLyricsShadow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)

public:
    explicit DesktopLyricsShadow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopLyrics : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-center"))
    CONFIG_PROPERTY(int, alignment, 1)
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopLyricsBackground, background)
    CONFIG_SUBOBJECT(DesktopLyricsShadow, shadow)

public:
    explicit DesktopLyrics(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopLyricsBackground(this))
        , m_shadow(new DesktopLyricsShadow(this)) {}
};

class BackgroundConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_PROPERTY(bool, wallpaperRecolor, false)
    CONFIG_PROPERTY(qreal, wallpaperRecolorStrength, 0.5)
    CONFIG_PROPERTY(bool, slideshowEnabled, false)
    CONFIG_PROPERTY(qreal, slideshowInterval, 0.16)
    CONFIG_PROPERTY(bool, slideshowRandom, true)
    CONFIG_PROPERTY(bool, videoWallpaperPaused, false)
    CONFIG_PROPERTY(bool, videoWallpaperSoundEnabled, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnFullscreen, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnTiled, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnAllDisplays, false)
    CONFIG_PROPERTY(bool, videoWallpaperMuteOnMedia, false)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(DesktopLyrics, desktopLyrics)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)

public:
    explicit BackgroundConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_desktopClock(new DesktopClock(this))
        , m_desktopLyrics(new DesktopLyrics(this))
        , m_visualiser(new BackgroundVisualiser(this)) {}
};

} // namespace caelestia::config
