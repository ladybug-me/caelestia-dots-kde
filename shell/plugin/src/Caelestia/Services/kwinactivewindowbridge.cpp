#include "kwinactivewindowbridge.hpp"
#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QTemporaryFile>
#include <QTimer>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusReply>

namespace caelestia::services {

namespace {

// Window addresses are interpolated into double-quoted JS string literals in
// the generated KWin scripts. They come from KWin's own internalId today, but
// nothing enforces that, so escape them rather than trusting the source.
QString escapeJsString(const QString& value) {
    QString escaped = value;
    escaped.replace('\\', QStringLiteral("\\\\"));
    escaped.replace('"', QStringLiteral("\\\""));
    escaped.replace('\n', QStringLiteral("\\n"));
    escaped.replace('\r', QStringLiteral("\\r"));
    return escaped;
}

} // namespace

KWinActiveWindowBridgeAdaptor::KWinActiveWindowBridgeAdaptor(QObject* parent)
    : QDBusAbstractAdaptor(parent) {}

void KWinActiveWindowBridgeAdaptor::notifyActiveWindow(const QString& uuid, const QString& title,
    const QString& appClass, const QString& activeOutputName, bool isFullscreen, bool isMaximized) {
    if (auto* bridge = qobject_cast<KWinActiveWindowBridge*>(parent())) {
        bridge->updateActiveWindow(uuid, title, appClass, activeOutputName, isFullscreen, isMaximized);
    }
}

void KWinActiveWindowBridgeAdaptor::notifyWindowList(const QString& windowsJson) {
    if (auto* bridge = qobject_cast<KWinActiveWindowBridge*>(parent())) {
        bridge->updateWindowList(windowsJson);
    }
}

void KWinActiveWindowBridgeAdaptor::notifyCurrentDesktop(int desktop) {
    if (auto* bridge = qobject_cast<KWinActiveWindowBridge*>(parent())) {
        bridge->updateCurrentDesktop(desktop);
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

function notifyActiveWindowReal() {
    let window = workspace.activeWindow;
    let cursorScreen = workspace.screenAt(workspace.cursorPos);
    let out = cursorScreen ? cursorScreen.name : "";
    if (window && (window.resourceClass === "quickshell" || window.resourceClass === "plasmashell")) {
        return; // Ignore shell panels taking focus
    }
    
    if (!window) {
        if (lastActiveUuid !== null) {
            lastActiveUuid = null;
            callDBus(BUS, PATH, IFACE, "notifyActiveWindow", "", "", "", out, false, false);
        }
        return;
    }

    let uuid = window.internalId ? String(window.internalId) : "";
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
    //console.info("Caelestia: notifyWindowList called");
    let arr = [];
    let wins = workspace.windowList();
    if (!wins) return;
    for (let i = 0; i < wins.length; ++i) {
        try {
            let w = wins[i];
            if (w.normalWindow) {
                if (w.resourceClass === "quickshell") continue;
                let deskId = -1;
                if (w.desktops && w.desktops.length > 0) {
                    let d = w.desktops[0];
                    if (d) {
                        let allD = workspace.desktops;
                        if (allD) {
                            for (let j = 0; j < allD.length; ++j) {
                                if (allD[j].id === d.id || allD[j] === d) {
                                    deskId = j + 1;
                                    break;
                                }
                            }
                        }
                    }
                }
                arr.push({
                    address: w.internalId ? String(w.internalId) : "",
                    pid: w.pid || 0,
                    title: w.caption || "",
                    class: w.resourceClass || "",
                    x: w.frameGeometry ? w.frameGeometry.x : (w.x || 0),
                    y: w.frameGeometry ? w.frameGeometry.y : (w.y || 0),
                    width: w.frameGeometry ? w.frameGeometry.width : (w.width || 0),
                    height: w.frameGeometry ? w.frameGeometry.height : (w.height || 0),
                    fullscreen: w.fullScreen ? true : false,
                    maximized: (w.maximizeMode === 3) ? true : false,
                    minimized: w.minimized ? true : false,
                    floating: !w.tile,
                    workspace: { id: deskId }
                });
            }
        } catch (e) {
            console.info("Caelestia: Error processing window: " + e);
        }
    }
    callDBus(BUS, PATH, IFACE, "notifyWindowList", JSON.stringify(arr));
}

workspace.windowActivated.connect(onActiveWindowChanged);

function onWindowAdded(window) {
    console.info("Caelestia: windowAdded fired");
    try {
        if (window && window.normalWindow) {
            try { window.minimizedChanged.connect(notifyWindowList); } catch(e){}
            try { window.desktopsChanged.connect(notifyWindowList); } catch(e){}
            try { window.frameGeometryChanged.connect(notifyWindowList); } catch(e){}
        }
    } catch (e) {
        console.info("Caelestia: Error in onWindowAdded: " + e);
    }
    notifyWindowList();
}

function onCurrentDesktopChanged() {
    let curr = workspace.currentDesktop;
    let idx = 1;
    let d = workspace.desktops;
    if (d) {
        for (let i = 0; i < d.length; ++i) {
            if (d[i].id === curr.id || d[i] === curr) {
                idx = i + 1;
                break;
            }
        }
    }
    callDBus(BUS, PATH, IFACE, "notifyCurrentDesktop", idx);
}

workspace.currentDesktopChanged.connect(onCurrentDesktopChanged);
workspace.windowAdded.connect(onWindowAdded);
workspace.windowRemoved.connect(function(w) {
    console.info("Caelestia: windowRemoved fired");
    notifyWindowList();
});
workspace.desktopsChanged.connect(notifyWindowList);

// Initial push
let initialWins = workspace.windowList();
for (let i = 0; i < initialWins.length; ++i) {
    try {
        if (initialWins[i].normalWindow) {
            try { initialWins[i].minimizedChanged.connect(notifyWindowList); } catch(e){}
            try { initialWins[i].desktopsChanged.connect(notifyWindowList); } catch(e){}
            try { initialWins[i].frameGeometryChanged.connect(notifyWindowList); } catch(e){}
        }
    } catch (e) {
        console.info("Caelestia: Error initializing window: " + e);
    }
}
onActiveWindowChanged();
notifyWindowList();
if (workspace.currentDesktop) {
    onCurrentDesktopChanged();
}
)js";

KWinActiveWindowBridge::KWinActiveWindowBridge(QObject* parent)
    : QObject(parent) {
    new KWinActiveWindowBridgeAdaptor(this);

    m_windowListDebounce = new QTimer(this);
    m_windowListDebounce->setInterval(150); // Throttle geometry updates to ~6 fps to save QML CPU
    m_windowListDebounce->setSingleShot(true);
    connect(m_windowListDebounce, &QTimer::timeout, this, [this]() {
        qDebug() << "Caelestia: windowListDebounce timer fired, pending JSON empty?" << m_pendingWindowListJson.isEmpty();
        if (!m_pendingWindowListJson.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(m_pendingWindowListJson.toUtf8());
            if (doc.isArray()) {
                m_windowList = doc.array().toVariantList();
                qDebug() << "Caelestia: emitting windowListChanged(), items count:" << m_windowList.size();
                emit windowListChanged();
            } else {
                qDebug() << "Caelestia: doc is not an array!";
            }

            QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
            QFile f(runtimeDir + "/qs_kwin_windows.json");
            if (f.open(QIODevice::WriteOnly)) {
                f.write(m_pendingWindowListJson.toUtf8());
                f.close();
            }
            m_pendingWindowListJson.clear();
        }
    });

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject("/dev/caelestia/KWinActiveWindow", this,
        QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals | QDBusConnection::ExportAllProperties |
            QDBusConnection::ExportAdaptors);
    bus.registerService("dev.caelestia.KWinActiveWindow");

    // Clean up orphan KWin scripts from previous crashed sessions before
    // injecting a fresh one, so duplicate D-Bus notifications don't pile up.
    QDBusMessage listMsg =
        QDBusMessage::createMethodCall("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadedScripts");
    QDBusReply<QStringList> listReply = bus.call(listMsg);
    if (listReply.isValid()) {
        for (const auto& name : listReply.value()) {
            if (name.startsWith("caelestia-active-window-")) {
                QDBusMessage unloadMsg = QDBusMessage::createMethodCall(
                    "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript");
                unloadMsg << name;
                bus.call(unloadMsg, QDBus::NoBlock);
            }
        }
    }

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

void KWinActiveWindowBridge::updateActiveWindow(const QString& uuid, const QString& title, const QString& appClass,
    const QString& activeOutputName, bool isFullscreen, bool isMaximized) {
    m_activeWindow = QVariantMap{ { "address", uuid }, { "title", title }, { "class", appClass },
        { "fullscreen", isFullscreen }, { "maximized", isMaximized } };
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

int KWinActiveWindowBridge::currentDesktop() const {
    return m_currentDesktop;
}

void KWinActiveWindowBridge::updateCurrentDesktop(int desktop) {
    if (m_currentDesktop != desktop) {
        m_currentDesktop = desktop;
        emit currentDesktopChanged();
    }
}

void KWinActiveWindowBridge::executeKWinScriptAction(const QString& scriptBody) {
    QString scriptName = "caelestia-kwin-action-" + QString::number(QCoreApplication::applicationPid()) + "-" +
                         QString::number(QDateTime::currentMSecsSinceEpoch());
    QString fileName = QDir::tempPath() + "/" + scriptName + ".js";
    QFile tempFile(fileName);
    if (!tempFile.open(QIODevice::WriteOnly)) {
        return;
    }
    tempFile.write(scriptBody.toUtf8());
    tempFile.close();

    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusMessage loadMsg =
        QDBusMessage::createMethodCall("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript");
    loadMsg << fileName << scriptName;
    QDBusReply<int> reply = bus.call(loadMsg);

    if (reply.isValid()) {
        int scriptId = reply.value();
        QDBusMessage runMsg = QDBusMessage::createMethodCall(
            "org.kde.KWin", QString("/Scripting/Script%1").arg(scriptId), "org.kde.kwin.Script", "run");
        bus.call(runMsg);

        QDBusMessage unloadMsg =
            QDBusMessage::createMethodCall("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript");
        unloadMsg << scriptName;
        bus.call(unloadMsg, QDBus::NoBlock);
    } else {
        qWarning() << "Failed to load script:" << reply.error().message();
    }

    QFile::remove(fileName);
}

void KWinActiveWindowBridge::runArbitraryScript(const QString& script) {
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::focusWindow(const QString& address) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                wins[i].minimized = false;
                workspace.activeWindow = wins[i];
                break;
            }
        }
    )")
                         .arg(escapeJsString(address));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::closeWindow(const QString& address) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                wins[i].closeWindow();
                break;
            }
        }
    )")
                         .arg(escapeJsString(address));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::minimizeWindow(const QString& address) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                wins[i].minimized = true;
                break;
            }
        }
    )")
                         .arg(escapeJsString(address));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::maximizeWindow(const QString& address, bool horz, bool vert) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                wins[i].setMaximize(%2, %3);
                break;
            }
        }
    )")
                         .arg(escapeJsString(address), vert ? QStringLiteral("true") : QStringLiteral("false"),
                             horz ? QStringLiteral("true") : QStringLiteral("false"));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::raiseWindow(const QString& address) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                workspace.raiseWindow(wins[i]);
                break;
            }
        }
    )")
                         .arg(escapeJsString(address));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::moveWindow(const QString& address, int x, int y) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                let q = Object.assign({}, wins[i].frameGeometry);
                q.x = %2;
                q.y = %3;
                wins[i].frameGeometry = q;
                break;
            }
        }
    )")
                         .arg(escapeJsString(address), QString::number(x), QString::number(y));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::resizeWindow(const QString& address, int width, int height) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                let q = Object.assign({}, wins[i].frameGeometry);
                q.width = %2;
                q.height = %3;
                wins[i].frameGeometry = q;
                break;
            }
        }
    )")
                         .arg(escapeJsString(address), QString::number(width), QString::number(height));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::setWindowProperty(const QString& address, const QString& property, bool enable) {
    QString kwinProp;
    if (property == "above")
        kwinProp = "keepAbove";
    else if (property == "below")
        kwinProp = "keepBelow";
    else if (property == "skip_taskbar")
        kwinProp = "skipTaskbar";
    else if (property == "skip_pager")
        kwinProp = "skipPager";
    else if (property == "fullscreen")
        kwinProp = "fullScreen";
    else if (property == "shaded")
        kwinProp = "shade";
    else if (property == "demands_attention")
        kwinProp = "demandsAttention";
    else if (property == "no_border")
        kwinProp = "noBorder";
    else if (property == "minimized")
        kwinProp = "minimized";
    else
        return;

    QString script =
        QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                wins[i].%2 = %3;
                break;
            }
        }
    )")
            .arg(escapeJsString(address), kwinProp, enable ? QStringLiteral("true") : QStringLiteral("false"));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::setWindowDesktop(const QString& address, int desktopId) {
    QString script = QString(R"(
        let wins = workspace.windowList();
        for (let i = 0; i < wins.length; ++i) {
            if (wins[i].internalId && String(wins[i].internalId) === "%1") {
                let id = %2;
                if (id == -1) {
                    wins[i].desktops = [workspace.currentDesktop];
                } else if (id == -2) {
                    wins[i].onAllDesktops = true;
                } else {
                    let dList = workspace.desktops;
                    let idx = id - 1;
                    if (dList && idx >= 0 && idx < dList.length) {
                        wins[i].desktops = [dList[idx]];
                    }
                }
                break;
            }
        }
    )")
                         .arg(escapeJsString(address), QString::number(desktopId));
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::setDesktop(int desktopId) {
    QString script = QString(R"(
        let d = workspace.desktops;
        let idx = %1 - 1;
        if (d && idx >= 0 && idx < d.length) {
            workspace.currentDesktop = d[idx];
        }
    )")
                         .arg(desktopId);
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::refreshWindows() {
    QString script = QString(R"(
        let wins = workspace.windowList();
        let arr = [];
        if (wins) {
            for (let i = 0; i < wins.length; ++i) {
                let w = wins[i];
                if (w.normalWindow && w.resourceClass !== "quickshell") {
                    let deskId = -1;
                    if (w.desktops && w.desktops.length > 0) {
                        let d = w.desktops[0];
                        if (d) {
                            let allD = workspace.desktops;
                            if (allD) {
                                for (let j = 0; j < allD.length; ++j) {
                                    if (allD[j].id === d.id || allD[j] === d) {
                                        deskId = j + 1;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    arr.push({
                        address: w.internalId ? String(w.internalId) : "",
                        pid: w.pid || 0,
                        title: w.caption || "",
                        class: w.resourceClass || "",
                        x: w.frameGeometry ? w.frameGeometry.x : w.x,
                        y: w.frameGeometry ? w.frameGeometry.y : w.y,
                        width: w.frameGeometry ? w.frameGeometry.width : w.width,
                        height: w.frameGeometry ? w.frameGeometry.height : w.height,
                        fullscreen: w.fullScreen ? true : false,
                        maximized: w.maximized ? true : false,
                        minimized: w.minimized ? true : false,
                        floating: !w.tile,
                        workspace: { id: deskId }
                    });
                }
            }
        }
        callDBus("dev.caelestia.KWinActiveWindow", "/dev/caelestia/KWinActiveWindow", "dev.caelestia.KWinActiveWindow", "notifyWindowList", JSON.stringify(arr));
    )");
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::nextDesktop() {
    QString script = QString(R"(
        let curr = workspace.currentDesktop;
        let d = workspace.desktops;
        for (let i = 0; i < d.length; ++i) {
            if (d[i] === curr) {
                let nextIdx = (i + 1) % d.length;
                workspace.currentDesktop = d[nextIdx];
                break;
            }
        }
    )");
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::previousDesktop() {
    QString script = QString(R"(
        let curr = workspace.currentDesktop;
        let d = workspace.desktops;
        for (let i = 0; i < d.length; ++i) {
            if (d[i] === curr) {
                let prevIdx = (i - 1 + d.length) % d.length;
                workspace.currentDesktop = d[prevIdx];
                break;
            }
        }
    )");
    executeKWinScriptAction(script);
}

void KWinActiveWindowBridge::updateWindowList(const QString& windowsJson) {
    qDebug() << "Caelestia: updateWindowList called, length:" << windowsJson.length();
    m_pendingWindowListJson = windowsJson;
    if (!m_windowListDebounce->isActive()) {
        m_windowListDebounce->start();
        qDebug() << "Caelestia: started windowListDebounce timer";
    }
}

void KWinActiveWindowBridge::injectKWinScript() {
    m_scriptName = "caelestia-active-window-" + QString::number(QCoreApplication::applicationPid()) + "-" +
                   QString::number(QDateTime::currentMSecsSinceEpoch());

    QTemporaryFile f(QDir::tempPath() + "/caelestia-kwin-bridge-XXXXXX.js");
    f.setAutoRemove(false);
    if (!f.open()) {
        qWarning() << "Failed to create temporary file for KWin bridge script";
        return;
    }
    f.write(kScriptSource.toUtf8());
    f.close();
    const QString scriptPath = f.fileName();

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

    // KWin has loaded the script into its own JS engine; the temp file on disk
    // is no longer needed.
    QFile::remove(scriptPath);
}

} // namespace caelestia::services
