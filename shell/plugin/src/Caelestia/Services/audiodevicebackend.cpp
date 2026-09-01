#include "audiodevicebackend.hpp"
#include <PulseAudioQt/Context>
#include <PulseAudioQt/Models>
#include <PulseAudioQt/Device>
#include <PulseAudioQt/Sink>
#include <PulseAudioQt/Source>
#include <PulseAudioQt/Card>
#include <PulseAudioQt/Profile>
#include <PulseAudioQt/Port>

using namespace PulseAudioQt;

AudioDeviceFilterModel::AudioDeviceFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
}

bool AudioDeviceFilterModel::showInactiveDevices() const
{
    return m_showInactiveDevices;
}

void AudioDeviceFilterModel::setShowInactiveDevices(bool show)
{
    if (m_showInactiveDevices != show) {
        m_showInactiveDevices = show;
        Q_EMIT showInactiveDevicesChanged();
        invalidate();
    }
}

bool AudioDeviceFilterModel::filterAcceptsRow(int source_row, const QModelIndex &source_parent) const
{
    if (m_showInactiveDevices) {
        return true;
    }

    QModelIndex index = sourceModel()->index(source_row, 0, source_parent);
    QVariant data = sourceModel()->data(index, AbstractModel::PulseObjectRole);
    if (Device *device = qobject_cast<Device *>(data.value<QObject *>())) {
        const auto ports = device->ports();
        if (ports.size() == 1 && ports.at(0)->availability() == Port::Unavailable) {
            return false; // KDE hides devices with exactly one port that is unavailable
        }
    }
    return true;
}

AudioBackend::AudioBackend(QObject* parent) : QObject(parent)
{
    Context::instance();

    m_sinksFilter = new AudioDeviceFilterModel(this);
    m_sinksFilter->setSourceModel(new SinkModel(this));

    m_sourcesFilter = new AudioDeviceFilterModel(this);
    m_sourcesFilter->setSourceModel(new SourceModel(this));

    m_cardModel = new CardModel(this);
}

AudioBackend::~AudioBackend()
{
}

bool AudioBackend::showInactiveDevices() const
{
    return m_showInactiveDevices;
}

void AudioBackend::setShowInactiveDevices(bool show)
{
    if (m_showInactiveDevices != show) {
        m_showInactiveDevices = show;
        m_sinksFilter->setShowInactiveDevices(show);
        m_sourcesFilter->setShowInactiveDevices(show);
        Q_EMIT showInactiveDevicesChanged();
    }
}

QAbstractItemModel* AudioBackend::sinks() const
{
    return m_sinksFilter;
}

QAbstractItemModel* AudioBackend::sources() const
{
    return m_sourcesFilter;
}

QAbstractItemModel* AudioBackend::cards() const
{
    return m_cardModel;
}

bool AudioBackend::isSinkInactive(const QString& name)
{
    for (auto sink : Context::instance()->sinks()) {
        if (sink->name() == name) {
            auto ports = sink->ports();
            if (ports.size() == 1 && ports.at(0)->availability() == Port::Unavailable) {
                return true;
            }
            return false;
        }
    }
    return false;
}

bool AudioBackend::isSourceInactive(const QString& name)
{
    for (auto source : Context::instance()->sources()) {
        if (source->name() == name) {
            auto ports = source->ports();
            if (ports.size() == 1 && ports.at(0)->availability() == Port::Unavailable) {
                return true;
            }
            return false;
        }
    }
    return false;
}
