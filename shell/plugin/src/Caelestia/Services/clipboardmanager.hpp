// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <qobject.h>
#include <qprocess.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariant.h>

namespace caelestia::services {

/**
 * C++ replacement for the cliphist subprocess logic in Clipboard.qml.
 * - reload() runs `cliphist list` natively via QProcess and parses in C++
 * - decodeImage() runs `cliphist decode ID` and writes output to a file via QFile.
 *   Emits imageReady(id, path) once the file is fully written so QML can react
 *   immediately instead of relying on a blind timer.
 * - reload() proactively pre-warms all image entries so they are cached on disk
 *   before the user opens the launcher.
 */
class ClipboardManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(QString imageCacheDir READ imageCacheDir CONSTANT)

public:
    explicit ClipboardManager(QObject* parent = nullptr);

    [[nodiscard]] QVariantList items() const;
    [[nodiscard]] QString imageCacheDir() const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE void decodeImage(int id, const QString& outPath);

signals:
    void itemsChanged();
    /// Emitted after the image file for `id` has been fully written to `path`.
    void imageReady(int id, const QString& path);

private:
    QVariantList m_items;
    QProcess* m_listProc = nullptr;
    QString m_imageCacheDir;
};

} // namespace caelestia::services
