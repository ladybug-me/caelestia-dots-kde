#include "cutils.hpp"

#include <QtConcurrent/qtconcurrentrun.h>
#include <qcryptographichash.h>
#include <QtQuick/qquickitemgrabresult.h>
#include <QtQuick/qquickwindow.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qfuturewatcher.h>
#include <qloggingcategory.h>
#include <qqmlengine.h>
#include <qregularexpression.h>
#include <QStandardPaths>
#include <KWindowEffects>
#include <KModifierKeyInfo>
#include <QCursor>

Q_LOGGING_CATEGORY(lcCUtils, "caelestia.cutils", QtInfoMsg)

namespace caelestia {

class CUtils::Private {
public:
    KModifierKeyInfo keyInfo;
};

CUtils::CUtils(QObject* parent)
    : QObject(parent)
    , d(new Private) {
    connect(&d->keyInfo, &KModifierKeyInfo::keyLocked, this, [this](Qt::Key key, bool locked) {
        Q_UNUSED(locked);
        if (key == Qt::Key_CapsLock) {
            emit capsLockChanged();
        } else if (key == Qt::Key_NumLock) {
            emit numLockChanged();
        }
    });
    connect(&d->keyInfo, &KModifierKeyInfo::keyPressed, this, [this](Qt::Key key, bool pressed) {
        if (key == Qt::Key_Alt || key == Qt::Key_AltGr) {
            emit altPressedChanged(pressed);
        } else if (key == Qt::Key_Meta || key == Qt::Key_Super_L || key == Qt::Key_Super_R) {
            emit metaPressedChanged(pressed);
        } else if (key == Qt::Key_Control) {
            emit ctrlPressedChanged(pressed);
        } else if (key == Qt::Key_Shift) {
            emit shiftPressedChanged(pressed);
        }
        emit keyPressed(static_cast<int>(key), pressed);
        if (!pressed) {
            emit modifierReleased();
        }
    });
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path) {
    this->saveItem(target, path, QRect(), QJSValue(), QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect) {
    this->saveItem(target, path, rect, QJSValue(), QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, QJSValue onSaved) {
    this->saveItem(target, path, QRect(), onSaved, QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, QJSValue onSaved, QJSValue onFailed) {
    this->saveItem(target, path, QRect(), onSaved, onFailed);
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect, QJSValue onSaved) {
    this->saveItem(target, path, rect, onSaved, QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect, QJSValue onSaved, QJSValue onFailed) {
    if (!target) {
        qCWarning(lcCUtils) << "saveItem: a target is required";
        return;
    }

    if (!path.isLocalFile()) {
        qCWarning(lcCUtils) << "saveItem:" << path << "is not a local file";
        return;
    }

    if (!target->window()) {
        qCWarning(lcCUtils) << "saveItem: unable to save target" << target << "without a window";
        return;
    }

    auto scaledRect = rect;
    const qreal scale = target->window()->devicePixelRatio();
    if (rect.isValid() && !qFuzzyCompare(scale + 1.0, 2.0)) {
        scaledRect =
            QRectF(rect.left() * scale, rect.top() * scale, rect.width() * scale, rect.height() * scale).toRect();
    }

    const QSharedPointer<const QQuickItemGrabResult> grabResult = target->grabToImage();

    QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this,
        [grabResult, scaledRect, path, onSaved, onFailed, this]() {
            const auto future = QtConcurrent::run([=]() {
                QImage image = grabResult->image();

                if (scaledRect.isValid()) {
                    image = image.copy(scaledRect);
                }

                const QString file = path.toLocalFile();
                const QString parent = QFileInfo(file).absolutePath();
                return QDir().mkpath(parent) && image.save(file);
            });

            auto* watcher = new QFutureWatcher<bool>(this);
            auto* engine = qmlEngine(this);

            QObject::connect(watcher, &QFutureWatcher<bool>::finished, this, [=]() {
                if (watcher->result()) {
                    if (onSaved.isCallable()) {
                        QJSValueList args = { QJSValue(path.toLocalFile()) };
                        if (engine) {
                            args << engine->toScriptValue(QVariant::fromValue(path));
                        }
                        onSaved.call(args);
                    }
                } else {
                    qCWarning(lcCUtils) << "saveItem: failed to save" << path;
                    if (onFailed.isCallable()) {
                        if (engine) {
                            onFailed.call({ engine->toScriptValue(QVariant::fromValue(path)) });
                        } else {
                            onFailed.call();
                        }
                    }
                }
                watcher->deleteLater();
            });
            watcher->setFuture(future);
        });
}

bool CUtils::copyFile(const QUrl& source, const QUrl& target, bool overwrite) {
    if (!source.isLocalFile()) {
        qCWarning(lcCUtils) << "copyFile: source" << source << "is not a local file";
        return false;
    }
    if (!target.isLocalFile()) {
        qCWarning(lcCUtils) << "copyFile: target" << target << "is not a local file";
        return false;
    }

    if (overwrite && QFile::exists(target.toLocalFile())) {
        if (!QFile::remove(target.toLocalFile())) {
            qCWarning(lcCUtils) << "copyFile: overwrite was specified but failed to remove" << target.toLocalFile();
            return false;
        }
    }

    return QFile::copy(source.toLocalFile(), target.toLocalFile());
}

bool CUtils::deleteFile(const QUrl& path) {
    if (!path.isLocalFile()) {
        qCWarning(lcCUtils) << "deleteFile: path" << path << "is not a local file";
        return false;
    }

    return QFile::remove(path.toLocalFile());
}

QString CUtils::toLocalFile(const QUrl& url) {
    if (!url.isLocalFile()) {
        qCWarning(lcCUtils) << "toLocalFile: given url is not a local file" << url;
        return QString();
    }

    return url.toLocalFile();
}

QString CUtils::sha256(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qCWarning(lcCUtils) << "sha256: failed to open" << path;
        return QString();
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&file);
    file.close();

    return hash.result().toHex();
}

void CUtils::enableBlurBehind(QQuickWindow* window, bool enable) {
    if (window) {
        KWindowEffects::enableBlurBehind(window, enable);
    }
}

qreal CUtils::clamp(qreal value, qreal min, qreal max) {
    return qBound(min, value, max);
}

void CUtils::setCursorPos(int x, int y) {
    QCursor::setPos(x, y);
}

#ifndef CAELESTIA_VERSION
#define CAELESTIA_VERSION ""
#endif

QString CUtils::version() const {
    return QStringLiteral(CAELESTIA_VERSION);
}

QString CUtils::qtVersion() const {
    return QStringLiteral(QT_VERSION_STR);
}

bool CUtils::capsLock() const {
    return d->keyInfo.isKeyLocked(Qt::Key_CapsLock);
}

bool CUtils::numLock() const {
    return d->keyInfo.isKeyLocked(Qt::Key_NumLock);
}

bool CUtils::isKeyPressed(int key) const {
    return d->keyInfo.isKeyPressed(static_cast<Qt::Key>(key));
}

bool CUtils::isAltPressed() const {
    return d->keyInfo.isKeyPressed(Qt::Key_Alt) || d->keyInfo.isKeyPressed(Qt::Key_AltGr);
}

bool CUtils::isMetaPressed() const {
    return d->keyInfo.isKeyPressed(Qt::Key_Meta) || d->keyInfo.isKeyPressed(Qt::Key_Super_L) || d->keyInfo.isKeyPressed(Qt::Key_Super_R);
}

bool CUtils::isCtrlPressed() const {
    return d->keyInfo.isKeyPressed(Qt::Key_Control);
}

bool CUtils::isShiftPressed() const {
    return d->keyInfo.isKeyPressed(Qt::Key_Shift);
}

bool CUtils::isShortcutModifierPressed(const QString& shortcutKey) const {
    if (shortcutKey.isEmpty()) {
        return isAltPressed();
    }
    const QString upper = shortcutKey.toUpper();
    const bool hasAlt = upper.contains(QLatin1String("ALT"));
    const bool hasMeta = upper.contains(QLatin1String("META")) || upper.contains(QLatin1String("SUPER")) || upper.contains(QLatin1String("WIN"));
    const bool hasCtrl = upper.contains(QLatin1String("CTRL")) || upper.contains(QLatin1String("CONTROL"));

    // Check primary holding modifiers
    if (hasAlt && isAltPressed()) return true;
    if (hasMeta && isMetaPressed()) return true;
    if (hasCtrl && isCtrlPressed()) return true;

    // If none of the standard primary holding modifiers are in the shortcut, check shift if specified
    if (!hasAlt && !hasMeta && !hasCtrl) {
        if (upper.contains(QLatin1String("SHIFT"))) {
            return isShiftPressed();
        }
        return isAltPressed();
    }

    // A primary modifier is defined in the shortcut, but is not currently pressed
    return false;
}

namespace {

// Unlike QObject::findChild, this walks parentItem/childItems relationships so
// it traverses the QML visual hierarchy.
template <typename Predicate> QQuickItem* findChildDfs(QQuickItem* root, Predicate&& match) {
    const auto children = root->childItems();
    for (QQuickItem* const child : children) {
        if (match(child)) {
            return child;
        }
        if (QQuickItem* const found = findChildDfs(child, match)) {
            return found;
        }
    }
    return nullptr;
}

// DFS over the visual item tree, appending every descendant matching the
// predicate to out.
template <typename Predicate> void findChildrenDfs(QQuickItem* root, Predicate&& match, QList<QQuickItem*>& out) {
    const auto children = root->childItems();
    for (QQuickItem* const child : children) {
        if (match(child)) {
            out.append(child);
        }
        findChildrenDfs(child, match, out);
    }
}

} // namespace

QQuickItem* CUtils::findChild(QQuickItem* root, const QString& name) {
    if (!root) {
        return nullptr;
    }

    return findChildDfs(root, [&name](const QQuickItem* item) {
        return item->objectName() == name;
    });
}

QList<QQuickItem*> CUtils::findChildren(QQuickItem* root, const QString& name) {
    QList<QQuickItem*> children;
    if (root) {
        findChildrenDfs(root, [&name](const QQuickItem* item) {
            return item->objectName() == name;
        }, children);
    }
    return children;
}

QList<QQuickItem*> CUtils::findChildrenMatching(QQuickItem* root, const QString& pattern) {
    QList<QQuickItem*> children;
    if (root) {
        const QRegularExpression re(pattern);
        findChildrenDfs(root, [&re](const QQuickItem* item) {
            return re.match(item->objectName()).hasMatch();
        }, children);
    }
    return children;
}

} // namespace caelestia
