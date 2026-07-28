// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>

namespace caelestia::services {

/**
 * Extracts an application icon from a window's own _NET_WM_ICON property.
 *
 * Games launched through a launcher (Minecraft via Prism, many Steam titles)
 * have no resolvable desktop entry and no themed icon under the class KWin
 * reports, so the dock has nothing to draw. Their icon only exists as a pixmap
 * on the window itself.
 *
 * Reads the property directly with XGetWindowProperty and caches the largest
 * image it finds as a PNG, rather than shelling out to a helper per window
 * class. Only XWayland clients can be served: _NET_WM_ICON is an X property, so
 * a native Wayland app with no desktop entry is not covered.
 */
class WindowIcon : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit WindowIcon(QObject* parent = nullptr);

    /**
     * Extract the icon for the window matching @p wmClass (and optionally
     * @p title), caching it under ~/.cache/caelestia/winicons.
     *
     * Returns the cached path immediately when it already exists, so a repeat
     * call costs nothing. Returns an empty string when no window matches or the
     * window carries no icon; extracted() is emitted on success either way.
     */
    Q_INVOKABLE QString extract(const QString& wmClass, const QString& title = QString());

signals:
    void extracted(const QString& wmClass, const QString& path);
};

} // namespace caelestia::services
