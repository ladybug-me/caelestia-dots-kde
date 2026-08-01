#pragma once

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QQmlEngine>
#include <QtDBus/QDBusAbstractAdaptor>
#include <QtDBus/QDBusConnection>

namespace caelestia::services {

class KWinActiveWindowBridgeAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "dev.caelestia.KWinActiveWindow")
public:
    explicit KWinActiveWindowBridgeAdaptor(QObject *parent);
    
public slots:
    Q_NOREPLY void notifyActiveWindow(const QString &uuid, const QString &title, const QString &appClass, const QString &activeOutputName, bool isFullscreen, bool isMaximized);
    Q_NOREPLY void notifyWindowList(const QString &windowsJson);
    Q_NOREPLY void notifyCurrentDesktop(int desktop);
};

class KWinActiveWindowBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap activeWindow READ activeWindow NOTIFY activeWindowChanged)
    Q_PROPERTY(QString activeOutputName READ activeOutputName NOTIFY activeWindowChanged)
    Q_PROPERTY(QVariantList windowList READ windowList NOTIFY windowListChanged)
    Q_PROPERTY(int currentDesktop READ currentDesktop NOTIFY currentDesktopChanged)
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit KWinActiveWindowBridge(QObject *parent = nullptr);
    ~KWinActiveWindowBridge() override;

    QVariantMap activeWindow() const;
    QString activeOutputName() const;

    QVariantList windowList() const;
    int currentDesktop() const;

    Q_INVOKABLE void focusWindow(const QString &address);
    Q_INVOKABLE void closeWindow(const QString &address);
    Q_INVOKABLE void minimizeWindow(const QString &address);
    Q_INVOKABLE void maximizeWindow(const QString &address, bool horz = true, bool vert = true);
    Q_INVOKABLE void raiseWindow(const QString &address);
    Q_INVOKABLE void moveWindow(const QString &address, int x, int y);
    Q_INVOKABLE void resizeWindow(const QString &address, int width, int height);
    Q_INVOKABLE void setWindowProperty(const QString &address, const QString &property, bool enable);
    Q_INVOKABLE void setWindowDesktop(const QString &address, int desktopId);
    Q_INVOKABLE void setFullscreen(const QString& address, bool fullscreen);
    Q_INVOKABLE void setMaximized(const QString& address, bool maximized);
    Q_INVOKABLE void setDesktop(int desktopId);
    Q_INVOKABLE void refreshWindows();
    Q_INVOKABLE void nextDesktop();
    Q_INVOKABLE void previousDesktop();
    Q_INVOKABLE void runArbitraryScript(const QString &script);
    Q_INVOKABLE void setActiveOutputName(const QString &outputName);

    void updateActiveWindow(const QString &uuid, const QString &title, const QString &appClass, const QString &activeOutputName, bool isFullscreen, bool isMaximized);
    void updateWindowList(const QString &windowsJson);
    void updateCurrentDesktop(int desktop);

signals:
    void activeWindowChanged();
    void windowListChanged();
    void currentDesktopChanged();

private:
    void injectKWinScript();
    void executeKWinScriptAction(const QString &scriptBody);

    QVariantMap m_activeWindow;
    QVariantList m_windowList;
    QString m_activeOutputName;
    QString m_scriptName;
    int m_currentDesktop = 1;

    class QTimer* m_windowListDebounce;
    QString m_pendingWindowListJson;
};

} // namespace caelestia::services
