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

namespace caelestia::services {

namespace {

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
    m_hasNvtop = !QStandardPaths::findExecutable(QStringLiteral("nvtop")).isEmpty();
    m_userConfig = svc->gpuType();

    detectDevices();
    updateSelectedDevice();

    QObject::connect(svc, &caelestia::config::ServiceConfig::gpuTypeChanged, this, [this, svc] {
        m_userConfig = svc->gpuType();
        // Stop existing nvtop so it restarts with the correct device index
        stopNvtop();
        updateSelectedDevice();
    });
}

Gpu::~Gpu() {
    stopNvtop();
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
        stopNvtop();
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

    if (type() == None) {
        stopNvtop();
    } else if (m_hasNvtop) {
        ensureNvtopRunning();
    }
}

void Gpu::tick() {
    const Type t = type();
    if (t == None) {
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

    if (m_hasNvtop) {
        // nvtop pushes data asynchronously via readyReadStandardOutput.
        // If it died unexpectedly, restart it; otherwise nothing to do here.
        ensureNvtopRunning();
    } else {
        readGenericUsage();
        readGpuTemperature();
    }
}

QString Gpu::ensureNvtopConfig() {
    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    const QString baseDir = runtimeDir.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::TempLocation)
        : runtimeDir;
    const QString dirPath = QStringLiteral("%1/caelestia").arg(baseDir);
    QDir().mkpath(dirPath);

    const QString configPath = QStringLiteral("%1/nvtop.ini").arg(dirPath);
    // Always (re)write the config so any stale file from a previous run is correct
    QFile file(configPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QByteArray cfg =
            "[GeneralOption]\n"
            "UseColor = false\n"
            "UpdateInterval = 10\n"
            "ShowInfoMessages = false\n\n"
            "[HeaderOption]\n"
            "UseFahrenheit = false\n"
            "EncodeHideTimer = -1\n"
            "GPUInfoBar = false\n\n"
            "[ChartOption]\n"
            "ReverseChart = false\n\n"
            "[ProcessListOption]\n"
            "HideNvtopProcess = true\n"
            "HideNvtopProcessList = true\n";
        file.write(cfg);
        file.close();
    }
    return configPath;
}

void Gpu::ensureNvtopRunning() {
    if (type() == None || !m_hasNvtop || m_nvtopProc) {
        return;
    }

    m_nvtopProc = new QProcess(this);
    m_nvtopBuffer.clear();

    // Capture the vendor ID of the selected device at launch time.
    // We match by vendor name in nvtop's device_name field rather than by
    // positional index because nvtop and sysfs enumerate GPUs in different orders
    // (e.g. nvtop lists NVIDIA first while sysfs places iGPU at index 0).
    const QString targetVendorId =
        (m_selectedDeviceIdx >= 0 && m_selectedDeviceIdx < m_detectedDevices.size())
            ? m_detectedDevices.at(m_selectedDeviceIdx).vendorId
            : QString();

    QObject::connect(m_nvtopProc, &QProcess::readyReadStandardOutput, this, [this, targetVendorId] {
        if (!m_nvtopProc) {
            return;
        }
        m_nvtopBuffer.append(m_nvtopProc->readAllStandardOutput());

        // nvtop -l emits one complete JSON array per update, followed by a newline.
        // We find the last COMPLETE top-level [...] block using a depth-tracking
        // backward scan — naive lastIndexOf('[') would wrongly match nested process
        // sub-arrays, producing a frame with no gpu_util/temp keys.
        qsizetype lastClose = -1;
        qsizetype firstOpen = -1;
        {
            int depth = 0;
            for (qsizetype i = m_nvtopBuffer.size() - 1; i >= 0; --i) {
                const char c = m_nvtopBuffer.at(i);
                if (c == ']') {
                    if (depth == 0) {
                        lastClose = i;
                    }
                    ++depth;
                } else if (c == '[') {
                    --depth;
                    if (depth == 0) {
                        firstOpen = i;
                        break;
                    }
                }
            }
        }
        if (firstOpen < 0 || lastClose < 0) {
            return;
        }

        const QByteArray frame = m_nvtopBuffer.mid(
            static_cast<qint64>(firstOpen),
            static_cast<qint64>(lastClose - firstOpen + 1));
        // Keep only data after the consumed frame (in case of partial next update)
        m_nvtopBuffer = m_nvtopBuffer.mid(static_cast<qint64>(lastClose + 1));

        QJsonParseError parseErr;
        const QJsonDocument doc = QJsonDocument::fromJson(frame, &parseErr);
        if (parseErr.error != QJsonParseError::NoError || !doc.isArray()) {
            return;
        }
        const QJsonArray arr = doc.array();
        if (arr.isEmpty()) {
            return;
        }

        // Match device by vendor name in nvtop's device_name field.
        // nvtop does not enumerate in sysfs order, so positional indexing is wrong.
        // Strategy:
        //   NVIDIA (10de) → device_name contains "NVIDIA"
        //   AMD   (1002)  → device_name contains "AMD" or "Radeon"
        //   Intel (8086)  → any entry that is not NVIDIA and not AMD
        //   Unknown       → first entry
        const auto isNvidiaEntry = [](const QString& name) {
            return name.contains(QStringLiteral("NVIDIA"), Qt::CaseInsensitive);
        };
        const auto isAmdEntry = [](const QString& name) {
            return name.contains(QStringLiteral("AMD"), Qt::CaseInsensitive)
                   || name.contains(QStringLiteral("Radeon"), Qt::CaseInsensitive);
        };

        QJsonObject devObj;
        for (const QJsonValue& val : arr) {
            if (!val.isObject()) {
                continue;
            }
            const QJsonObject obj = val.toObject();
            const QString devName = obj.value(QStringLiteral("device_name")).toString();
            if (targetVendorId == QStringLiteral("10de")) {
                if (isNvidiaEntry(devName)) {
                    devObj = obj;
                    break;
                }
            } else if (targetVendorId == QStringLiteral("1002")) {
                if (isAmdEntry(devName)) {
                    devObj = obj;
                    break;
                }
            } else {
                // Intel or unknown: pick first non-NVIDIA, non-AMD entry
                if (!isNvidiaEntry(devName) && !isAmdEntry(devName)) {
                    devObj = obj;
                    break;
                }
            }
        }
        // Fall back to first entry if nothing matched (single-GPU system, etc.)
        if (devObj.isEmpty() && !arr.isEmpty()) {
            devObj = arr.first().toObject();
        }

        if (devObj.isEmpty()) {
            return;
        }

        // --- GPU utilization ---
        const QJsonValue utilVal = devObj.value(QStringLiteral("gpu_util"));
        if (utilVal.isString()) {
            const QString utilStr = utilVal.toString();
            qreal raw = 0.0;
            if (parseTrailingNumber(utilStr, raw)) {
                const qreal usage = raw / 100.0;
                if (std::abs(usage - m_percentage) > 0.0001) {
                    m_percentage = usage;
                    Q_EMIT percentageChanged();
                }
            }
        }

        // --- Temperature ---
        // nvtop may report null temp for iGPUs (Intel), so we fall back to sysfs only then.
        const QJsonValue tempVal = devObj.value(QStringLiteral("temp"));
        if (!tempVal.isNull() && tempVal.isString()) {
            qreal raw = 0.0;
            if (parseTrailingNumber(tempVal.toString(), raw)) {
                if (std::abs(raw - m_temperature) > 0.05) {
                    m_temperature = raw;
                    Q_EMIT temperatureChanged();
                }
            }
        } else {
            // iGPU — temperature not reported by nvtop; read from hwmon sysfs
            readGpuTemperature();
        }
    });

    QObject::connect(
        m_nvtopProc,
        &QProcess::errorOccurred,
        this,
        [this](QProcess::ProcessError) { stopNvtop(); });

    QObject::connect(
        m_nvtopProc,
        &QProcess::finished,
        this,
        [this](int, QProcess::ExitStatus) { stopNvtop(); });

    const QString configPath = ensureNvtopConfig();
    m_nvtopProc->start(
        QStringLiteral("nvtop"),
        {QStringLiteral("-c"),
         configPath,
         QStringLiteral("-p"),
         QStringLiteral("-P"),
         QStringLiteral("-l"),
         QStringLiteral("-d"),
         QStringLiteral("10")});
}

void Gpu::stopNvtop() {
    if (m_nvtopProc) {
        // Disconnect all signals from this object to prevent re-entrant stopNvtop() calls
        m_nvtopProc->disconnect(this);
        m_nvtopProc->kill();
        m_nvtopProc->deleteLater();
        m_nvtopProc = nullptr;
        m_nvtopBuffer.clear();
    }
}

void Gpu::readGenericUsage() {
    const QStringList cards =
        QDir(QStringLiteral("/sys/class/drm"))
            .entryList(QStringList() << QStringLiteral("card*"), QDir::Dirs | QDir::NoDotAndDotDot);

    qreal sum = 0.0;
    int count = 0;

    // First preference: gpu_busy_percent (AMDGPU, some Intel i915)
    for (const QString& card : cards) {
        QFile f(QStringLiteral("/sys/class/drm/%1/device/gpu_busy_percent").arg(card));
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        bool ok = false;
        const qreal v = f.readAll().trimmed().toDouble(&ok);
        f.close();
        if (ok) {
            sum += v;
            ++count;
        }
    }

    // Second preference: RPS frequency ratio (Intel i915 gt sysfs)
    if (count < static_cast<int>(cards.size())) {
        for (const QString& card : cards) {
            if (QFile::exists(
                    QStringLiteral("/sys/class/drm/%1/device/gpu_busy_percent").arg(card))) {
                continue; // already counted above
            }
            QFile cur(QStringLiteral("/sys/class/drm/%1/gt/gt0/rps_cur_freq_mhz").arg(card));
            if (!cur.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }
            QFile max(QStringLiteral("/sys/class/drm/%1/gt/gt0/rps_max_freq_mhz").arg(card));
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
                const qreal ratio = qBound(0.0, curV / maxV, 1.0);
                sum += ratio * 100.0;
                ++count;
            }
        }
    }

    const qreal newPerc = count > 0 ? sum / static_cast<qreal>(count) / 100.0 : 0.0;
    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        Q_EMIT percentageChanged();
    }
}

void Gpu::readGpuTemperature() {
    const auto t = sensorslib::gpuPciAverageTemp();
    const qreal newTemp = t.value_or(0.0);
    if (std::abs(newTemp - m_temperature) > 0.05) {
        m_temperature = newTemp;
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
