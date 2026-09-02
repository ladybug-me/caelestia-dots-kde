#include "gpu.hpp"

#include "../Config/rootnodes.hpp"
#include "../Config/serviceconfig.hpp"
#include "sensorslib.hpp"

#include <cmath>
#include <qdir.h>
#include <qfile.h>
#include <qregularexpression.h>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QTextStream>
#include <dlfcn.h>
#include <qloggingcategory.h>

Q_DECLARE_LOGGING_CATEGORY(lcGpu)
Q_LOGGING_CATEGORY(lcGpu, "caelestia.services.gpu", QtInfoMsg)

namespace caelestia::services {

namespace {

// NVML minimal definitions
typedef enum nvmlReturn_enum {
    NVML_SUCCESS = 0,
} nvmlReturn_t;

typedef struct nvmlDevice_st* nvmlDevice_t;

typedef struct nvmlUtilization_st {
    unsigned int gpu;
    unsigned int memory;
} nvmlUtilization_t;

constexpr int NVML_TEMPERATURE_GPU = 0;

typedef nvmlReturn_t (*nvmlInit_v2_t)(void);
typedef nvmlReturn_t (*nvmlShutdown_t)(void);
typedef nvmlReturn_t (*nvmlDeviceGetHandleByPciBusId_v2_t)(const char *pciBusId, nvmlDevice_t *device);
typedef nvmlReturn_t (*nvmlDeviceGetUtilizationRates_t)(nvmlDevice_t device, nvmlUtilization_t *utilization);
typedef nvmlReturn_t (*nvmlDeviceGetTemperature_t)(nvmlDevice_t device, int sensorType, unsigned int *temp);

nvmlInit_v2_t nvmlInit_v2_fn = nullptr;
nvmlShutdown_t nvmlShutdown_fn = nullptr;
nvmlDeviceGetHandleByPciBusId_v2_t nvmlDeviceGetHandleByPciBusId_v2_fn = nullptr;
nvmlDeviceGetUtilizationRates_t nvmlDeviceGetUtilizationRates_fn = nullptr;
nvmlDeviceGetTemperature_t nvmlDeviceGetTemperature_fn = nullptr;

void lookupPciNames(
    const QString& vendorId,
    const QString& deviceId,
    QString& vendorName,
    QString& deviceName
) {
    const QString lowerVendor = vendorId.toLower();
    const QString lowerDevice = deviceId.toLower();

    if (lowerVendor == QStringLiteral("10de")) {
        vendorName = QStringLiteral("NVIDIA");
    } else if (lowerVendor == QStringLiteral("8086")) {
        vendorName = QStringLiteral("Intel");
    } else if (lowerVendor == QStringLiteral("1002")) {
        vendorName = QStringLiteral("AMD");
    }

    const QStringList candidatePaths = {
        QStringLiteral("/usr/share/hwdata/pci.ids"),
        QStringLiteral("/usr/share/misc/pci.ids"),
        QStringLiteral("/usr/share/pci.ids"),
    };

    for (const QString& path : candidatePaths) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        QTextStream in(&file);
        bool inTargetVendor = false;
        while (!in.atEnd()) {
            const QString line = in.readLine();
            if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
                continue;
            }
            if (!line.startsWith(QLatin1Char('\t'))) {
                const QStringList parts = line.split(
                    QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
                if (!parts.isEmpty() && parts.first().toLower() == lowerVendor) {
                    inTargetVendor = true;
                    if (parts.size() > 1) {
                        vendorName = line.mid(line.indexOf(parts[1]));
                    }
                } else if (inTargetVendor) {
                    break;
                }
            } else if (inTargetVendor
                       && line.startsWith(QLatin1Char('\t'))
                       && !line.startsWith(QStringLiteral("\t\t"))) {
                const QString trimmed = line.trimmed();
                const QStringList parts = trimmed.split(
                    QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
                if (!parts.isEmpty() && parts.first().toLower() == lowerDevice) {
                    if (parts.size() > 1) {
                        deviceName = trimmed.mid(trimmed.indexOf(parts[1]));
                    }
                    break;
                }
            }
        }
        file.close();
        if (!deviceName.isEmpty()) {
            break;
        }
    }
}

// Parse a trailing-% or trailing-unit number string, e.g. "42%" → 42.0, "55C" → 55.0
bool parseTrailingNumber(const QString& s, qreal& out) {
    if (s.isEmpty()) {
        return false;
    }
    // Strip one trailing non-digit character
    const QString num = s.last(1).at(0).isDigit() ? s : s.chopped(1);
    bool ok = false;
    out = num.toDouble(&ok);
    return ok;
}

} // namespace

Gpu::Gpu(QObject* parent)
    : TickingService(parent) {
    auto* svc = caelestia::config::ConfigSingleton::instance()->services();
    m_userConfig = svc->gpuType();

    detectDevices();
    updateSelectedDevice();

    QObject::connect(svc, &caelestia::config::ServiceConfig::gpuTypeChanged, this, [this, svc] {
        m_userConfig = svc->gpuType();
        updateSelectedDevice();
    });
}

Gpu::~Gpu() {
    cleanupNvidia();
}

Gpu::Type Gpu::type() const {
    return m_userType == Auto ? m_autoType : m_userType;
}

Gpu::Type Gpu::userType() const {
    return m_userType;
}

Gpu::Type Gpu::autoType() const {
    return m_autoType;
}

QString Gpu::name() const {
    return m_name;
}

qreal Gpu::percentage() const {
    return m_percentage;
}

qreal Gpu::temperature() const {
    return m_temperature;
}

QStringList Gpu::devices() const {
    QStringList list;
    list.reserve(m_detectedDevices.size());
    for (const auto& dev : m_detectedDevices) {
        list.append(dev.name);
    }
    return list;
}

void Gpu::setUserType(Type value) {
    if (value == m_userType) {
        return;
    }
    const Type prevDerived = type();
    m_userType = value;
    Q_EMIT userTypeChanged();
    if (type() != prevDerived) {
        Q_EMIT typeChanged();
    }
}

void Gpu::setAutoType(Type value) {
    if (value == m_autoType) {
        return;
    }
    const Type prevDerived = type();
    m_autoType = value;
    Q_EMIT autoTypeChanged();
    if (type() != prevDerived) {
        Q_EMIT typeChanged();
    }
}

void Gpu::setName(QString value) {
    if (value == m_name) {
        return;
    }
    m_name = std::move(value);
    Q_EMIT nameChanged();
}

void Gpu::detectDevices() {
    m_detectedDevices.clear();
    const QDir pciDir(QStringLiteral("/sys/bus/pci/devices"));
    const QStringList entries = pciDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    for (const QString& pciId : entries) {
        QFile classFile(QStringLiteral("/sys/bus/pci/devices/%1/class").arg(pciId));
        if (!classFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        const QString classStr = QString::fromLatin1(classFile.readAll().trimmed());
        classFile.close();

        // Display controller classes: 0x0300xx (VGA), 0x0302xx (3D), 0x0380xx (Display)
        if (!classStr.startsWith(QStringLiteral("0x030"))) {
            continue;
        }

        QString vendorId;
        QString deviceId;

        QFile vendorFile(QStringLiteral("/sys/bus/pci/devices/%1/vendor").arg(pciId));
        if (vendorFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            vendorId = QString::fromLatin1(vendorFile.readAll().trimmed());
            if (vendorId.startsWith(QStringLiteral("0x"))) {
                vendorId = vendorId.mid(2);
            }
            vendorFile.close();
        }

        QFile devFile(QStringLiteral("/sys/bus/pci/devices/%1/device").arg(pciId));
        if (devFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            deviceId = QString::fromLatin1(devFile.readAll().trimmed());
            if (deviceId.startsWith(QStringLiteral("0x"))) {
                deviceId = deviceId.mid(2);
            }
            devFile.close();
        }

        QString vendorName;
        QString deviceName;
        lookupPciNames(vendorId, deviceId, vendorName, deviceName);

        QString fullName;
        if (!vendorName.isEmpty() && !deviceName.isEmpty()) {
            fullName = QStringLiteral("%1 %2").arg(vendorName, deviceName);
        } else if (!deviceName.isEmpty()) {
            fullName = deviceName;
        } else if (!vendorName.isEmpty()) {
            fullName = QStringLiteral("%1 Display (%2:%3)").arg(vendorName, vendorId, deviceId);
        } else {
            fullName = QStringLiteral("PCI %1 (%2:%3)").arg(pciId, vendorId, deviceId);
        }

        GpuDevice dev;
        dev.pciId = pciId;
        dev.name = cleanName(fullName);
        dev.vendorId = vendorId.toLower();
        dev.deviceId = deviceId.toLower();

        m_detectedDevices.append(std::move(dev));
    }

    Q_EMIT devicesChanged();
}

void Gpu::updateSelectedDevice() {
    const QString config = m_userConfig.trimmed();

    if (config.compare(QStringLiteral("None"), Qt::CaseInsensitive) == 0) {
        setUserType(None);
        setAutoType(None);
        m_selectedDeviceIdx = -1;
        setName(QString());
        if (m_percentage > 0.0001) {
            m_percentage = 0.0;
            Q_EMIT percentageChanged();
        }
        if (m_temperature > 0.05) {
            m_temperature = 0.0;
            Q_EMIT temperatureChanged();
        }
        cleanupNvidia();
        return;
    }

    if (config.isEmpty() || config.compare(QStringLiteral("Auto"), Qt::CaseInsensitive) == 0) {
        setUserType(Auto);
        if (m_detectedDevices.isEmpty()) {
            setAutoType(None);
            m_selectedDeviceIdx = -1;
            setName(QString());
        } else {
            // Default selected GPU is the first GPU
            m_selectedDeviceIdx = 0;
            const auto& dev = m_detectedDevices.first();
            setAutoType(dev.vendorId == QStringLiteral("10de") ? Nvidia : Generic);
            setName(dev.name);
        }
    } else {
        int matchIdx = -1;
        for (int i = 0; i < m_detectedDevices.size(); ++i) {
            const auto& dev = m_detectedDevices.at(i);
            if (dev.name.compare(config, Qt::CaseInsensitive) == 0
                || dev.pciId.compare(config, Qt::CaseInsensitive) == 0
                || dev.name.contains(config, Qt::CaseInsensitive)) {
                matchIdx = i;
                break;
            }
        }

        if (matchIdx == -1 && config.compare(QStringLiteral("NVIDIA"), Qt::CaseInsensitive) == 0) {
            for (int i = 0; i < m_detectedDevices.size(); ++i) {
                if (m_detectedDevices.at(i).vendorId == QStringLiteral("10de")) {
                    matchIdx = i;
                    break;
                }
            }
        } else if (matchIdx == -1
                   && config.compare(QStringLiteral("GENERIC"), Qt::CaseInsensitive) == 0) {
            for (int i = 0; i < m_detectedDevices.size(); ++i) {
                if (m_detectedDevices.at(i).vendorId != QStringLiteral("10de")) {
                    matchIdx = i;
                    break;
                }
            }
        }

        if (matchIdx >= 0 && matchIdx < m_detectedDevices.size()) {
            m_selectedDeviceIdx = matchIdx;
            const auto& dev = m_detectedDevices.at(matchIdx);
            setUserType(dev.vendorId == QStringLiteral("10de") ? Nvidia : Generic);
            setName(dev.name);
        } else if (!m_detectedDevices.isEmpty()) {
            m_selectedDeviceIdx = 0;
            const auto& dev = m_detectedDevices.first();
            setUserType(dev.vendorId == QStringLiteral("10de") ? Nvidia : Generic);
            setName(dev.name);
        } else {
            setUserType(None);
            m_selectedDeviceIdx = -1;
            setName(QString());
        }
    }

    if (type() == Nvidia) {
        initNvidia();
    } else {
        cleanupNvidia();
    }
}

void Gpu::tick() {
    const Type t = type();
    if (t == None || m_selectedDeviceIdx < 0 || m_selectedDeviceIdx >= m_detectedDevices.size()) {
        if (m_percentage > 0.0001) {
            m_percentage = 0.0;
            Q_EMIT percentageChanged();
        }
        if (m_temperature > 0.05) {
            m_temperature = 0.0;
            Q_EMIT temperatureChanged();
        }
        return;
    }

    if (t == Nvidia) {
        readNvidiaUsageAndTemp();
    } else {
        readGenericUsage();
        readGenericTemperature();
    }
}

void Gpu::initNvidia() {
    if (m_nvmlLib) {
        return; // Already initialized
    }

    m_nvmlLib = dlopen("libnvidia-ml.so", RTLD_NOW);
    if (!m_nvmlLib) {
        m_nvmlLib = dlopen("libnvidia-ml.so.1", RTLD_NOW);
    }
    if (!m_nvmlLib) {
        qCWarning(lcGpu) << "Failed to load libnvidia-ml.so";
        return;
    }

    nvmlInit_v2_fn = reinterpret_cast<nvmlInit_v2_t>(dlsym(m_nvmlLib, "nvmlInit_v2"));
    nvmlShutdown_fn = reinterpret_cast<nvmlShutdown_t>(dlsym(m_nvmlLib, "nvmlShutdown"));
    nvmlDeviceGetHandleByPciBusId_v2_fn = reinterpret_cast<nvmlDeviceGetHandleByPciBusId_v2_t>(dlsym(m_nvmlLib, "nvmlDeviceGetHandleByPciBusId_v2"));
    nvmlDeviceGetUtilizationRates_fn = reinterpret_cast<nvmlDeviceGetUtilizationRates_t>(dlsym(m_nvmlLib, "nvmlDeviceGetUtilizationRates"));
    nvmlDeviceGetTemperature_fn = reinterpret_cast<nvmlDeviceGetTemperature_t>(dlsym(m_nvmlLib, "nvmlDeviceGetTemperature"));

    if (!nvmlInit_v2_fn || !nvmlShutdown_fn || !nvmlDeviceGetHandleByPciBusId_v2_fn || !nvmlDeviceGetUtilizationRates_fn || !nvmlDeviceGetTemperature_fn) {
        qCWarning(lcGpu) << "Failed to resolve required NVML functions";
        cleanupNvidia();
        return;
    }

    if (nvmlInit_v2_fn() != NVML_SUCCESS) {
        qCWarning(lcGpu) << "nvmlInit_v2 failed";
        cleanupNvidia();
        return;
    }

    const QString& pciId = m_detectedDevices.at(m_selectedDeviceIdx).pciId;
    nvmlDevice_t dev = nullptr;
    if (nvmlDeviceGetHandleByPciBusId_v2_fn(pciId.toUtf8().constData(), &dev) == NVML_SUCCESS) {
        m_nvmlDevice = dev;
    } else {
        qCWarning(lcGpu) << "Failed to get NVML handle for PCI ID:" << pciId;
    }
}

void Gpu::cleanupNvidia() {
    m_nvmlDevice = nullptr;
    if (m_nvmlLib) {
        if (nvmlShutdown_fn) {
            nvmlShutdown_fn();
        }
        dlclose(m_nvmlLib);
        m_nvmlLib = nullptr;
    }
}

void Gpu::readNvidiaUsageAndTemp() {
    if (!m_nvmlDevice || !nvmlDeviceGetUtilizationRates_fn || !nvmlDeviceGetTemperature_fn) {
        return;
    }

    nvmlUtilization_t util;
    if (nvmlDeviceGetUtilizationRates_fn(static_cast<nvmlDevice_t>(m_nvmlDevice), &util) == NVML_SUCCESS) {
        const qreal newPerc = util.gpu / 100.0;
        if (std::abs(newPerc - m_percentage) > 0.0001) {
            m_percentage = newPerc;
            Q_EMIT percentageChanged();
        }
    }

    unsigned int temp = 0;
    if (nvmlDeviceGetTemperature_fn(static_cast<nvmlDevice_t>(m_nvmlDevice), NVML_TEMPERATURE_GPU, &temp) == NVML_SUCCESS) {
        if (std::abs(static_cast<qreal>(temp) - m_temperature) > 0.05) {
            m_temperature = temp;
            Q_EMIT temperatureChanged();
        }
    }
}

void Gpu::readGenericUsage() {
    if (m_selectedDeviceIdx < 0 || m_selectedDeviceIdx >= m_detectedDevices.size()) {
        return;
    }
    const QString& pciId = m_detectedDevices.at(m_selectedDeviceIdx).pciId;
    const QString sysfsDir = QStringLiteral("/sys/bus/pci/devices/%1").arg(pciId);
    const QString drmDir = sysfsDir + QStringLiteral("/drm");

    qreal newPerc = 0.0;
    bool found = false;

    // List cards under the specific PCI device
    const QStringList cards = QDir(drmDir).entryList(QStringList() << QStringLiteral("card*"), QDir::Dirs | QDir::NoDotAndDotDot);

    // First preference: gpu_busy_percent (AMDGPU, some Intel Xe)
    for (const QString& card : cards) {
        QFile f(QStringLiteral("%1/%2/device/gpu_busy_percent").arg(drmDir, card));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool ok = false;
            newPerc = f.readAll().trimmed().toDouble(&ok) / 100.0;
            f.close();
            if (ok) {
                found = true;
                break;
            }
        }
    }

    // Second preference: RPS frequency ratio (Intel i915 gt sysfs)
    if (!found) {
        for (const QString& card : cards) {
            QFile cur(QStringLiteral("%1/%2/gt/gt0/rps_cur_freq_mhz").arg(drmDir, card));
            if (!cur.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }
            QFile max(QStringLiteral("%1/%2/gt/gt0/rps_max_freq_mhz").arg(drmDir, card));
            if (!max.open(QIODevice::ReadOnly | QIODevice::Text)) {
                cur.close();
                continue;
            }
            bool curOk = false;
            bool maxOk = false;
            const qreal curV = cur.readAll().trimmed().toDouble(&curOk);
            const qreal maxV = max.readAll().trimmed().toDouble(&maxOk);
            cur.close();
            max.close();
            if (curOk && maxOk && maxV > 0.0) {
                newPerc = qBound(0.0, curV / maxV, 1.0);
                found = true;
                break;
            }
        }
    }

    if (found && std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        Q_EMIT percentageChanged();
    }
}

void Gpu::readGenericTemperature() {
    if (m_selectedDeviceIdx < 0 || m_selectedDeviceIdx >= m_detectedDevices.size()) {
        return;
    }
    const QString& pciId = m_detectedDevices.at(m_selectedDeviceIdx).pciId;
    const QString hwmonDir = QStringLiteral("/sys/bus/pci/devices/%1/hwmon").arg(pciId);
    
    // Some Intel GPUs don't expose hwmon under their PCI device directly. 
    // Usually iGPUs share the CPU package temperature. We could fall back to it,
    // but reading the exact device's hwmon is most accurate for AMD/dGPUs.
    const QStringList hwmons = QDir(hwmonDir).entryList(QStringList() << QStringLiteral("hwmon*"), QDir::Dirs | QDir::NoDotAndDotDot);
    
    qreal maxTemp = 0.0;
    bool found = false;

    for (const QString& hwmon : hwmons) {
        // Find all tempX_input files
        const QStringList tempFiles = QDir(QStringLiteral("%1/%2").arg(hwmonDir, hwmon)).entryList(QStringList() << QStringLiteral("temp*_input"), QDir::Files);
        for (const QString& tempFile : tempFiles) {
            QFile f(QStringLiteral("%1/%2/%3").arg(hwmonDir, hwmon, tempFile));
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                bool ok = false;
                const qreal t = f.readAll().trimmed().toDouble(&ok);
                if (ok) {
                    // sysfs temp is usually in millidegrees Celsius
                    maxTemp = std::max(maxTemp, t / 1000.0);
                    found = true;
                }
                f.close();
            }
        }
    }

    // Fallback: If no hwmon on the device (like many Intel iGPUs), use sensorslib cpu fallback if generic
    if (!found) {
        const auto t = sensorslib::gpuPciAverageTemp();
        if (t.has_value()) {
            maxTemp = *t;
            found = true;
        }
    }

    if (found && std::abs(maxTemp - m_temperature) > 0.05) {
        m_temperature = maxTemp;
        Q_EMIT temperatureChanged();
    }
}

QString Gpu::cleanName(QString s) {
    s.replace(QStringLiteral("Corporation"), QString());
    s.replace(QStringLiteral("Technology Inc."), QString());
    s.replace(QStringLiteral("["), QStringLiteral("("));
    s.replace(QStringLiteral("]"), QStringLiteral(")"));
    static const QRegularExpression noise(
        QStringLiteral(
            "Graphics|Controller|VGA compatible controller|3D controller|\\(R\\)|\\(TM\\)"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression spaces(QStringLiteral("\\s+"));
    s.replace(noise, QStringLiteral(" "));
    s.replace(spaces, QStringLiteral(" "));
    return s.trimmed();
}

} // namespace caelestia::services
