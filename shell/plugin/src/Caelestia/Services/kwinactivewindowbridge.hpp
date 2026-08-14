#pragma once

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QQmlEngine>
#include <QTimer>

namespace caelestia::services {

class PlasmaWindowHandle;

class KWinActiveWindowBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap activeWindow READ activeWindow NOTIFY activeWindowChanged)
    Q_PROPERTY(QString activeOutputName READ activeOutputName WRITE setActiveOutputName NOTIFY activeOutputNameChanged)
    Q_PROPERTY(QVariantList windowList READ windowList NOTIFY windowListChanged)
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit KWinActiveWindowBridge(QObject *parent = nullptr);
    ~KWinActiveWindowBridge() override;

    QVariantMap activeWindow() const;
    QString activeOutputName() const;
    void setActiveOutputName(const QString &outputName);

    QVariantList windowList() const;

    Q_INVOKABLE void focusWindow(const QString &address);
    Q_INVOKABLE void closeWindow(const QString &address);
    Q_INVOKABLE void minimizeWindow(const QString &address);
    Q_INVOKABLE void maximizeWindow(const QString &address, bool horz = true, bool vert = true);
    Q_INVOKABLE void raiseWindow(const QString &address);
    Q_INVOKABLE void setWindowProperty(const QString &address, const QString &property, bool enable);
    Q_INVOKABLE void setWindowDesktop(const QString &address, int desktopId);
    Q_INVOKABLE void setFullscreen(const QString& address, bool fullscreen);
    Q_INVOKABLE void setMaximized(const QString& address, bool maximized);



    // Kept for backward compatibility, though no longer backed by JS
    Q_INVOKABLE void refreshWindows();

signals:
    void activeWindowChanged();
    void activeOutputNameChanged();
    void windowListChanged();

private slots:
    void onWindowAdded(const QString& uuid);
    void onWindowLost(const QString& uuid);
    void scheduleWindowListUpdate();
    void buildWindowList();

private:
    QVariantMap windowToVariant(PlasmaWindowHandle* w) const;
    QString getOutputNameForGeometry(int x, int y, int w, int h) const;

    QVariantMap m_activeWindow;
    QVariantList m_windowList;
    QString m_activeOutputName;

    QTimer m_updateTimer;
};

} // namespace caelestia::services
