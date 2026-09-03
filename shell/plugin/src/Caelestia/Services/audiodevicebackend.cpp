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

static bool isDeviceInactive(PulseAudioQt::Device *device) {
    if (!device) {
        return false;
    }
    const auto ports = device->ports();
    if (ports.isEmpty()) {
        return false;
    }

    auto activeIdx = device->activePortIndex();
    if (activeIdx < static_cast<quint32>(ports.size())) {
        auto activePort = ports.at(static_cast<qsizetype>(activeIdx));
        if (activePort && activePort->availability() == PulseAudioQt::Port::Unavailable) {
            return true;
        }
        return false;
    }

    for (auto port : ports) {
        if (port && port->availability() != PulseAudioQt::Port::Unavailable) {
            return false;
        }
    }
    return true;
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
        if (isDeviceInactive(device)) {
            return false;
        }
    }
    return true;
}

CardFilterModel::CardFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
}

QHash<int, QByteArray> CardFilterModel::roleNames() const
{
    QHash<int, QByteArray> roles = QSortFilterProxyModel::roleNames();
    roles[DescriptionRole] = "description";
    return roles;
}

QVariant CardFilterModel::data(const QModelIndex &index, int role) const
{
    if (role == DescriptionRole || role == Qt::DisplayRole) {
        QModelIndex sourceIndex = mapToSource(index);
        QVariant poVar = sourceModel()->data(sourceIndex, PulseAudioQt::AbstractModel::PulseObjectRole);
        if (auto card = qobject_cast<PulseAudioQt::Card *>(poVar.value<QObject *>())) {
            const auto props = card->properties();
            if (props.contains(QStringLiteral("device.description"))) {
                return props.value(QStringLiteral("device.description")).toString();
            }
            if (props.contains(QStringLiteral("alsa.card_name"))) {
                return props.value(QStringLiteral("alsa.card_name")).toString();
            }
            return card->name();
        }
    }
    return QSortFilterProxyModel::data(index, role);
}

AudioBackend::AudioBackend(QObject* parent) : QObject(parent)
{
    Context *context = Context::instance();

    m_sinksFilter = new AudioDeviceFilterModel(this);
    m_sinksFilter->setSourceModel(new SinkModel(this));

    m_sourcesFilter = new AudioDeviceFilterModel(this);
    m_sourcesFilter->setSourceModel(new SourceModel(this));

    m_cardModel = new CardFilterModel(this);
    m_cardModel->setSourceModel(new CardModel(this));

    connect(context, &Context::sinkAdded, this, [this](Sink *sink) {
        registerSink(sink);
        m_sinksFilter->invalidate();
        Q_EMIT devicesChanged();
    });
    connect(context, &Context::sinkRemoved, this, [this](Sink *) {
        m_sinksFilter->invalidate();
        Q_EMIT devicesChanged();
    });

    connect(context, &Context::sourceAdded, this, [this](Source *source) {
        registerSource(source);
        m_sourcesFilter->invalidate();
        Q_EMIT devicesChanged();
    });
    connect(context, &Context::sourceRemoved, this, [this](Source *) {
        m_sourcesFilter->invalidate();
        Q_EMIT devicesChanged();
    });

    connect(context, &Context::cardAdded, this, [this](Card *card) {
        registerCard(card);
        m_cardModel->invalidate();
        Q_EMIT devicesChanged();
    });
    connect(context, &Context::cardRemoved, this, [this](Card *) {
        m_cardModel->invalidate();
        Q_EMIT devicesChanged();
    });

    connect(context, &Context::stateChanged, this, [this]() {
        m_sinksFilter->invalidate();
        m_sourcesFilter->invalidate();
        m_cardModel->invalidate();
        Q_EMIT devicesChanged();
    });

    for (auto sink : context->sinks()) {
        registerSink(sink);
    }
    for (auto source : context->sources()) {
        registerSource(source);
    }
    for (auto card : context->cards()) {
        registerCard(card);
    }
}

AudioBackend::~AudioBackend()
{
}

void AudioBackend::onSinkChanged()
{
    m_sinksFilter->invalidate();
    Q_EMIT devicesChanged();
}

void AudioBackend::onSourceChanged()
{
    m_sourcesFilter->invalidate();
    Q_EMIT devicesChanged();
}

void AudioBackend::onCardChanged()
{
    m_sinksFilter->invalidate();
    m_sourcesFilter->invalidate();
    m_cardModel->invalidate();
    Q_EMIT devicesChanged();
}

void AudioBackend::registerSink(QObject *sinkObj)
{
    if (auto sink = qobject_cast<Sink *>(sinkObj)) {
        connect(sink, &Device::portsChanged, this, &AudioBackend::onSinkChanged, Qt::UniqueConnection);
        connect(sink, &Device::activePortIndexChanged, this, &AudioBackend::onSinkChanged, Qt::UniqueConnection);
        connect(sink, &Device::stateChanged, this, &AudioBackend::onSinkChanged, Qt::UniqueConnection);
    }
}

void AudioBackend::registerSource(QObject *sourceObj)
{
    if (auto source = qobject_cast<Source *>(sourceObj)) {
        connect(source, &Device::portsChanged, this, &AudioBackend::onSourceChanged, Qt::UniqueConnection);
        connect(source, &Device::activePortIndexChanged, this, &AudioBackend::onSourceChanged, Qt::UniqueConnection);
        connect(source, &Device::stateChanged, this, &AudioBackend::onSourceChanged, Qt::UniqueConnection);
    }
}

void AudioBackend::registerCard(QObject *cardObj)
{
    if (auto card = qobject_cast<Card *>(cardObj)) {
        connect(card, &Card::activeProfileIndexChanged, this, &AudioBackend::onCardChanged, Qt::UniqueConnection);
        connect(card, &Card::profilesChanged, this, &AudioBackend::onCardChanged, Qt::UniqueConnection);
        connect(card, &Card::portsChanged, this, &AudioBackend::onCardChanged, Qt::UniqueConnection);
    }
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
        Q_EMIT devicesChanged();
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
        if (sink->name() == name || sink->description() == name) {
            return isDeviceInactive(sink);
        }
    }
    return false;
}

bool AudioBackend::isSourceInactive(const QString& name)
{
    for (auto source : Context::instance()->sources()) {
        if (source->name() == name || source->description() == name) {
            return isDeviceInactive(source);
        }
    }
    return false;
}

QString AudioBackend::cardDescription(QObject *cardObj) const
{
    if (auto card = qobject_cast<PulseAudioQt::Card *>(cardObj)) {
        const auto props = card->properties();
        if (props.contains(QStringLiteral("device.description"))) {
            return props.value(QStringLiteral("device.description")).toString();
        }
        if (props.contains(QStringLiteral("alsa.card_name"))) {
            return props.value(QStringLiteral("alsa.card_name")).toString();
        }
        return card->name();
    }
    return QString();
}
