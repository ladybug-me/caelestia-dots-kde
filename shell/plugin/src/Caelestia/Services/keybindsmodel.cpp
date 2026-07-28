// SPDX-License-Identifier: GPL-3.0-only
#include "keybindsmodel.hpp"

#include <qloggingcategory.h>

Q_LOGGING_CATEGORY(lcKeybinds, "caelestia.services.keybindsmodel", QtInfoMsg)

namespace caelestia::services {

namespace {

// Formats a KDE key string the way the cheatsheet shows it. Returns an empty
// string for anything that isn't actually bound.
QString formatBind(const QString& key) {
    auto bind = key.trimmed();
    if (bind.isEmpty() || bind == "none") {
        return {};
    }

    // A shortcut may declare alternates as "Meta+Space; Meta"; show the first.
    bind = bind.split(';').first().trimmed();
    if (bind.isEmpty()) {
        return {};
    }

    // Match the naming used elsewhere in the shell.
    bind.replace("Meta", "Super");
    bind.replace("+", " + ");
    return bind;
}

} // namespace

KeybindsModel::KeybindsModel(QObject* parent)
    : QObject(parent) {}

QVariantList KeybindsModel::keybinds() const {
    return m_keybinds;
}

bool KeybindsModel::initialized() const {
    return m_initialized;
}

void KeybindsModel::registerKeybind(
    QObject* shortcut, const QString& name, const QString& key, const QString& description) {
    if (!shortcut) {
        qCWarning(lcKeybinds) << "registerKeybind called with a null shortcut";
        return;
    }

    if (!m_registered.contains(shortcut)) {
        m_order.append(shortcut);
        // Safety net: a shortcut destroyed without Component.onDestruction
        // running must not leave a stale entry behind.
        connect(shortcut, &QObject::destroyed, this, [this](QObject* obj) { unregisterKeybind(obj); });
    }

    m_registered.insert(shortcut, Keybind{ name, key, description });
    scheduleRebuild();
}

void KeybindsModel::unregisterKeybind(QObject* shortcut) {
    if (m_registered.remove(shortcut) > 0) {
        m_order.removeOne(shortcut);
        scheduleRebuild();
    }
}

void KeybindsModel::scheduleRebuild() {
    // Shortcuts register one by one as the QML tree is built, and their keys
    // can settle a moment later; coalesce that into a single rebuild.
    if (m_rebuildQueued) {
        return;
    }
    m_rebuildQueued = true;
    QMetaObject::invokeMethod(this, &KeybindsModel::rebuild, Qt::QueuedConnection);
}

void KeybindsModel::rebuild() {
    m_rebuildQueued = false;

    QVariantList result;
    result.reserve(m_order.size());

    for (const auto* shortcut : std::as_const(m_order)) {
        const auto it = m_registered.constFind(const_cast<QObject*>(shortcut));
        if (it == m_registered.constEnd() || it->name.isEmpty()) {
            continue;
        }

        const auto bind = formatBind(it->key);
        if (bind.isEmpty()) {
            continue; // Not bound on this session
        }

        result.append(QVariantMap{
            { "bind", bind },
            { "action", it->name },
            { "description", it->description.isEmpty() ? it->name : it->description },
        });
    }

    m_keybinds = result;
    emit keybindsChanged();

    if (!m_initialized) {
        m_initialized = true;
        emit initializedChanged();
    }
    emit loaded();
}

void KeybindsModel::load() {
    rebuild();
}

QVariantList KeybindsModel::query(const QString& searchText) const {
    if (searchText.isEmpty())
        return m_keybinds;

    const auto lower = searchText.toLower();
    QVariantList result;
    for (const auto& v : m_keybinds) {
        const auto map = v.toMap();
        if (map.value("bind").toString().toLower().contains(lower) ||
            map.value("description").toString().toLower().contains(lower)) {
            result.append(v);
        }
    }
    return result;
}

} // namespace caelestia::services
