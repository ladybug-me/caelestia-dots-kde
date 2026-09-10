#include <QtQml/qqmlregistration.h>
#pragma once

#include <QObject>
#include <QAction>
#include <QString>
#include <QList>
#include <QKeySequence>
#include <QHash>
#include <memory>
#include <QAtomicInt>

class GlobalShortcut;

class GlobalShortcutDispatcher : public QObject {
    Q_OBJECT
public:
    static GlobalShortcutDispatcher* instance();

    // Returns the friendly label (e.g. "Spectacle - Launch Spectacle") for a
    // stolen key sequence, or an empty string if the key is not in the index.
    Q_INVOKABLE QString collisionForKey(const QString& portableKeyString) const;

    // Rebuilds the dispatcher's collision index from all current in-memory
    // stolen shortcuts. Called by GlobalShortcut::persistStolenShortcuts().
    void rebuildCollisionIndex();

    QHash<QString, QString> m_collisionIndex; // portable key → friendly label

signals:
    void shortcutRegistered(GlobalShortcut* sc);
    void shortcutUnregistered(GlobalShortcut* sc);
    void collisionIndexChanged();
};


class GlobalShortcut : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged)
    Q_PROPERTY(QString description READ description WRITE setDescription NOTIFY descriptionChanged)

public:
    explicit GlobalShortcut(QObject *parent = nullptr);
    ~GlobalShortcut() override;

    QString name() const;
    void setName(const QString &name);

    QString key() const;
    void setKey(const QString &key);

    QString description() const;
    void setDescription(const QString &description);
    
    QString getCollisionName() const;
    QString getCollisionNameForKey(const QString& keyPart) const;
    int stolenCount() const { return m_stolenShortcuts.size(); }

    // Human-readable label for this shortcut, used when naming it as one of the
    // parties in a collision between two Caelestia shortcuts.
    QString displayLabel() const;

signals:
    void nameChanged();
    void keyChanged();
    void descriptionChanged();
    void activated();

public:
    static GlobalShortcut* findByName(const QString& name);
    static QList<GlobalShortcut*> allShortcuts();
    // Rebuilds the dispatcher's collision index by scanning all instances.
    // Declared here so it can access the private m_stolenShortcuts member.
    static void rebuildCollisionIndex();

private:
    void updateShortcut();
    void persistStolenShortcuts() const;

    QString m_name;
    QString m_key;
    QString m_description;
    QAction *m_action;
    
    int m_registerGeneration = 0;

    static QHash<QString, GlobalShortcut*> s_registry;

    struct StolenShortcut {
        QString component;
        QString action;
        QList<QKeySequence> keys;          // KDE app's original keys (for restoration)
        QString componentFriendlyName;
        QString actionFriendlyName;
        QKeySequence triggerKey;           // which of our seqs caused this steal
    };
    QList<StolenShortcut> m_stolenShortcuts;
    QList<QKeySequence> m_activeKeys;      // key sequences currently bound by this shortcut
};
