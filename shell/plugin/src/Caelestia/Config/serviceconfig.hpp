#pragma once

#include "../Settings/objectnode.hpp"
#include "common.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class ServiceConfig : public settings::ObjectNode {
    CONFIG_NODE(ServiceConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, weatherLocation, QString())
    // Guess based on locale
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheit,
        QLocale().measurementSystem() == QLocale::ImperialUSSystem ||
            QLocale().measurementSystem() == QLocale::ImperialUKSystem)
    // This is always false by default cause apparently even imperial system users don't use it for perf temps?
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheitPerformance, false)
    // Attempt to guess based on locale
    CONFIG_GLOBAL_PROPERTY(
        bool, useTwelveHourClock, QLocale().timeFormat(QLocale::ShortFormat).toLower().contains(u"a"_s))
    CONFIG_GLOBAL_PROPERTY(QString, gpuType, QString())
    CONFIG_GLOBAL_PROPERTY(int, visualiserBars, 60)
    CONFIG_GLOBAL_PROPERTY(qreal, audioIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, brightnessIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, maxVolume, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, smartScheme, true)

    // Put launched applications in their own systemd unit via app2unit,
    // instead of leaving them as children of the shell. Off by default: it
    // changes how an application is supervised, which desktop launchers are
    // sensitive to. Their stdio is redirected either way - see
    // utils/Launch.qml.
    CONFIG_GLOBAL_PROPERTY(bool, useSystemd, false)
    // Optional Wallhaven API key (NSFW searches require one).
    CONFIG_GLOBAL_PROPERTY(QString, wallhavenApiKey, QString())

    // Automatic light/dark switching.
    CONFIG_GLOBAL_PROPERTY(bool, autoSchemeEnabled, false)
    // "solar" derives the times from weatherLocation; "fixed" uses the two below.
    CONFIG_GLOBAL_PROPERTY(QString, autoSchemeMode, u"solar"_s)
    // "HH:MM", local time. Also used as the fallback when solar times cannot be
    // computed (no location set, or polar day/night).
    CONFIG_GLOBAL_PROPERTY(QString, autoSchemeLightTime, u"07:00"_s)
    CONFIG_GLOBAL_PROPERTY(QString, autoSchemeDarkTime, u"19:00"_s)
    CONFIG_GLOBAL_PROPERTY(QString, defaultPlayer, u"Spotify"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, playerAliases,
        { vmap({ { u"from"_s, u"com.github.th_ch.youtube_music"_s }, { u"to"_s, u"YT Music"_s } }) })
    CONFIG_GLOBAL_PROPERTY(QString, lyricsBackend, u"Auto"_s)
    CONFIG_GLOBAL_PROPERTY(QStringList, bluetoothAutoReconnectDevices, QStringList())

    // Discord ARPC Settings
    CONFIG_GLOBAL_PROPERTY(bool, arpcEnabled, false)
    CONFIG_GLOBAL_PROPERTY(QString, arpcClientId, u"1126685412586733678"_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcAppName, u"Caelestia Shell"_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcDetails, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcState, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcLargeImage, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, arpcSmallImage, u""_s)
    CONFIG_GLOBAL_PROPERTY(bool, arpcSteamAutoDetect, false)
    CONFIG_GLOBAL_PROPERTY(QStringList, arpcSteamBlacklist, QStringList())
    CONFIG_GLOBAL_PROPERTY(QStringList, arpcTargetWindows, QStringList())
    CONFIG_GLOBAL_PROPERTY(QStringList, arpcTargetWindowLabels, QStringList())
    CONFIG_GLOBAL_PROPERTY(bool, arpcCaelestiaInfo, false)
    CONFIG_GLOBAL_PROPERTY(bool, arpcManualOverride, false)
    // Seconds of inactivity after which the presence is cleared. 0 disables it,
    // which keeps the existing always-on behaviour for anyone already using ARPC.
    CONFIG_GLOBAL_PROPERTY(int, arpcIdleTimeout, 0)

};

} // namespace caelestia::config
