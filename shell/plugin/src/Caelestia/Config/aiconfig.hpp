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
    CONFIG_PROPERTY(bool, enableCelestialMode, true)
    CONFIG_PROPERTY(bool, showNews, true)
    CONFIG_PROPERTY(bool, showCaelestiaMode, true)
    CONFIG_PROPERTY(QString, orionModel, u"qwen3.5:9b"_s)

    CONFIG_PROPERTY(QString, activeProvider, u"ollama"_s)
    CONFIG_PROPERTY(QString, activeOllamaModel, u"llama3"_s)

    // Master switch for the whole sidebar AI assistant (independent of which
    // providers are enabled). When false, the AI tab is hidden entirely.
    CONFIG_PROPERTY(bool, enableAiAssistant, true)

    // Claude Code provider: shells out to the `claude` CLI in headless mode, using
    // the user's existing subscription login (~/.claude) — no API key required.
    CONFIG_PROPERTY(bool, enableClaudeCode, true)
    CONFIG_PROPERTY(QString, claudeCodeBin, u"claude"_s)
    CONFIG_PROPERTY(QString, defaultClaudeCodeModel, u"default"_s)
    // Effort / thinking level passed to `claude --effort` ("default" = don't pass).
    CONFIG_PROPERTY(QString, claudeCodeEffort, u"default"_s)

    // Multiple Claude accounts, each backed by its own CLAUDE_CONFIG_DIR.
    // claudeAccountsJson: JSON array of {"id","name"} (the default ~/.claude login
    // is always available as an implicit "Default" entry, id ""). activeClaudeAccount
    // holds the selected account id ("" = default). loginTerminal is the terminal
    // emulator used for the interactive `claude` login.
    CONFIG_PROPERTY(QString, claudeAccountsJson, u"[]"_s)
    CONFIG_PROPERTY(QString, activeClaudeAccount, u""_s)
    CONFIG_PROPERTY(QString, loginTerminal, u"konsole"_s)

    // Anthropic (Claude) HTTP API provider (pay-per-token, API key).
    // Disabled by default; enable to expose it in the provider selector.
    // The API key is stored here in plaintext; the ANTHROPIC_API_KEY environment
    // variable takes precedence when set (see getApiKey() in AiAssistant.qml).
    CONFIG_PROPERTY(bool, enableClaude, false)
    CONFIG_PROPERTY(QString, anthropicApiKey, u""_s)
    CONFIG_PROPERTY(QString, anthropicUrl, u"https://api.anthropic.com"_s)
    CONFIG_PROPERTY(QString, defaultClaudeModel, u"claude-sonnet-5"_s)

public:
    explicit AiConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
