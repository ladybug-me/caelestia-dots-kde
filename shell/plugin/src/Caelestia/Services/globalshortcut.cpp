#include "globalshortcut.hpp"

#include "../Config/rootnodes.hpp"
#include "../Config/generalconfig.hpp"
#include <KGlobalAccel>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QKeySequence>
#include <QProcess>
#include <QStringList>
#include <QTextStream>
#include <cstdlib>

Q_GLOBAL_STATIC(GlobalShortcutDispatcher, s_dispatcher)

namespace {

QString escapeGVariantString(const QString& value) {
    QString escaped = value;
    escaped.replace('\\', QStringLiteral("\\\\"));
    escaped.replace('\'', QStringLiteral("\\'"));
    return escaped;
}

QString stolenShortcutsPath() {
    return QDir::homePath() + "/.config/caelestia/stolen-shortcuts.json";
}

// Build gdbus args to restore a single stolen shortcut
QStringList buildRestoreArgs(const QString& component, const QString& action, const QList<QKeySequence>& keys) {
    QStringList seqStrings;
    for (const QKeySequence& seq : keys) {
        int k1 = seq.count() > 0 ? seq[0].toCombined() : 0;
        int k2 = seq.count() > 1 ? seq[1].toCombined() : 0;
        int k3 = seq.count() > 2 ? seq[2].toCombined() : 0;
        int k4 = seq.count() > 3 ? seq[3].toCombined() : 0;
        seqStrings.append(QString("([%1, %2, %3, %4],)").arg(k1).arg(k2).arg(k3).arg(k4));
    }
    QString arrayStr = seqStrings.isEmpty() ? QStringLiteral("[([0, 0, 0, 0],)]") : "[" + seqStrings.join(", ") + "]";
    return {
        QStringLiteral("call"),
        QStringLiteral("--session"),
        QStringLiteral("--dest"), QStringLiteral("org.kde.kglobalaccel"),
        QStringLiteral("--object-path"), QStringLiteral("/kglobalaccel"),
        QStringLiteral("--method"), QStringLiteral("org.kde.KGlobalAccel.setShortcutKeys"),
        QString("['%1', '%2', '', '']").arg(escapeGVariantString(component), escapeGVariantString(action)),
        arrayStr,
        QStringLiteral("4")
    };
}

bool isLockscreen() {
    static bool checked = false;
    static bool result = false;
    if (!checked) {
        checked = true;

        QFile cmdline(QStringLiteral("/proc/self/cmdline"));
        if (cmdline.open(QIODevice::ReadOnly)) {
            QByteArray data = cmdline.readAll();
            QList<QByteArray> args = data.split('\0');
            for (const QByteArray& arg : args) {
                if (arg.endsWith("lockscreen.qml")) {
                    result = true;
                    break;
                }
            }
        }

        if (result) {
            qDebug() << "[Caelestia] Running as lockscreen — global shortcut stealing disabled";
        }
    }
    return result;
}

} // namespace

GlobalShortcutDispatcher* GlobalShortcutDispatcher::instance() {
    GlobalShortcutDispatcher* inst = s_dispatcher();

    // On very first access, run crash recovery: if the stolen-shortcuts file
    // exists, a previous session crashed before cleaning up. Restore everything
    // and pre-populate the collision index so blinkers light up immediately.
    static bool recovered = false;
    if (!recovered) {
        recovered = true;
        if (!isLockscreen()) {
            QString path = stolenShortcutsPath();
            QFile file(path);
            if (file.open(QIODevice::ReadOnly)) {
                QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            file.close();
            if (doc.isArray()) {
                const QJsonArray entries = doc.array();
                for (const QJsonValue& val : entries) {
                    QJsonObject obj = val.toObject();
                    QString component = obj.value("component").toString();
                    QString action = obj.value("action").toString();
                    QString componentFriendly = obj.value("componentFriendlyName").toString();
                    QString actionFriendly = obj.value("actionFriendlyName").toString();
                    QList<QKeySequence> keys;
                    for (const QJsonValue& kv : obj.value("keys").toArray()) {
                        QKeySequence seq = QKeySequence::fromString(kv.toString());
                        if (!seq.isEmpty()) keys.append(seq);
                    }
                    if (!component.isEmpty() && !action.isEmpty()) {
                        qDebug() << "[Caelestia] Crash recovery: restoring shortcut" << action << "for" << component;
                        QProcess::startDetached(QStringLiteral("gdbus"), buildRestoreArgs(component, action, keys));

                        // Populate the collision index so the blinker shows collisions
                        // even though no GlobalShortcut instances have been created yet.
                        QString label = componentFriendly.isEmpty() ? component : componentFriendly;
                        QString actionLabel = actionFriendly.isEmpty() ? action : actionFriendly;
                        QString friendlyLabel = label + " - " + actionLabel;
                        for (const QKeySequence& seq : keys) {
                            inst->m_collisionIndex.insert(seq.toString(QKeySequence::PortableText), friendlyLabel);
                        }
                    }
                }
                if (!inst->m_collisionIndex.isEmpty()) {
                    emit inst->collisionIndexChanged();
                }
            }
            // Remove recovery file — crash recovery is done
            QFile::remove(path);
        }
        } // close if (!isLockscreen())

        // Register clean exit handler to delete the recovery file
        if (QCoreApplication::instance()) {
            QObject::connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, [] {
                if (!isLockscreen()) {
                    QFile::remove(stolenShortcutsPath());
                    qDebug() << "[Caelestia] Removed stolen-shortcuts recovery file on clean exit";
                }
            });
        }
    }

    return inst;
}

QString GlobalShortcutDispatcher::collisionForKey(const QString& portableKeyString) const {
    return m_collisionIndex.value(portableKeyString);
}

void GlobalShortcutDispatcher::rebuildCollisionIndex() {
    GlobalShortcut::rebuildCollisionIndex();
}

// Implemented on GlobalShortcut so it can access the private m_stolenShortcuts member.
void GlobalShortcut::rebuildCollisionIndex() {
    auto* dispatcher = GlobalShortcutDispatcher::instance();
    dispatcher->m_collisionIndex.clear();
    for (const GlobalShortcut* sc : s_registry) {
        for (const auto& stolen : sc->m_stolenShortcuts) {
            const QString label = stolen.componentFriendlyName.isEmpty() ? stolen.component : stolen.componentFriendlyName;
            const QString actionLabel = stolen.actionFriendlyName.isEmpty() ? stolen.action : stolen.actionFriendlyName;
            const QString friendlyLabel = label + " - " + actionLabel;
            for (const QKeySequence& seq : stolen.keys) {
                dispatcher->m_collisionIndex.insert(seq.toString(QKeySequence::PortableText), friendlyLabel);
            }
        }
    }

    // Two Caelestia shortcuts bound to the same key. KGlobalAccel resolves this
    // last-write-wins, so one of them silently stops working. The steal scan in
    // updateShortcut() skips our own component names by design, which means a
    // Caelestia-vs-Caelestia clash never reached the index and nothing in the
    // shortcut manager flagged it (#569).
    QHash<QString, QList<const GlobalShortcut*>> owners;
    for (const GlobalShortcut* sc : s_registry) {
        for (const QKeySequence& seq : sc->m_activeKeys) {
            owners[seq.toString(QKeySequence::PortableText)].append(sc);
        }
    }

    for (auto it = owners.constBegin(); it != owners.constEnd(); ++it) {
        if (it.value().size() < 2)
            continue;

        // A key already in the index was taken from a third-party shortcut, and
        // that row is flagged already. Leave the label naming the app whose
        // binding was overridden rather than replacing it.
        if (dispatcher->m_collisionIndex.contains(it.key()))
            continue;

        QStringList names;
        QList<const GlobalShortcut*> counted;
        for (const GlobalShortcut* sc : it.value()) {
            // De-duplicate by instance, not by label: two different actions can
            // carry the same description and both are parties to the collision.
            if (counted.contains(sc))
                continue;
            counted.append(sc);
            names.append(sc->displayLabel());
        }
        names.sort(); // QHash iteration order is unspecified; keep the label stable.

        dispatcher->m_collisionIndex.insert(it.key(),
            QStringLiteral("Caelestia - ") + names.join(QStringLiteral(", ")));
    }

    emit dispatcher->collisionIndexChanged();
}

QString GlobalShortcut::displayLabel() const {
    if (!m_description.isEmpty())
        return m_description;
    if (!m_name.isEmpty())
        return m_name;
    return QStringLiteral("unnamed shortcut");
}

QHash<QString, GlobalShortcut*> GlobalShortcut::s_registry;

GlobalShortcut::GlobalShortcut(QObject* parent)
    : QObject(parent)
    , m_action(new QAction(this)) {
    connect(m_action, &QAction::triggered, this, &GlobalShortcut::activated);
}

GlobalShortcut::~GlobalShortcut() {
    if (!m_name.isEmpty()) {
        s_registry.remove(m_name);
        emit GlobalShortcutDispatcher::instance() -> shortcutUnregistered(this);
    }

    // Restore any KDE shortcuts we stole on startup
    for (const auto& stolen : m_stolenShortcuts) {
        QProcess::startDetached(QStringLiteral("gdbus"), buildRestoreArgs(stolen.component, stolen.action, stolen.keys));
    }

    // Re-persist so the recovery file and collision index reflect the restored
    // shortcuts. Every mutation in updateShortcut() calls persistStolenShortcuts();
    // the destructor must do the same, or a hot-reload leaves stale entries on disk
    // and phantom collisions in the Nexus Shortcut Manager blinker.
    if (!m_stolenShortcuts.isEmpty())
        persistStolenShortcuts();
}

void GlobalShortcut::persistStolenShortcuts() const {
    // Collect stolen entries from ALL registered shortcuts so the recovery file
    // is always a complete, up-to-date picture of what we have taken from KDE.
    QJsonArray entries;
    for (const GlobalShortcut* sc : s_registry) {
        for (const auto& stolen : sc->m_stolenShortcuts) {
            QJsonArray keyArr;
            for (const QKeySequence& seq : stolen.keys) {
                keyArr.append(seq.toString(QKeySequence::PortableText));
            }
            QJsonObject obj;
            obj.insert(QStringLiteral("component"), stolen.component);
            obj.insert(QStringLiteral("action"), stolen.action);
            obj.insert(QStringLiteral("componentFriendlyName"), stolen.componentFriendlyName);
            obj.insert(QStringLiteral("actionFriendlyName"), stolen.actionFriendlyName);
            obj.insert(QStringLiteral("keys"), keyArr);
            entries.append(obj);
        }
    }

    const QString path = stolenShortcutsPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(QJsonDocument(entries).toJson());
    }

    // Keep the live collision index in sync with the file
    GlobalShortcutDispatcher::instance()->rebuildCollisionIndex();
}

QString GlobalShortcut::name() const {
    return m_name;
}

void GlobalShortcut::setName(const QString& name) {
    if (m_name == name)
        return;

    if (!m_name.isEmpty()) {
        s_registry.remove(m_name);
    }

    m_name = name;
    m_action->setObjectName("caelestia-shortcut-" + m_name);

    if (!m_name.isEmpty()) {
        s_registry.insert(m_name, this);
    }

    emit nameChanged();
    emit GlobalShortcutDispatcher::instance() -> shortcutRegistered(this);

    updateShortcut();
}

QString GlobalShortcut::key() const {
    return m_key;
}

void GlobalShortcut::setKey(const QString& key) {
    if (m_key == key)
        return;

    m_key = key;
    emit keyChanged();
    updateShortcut();
}

QString GlobalShortcut::getCollisionName() const {
    if (m_stolenShortcuts.isEmpty()) {
        return QString();
    }
    const auto& s = m_stolenShortcuts.first();
    QString actionName = s.actionFriendlyName;
    if (actionName.isEmpty())
        actionName = s.action;
    return s.componentFriendlyName + " - " + actionName;
}

QString GlobalShortcut::getCollisionNameForKey(const QString& keyPart) const {
    QKeySequence targetSeq(keyPart.trimmed());
    if (targetSeq.isEmpty()) return QString();

    for (const auto& s : m_stolenShortcuts) {
        if (s.keys.contains(targetSeq)) {
            QString actionName = s.actionFriendlyName;
            if (actionName.isEmpty())
                actionName = s.action;
            return s.componentFriendlyName + " - " + actionName;
        }
    }
    return QString();
}

QString GlobalShortcut::description() const {
    return m_description;
}

void GlobalShortcut::setDescription(const QString& description) {
    if (m_description == description)
        return;

    m_description = description;
    emit descriptionChanged();
    updateShortcut();
}

GlobalShortcut* GlobalShortcut::findByName(const QString& name) {
    return s_registry.value(name, nullptr);
}

QList<GlobalShortcut*> GlobalShortcut::allShortcuts() {
    return s_registry.values();
}

void GlobalShortcut::updateShortcut() {
    if (isLockscreen())
        return;

    if (m_name.isEmpty()) {
        return;
    }

    // Increment generation immediately so any pending async dbus bindings from a
    // previous call are aborted before they can race-bind a stale shortcut.
    const int myGeneration = ++m_registerGeneration;

    m_action->setText(m_description.isEmpty() ? "Caelestia Action" : m_description);

    // Parse the new desired key sequences
    QList<QKeySequence> newSeqs;
    if (!m_key.isEmpty()) {
        const QStringList parts = m_key.split(";");
        for (const QString& part : parts) {
            const QString trimmed = part.trimmed();
            if (!trimmed.isEmpty()) {
                newSeqs.append(QKeySequence(trimmed));
            }
        }
    }

    // Diff: which sequences were added vs removed compared to what we currently hold
    QList<QKeySequence> removedSeqs;
    for (const QKeySequence& old : m_activeKeys) {
        if (!newSeqs.contains(old)) {
            removedSeqs.append(old);
        }
    }
    QList<QKeySequence> addedSeqs;
    for (const QKeySequence& seq : newSeqs) {
        if (!m_activeKeys.contains(seq)) {
            addedSeqs.append(seq);
        }
    }

    // Immediately restore stolen shortcuts whose trigger key was removed.
    // This covers: key cleared, key changed, or one part of a multi-key removed.
    if (!removedSeqs.isEmpty()) {
        QList<StolenShortcut> toKeep;
        for (const auto& stolen : m_stolenShortcuts) {
            if (removedSeqs.contains(stolen.triggerKey)) {
                qDebug() << "[Caelestia] Restoring shortcut" << stolen.action
                         << "for" << stolen.component << "— trigger key removed";
                QProcess::startDetached(QStringLiteral("gdbus"),
                    buildRestoreArgs(stolen.component, stolen.action, stolen.keys));
            } else {
                toKeep.append(stolen);
            }
        }
        m_stolenShortcuts = toKeep;
    }

    m_activeKeys = newSeqs;

    if (newSeqs.isEmpty()) {
        // All keys cleared — no binding needed; stolen set is already cleaned above
        persistStolenShortcuts();
        KGlobalAccel::self()->removeAllShortcuts(m_action);
        return;
    }

    if (addedSeqs.isEmpty()) {
        // No new keys — only description changed or keys were removed.
        // Just rebind with the surviving sequences.
        persistStolenShortcuts();
        KGlobalAccel::self()->setShortcut(m_action, newSeqs, KGlobalAccel::NoAutoloading);
        return;
    }

    // Steal conflicts for newly-added key sequences only
    QList<QStringList> stealCmds;

    for (const QKeySequence& seq : addedSeqs) {
        const QList<KGlobalShortcutInfo> conflicts = KGlobalAccel::globalShortcutsByKey(seq);
        for (const auto& info : conflicts) {
            if (info.componentUniqueName() == "caelestia" ||
                info.componentUniqueName() == QCoreApplication::applicationName() ||
                info.componentUniqueName() == "quickshell") {
                continue;
            }

            // Deduplicate: don't steal the same component/action twice
            bool alreadyStolen = false;
            for (const auto& existing : m_stolenShortcuts) {
                if (existing.component == info.componentUniqueName() &&
                    existing.action == info.uniqueName()) {
                    alreadyStolen = true;
                    break;
                }
            }
            if (alreadyStolen) continue;

            m_stolenShortcuts.append({ info.componentUniqueName(), info.uniqueName(), info.keys(),
                info.componentFriendlyName(), info.friendlyName(), seq });


            stealCmds.append({
                QStringLiteral("call"),
                QStringLiteral("--session"),
                QStringLiteral("--dest"), QStringLiteral("org.kde.kglobalaccel"),
                QStringLiteral("--object-path"), QStringLiteral("/kglobalaccel"),
                QStringLiteral("--method"), QStringLiteral("org.kde.KGlobalAccel.setShortcutKeys"),
                QString("['%1', '%2', '', '']").arg(escapeGVariantString(info.componentUniqueName()),
                                                    escapeGVariantString(info.uniqueName())),
                QStringLiteral("[([0, 0, 0, 0],)]"),
                QStringLiteral("4")
            });
        }
    }

    // Persist after all steals for this round are computed
    persistStolenShortcuts();

    if (stealCmds.isEmpty()) {
        KGlobalAccel::self()->setShortcut(m_action, newSeqs, KGlobalAccel::NoAutoloading);
        return;
    }

    // Run all steal commands concurrently and bind only after the last one finishes
    auto pending = std::make_shared<QAtomicInt>(stealCmds.size());
    for (const QStringList& args : stealCmds) {
        auto* proc = new QProcess();
        connect(proc, &QProcess::finished, proc, [this, pending, newSeqs, myGeneration, proc](int, QProcess::ExitStatus) {
            proc->deleteLater();
            if (pending->fetchAndSubRelaxed(1) == 1) {
                if (m_registerGeneration == myGeneration) {
                    KGlobalAccel::self()->setShortcut(m_action, newSeqs, KGlobalAccel::NoAutoloading);
                }
            }
        });
        proc->start(QStringLiteral("gdbus"), args);
    }
}

