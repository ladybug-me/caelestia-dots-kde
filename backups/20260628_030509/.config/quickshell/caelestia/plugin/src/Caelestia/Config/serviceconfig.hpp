#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class ServiceConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, weatherLocation)
    // Guess based on locale
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheit,
        QLocale().measurementSystem() == QLocale::ImperialUSSystem ||
            QLocale().measurementSystem() == QLocale::ImperialUKSystem)
    // This is always false by default cause apparently even imperial system users don't use it for perf temps?
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheitPerformance, false)
    // Attempt to guess based on locale
    CONFIG_GLOBAL_PROPERTY(
        bool, useTwelveHourClock, QLocale().timeFormat(QLocale::ShortFormat).toLower().contains(u"a"_s))
    CONFIG_GLOBAL_PROPERTY(QString, gpuType)
    CONFIG_GLOBAL_PROPERTY(int, visualiserBars, 60)
    CONFIG_GLOBAL_PROPERTY(qreal, audioIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, brightnessIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, maxVolume, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, smartScheme, true)
    CONFIG_GLOBAL_PROPERTY(QString, defaultPlayer, u"Spotify"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, playerAliases,
        { vmap({ { u"from"_s, u"com.github.th_ch.youtube_music"_s }, { u"to"_s, u"YT Music"_s } }) })
    CONFIG_GLOBAL_PROPERTY(QString, lyricsBackend, u"Auto"_s)
    CONFIG_GLOBAL_PROPERTY(QStringList, bluetoothAutoReconnectDevices)

    // Discord ARPC Settings
    CONFIG_GLOBAL_PROPERTY(bool, arpcEnabled, false)
    CONFIG_GLOBAL_PROPERTY(QString, arpcClientId, u"1126685412586733678"_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcAppName, u"Caelestia Shell"_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcDetails, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcState, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcLargeImage, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcSmallImage, u""_s)
    CONFIG_GLOBAL_PROPERTY(bool, arpcSteamAutoDetect, false)
    CONFIG_GLOBAL_PROPERTY(QStringList, arpcSteamBlacklist)
    CONFIG_GLOBAL_PROPERTY(QStringList, arpcTargetWindows)
    CONFIG_GLOBAL_PROPERTY(bool, arpcCaelestiaInfo, false)
    CONFIG_GLOBAL_PROPERTY(bool, arpcManualOverride, false)

public:
    explicit ServiceConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
