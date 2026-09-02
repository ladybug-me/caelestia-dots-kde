#pragma once

#include "tickingservice.hpp"

#include <qprocess.h>
#include <qqmlintegration.h>
#include <QStringList>

namespace caelestia::services {

struct GpuDevice {
    QString pciId;
    QString name;
    QString vendorId;
    QString deviceId;
};

class Gpu : public TickingService {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Type {
        Auto,    // user override is empty (config "") — defer to detected autoType
        None,    // no usable GPU / disabled
        Nvidia,  // Nvidia GPU
        Generic, // Intel / AMD / other GPU
    };
    Q_ENUM(Type)

private:
    Q_PROPERTY(Type type READ type NOTIFY typeChanged)
    Q_PROPERTY(Type userType READ userType NOTIFY userTypeChanged)
    Q_PROPERTY(Type autoType READ autoType NOTIFY autoTypeChanged)
    Q_PROPERTY(QString name READ name NOTIFY nameChanged)
    Q_PROPERTY(qreal percentage READ percentage NOTIFY percentageChanged)
    Q_PROPERTY(qreal temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(QStringList devices READ devices NOTIFY devicesChanged)

public:
    explicit Gpu(QObject* parent = nullptr);
    ~Gpu() override;

    [[nodiscard]] Type type() const;
    [[nodiscard]] Type userType() const;
    [[nodiscard]] Type autoType() const;
    [[nodiscard]] QString name() const;
    [[nodiscard]] qreal percentage() const;
    [[nodiscard]] qreal temperature() const;
    [[nodiscard]] QStringList devices() const;

signals:
    void typeChanged();
    void userTypeChanged();
    void autoTypeChanged();
    void nameChanged();
    void percentageChanged();
    void temperatureChanged();
    void devicesChanged();

protected:
    void tick() override;

private:
    void detectDevices();
    void updateSelectedDevice();
    void ensureNvtopRunning();
    void stopNvtop();
    void readGenericUsage();
    void readGpuTemperature();

    void setUserType(Type value);
    void setAutoType(Type value);
    void setName(QString value);

    [[nodiscard]] static QString cleanName(QString s);
    [[nodiscard]] static QString ensureNvtopConfig();

    Type m_userType = Auto;
    Type m_autoType = None;
    QString m_userConfig;
    QString m_name;
    qreal m_percentage = 0.0;
    qreal m_temperature = 0.0;

    QList<GpuDevice> m_detectedDevices;
    int m_selectedDeviceIdx = -1;

    QProcess* m_nvtopProc = nullptr;
    QByteArray m_nvtopBuffer;
    bool m_hasNvtop = false;
};

} // namespace caelestia::services
