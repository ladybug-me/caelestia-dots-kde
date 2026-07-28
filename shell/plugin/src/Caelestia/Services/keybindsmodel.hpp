// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariant.h>

namespace caelestia::services {

class KeybindsModel : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList keybinds READ keybinds NOTIFY keybindsChanged)
    Q_PROPERTY(bool initialized READ initialized NOTIFY initializedChanged)

public:
    explicit KeybindsModel(QObject* parent = nullptr);

    [[nodiscard]] QVariantList keybinds() const;
    [[nodiscard]] bool initialized() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE QVariantList query(const QString& searchText) const;

    // Called by CustomShortcut whenever its name/key/description changes, so
    // the cheatsheet lists whatever is actually bound rather than only what a
    // regex can find in the source file.
    Q_INVOKABLE void registerKeybind(
        QObject* shortcut, const QString& name, const QString& key, const QString& description);
    Q_INVOKABLE void unregisterKeybind(QObject* shortcut);

signals:
    void keybindsChanged();
    void initializedChanged();
    void loaded();

private:
    struct Keybind {
        QString name;
        QString key;
        QString description;
    };

    void scheduleRebuild();
    void rebuild();

    QVariantList m_keybinds;
    bool m_initialized = false;

    // m_order keeps the QML declaration order, m_registered holds the values.
    QList<QObject*> m_order;
    QHash<QObject*, Keybind> m_registered;
    bool m_rebuildQueued = false;
};

} // namespace caelestia::services
