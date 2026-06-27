#include "discordipc.hpp"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QDataStream>
#include <QCoreApplication>
#include <QDateTime>

namespace caelestia {

enum class Opcode : int32_t {
    Handshake = 0,
    Frame = 1,
    Close = 2,
    Ping = 3,
    Pong = 4
};

DiscordIpc::DiscordIpc(QObject* parent)
    : QObject(parent), m_socket(new QLocalSocket(this)), m_reconnectTimer(new QTimer(this)), m_connected(false)
{
    connect(m_socket, &QLocalSocket::connected, this, &DiscordIpc::onSocketConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &DiscordIpc::onSocketDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &DiscordIpc::onReadyRead);
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    connect(m_socket, &QLocalSocket::errorOccurred, this, &DiscordIpc::onError);
#else
    connect(m_socket, QOverload<QLocalSocket::LocalSocketError>::of(&QLocalSocket::error), this, &DiscordIpc::onError);
#endif

    m_reconnectTimer->setInterval(5000);
    connect(m_reconnectTimer, &QTimer::timeout, this, &DiscordIpc::checkReconnect);
}

DiscordIpc::~DiscordIpc() {
    disconnectIpc();
}

bool DiscordIpc::connected() const {
    return m_connected;
}

void DiscordIpc::connectIpc(const QString& clientId) {
    m_clientId = clientId;
    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }
    checkReconnect();
    m_reconnectTimer->start();
}

void DiscordIpc::disconnectIpc() {
    m_reconnectTimer->stop();
    m_clientId.clear();
    m_socket->abort();
    if (m_connected) {
        m_connected = false;
        emit connectedChanged();
    }
}

void DiscordIpc::checkReconnect() {
    if (m_clientId.isEmpty()) return;
    if (m_socket->state() == QLocalSocket::ConnectedState || m_socket->state() == QLocalSocket::ConnectingState) return;

    QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    QString pipePath = runtimeDir + "/discord-ipc-0";

    m_socket->connectToServer(pipePath);
}

void DiscordIpc::onSocketConnected() {
    // Send Handshake
    QJsonObject payload;
    payload["v"] = 1;
    payload["client_id"] = m_clientId;
    sendFrame(static_cast<int>(Opcode::Handshake), payload);
}

void DiscordIpc::onSocketDisconnected() {
    m_buffer.clear();
    if (m_connected) {
        m_connected = false;
        emit connectedChanged();
    }
}

void DiscordIpc::onError(QLocalSocket::LocalSocketError) {
    emit errorOccurred(m_socket->errorString());
    onSocketDisconnected();
}

void DiscordIpc::onReadyRead() {
    m_buffer.append(m_socket->readAll());

    while (m_buffer.size() >= 8) {
        QDataStream stream(m_buffer);
        stream.setByteOrder(QDataStream::LittleEndian);

        int32_t opcode;
        int32_t length;
        stream >> opcode >> length;

        if (m_buffer.size() < 8 + length) {
            break; // Wait for more data
        }

        QByteArray payloadData = m_buffer.mid(8, length);
        m_buffer.remove(0, 8 + length);

        QJsonDocument doc = QJsonDocument::fromJson(payloadData);
        if (doc.isObject()) {
            processPayload(opcode, doc.object());
        }
    }
}

void DiscordIpc::processPayload(int opcode, const QJsonObject& payload) {
    if (opcode == static_cast<int>(Opcode::Frame)) {
        if (payload.contains("cmd") && payload["cmd"].toString() == "DISPATCH") {
            if (payload.contains("evt") && payload["evt"].toString() == "READY") {
                m_connected = true;
                emit connectedChanged();
            }
        }
    } else if (opcode == static_cast<int>(Opcode::Close)) {
        m_socket->abort();
    }
}

void DiscordIpc::sendFrame(int opcode, const QJsonObject& payload) {
    if (m_socket->state() != QLocalSocket::ConnectedState) return;

    QJsonDocument doc(payload);
    QByteArray data = doc.toJson(QJsonDocument::Compact);

    QByteArray header;
    QDataStream stream(&header, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream << static_cast<int32_t>(opcode) << static_cast<int32_t>(data.size());

    m_socket->write(header);
    m_socket->write(data);
    m_socket->flush();
}

void DiscordIpc::sendActivity(const QJsonObject& activity) {
    if (!m_connected) return;

    QJsonObject args;
    args["pid"] = static_cast<int>(QCoreApplication::applicationPid());
    args["activity"] = activity;

    QJsonObject payload;
    payload["cmd"] = "SET_ACTIVITY";
    payload["args"] = args;
    payload["nonce"] = QString::number(QDateTime::currentMSecsSinceEpoch());

    sendFrame(static_cast<int>(Opcode::Frame), payload);
}

void DiscordIpc::clearActivity() {
    if (!m_connected) return;

    QJsonObject args;
    args["pid"] = static_cast<int>(QCoreApplication::applicationPid());

    QJsonObject payload;
    payload["cmd"] = "SET_ACTIVITY";
    payload["args"] = args;
    payload["nonce"] = QString::number(QDateTime::currentMSecsSinceEpoch());

    sendFrame(static_cast<int>(Opcode::Frame), payload);
}

} // namespace caelestia
