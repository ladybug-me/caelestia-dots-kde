#include "kwinactivewindowbridge.hpp"
#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryFile>
#include <QProcess>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusReply>

namespace caelestia::services {

KWinActiveWindowBridgeAdaptor::KWinActiveWindowBridgeAdaptor(QObject* parent)
    : QDBusAbstractAdaptor(parent) {}

void KWinActiveWindowBridgeAdaptor::notifyActiveWindow(
    const QString& uuid, const QString& title, const QString& appClass, const QString& activeOutputName, bool isFullscreen, bool isMaximized) {
    if (auto* bridge = qobject_cast<KWinActiveWindowBridge*>(parent())) {
        bridge->updateActiveWindow(uuid, title, appClass, activeOutputName, isFullscreen, isMaximized);
    }
}

void KWinActiveWindowBridgeAdaptor::notifyWindowList(const QString& windowsJson) {
    if (auto* bridge = qobject_cast<KWinActiveWindowBridge*>(parent())) {
        bridge->updateWindowList(windowsJson);
    }
}

static const QString kScriptSource = R"js(
const BUS = "dev.caelestia.KWinActiveWindow";
const PATH = "/dev/caelestia/KWinActiveWindow";
const IFACE = "dev.caelestia.KWinActiveWindow";

let currentActiveWindow = null;
let lastActiveUuid = null;
let lastFullscreen = null;
let lastMaximized = null;
let lastOut = null;
let lastTitle = null;

function normalizeWindowId(windowId) {
    if (!windowId)
        return "";

    let raw = "";
    try { raw = windowId.toString(); } catch (e) {}
    if (!raw)
        raw = String(windowId);
    if (!raw)
        return "";

    const uuidMatch = raw.match(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/);
    if (uuidMatch && uuidMatch[0])
        return uuidMatch[0].toLowerCase();

    let compact = raw.trim();
    compact = compact.replace(/[{}]/g, "");
    compact = compact.replace(/^urn:uuid:/i, "");

    if (/^[0-9a-fA-F]{32}$/.test(compact)) {
        compact = compact.slice(0, 8) + "-" + compact.slice(8, 12) + "-" + compact.slice(12, 16) + "-" +
                  compact.slice(16, 20) + "-" + compact.slice(20);
    }

    if (/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(compact))
        return compact.toLowerCase();

    return compact;
}

function notifyActiveWindowReal() {
    let window = workspace.activeWindow;
    let cursorScreen = workspace.screenAt(workspace.cursorPos);
    let out = cursorScreen ? cursorScreen.name : "";
    if (!window) {
        if (lastActiveUuid !== null) {
            lastActiveUuid = null;
            callDBus(BUS, PATH, IFACE, "notifyActiveWindow", "", "", "", out, false, false);
        }
        return;
    }

    let uuid = normalizeWindowId(window.internalId);
    let title = window.caption || "";
    let appClass = window.resourceClass || "";
    let isFullscreen = window.fullScreen ? true : false;
    let isMaximized = (window.maximizeMode === 3) ? true : false;

    if (lastActiveUuid === uuid && lastFullscreen === isFullscreen && lastMaximized === isMaximized && lastOut === out && lastTitle === title) {
        return;
    }

    lastActiveUuid = uuid;
    lastFullscreen = isFullscreen;
    lastMaximized = isMaximized;
    lastOut = out;
    lastTitle = title;

    callDBus(BUS, PATH, IFACE, "notifyActiveWindow", uuid, title, appClass, out, isFullscreen, isMaximized);
}

function onActiveWindowChanged() {
    let window = workspace.activeWindow;
    if (currentActiveWindow !== window) {
        if (currentActiveWindow) {
            try { currentActiveWindow.frameGeometryChanged.disconnect(notifyActiveWindowReal); } catch(e){}
            try { currentActiveWindow.fullScreenChanged.disconnect(notifyActiveWindowReal); } catch(e){}
            try { currentActiveWindow.maximizedChanged.disconnect(notifyActiveWindowReal); } catch(e){}
        }
        currentActiveWindow = window;
        if (currentActiveWindow) {
            try { currentActiveWindow.frameGeometryChanged.connect(notifyActiveWindowReal); } catch(e){}
            try { currentActiveWindow.fullScreenChanged.connect(notifyActiveWindowReal); } catch(e){}
            try { currentActiveWindow.maximizedChanged.connect(notifyActiveWindowReal); } catch(e){}
        }
    }
    notifyActiveWindowReal();
}

function notifyWindowList() {
    let wins = workspace.windowList();
    let arr = [];
    for (let i = 0; i < wins.length; ++i) {
        let w = wins[i];
        if (w.normalWindow) {
            let deskId = "";
            if (w.resourceClass === "quickshell") continue;
            if (w.desktops && w.desktops.length > 0) {
                let d = w.desktops[0];
                deskId = String(d.id || d.name || d);
            }
            arr.push({
                address: normalizeWindowId(w.internalId),
                pid: w.pid || 0,
                title: w.caption || "",
                class: w.resourceClass || "",
                screen: w.output ? w.output.name : "",
                x: w.frameGeometry ? w.frameGeometry.x : w.x,
                y: w.frameGeometry ? w.frameGeometry.y : w.y,
                width: w.frameGeometry ? w.frameGeometry.width : w.width,
                height: w.frameGeometry ? w.frameGeometry.height : w.height,
                fullscreen: w.fullScreen ? true : false,
                floating: !w.tile,
                workspace: { id: deskId }
            });
        }
    }
    callDBus(BUS, PATH, IFACE, "notifyWindowList", JSON.stringify(arr));
}

workspace.windowActivated.connect(onActiveWindowChanged);
workspace.windowAdded.connect(notifyWindowList);
workspace.windowRemoved.connect(notifyWindowList);

// Initial push
onActiveWindowChanged();
notifyWindowList();
)js";

KWinActiveWindowBridge::KWinActiveWindowBridge(QObject* parent)
    : QObject(parent) {
    new KWinActiveWindowBridgeAdaptor(this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject("/dev/caelestia/KWinActiveWindow", this,
        QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals | QDBusConnection::ExportAllProperties |
            QDBusConnection::ExportAdaptors);
    bus.registerService("dev.caelestia.KWinActiveWindow");

    injectKWinScript();
}

KWinActiveWindowBridge::~KWinActiveWindowBridge() {
    if (!m_scriptName.isEmpty()) {
        QDBusMessage msg =
            QDBusMessage::createMethodCall("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript");
        msg << m_scriptName;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    }
}

QVariantMap KWinActiveWindowBridge::activeWindow() const {
    return m_activeWindow;
}

QString KWinActiveWindowBridge::activeOutputName() const {
    return m_activeOutputName;
}

void KWinActiveWindowBridge::setActiveOutputName(const QString& outputName) {
    if (m_activeOutputName != outputName) {
        m_activeOutputName = outputName;
        emit activeWindowChanged();

        QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
        QFile f(runtimeDir + "/qs_kwin_active_output.txt");
        if (f.open(QIODevice::WriteOnly)) {
            f.write(outputName.toUtf8());
            f.close();
        }
    }
}

void KWinActiveWindowBridge::updateActiveWindow(
    const QString& uuid, const QString& title, const QString& appClass, const QString& activeOutputName, bool isFullscreen, bool isMaximized) {
    m_activeWindow = QVariantMap{ { "address", uuid }, { "title", title }, { "class", appClass }, { "fullscreen", isFullscreen }, { "maximized", isMaximized } };
    if (m_activeOutputName != activeOutputName) {
        m_activeOutputName = activeOutputName;
        QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
        QFile f(runtimeDir + "/qs_kwin_active_output.txt");
        if (f.open(QIODevice::WriteOnly)) {
            f.write(activeOutputName.toUtf8());
            f.close();
        }
    }
    emit activeWindowChanged();
}

QVariantList KWinActiveWindowBridge::windowList() const {
    return m_windowList;
}

void KWinActiveWindowBridge::focusWindow(const QString& address) {
    QString scriptName = "caelestia-kwin-focus-" + QString::number(QCoreApplication::applicationPid()) + "-" +
                         QString::number(QDateTime::currentMSecsSinceEpoch());
    QString fileName = QDir::tempPath() + "/" + scriptName + ".js";
    QFile tempFile(fileName);
    if (!tempFile.open(QIODevice::WriteOnly)) {
        return;
    }

    QString scriptSource = QString(R"(
        function normalizeWindowId(windowId) {
            if (!windowId)
                return "";

            let raw = "";
            try { raw = windowId.toString(); } catch (e) {}
            if (!raw)
                raw = String(windowId);
            if (!raw)
                return "";

            const uuidMatch = raw.match(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/);
            if (uuidMatch && uuidMatch[0])
                return uuidMatch[0].toLowerCase();

            let compact = raw.trim();
            compact = compact.replace(/[{}]/g, "");
            compact = compact.replace(/^urn:uuid:/i, "");

            if (/^[0-9a-fA-F]{32}$/.test(compact)) {
                compact = compact.slice(0, 8) + "-" + compact.slice(8, 12) + "-" + compact.slice(12, 16) + "-" +
                          compact.slice(16, 20) + "-" + compact.slice(20);
            }

            if (/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(compact))
                return compact.toLowerCase();

            return compact;
        }

        const target = normalizeWindowId("%1");
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (normalizeWindowId(wins[i].internalId) === target) {
                workspace.activeWindow = wins[i];
                break;
            }
        }
    )")
                               .arg(address);

    tempFile.write(scriptSource.toUtf8());
    tempFile.close();

    QProcess::startDetached("bash", { "-c", QString(
        "qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript %1 %2 > /dev/null && "
        "script_id=$(qdbus6 org.kde.KWin | grep '/Scripting/Script' | tail -n 1) && "
        "if [ ! -z \"$script_id\" ]; then qdbus6 org.kde.KWin $script_id org.kde.kwin.Script.run; fi; "
        "qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript %2; "
        "rm -f %1").arg(fileName).arg(scriptName)
    });
}

void KWinActiveWindowBridge::closeWindow(const QString& address) {
    qWarning() << "CLOSE WINDOW CALLED WITH ADDRESS" << address;
    QString scriptName = "caelestia-kwin-close-" + QString::number(QCoreApplication::applicationPid()) + "-" +
                         QString::number(QDateTime::currentMSecsSinceEpoch());
    QString fileName = QDir::tempPath() + "/" + scriptName + ".js";
    QFile tempFile(fileName);
    if (!tempFile.open(QIODevice::WriteOnly)) {
        return;
    }

    QString scriptSource = QString(R"(
        function normalizeWindowId(windowId) {
            if (!windowId)
                return "";

            let raw = "";
            try { raw = windowId.toString(); } catch (e) {}
            if (!raw)
                raw = String(windowId);
            if (!raw)
                return "";

            const uuidMatch = raw.match(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/);
            if (uuidMatch && uuidMatch[0])
                return uuidMatch[0].toLowerCase();

            let compact = raw.trim();
            compact = compact.replace(/[{}]/g, "");
            compact = compact.replace(/^urn:uuid:/i, "");

            if (/^[0-9a-fA-F]{32}$/.test(compact)) {
                compact = compact.slice(0, 8) + "-" + compact.slice(8, 12) + "-" + compact.slice(12, 16) + "-" +
                          compact.slice(16, 20) + "-" + compact.slice(20);
            }

            if (/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(compact))
                return compact.toLowerCase();

            return compact;
        }

        const target = normalizeWindowId("%1");
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (normalizeWindowId(wins[i].internalId) === target) {
                wins[i].closeWindow();
                break;
            }
        }
    )")
                               .arg(address);

    tempFile.write(scriptSource.toUtf8());
    tempFile.close();

    QProcess::startDetached("bash", { "-c", QString(
        "qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript %1 %2 > /dev/null && "
        "script_id=$(qdbus6 org.kde.KWin | grep '/Scripting/Script' | tail -n 1) && "
        "if [ ! -z \"$script_id\" ]; then qdbus6 org.kde.KWin $script_id org.kde.kwin.Script.run; fi; "
        "qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript %2; "
        "rm -f %1").arg(fileName).arg(scriptName)
    });
}

void KWinActiveWindowBridge::updateWindowList(const QString& windowsJson) {
    QJsonDocument doc = QJsonDocument::fromJson(windowsJson.toUtf8());
    if (doc.isArray()) {
        m_windowList = doc.array().toVariantList();
        emit windowListChanged();
    }

    // Optionally update a file for backwards compatibility with hyprlandstate.cpp
    QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
    QFile f(runtimeDir + "/qs_kwin_windows.json");
    if (f.open(QIODevice::WriteOnly)) {
        f.write(windowsJson.toUtf8());
        f.close();
    }
}

void KWinActiveWindowBridge::injectKWinScript() {
    m_scriptName = "caelestia-active-window-" + QString::number(QCoreApplication::applicationPid()) + "-" +
                   QString::number(QDateTime::currentMSecsSinceEpoch());

    QString scriptPath = QDir::tempPath() + "/caelestia-kwin-bridge.js";
    QFile f(scriptPath);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(kScriptSource.toUtf8());
        f.close();
    }

    QDBusConnection bus = QDBusConnection::sessionBus();

    QDBusMessage loadMsg =
        QDBusMessage::createMethodCall("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript");
    loadMsg << scriptPath << m_scriptName;

    QDBusReply<int> reply = bus.call(loadMsg);
    if (reply.isValid()) {
        int scriptId = reply.value();
        QDBusMessage runMsg = QDBusMessage::createMethodCall(
            "org.kde.KWin", QString("/Scripting/Script%1").arg(scriptId), "org.kde.kwin.Script", "run");
        bus.call(runMsg);
    } else {
        qWarning() << "Failed to inject KWin active window script:" << reply.error().message();
    }
}

} // namespace caelestia::services
