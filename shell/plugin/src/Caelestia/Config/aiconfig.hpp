#pragma once

#include "configobject.hpp"
#include <qstring.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class AiConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, ollamaUrl, u"http://localhost:11434"_s)
    CONFIG_PROPERTY(QString, ollamaModel, u"llama3"_s)
    
    CONFIG_PROPERTY(bool, saveChatHistory, true)
    CONFIG_PROPERTY(QString, ollamaHistoryJson, u"[]"_s)

    CONFIG_PROPERTY(bool, snapToDefaultOllama, true)
    CONFIG_PROPERTY(QString, defaultOllamaModel, u"llama3"_s)

    CONFIG_PROPERTY(QString, defaultProvider, u"ollama"_s)
    CONFIG_PROPERTY(bool, enableOllama, true)
    CONFIG_PROPERTY(bool, enableCelestialMode, false)
    CONFIG_PROPERTY(QString, orionModel, u"qwen3.5:9b"_s)

    CONFIG_PROPERTY(QString, activeProvider, u"ollama"_s)
    CONFIG_PROPERTY(QString, activeOllamaModel, u"llama3"_s)

public:
    explicit AiConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
