#include "kwinwindowthumbnailprovider.hpp"

#include <qdbusconnection.h>
#include <qdbusmessage.h>
#include <qdbusunixfiledescriptor.h>
#include <qfile.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qregularexpression.h>
#include <qrunnable.h>
#include <qthreadpool.h>
#include <quuid.h>
#include <qvariantlist.h>
#include <qvariantmap.h>

#include <limits>
#include <unistd.h>

Q_LOGGING_CATEGORY(lcKWinThumbProv, "caelestia.images.kwinthumb", QtInfoMsg)

namespace caelestia::images {

namespace {

class KWinWindowThumbnailResponse final : public QQuickImageResponse, public QRunnable {
public:
    KWinWindowThumbnailResponse(const QString& id, const QSize& requestedSize)
        : m_id(id)
        , m_requestedSize(requestedSize) {
        setAutoDelete(false);
    }

    [[nodiscard]] QQuickTextureFactory* textureFactory() const override {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }

    [[nodiscard]] QString errorString() const override { return m_error; }

    void run() override {
        process();
        emit finished();
    }

private:
    static QString decodeHandle(const QString& id) {
        const qsizetype queryIndex = id.indexOf(QLatin1Char('?'));
        QString cleanId = queryIndex >= 0 ? id.left(queryIndex) : id;
        QString handle = QString::fromUtf8(QByteArray::fromPercentEncoding(cleanId.toUtf8()));
        if (handle.startsWith(QLatin1Char('/')))
            handle.remove(0, 1);
        return handle;
    }

    static QString normalizeHandle(QString handle, QString* error) {
        handle = handle.trimmed();
        if (handle.isEmpty()) {
            *error = QStringLiteral("Missing KWin window handle");
            return {};
        }

        handle.remove(QLatin1Char('{'));
        handle.remove(QLatin1Char('}'));

        if (handle.startsWith(QStringLiteral("urn:uuid:"), Qt::CaseInsensitive))
            handle = handle.mid(9);

        static const QRegularExpression kUuidPattern(
            QStringLiteral("([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"));
        QRegularExpressionMatch match = kUuidPattern.match(handle);
        if (match.hasMatch())
            handle = match.captured(1);

        QString compact = handle;
        compact.remove(QLatin1Char('-'));

        static const QRegularExpression kHex32Pattern(QStringLiteral("^[0-9a-fA-F]{32}$"));
        if (kHex32Pattern.match(compact).hasMatch()) {
            handle = QStringLiteral("%1-%2-%3-%4-%5")
                         .arg(compact.first(8), compact.mid(8, 4), compact.mid(12, 4), compact.mid(16, 4), compact.mid(20, 12));
        }

        const QUuid uuid = QUuid::fromString(handle);
        if (uuid.isNull()) {
            *error = QStringLiteral("Invalid KWin window handle format: ") + handle;
            return {};
        }

        return uuid.toString(QUuid::WithoutBraces).toLower();
    }

    static QByteArray readPipeFully(int fd, QString* error) {
        QFile pipeFile;
        if (!pipeFile.open(fd, QIODevice::ReadOnly, QFileDevice::AutoCloseHandle)) {
            *error = QStringLiteral("Failed to open screenshot pipe: ") + pipeFile.errorString();
            return {};
        }

        const QByteArray data = pipeFile.readAll();
        if (pipeFile.error() != QFileDevice::NoError) {
            *error = QStringLiteral("Failed to read screenshot pipe: ") + pipeFile.errorString();
            return {};
        }

        return data;
    }

    void process() {
        const QString decodedHandle = decodeHandle(m_id);
        const QString handle = normalizeHandle(decodedHandle, &m_error);
        if (handle.isEmpty()) {
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        int pipeFds[2];
        if (::pipe(pipeFds) != 0) {
            m_error = QStringLiteral("Failed to create screenshot pipe for handle: ") + handle;
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        QVariantMap options;
        options.insert(QStringLiteral("include-decoration"), false);
        options.insert(QStringLiteral("include-shadow"), false);
        options.insert(QStringLiteral("native-resolution"), false);

        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.KWin.ScreenShot2"),
            QStringLiteral("/org/kde/KWin/ScreenShot2"),
            QStringLiteral("org.kde.KWin.ScreenShot2"),
            QStringLiteral("CaptureWindow"));
        QVariantList callArgs;
        callArgs << handle << options << QVariant::fromValue(QDBusUnixFileDescriptor(pipeFds[1]));
        message.setArguments(callArgs);

        const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, 30000);
        ::close(pipeFds[1]);

        if (reply.type() == QDBusMessage::ErrorMessage) {
            ::close(pipeFds[0]);
            m_error = QStringLiteral("KWin screenshot failed for %1: %2").arg(handle, reply.errorMessage());
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        const QVariantList args = reply.arguments();
        if (args.isEmpty() || !args.constFirst().canConvert<QVariantMap>()) {
            ::close(pipeFds[0]);
            m_error = QStringLiteral("KWin screenshot returned invalid metadata for handle: ") + handle;
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        const QVariantMap results = args.constFirst().toMap();
        const QByteArray rawBytes = readPipeFully(pipeFds[0], &m_error);
        if (rawBytes.isEmpty()) {
            if (m_error.isEmpty())
                m_error = QStringLiteral("KWin screenshot returned empty data for handle: ") + handle;
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        const QString type = results.value(QStringLiteral("type")).toString();
        if (type != QStringLiteral("raw")) {
            QImage image;
            if (!image.loadFromData(rawBytes)) {
                m_error = QStringLiteral("Unsupported screenshot payload type for handle %1: %2").arg(handle, type);
                qCWarning(lcKWinThumbProv).noquote() << m_error;
                return;
            }
            m_image = image;
            return;
        }

        const int width = results.value(QStringLiteral("width")).toInt();
        const int height = results.value(QStringLiteral("height")).toInt();
        const int stride = results.value(QStringLiteral("stride")).toInt();
        const auto format = static_cast<QImage::Format>(results.value(QStringLiteral("format")).toInt());
        const double scale = results.value(QStringLiteral("scale")).toDouble();

        const quint64 expectedMinBytes = static_cast<quint64>(height) * static_cast<quint64>(stride);
        const bool bytesOutOfRange = expectedMinBytes > static_cast<quint64>(std::numeric_limits<qsizetype>::max())
            || rawBytes.size() < static_cast<qsizetype>(expectedMinBytes);
        const bool invalidFormat = format <= QImage::Format_Invalid || format >= QImage::NImageFormats;

        if (width <= 0 || height <= 0 || stride <= 0 || invalidFormat || bytesOutOfRange) {
            m_error = QStringLiteral("Invalid KWin screenshot payload for handle: ") + handle;
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        QImage image(reinterpret_cast<const uchar*>(rawBytes.constData()), width, height, stride, format);
        if (image.isNull()) {
            m_error = QStringLiteral("Failed to construct KWin screenshot image for handle: ") + handle;
            qCWarning(lcKWinThumbProv).noquote() << m_error;
            return;
        }

        m_image = image.copy();
        if (scale > 0.0)
            m_image.setDevicePixelRatio(scale);

        if (m_requestedSize.isValid() && !m_requestedSize.isEmpty()) {
            m_image = m_image.scaled(m_requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
    }

    QString m_id;
    QSize m_requestedSize;
    QImage m_image;
    QString m_error;
};

} // namespace

QQuickImageResponse* KWinWindowThumbnailProvider::requestImageResponse(const QString& id, const QSize& requestedSize) {
    auto* const response = new KWinWindowThumbnailResponse(id, requestedSize);
    QThreadPool::globalInstance()->start(response);
    return response;
}

} // namespace caelestia::images