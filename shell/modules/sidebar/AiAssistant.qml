pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import M3Shapes
import Caelestia.Blobs

Item {
    id: root

    ListModel { id: chatHistory }
    ListModel { id: historySessionsModel }

    property bool isHistoryTab: false
    property string currentChatId: ""
    property var currentRequest: null
    

    Timer {
        id: typingTimer
        interval: 16
        repeat: true
        property string fullText: ""
        property string currentText: ""
        property int charIndex: 0
        property int targetIdx: -1
        
        onTriggered: {
            if (targetIdx < 0 || targetIdx >= chatHistory.count) {
                stop();
                isTyping = false;
                isThinking = false;
                inAgentLoop = false;
                return;
            }
            if (charIndex >= fullText.length) {
                stop();
                chatHistory.setProperty(targetIdx, "text", fullText);
                chatHistory.setProperty(targetIdx, "isFinished", true);
                saveHistory();
                isTyping = false;
                isThinking = false;
                inAgentLoop = false;
                return;
            }
            var chunkSize = Math.max(1, Math.ceil(fullText.length / 30));
            currentText += fullText.substr(charIndex, chunkSize);
            charIndex += chunkSize;
            chatHistory.setProperty(targetIdx, "text", currentText);
            listView.positionViewAtEnd();
        }
    }
    
    property real savedContentY: -1

    onVisibleChanged: {
        if (visible) {
            fetchOllamaModels();
            if (savedContentY >= 0) {
                Qt.callLater(function() { listView.contentY = savedContentY; });
            }
        } else {
            savedContentY = listView.contentY;
        }
    }

    function startTypingAnimation(text) {
        isThinking = false;
        typingTimer.targetIdx = chatHistory.count - 1;
        typingTimer.fullText = text;
        typingTimer.currentText = "";
        typingTimer.charIndex = 0;
        typingTimer.start();
        listView.positionViewAtEnd();
    }

    Component.onCompleted: {
        fetchOllamaModels();
        fetchClaudeCodeModels();
        loadHistory();
    }

    property var ollamaModelsList: []

    // Static curated list of Claude models (Anthropic has no public "list models"
    // discovery that the free-form chat needs; these are the current chat-capable IDs).
    readonly property var claudeModelsList: [
        "claude-sonnet-5",
        "claude-opus-4-8",
        "claude-opus-4-7",
        "claude-haiku-4-5"
    ]

    // "Model" choices for the Claude Code (subscription CLI) provider. "default"
    // means: don't pass --model, let the CLI use the subscription's default.
    // Populated at startup by fetchClaudeCodeModels() from the installed CLI binary.
    property var claudeCodeModelsList: ["default", "opus", "sonnet", "haiku"]

    // Effort/thinking levels vary per model: recent models add xhigh/max, some support
    // fewer, and several (haiku, older sonnet, opus ≤4.1) support none at all. Returns
    // the valid levels for a given model ("" when the model has no effort control).
    function effortLevelsFor(model) {
        var m = String(model || "default").toLowerCase();
        if (m === "haiku")
            return [];
        if (m === "default" || m === "opus" || m === "sonnet" || m === "fable")
            return ["low", "medium", "high", "xhigh", "max"];

        var fam = m.indexOf("opus") !== -1 ? "opus"
                : m.indexOf("sonnet") !== -1 ? "sonnet"
                : m.indexOf("haiku") !== -1 ? "haiku"
                : m.indexOf("fable") !== -1 ? "fable" : "";
        var nums = (m.match(/\d+/g) || []).map(Number);
        var major = nums.length >= 1 ? nums[0] : 0;
        var minor = nums.length >= 2 ? nums[1] : 0;

        if (fam === "haiku")
            return [];
        if (fam === "fable")
            return ["low", "medium", "high", "xhigh", "max"];
        if (fam === "opus") {
            if (major > 4 || (major === 4 && minor >= 7))
                return ["low", "medium", "high", "xhigh", "max"];
            if (major === 4 && minor === 6)
                return ["low", "medium", "high", "max"];
            if (major === 4 && minor === 5)
                return ["low", "medium", "high"];
            return [];
        }
        if (fam === "sonnet") {
            if (major >= 5)
                return ["low", "medium", "high", "xhigh", "max"];
            if (major === 4 && minor === 6)
                return ["low", "medium", "high", "max"];
            return [];
        }
        return [];
    }

    // Effort choices for the currently-selected Claude Code model (empty = unsupported).
    readonly property var claudeCodeEffortOptions: {
        var lv = effortLevelsFor(activeModel());
        return lv.length > 0 ? ["default"].concat(lv) : [];
    }

    // Extract the model IDs the installed `claude` binary knows about (a real
    // "fetch" of what this CLI version supports), merged with the handy aliases.
    function fetchClaudeCodeModels() {
        var bin = claudeCodeBinPath();
        var script =
            "t=\"$(readlink -f " + JSON.stringify(bin) + " 2>/dev/null)\"; [ -z \"$t\" ] && t=" + JSON.stringify(bin) + "; " +
            "strings \"$t\" 2>/dev/null | grep -oE 'claude-(opus|sonnet|haiku|fable)-[0-9]+(-[0-9]+)?' | sort -u";
        var commandStr = JSON.stringify(["sh", "-c", script]);
        var qml =
            "import QtQuick\n" +
            "import Quickshell.Io\n" +
            "Process {\n" +
            "    id: mp\n" +
            "    command: " + commandStr + "\n" +
            "    stdout: StdioCollector { onStreamFinished: root.applyClaudeCodeModels(text || \"\"); }\n" +
            "    onExited: code => mp.destroy()\n" +
            "}";
        try {
            var o = Qt.createQmlObject(qml, root, "ccModelsProc");
            o.running = true;
        } catch (e) {
            Logger.log("[AI] claude-code model fetch error: " + e.message);
        }
    }

    function applyClaudeCodeModels(text) {
        var out = ["default", "opus", "sonnet", "haiku"];
        var seen = {};
        for (var k = 0; k < out.length; k++)
            seen[out[k]] = true;
        var lines = (text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var id = lines[i].trim();
            if (id === "")
                continue;
            // Drop dated snapshots (…-20250514) and the deprecated .0 base versions
            // (claude-opus-4-0, claude-sonnet-4-0) — these aren't selectable models.
            if (/-\d{5,}$/.test(id) || /-0$/.test(id))
                continue;
            if (!seen[id]) {
                out.push(id);
                seen[id] = true;
            }
        }
        claudeCodeModelsList = out;
    }

    // Currently selected provider ("ollama" | "claude-code" | "claude"), persisted in config.
    readonly property string provider: GlobalConfig.ai.defaultProvider || "ollama"
    readonly property bool isClaude: provider === "claude"       // Anthropic HTTP API (API key)
    readonly property bool isClaudeCode: provider === "claude-code" // `claude` CLI (subscription)

    // Runtime cache of Claude Code CLI session ids, keyed by chat id (also persisted
    // into allChatSessions so --resume works across shell restarts).
    property var claudeCodeSessions: ({})
    property var currentClaudeCodeProc: null

    // Prompt suggestions (Claude Code): starter prompts generated on demand.
    property var promptSuggestions: []
    property bool loadingSuggestions: false

    function fetchPromptSuggestions() {
        if (!isClaudeCode || loadingSuggestions)
            return;
        loadingSuggestions = true;
        promptSuggestions = [];

        // Gather recent conversation context + the current input draft so suggestions
        // are relevant to what the user is doing (not generic starters).
        var lines = [];
        for (var li = 0; li < chatHistory.count; li++) {
            var lm = chatHistory.get(li);
            if (!lm.isUser && !lm.isFinished)
                continue;
            var lt = (lm.text || "").trim();
            if (lt === "")
                continue;
            lines.push((lm.isUser ? "User" : "Assistant") + ": " + lt);
        }
        if (lines.length > 6)
            lines = lines.slice(lines.length - 6);
        var context = lines.join("\n");
        var draft = "";
        try {
            draft = (inputArea.text || "").trim();
        } catch (e) {}

        var prompt;
        if (context === "" && draft === "") {
            prompt = "Suggest exactly 4 short, varied example prompts a user might ask a helpful AI desktop assistant. Reply with ONLY a JSON array of 4 short strings, nothing else.";
        } else {
            prompt = "You are suggesting what the user might type NEXT in this chat. Based only on the context below, propose exactly 4 short, specific follow-up prompts they are likely to want to send next. Reply with ONLY a JSON array of 4 short strings, nothing else.\n\n";
            if (context !== "")
                prompt += "Conversation so far:\n" + context + "\n\n";
            if (draft !== "")
                prompt += "The user has started typing: \"" + draft + "\"\n\n";
        }

        var cmd = [claudeCodeBinPath(), "-p", prompt, "--output-format", "json", "--dangerously-skip-permissions"];
        var qml =
            "import QtQuick\n" +
            "import Quickshell.Io\n" +
            "Process {\n" +
            "    id: sp\n" +
            "    command: " + JSON.stringify(cmd) + "\n" +
            "    workingDirectory: " + JSON.stringify(claudeCodeCwd()) + "\n" +
            claudeCodeEnvSnippet() +
            "    stdout: StdioCollector { onStreamFinished: root.applyPromptSuggestions(text || \"\"); }\n" +
            "    onExited: code => { root.loadingSuggestions = false; sp.destroy(); }\n" +
            "}";
        try {
            var o = Qt.createQmlObject(qml, root, "promptSugProc");
            o.running = true;
        } catch (e) {
            loadingSuggestions = false;
            Logger.log("[AI] suggestion process error: " + e.message);
        }
    }

    function applyPromptSuggestions(text) {
        loadingSuggestions = false;
        var resultStr = "";
        try {
            resultStr = JSON.parse(text).result || "";
        } catch (e) {
            return;
        }
        var arr = null;
        try {
            arr = JSON.parse(resultStr);
        } catch (e) {
            var m = resultStr.match(/\[[\s\S]*\]/);
            if (m)
                try { arr = JSON.parse(m[0]); } catch (e2) {}
        }
        if (Array.isArray(arr)) {
            var list = [];
            for (var i = 0; i < arr.length && i < 6; i++)
                list.push(String(arr[i]));
            promptSuggestions = list;
        }
    }

    // A stored CLI session id only applies to the account that created it (session
    // ids live under that account's CLAUDE_CONFIG_DIR). If the active account differs,
    // return "" so we start a fresh session under the new account instead of a
    // --resume that would fail with "no conversation found".
    function claudeCodeSessionFor(chatId) {
        var active = GlobalConfig.ai.activeClaudeAccount || "";
        var c = claudeCodeSessions[chatId];
        if (c && c.acc === active)
            return c.sid;
        for (var i = 0; i < allChatSessions.length; i++)
            if (allChatSessions[i].id === chatId) {
                if ((allChatSessions[i].claudeCodeSessionAccount || "") === active)
                    return allChatSessions[i].claudeCodeSessionId || "";
                return "";
            }
        return "";
    }

    function setClaudeCodeSession(chatId, sid) {
        if (!sid)
            return;
        var active = GlobalConfig.ai.activeClaudeAccount || "";
        claudeCodeSessions[chatId] = { sid: sid, acc: active };
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === chatId) {
                allChatSessions[i].claudeCodeSessionId = sid;
                allChatSessions[i].claudeCodeSessionAccount = active;
                break;
            }
        }
    }

    // Plain-text transcript of the conversation so far, used to seed a *fresh* CLI
    // session (new chat, or after switching account) with prior context. Includes the
    // latest user message and skips the streaming placeholder. Returns "" when there
    // is only the single latest message (nothing to carry over).
    function claudeCodeTranscript() {
        var lines = [];
        var count = 0;
        for (var i = 0; i < chatHistory.count; i++) {
            var m = chatHistory.get(i);
            if (!m.isUser && !m.isFinished)
                continue;
            var t = (m.text || "").trim();
            if (t === "")
                continue;
            lines.push((m.isUser ? "User: " : "Assistant: ") + t);
            count++;
        }
        if (count <= 1)
            return "";
        return "Continue this conversation. Conversation so far:\n\n" + lines.join("\n\n") + "\n\nReply to the last user message.";
    }

    // Resolve the Anthropic API key: ANTHROPIC_API_KEY env var wins, config field is the fallback.
    function getApiKey() {
        var envKey = Quickshell.env("ANTHROPIC_API_KEY");
        if (envKey && envKey.trim() !== "")
            return envKey.trim();
        return (GlobalConfig.ai.anthropicApiKey || "").trim();
    }

    // The model to send for the active provider.
    function activeModel() {
        if (isClaudeCode)
            return GlobalConfig.ai.defaultClaudeCodeModel || "default";
        if (isClaude)
            return GlobalConfig.ai.defaultClaudeModel || "claude-sonnet-5";
        return GlobalConfig.ai.defaultOllamaModel || "llama3";
    }

    // Providers exposed in the provider selector (respecting the enable toggles).
    readonly property var providerList: {
        var l = [];
        if (GlobalConfig.ai.enableOllama)
            l.push("ollama");
        if (GlobalConfig.ai.enableClaudeCode)
            l.push("claude-code");
        if (GlobalConfig.ai.enableClaude)
            l.push("claude");
        if (l.length === 0)
            l.push("ollama");
        return l;
    }

    function providerLabel(p) {
        if (p === "claude-code")
            return "Claude Code";
        if (p === "claude")
            return "Claude API";
        return "Ollama";
    }

    property bool isTyping: false
    property bool isThinking: false
    property string currentThoughtText: ""
    property bool isThoughtExpanded: false
    onIsTypingChanged: {
        if (isTyping) listView.positionViewAtEnd();
    }
    property bool inAgentLoop: false

    function shellQuote(str) {
        if (str === null || str === undefined) return "''";
        return "'" + String(str).replace(/'/g, "'\\''") + "'";
    }

    // Parse <tool_call>{...}</tool_call> blocks from model response text
    function parseTextToolCalls(text) {
        var calls = [];
        var startTag = "<tool_call>";
        var endTag = "</tool_call>";
        var pos = 0;
        while (true) {
            var start = text.indexOf(startTag, pos);
            if (start === -1) break;
            var end = text.indexOf(endTag, start);
            if (end === -1) break;
            var jsonStr = text.substring(start + startTag.length, end).trim();
            // Remove markdown code block fences if the model included them
            jsonStr = jsonStr.replace(/^```[a-zA-Z]*\n?/, "");
            jsonStr = jsonStr.replace(/```$/, "");
            jsonStr = jsonStr.trim();

            try {
                var parsed = JSON.parse(jsonStr);
                if (parsed.name) calls.push(parsed);
            } catch(e) { Logger.log("[AI] Bad tool_call JSON: " + jsonStr); }
            pos = end + endTag.length;
        }
        return calls;
    }

    // Strip all <tool_call>...</tool_call> blocks (and text after partial open tag)
    function stripToolCalls(text) {
        var startTag = "<tool_call>";
        var endTag = "</tool_call>";
        var result = text;
        // Remove complete blocks
        while (true) {
            var s = result.indexOf(startTag);
            if (s === -1) break;
            var e = result.indexOf(endTag, s);
            if (e === -1) { result = result.substring(0, s); break; }
            result = result.substring(0, s) + result.substring(e + endTag.length);
        }
        return result.replace(/\s+$/, '');
    }

    function runAgentCommand(cmd, type) {
        var commandStr = Array.isArray(cmd) ? JSON.stringify(cmd) : '["sh", "-c", ' + JSON.stringify("exec </dev/null; " + cmd) + ']';
        var processQml = "import QtQuick\n" +
                         "import Quickshell.Io\n" +
                         "Process {\n" +
                         "    id: proc\n" +
                         "    command: " + commandStr + "\n" +
                         "    property string outStr: \"\"\n" +
                         "    property string errStr: \"\"\n" +
                         "    property bool hasExited: false\n" +
                         "    property bool outFinished: false\n" +
                         "    property bool errFinished: false\n" +
                         "    function checkDone() {\n" +
                         "        if (hasExited && outFinished && errFinished) {\n" +
                         "            root.handleAgentProcessResult(" + JSON.stringify(type) + ", proc.outStr, proc.errStr, " + JSON.stringify(cmd) + ");\n" +
                         "            proc.destroy();\n" +
                         "        }\n" +
                         "    }\n" +
                         "    stdout: StdioCollector { onStreamFinished: { proc.outStr = text || \"\"; proc.outFinished = true; proc.checkDone(); } }\n" +
                         "    stderr: StdioCollector { onStreamFinished: { proc.errStr = text || \"\"; proc.errFinished = true; proc.checkDone(); } }\n" +
                         "    onExited: code => { proc.hasExited = true; proc.checkDone(); }\n" +
                         "}";
        try {
            var obj = Qt.createQmlObject(processQml, root, "agentProcess");
            obj.running = true;
        } catch(e) {
            console.error("AGENT PROCESS ERROR: " + e.message);
            console.error("FAILED QML: \n" + processQml);
        }
    }

    property int runningToolsCount: 0
    property string accumulatedToolResults: ""
    property string accumulatedToolImage: ""

    function handleAgentProcessResult(type, stdout, stderr, cmd) {
        if (type === "screenshot_take") {
            var convertCmd = `magick ${Paths.runtimeTemp("orion_screenshot.png")} -resize '1024x1024>' -quality 85 ${Paths.runtimeTemp("orion_screenshot.jpg")} && base64 ${Paths.runtimeTemp("orion_screenshot.jpg")}`;
            runAgentCommand(convertCmd, "screenshot_encode");
        } else if (type === "screenshot_encode") {
            var b64 = stdout.replace(/\n/g, "").trim();
            accumulatedToolImage = b64;
            accumulatedToolResults += "Tool: take_screenshot\nResult: Screenshot taken. Analyze the attached image.\n\n";
            runningToolsCount--;
            checkToolsFinished();
        } else if (type.startsWith("exec_")) {
            var toolName = type.substring(5);
            var outText = stdout.trim();
            var errText = stderr.trim();
            if (!outText && !errText) {
                outText = "(Command completed with no output. If it was a background task, it has been launched successfully.)";
            }
            accumulatedToolResults += "Tool: " + toolName + "\nCommand executed: " + cmd + "\nOutput: " + outText + "\nError: " + errText + "\n\n";
            runningToolsCount--;
            checkToolsFinished();
        }
    }

    function checkToolsFinished() {
        if (runningToolsCount <= 0) {
            var b64 = accumulatedToolImage ? accumulatedToolImage : null;
            sendPrompt(accumulatedToolResults.trim(), true, b64, "multi_tool");
        }
    }

    // ---- Claude Code provider (subscription `claude` CLI, no API key) ----

    function claudeCodeCwd() {
        return Quickshell.env("HOME") || ".";
    }

    // Resolve the `claude` binary without depending on the shell PATH (Quickshell may
    // not inherit ~/.local/bin). If the config value is left at the default "claude",
    // point at the official installer location; a custom value is used verbatim.
    function claudeCodeBinPath() {
        var b = (GlobalConfig.ai.claudeCodeBin || "claude").trim();
        if (b === "" || b === "claude") {
            var home = Quickshell.env("HOME") || "";
            if (home !== "")
                return home + "/.local/bin/claude";
            return "claude";
        }
        return b;
    }

    // ---- Claude accounts (multi-login via CLAUDE_CONFIG_DIR) ----
    // The default ~/.claude login is always present as an implicit "Default" (id "").
    // Additional accounts each get their own config dir under ~/.config/caelestia/claude/<id>.
    function claudeAccounts() {
        var list = [{ "id": "", "name": "Default", "dir": "" }];
        try {
            var parsed = JSON.parse(GlobalConfig.ai.claudeAccountsJson || "[]");
            if (Array.isArray(parsed)) {
                var home = Quickshell.env("HOME") || "";
                for (var i = 0; i < parsed.length; i++) {
                    var a = parsed[i];
                    if (a && a.id)
                        list.push({
                            "id": String(a.id),
                            "name": String(a.name || a.id),
                            "dir": home + "/.config/caelestia/claude/" + String(a.id)
                        });
                }
            }
        } catch (e) {}
        return list;
    }

    function activeClaudeAccountObj() {
        var id = GlobalConfig.ai.activeClaudeAccount || "";
        var list = claudeAccounts();
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i];
        return list[0];
    }

    function activeClaudeConfigDir() {
        return activeClaudeAccountObj().dir || "";
    }

    // Real display names (login email / name) read from each account's .claude.json.
    property var resolvedAccountNames: ({})

    function accountJsonPath(id) {
        var home = Quickshell.env("HOME") || "";
        if (!id || id === "")
            return home + "/.claude.json";
        return home + "/.config/caelestia/claude/" + id + "/.claude.json";
    }

    function accountLabel(id) {
        if (resolvedAccountNames[id])
            return resolvedAccountNames[id];
        var list = claudeAccounts();
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i].name;
        return "Default";
    }

    // One FileView per account resolves its login name from .claude.json.
    Instantiator {
        model: root.claudeAccountIds
        delegate: FileView {
            required property string modelData
            path: root.accountJsonPath(modelData)
            printErrors: false
            watchChanges: false
            onLoaded: {
                try {
                    var d = JSON.parse(text());
                    var oa = d.oauthAccount || {};
                    var nm = oa.displayName || oa.emailAddress || "";
                    if (nm) {
                        var map = root.resolvedAccountNames;
                        map[modelData] = nm;
                        root.resolvedAccountNames = Object.assign({}, map);
                    }
                } catch (e) {}
            }
        }
    }

    readonly property var claudeAccountIds: {
        var l = [];
        var a = claudeAccounts();
        for (var i = 0; i < a.length; i++)
            l.push(a[i].id);
        return l;
    }

    // Env-var line injected into the dynamically-built Process (empty for Default).
    function claudeCodeEnvSnippet() {
        var dir = activeClaudeConfigDir();
        if (dir && dir !== "")
            return "    environment: ({ \"CLAUDE_CONFIG_DIR\": " + JSON.stringify(dir) + " })\n";
        return "";
    }

    function logClaudeCodeStderr(proc, line) {
        if (!line)
            return;
        var t = line.trim();
        if (t === "")
            return;
        proc.errAcc = (proc.errAcc || "") + t + "\n";
        Logger.log("[ClaudeCode] " + t);
    }

    // Heuristic: does this CLI output indicate the Claude account isn't logged in?
    function isClaudeCodeAuthError(text) {
        if (!text)
            return false;
        var t = String(text).toLowerCase();
        return t.indexOf("login") !== -1
            || t.indexOf("log in") !== -1
            || t.indexOf("logged in") !== -1
            || t.indexOf("not authenticated") !== -1
            || t.indexOf("unauthorized") !== -1
            || t.indexOf("authentication") !== -1
            || t.indexOf("oauth") !== -1
            || t.indexOf("invalid api key") !== -1
            || t.indexOf("api key") !== -1
            || t.indexOf("expired") !== -1
            || t.indexOf("sign in") !== -1
            || t.indexOf("credentials") !== -1;
    }

    function claudeCodeAuthHint() {
        return "⚠️ Claude hesabınıza giriş yapılmamış görünüyor.\n\nBir terminal açıp `claude` komutunu çalıştırın ve aboneliğinizle giriş yapın (login), ardından burada tekrar deneyin.";
    }

    // Generate a short chat title via a one-shot `claude -p ... --output-format json`.
    function generateClaudeCodeTitleAsync(chatId, firstMessage) {
        if (!firstMessage)
            return;
        var safeMsg = firstMessage.substring(0, 200);
        var prompt = "Output ONLY a concise 2-4 word title for the following message. No quotes, no trailing punctuation, no explanation.\n\nMessage: " + safeMsg;

        var cmd = [claudeCodeBinPath(), "-p", prompt, "--output-format", "json", "--dangerously-skip-permissions"];
        var commandStr = JSON.stringify(cmd);
        var cwdStr = JSON.stringify(claudeCodeCwd());
        var chatIdStr = JSON.stringify(chatId);
        var qml =
            "import QtQuick\n" +
            "import Quickshell.Io\n" +
            "Process {\n" +
            "    id: tproc\n" +
            "    command: " + commandStr + "\n" +
            "    workingDirectory: " + cwdStr + "\n" +
            claudeCodeEnvSnippet() +
            "    stdout: StdioCollector { onStreamFinished: root.handleClaudeCodeTitle(" + chatIdStr + ", text || \"\", tproc); }\n" +
            "    onExited: code => { if (code !== 0) tproc.destroy(); }\n" +
            "}";
        try {
            var obj = Qt.createQmlObject(qml, root, "claudeCodeTitleProc");
            obj.running = true;
        } catch (e) {
            Logger.log("[AI] claude-code title process error: " + e.message);
        }
    }

    function handleClaudeCodeTitle(chatId, text, proc) {
        try {
            var parsed = JSON.parse(text);
            if (parsed && parsed.result && !parsed.is_error)
                applyGeneratedTitle(chatId, String(parsed.result));
        } catch (e) {}
        if (proc)
            proc.destroy();
    }

    function stopClaudeCode() {
        if (root.currentClaudeCodeProc) {
            try {
                root.currentClaudeCodeProc.running = false;
            } catch (e) {}
            root.currentClaudeCodeProc = null;
        }
    }

    function sendClaudeCode(promptText) {
        // Drop any stale empty assistant placeholder, then add a fresh bubble to stream into.
        for (var i = chatHistory.count - 1; i >= 0; i--) {
            var m = chatHistory.get(i);
            if (!m.isUser && !m.isFinished && m.text === "")
                chatHistory.remove(i);
        }
        chatHistory.append({
            "isUser": false,
            "text": "",
            "isFinished": false,
            "thoughtText": ""
        });
        listView.positionViewAtEnd();

        var bin = claudeCodeBinPath();
        var sid = claudeCodeSessionFor(currentChatId);

        // Fresh session (new chat, or the active account changed) → seed it with the
        // prior transcript so the new account continues the same conversation.
        var promptToSend = promptText;
        if (sid === "") {
            var transcript = claudeCodeTranscript();
            if (transcript !== "")
                promptToSend = transcript;
        }

        var cmd = [bin, "-p", promptToSend, "--output-format", "stream-json", "--verbose", "--include-partial-messages", "--dangerously-skip-permissions"];

        var mdl = GlobalConfig.ai.defaultClaudeCodeModel || "default";
        if (mdl && mdl !== "default") {
            cmd.push("--model");
            cmd.push(mdl);
        }

        var eff = GlobalConfig.ai.claudeCodeEffort || "default";
        if (eff && eff !== "default" && effortLevelsFor(mdl).indexOf(eff) !== -1) {
            cmd.push("--effort");
            cmd.push(eff);
        }

        if (sid !== "") {
            cmd.push("--resume");
            cmd.push(sid);
        }

        var commandStr = JSON.stringify(cmd);
        var cwdStr = JSON.stringify(claudeCodeCwd());
        var processQml =
            "import QtQuick\n" +
            "import Quickshell.Io\n" +
            "Process {\n" +
            "    id: proc\n" +
            "    command: " + commandStr + "\n" +
            "    workingDirectory: " + cwdStr + "\n" +
            claudeCodeEnvSnippet() +
            "    property string acc: \"\"\n" +
            "    property string thought: \"\"\n" +
            "    property string sess: \"\"\n" +
            "    property string errAcc: \"\"\n" +
            "    property bool done: false\n" +
            "    stdout: SplitParser { onRead: line => root.onClaudeCodeLine(proc, line) }\n" +
            "    stderr: SplitParser { onRead: line => root.logClaudeCodeStderr(proc, line) }\n" +
            "    onExited: code => root.onClaudeCodeExit(proc, code)\n" +
            "}";
        try {
            var obj = Qt.createQmlObject(processQml, root, "claudeCodeProc");
            root.currentClaudeCodeProc = obj;
            obj.running = true;
        } catch (e) {
            console.error("CLAUDE CODE PROCESS ERROR: " + e.message);
            chatHistory.setProperty(chatHistory.count - 1, "text", "⚠️ Failed to launch Claude Code: " + e.message);
            chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
            isTyping = false;
            isThinking = false;
            inAgentLoop = false;
            saveHistory();
        }
    }

    function onClaudeCodeLine(proc, line) {
        line = (line || "").trim();
        if (line === "")
            return;

        var evt;
        try {
            evt = JSON.parse(line);
        } catch (e) {
            return; // non-JSON diagnostic output
        }

        if (evt.session_id)
            proc.sess = evt.session_id;

        if (evt.type === "system")
            return;

        // Token-level streaming (when the CLI emits partial messages).
        if (evt.type === "stream_event" && evt.event) {
            var ev = evt.event;
            if (ev.type === "content_block_delta" && ev.delta) {
                if (ev.delta.type === "text_delta") {
                    proc.acc += ev.delta.text || "";
                    if (isThinking) isThinking = false;
                } else if (ev.delta.type === "thinking_delta") {
                    proc.thought += ev.delta.thinking || "";
                }
                root.currentThoughtText = proc.thought.trim();
                chatHistory.setProperty(chatHistory.count - 1, "thoughtText", proc.thought.trim());
                chatHistory.setProperty(chatHistory.count - 1, "text", proc.acc.trim());
                listView.positionViewAtEnd();
            }
            return;
        }

        // Whole assistant messages (also carry tool_use blocks). Used as the fallback
        // when token-level partials aren't emitted, and to surface tool activity.
        if (evt.type === "assistant" && evt.message && evt.message.content) {
            var hasTool = false;
            var textPart = "";
            for (var i = 0; i < evt.message.content.length; i++) {
                var b = evt.message.content[i];
                if (b.type === "tool_use") {
                    hasTool = true;
                    if (b.name)
                        currentActionText = "Running " + b.name + "...";
                } else if (b.type === "text") {
                    textPart += b.text || "";
                }
            }
            if (textPart.trim() !== "" && proc.acc.indexOf(textPart) === -1) {
                proc.acc = (proc.acc ? proc.acc + "\n\n" : "") + textPart;
                if (isThinking) isThinking = false;
                chatHistory.setProperty(chatHistory.count - 1, "text", proc.acc.trim());
                listView.positionViewAtEnd();
            }
            if (hasTool && textPart.trim() === "")
                isThinking = true;
            return;
        }

        if (evt.type === "result") {
            var resText = (evt.result !== undefined && evt.result !== null) ? String(evt.result) : "";
            var errored = (evt.is_error === true) || (evt.subtype && String(evt.subtype).indexOf("error") !== -1);
            if (errored && (isClaudeCodeAuthError(resText) || isClaudeCodeAuthError(proc.errAcc))) {
                proc.acc = claudeCodeAuthHint();
            } else if (proc.acc.trim() === "" && resText !== "") {
                proc.acc = resText;
            }
            finalizeClaudeCode(proc);
            return;
        }
    }

    function finalizeClaudeCode(proc) {
        if (proc.done)
            return;
        proc.done = true;
        var finalText = (proc.acc || "").trim();
        chatHistory.setProperty(chatHistory.count - 1, "text", finalText !== "" ? finalText : "(no output)");
        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
        setClaudeCodeSession(currentChatId, proc.sess);
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        currentActionText = "Thinking...";
        saveHistory();
        listView.positionViewAtEnd();
    }

    function onClaudeCodeExit(proc, code) {
        if (!proc.done) {
            if ((proc.acc || "").trim() === "") {
                if (isClaudeCodeAuthError(proc.errAcc))
                    chatHistory.setProperty(chatHistory.count - 1, "text", claudeCodeAuthHint());
                else if (code !== 0)
                    chatHistory.setProperty(chatHistory.count - 1, "text",
                        "⚠️ Claude Code çalıştırılamadı (çıkış kodu " + code + "). `claude` CLI kurulu ve giriş yapılmış mı? Bir terminalde `claude` çalıştırıp giriş yapmayı deneyin.");
            }
            finalizeClaudeCode(proc);
        }
        if (root.currentClaudeCodeProc === proc)
            root.currentClaudeCodeProc = null;
        proc.destroy();
    }

    property string currentActionText: "Thinking..."

    function fetchOllamaModels() {
        var ollamaUrl = GlobalConfig.ai.ollamaUrl || "http://localhost:11434";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", ollamaUrl + "/api/tags", true);
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var list = [];
                        if (response.models) {
                            for (var i = 0; i < response.models.length; i++) {
                                list.push(response.models[i].name);
                            }
                        }
                        if (list.length > 0) {
                            ollamaModelsList = list;
                            if (list.indexOf(GlobalConfig.ai.defaultOllamaModel) === -1) {
                                GlobalConfig.ai.defaultOllamaModel = list[0];
                            }
                        } else {
                            ollamaModelsList = ["llama3", "mistral", "phi3", "gemma"];
                        }
                    } catch (e) {
                        Logger.log("Error parsing Ollama models: " + e.message);
                        ollamaModelsList = ["llama3", "mistral", "phi3", "gemma"];
                    }
                } else {
                    Logger.log("Ollama tags request failed (status " + xhr.status + ")");
                    ollamaModelsList = ["llama3", "mistral", "phi3", "gemma"];
                }
            }
        };
        xhr.send();
    }

    property var allChatSessions: []

    function createNewChat() {
        typingTimer.stop();
        stopClaudeCode();
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        currentChatId = "chat_" + Date.now();
        chatHistory.clear();
        isHistoryTab = false;
    }

    function loadChat(id) {
        typingTimer.stop();
        stopClaudeCode();
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        currentChatId = id;
        chatHistory.clear();
        var found = false;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                var msgs = allChatSessions[i].messages;
                for (var j = 0; j < msgs.length; j++) {
                    // Strictly sanitize incoming JSON data before ListModel append
                    chatHistory.append({
                        "isUser": msgs[j].isUser === true,
                        "text": msgs[j].text || "",
                        "isFinished": msgs[j].isFinished !== false,
                        "thoughtText": msgs[j].thoughtText || ""
                    });
                }
                found = true;
                break;
            }
        }
        if (!found) createNewChat();
        savedContentY = -1;
        Qt.callLater(function() { listView.positionViewAtEnd(); });
        isHistoryTab = false;
    }

    function loadHistory() {
        allChatSessions = [];
        var jsonStr = GlobalConfig.ai.ollamaHistoryJson;
        if (jsonStr) {
            try {
                var parsed = JSON.parse(jsonStr);
                // Protect against corrupted saves
                if (Array.isArray(parsed)) {
                    allChatSessions = parsed.filter(s => s !== null && s.id);
                }
            } catch (e) {}
        }

        historySessionsModel.clear();
        for (var i = 0; i < allChatSessions.length; i++) {
            // Strictly enforce string values
            historySessionsModel.append({
                "id": allChatSessions[i].id || ("chat_" + Date.now()),
                "title": allChatSessions[i].title || "Chat"
            });
        }

        if (allChatSessions.length > 0) {
            loadChat(allChatSessions[0].id);
        } else {
            createNewChat();
        }
    }

    function saveHistory() {
        var msgs = [];
        for (var i = 0; i < chatHistory.count; i++) {
            var msg = chatHistory.get(i);
            msgs.push({
                "isUser": msg.isUser === true,
                "text": msg.text || "",
                "isFinished": msg.isFinished !== false,
                "thoughtText": msg.thoughtText || ""
            });
        }
        
        if (msgs.length === 0) return;
        
        var found = false;
        for (var j = 0; j < allChatSessions.length; j++) {
            if (allChatSessions[j].id === currentChatId) {
                allChatSessions[j].messages = msgs;
                
                var firstUser = null;
                for (var k = 0; k < msgs.length; k++) {
                    if (msgs[k].isUser) { firstUser = msgs[k]; break; }
                }
                if (msgs.length > 1 && (allChatSessions[j].title === "Legacy Chat" || allChatSessions[j].title === "New Chat" || allChatSessions[j].title.indexOf("New Chat") === 0 || !allChatSessions[j].title)) {
                    if (firstUser) {
                        generateChatTitleAsync(currentChatId, firstUser.text);
                    }
                }
                found = true;
                break;
            }
        }
        
        if (!found) {
            var firstUserMsg = null;
            for (var m = 0; m < msgs.length; m++) {
                if (msgs[m].isUser) { firstUserMsg = msgs[m]; break; }
            }
            
            var initialTitle = "New Chat";
            
            allChatSessions.unshift({
                "id": currentChatId || ("chat_" + Date.now()),
                "title": initialTitle,
                "messages": msgs
            });
            
            historySessionsModel.insert(0, {
                "id": currentChatId || ("chat_" + Date.now()),
                "title": initialTitle
            });
            
            if (firstUserMsg) {
                generateChatTitleAsync(currentChatId, firstUserMsg.text);
            }
        }
        
        GlobalConfig.ai.ollamaHistoryJson = JSON.stringify(allChatSessions);
    }

    function deleteChat(id) {
        var idx = -1;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                idx = i;
                break;
            }
        }
        if (idx !== -1) {
            allChatSessions.splice(idx, 1);
            for (var j = 0; j < historySessionsModel.count; j++) {
                if (historySessionsModel.get(j).id === id) {
                    historySessionsModel.remove(j);
                    break;
                }
            }
            
            GlobalConfig.ai.ollamaHistoryJson = JSON.stringify(allChatSessions);

            if (currentChatId === id) {
                chatHistory.clear();
                if (allChatSessions.length > 0) {
                    loadChat(allChatSessions[0].id);
                } else {
                    createNewChat();
                }
            }
        }
    }

    function clearAllHistory() {
        allChatSessions = [];
        historySessionsModel.clear();
        GlobalConfig.ai.ollamaHistoryJson = "[]";
        createNewChat();
    }

    function applyGeneratedTitle(chatId, raw) {
        if (!raw)
            return;
        var title = raw.trim().replace(/^"|"$/g, '').replace(/\n/g, ' ');
        if (title.length > 40)
            title = title.substring(0, 40) + "...";
        if (title.length > 0)
            updateChatTitle(chatId, title);
    }

    function generateChatTitleAsync(chatId, firstMessage) {
        if (!firstMessage) return;

        if (root.isClaudeCode) {
            root.generateClaudeCodeTitleAsync(chatId, firstMessage);
            return;
        }

        var safeMsg = firstMessage.substring(0, 200);
        var titleSystem = "You are a title generator. Output ONLY a 2-4 word title representing the user's message. NO quotes, NO explanation.";
        var xhr = new XMLHttpRequest();

        if (root.isClaude) {
            if (root.getApiKey() === "")
                return;
            var claudeBase = GlobalConfig.ai.anthropicUrl || "https://api.anthropic.com";
            xhr.open("POST", claudeBase + "/v1/messages", true);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("x-api-key", root.getApiKey());
            xhr.setRequestHeader("anthropic-version", "2023-06-01");
            xhr.setRequestHeader("anthropic-dangerous-direct-browser-access", "true");
            xhr.onreadystatechange = () => {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    try {
                        var parsed = JSON.parse(xhr.responseText);
                        if (parsed.content && parsed.content.length > 0 && parsed.content[0].text)
                            root.applyGeneratedTitle(chatId, parsed.content[0].text);
                    } catch (e) {}
                }
            };
            xhr.send(JSON.stringify({
                model: root.activeModel(),
                max_tokens: 32,
                system: titleSystem,
                messages: [{ role: "user", content: "Message: " + safeMsg + "\nTitle:" }]
            }));
            return;
        }

        var url = (GlobalConfig.ai.ollamaUrl || "http://localhost:11434") + "/api/generate";
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var parsed = JSON.parse(xhr.responseText);
                    if (parsed.response)
                        root.applyGeneratedTitle(chatId, parsed.response);
                } catch (e) {}
            }
        };
        xhr.send(JSON.stringify({
            model: GlobalConfig.ai.defaultOllamaModel || "llama3",
            system: titleSystem,
            prompt: "Message: " + safeMsg + "\nTitle:",
            stream: false
        }));
    }

    function updateChatTitle(chatId, title) {
        if (!title || !chatId) return;
        
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === chatId) {
                allChatSessions[i].title = title;
                
                var inModel = false;
                for (var j = 0; j < historySessionsModel.count; j++) {
                    if (historySessionsModel.get(j).id === chatId) {
                        historySessionsModel.setProperty(j, "title", title);
                        inModel = true;
                        break;
                    }
                }
                
                if (!inModel) {
                    historySessionsModel.insert(0, {
                        "id": chatId || "",
                        "title": title || "New Chat"
                    });
                }
                
                GlobalConfig.ai.ollamaHistoryJson = JSON.stringify(allChatSessions);
                break;
            }
        }
    }

    function addAiMessage(message) {
        chatHistory.append({
            "isUser": false,
            "text": message || "",
            "isFinished": true,
            "thoughtText": ""
        });
        listView.positionViewAtEnd();
        saveHistory();
    }

    function sendPrompt(promptText, isSystemToolResult = false, base64Image = null, toolName = "") {
        if (!promptText.trim() && !base64Image) return;

        // Sending a message dismisses any open prompt suggestions.
        promptSuggestions = [];

        if (!isSystemToolResult) {
            chatHistory.append({
                "isUser": true,
                "text": promptText || "",
                "isFinished": true,
                "thoughtText": ""
            });
            listView.positionViewAtEnd();
            saveHistory();
        }

        if (root.isClaude && root.getApiKey() === "") {
            addAiMessage("⚠️ No Claude API key configured. Set the ANTHROPIC_API_KEY environment variable, or add a key in the AI settings.");
            return;
        }

        isTyping = true;
        isThinking = true;
        inAgentLoop = true;
        currentThoughtText = "";
        isThoughtExpanded = false;
        
        if (isSystemToolResult) {
            if (toolName === "web_search" || toolName === "read_webpage") {
                currentActionText = "Reading results...";
            } else if (toolName === "take_screenshot") {
                currentActionText = "Analyzing screen...";
            } else if (toolName === "get_weather") {
                currentActionText = "Analyzing weather...";
            } else {
                currentActionText = "Thinking...";
            }
        } else {
            currentActionText = "Thinking...";
        }

        // Claude Code (subscription CLI) uses a Process, not XMLHttpRequest.
        if (root.isClaudeCode) {
            root.sendClaudeCode(promptText);
            return;
        }

        var xhr = new XMLHttpRequest();
        root.currentRequest = xhr;

        var model = root.activeModel();
        if (root.isClaude) {
            var claudeBase = GlobalConfig.ai.anthropicUrl || "https://api.anthropic.com";
            xhr.open("POST", claudeBase + "/v1/messages", true);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("x-api-key", root.getApiKey());
            xhr.setRequestHeader("anthropic-version", "2023-06-01");
            // QML's XMLHttpRequest presents a browser-like origin; this header opts into direct access.
            xhr.setRequestHeader("anthropic-dangerous-direct-browser-access", "true");
        } else {
            var ollamaUrl = GlobalConfig.ai.ollamaUrl || "http://localhost:11434";
            xhr.open("POST", ollamaUrl + "/api/chat", true);
            xhr.setRequestHeader("Content-Type", "application/json");
        }
        
        var processedTextLength = 0;
        var accumulatedThoughtText = "";
        var accumulatedContentText = "";
        var rawAccumulatedContentText = "";
        var finalToolCalls = null;
        
        for (var i = chatHistory.count - 1; i >= 0; i--) {
            var m = chatHistory.get(i);
            if (!m.isUser && !m.isFinished && m.text === "") {
                chatHistory.remove(i);
            }
        }
        
        chatHistory.append({
            "isUser": false,
            "text": "",
            "isFinished": false,
            "thoughtText": ""
        });
        
        listView.positionViewAtEnd();
        
        xhr.onreadystatechange = () => {
            if (xhr.readyState === 3 || xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var currentText = xhr.responseText;
                    var unparsed = currentText.substring(processedTextLength);
                    var lines = unparsed.split('\n');
                    
                    var linesToProcess = (xhr.readyState === XMLHttpRequest.DONE) ? lines.length : lines.length - 1;
                    
                    for (var i = 0; i < linesToProcess; i++) {
                        var rawLine = lines[i];
                        var line = rawLine.trim();
                        if (line === "") {
                            processedTextLength += rawLine.length + 1;
                            continue;
                        }

                        var chunkContent = "";
                        var chunkReasoning = "";

                        if (root.isClaude) {
                            // Anthropic streams Server-Sent Events; only "data:" lines carry JSON.
                            if (line.indexOf("event:") === 0) {
                                processedTextLength += rawLine.length + 1;
                                continue;
                            }
                            if (line.indexOf("data:") !== 0) {
                                processedTextLength += rawLine.length + 1;
                                continue;
                            }
                            var jsonStr = line.substring(5).trim();
                            if (jsonStr === "" || jsonStr === "[DONE]") {
                                processedTextLength += rawLine.length + 1;
                                continue;
                            }
                            try {
                                var evt = JSON.parse(jsonStr);
                                processedTextLength += rawLine.length + 1;
                                if (evt.type === "content_block_delta" && evt.delta) {
                                    if (evt.delta.type === "text_delta")
                                        chunkContent = evt.delta.text || "";
                                    else if (evt.delta.type === "thinking_delta")
                                        chunkReasoning = evt.delta.thinking || "";
                                } else if (evt.type === "error") {
                                    Logger.log("[AI] Claude stream error: " + JSON.stringify(evt.error || {}));
                                }
                            } catch (e) {
                                break;
                            }
                        } else {
                            // Ollama streams newline-delimited JSON objects.
                            try {
                                var parsed = JSON.parse(line);
                                processedTextLength += rawLine.length + 1;
                                if (parsed.message) {
                                    chunkReasoning = parsed.message.thinking || parsed.message.reasoning || parsed.message.reasoning_content || "";
                                    chunkContent = parsed.message.content || "";
                                }
                            } catch (e) {
                                break;
                            }
                        }

                        if (chunkReasoning)
                            accumulatedThoughtText += chunkReasoning;
                        if (chunkContent)
                            rawAccumulatedContentText += chunkContent;

                        if (chunkContent === "" && chunkReasoning === "")
                            continue;

                        var displayContent = stripToolCalls(rawAccumulatedContentText);
                        var displayThought = accumulatedThoughtText;

                        if (accumulatedThoughtText === "") {
                            var openThinkIdx = displayContent.indexOf("<think>");
                            var closeThinkIdx = displayContent.indexOf("</think>");

                            if (openThinkIdx !== -1) {
                                if (closeThinkIdx !== -1) {
                                    displayThought = displayContent.substring(openThinkIdx + 7, closeThinkIdx).trim();
                                    displayContent = displayContent.substring(0, openThinkIdx) + displayContent.substring(closeThinkIdx + 8);
                                } else {
                                    displayThought = displayContent.substring(openThinkIdx + 7).trim();
                                    displayContent = displayContent.substring(0, openThinkIdx);
                                }
                            }
                        }

                        root.currentThoughtText = displayThought.trim();

                        if (displayContent.trim() !== "") {
                            if (isThinking) isThinking = false;
                        }

                        chatHistory.setProperty(chatHistory.count - 1, "thoughtText", displayThought.trim());
                        chatHistory.setProperty(chatHistory.count - 1, "text", displayContent.trim());
                        listView.positionViewAtEnd();
                    }
                }
                
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                        saveHistory();
                        
                        var enableTools = GlobalConfig.ai.enableCelestialMode;
                        var textToolCalls = enableTools ? parseTextToolCalls(rawAccumulatedContentText) : [];

                        if (textToolCalls.length > 0) {
                            if (enableTools) {
                                currentActionText = "Using tools...";
                                accumulatedToolResults = "";
                                accumulatedToolImage = "";
                                runningToolsCount = 0;

                                for (var t = 0; t < textToolCalls.length; t++) {
                                    var toolCall = textToolCalls[t];
                                    var toolName = toolCall.name;
                                    var args = toolCall.args || {};

                                    // Count async tools (set_timer and get_weather are synchronous, skip count for them)
                                    if (toolName === "take_screenshot" || toolName === "web_search" || toolName === "read_webpage" || toolName === "open_app" || toolName === "caelestia_command") {
                                        runningToolsCount++;
                                    }

                                    if (toolName === "take_screenshot") {
                                        currentActionText = "Analyzing screen...";
                                        var screenCmd = `spectacle -b -m -n -o ${Paths.runtimeTemp("orion_screenshot.png")}`;
                                        runAgentCommand(screenCmd, "screenshot_take");

                                    } else if (toolName === "web_search") {
                                        currentActionText = "Searching the web...";
                                        var query = String(args.query || "");
                                        var page = args.page || 1;
                                        runAgentCommand(["env", "PYTHONIOENCODING=utf8", "python3", Quickshell.shellDir + "/scripts/orion_search.py", "--mode", "search", "--query", query, "--page", String(page)], "exec_" + toolName);

                                    } else if (toolName === "read_webpage") {
                                        currentActionText = "Reading webpage...";
                                        var url = String(args.url || "");
                                        runAgentCommand(["env", "PYTHONIOENCODING=utf8", "python3", Quickshell.shellDir + "/scripts/orion_search.py", "--mode", "read", "--url", url], "exec_" + toolName);

                                    } else if (toolName === "open_app") {
                                        currentActionText = "Opening app...";
                                        var app = String(args.app_name || "");
                                        var safeApp = shellQuote("Name=.*" + app);
                                        runAgentCommand(["sh", "-c", 'grep -i -m 1 "^Exec=" $(find /usr/share/applications ~/.local/share/applications -name "*.desktop" -exec grep -il "$1" {} + 2>/dev/null) | cut -d "=" -f 2- | sed "s/ %[a-zA-Z]//g" | xargs -I {} sh -c "setsid {} >/dev/null 2>&1 &"', "--", safeApp], "exec_" + toolName);

                                    } else if (toolName === "set_timer") {
                                        currentActionText = "Setting timer...";
                                        var secs = Number(args.seconds) || 5;
                                        var msg = String(args.message || "Timer finished");
                                        var timerQml = "import QtQuick; Timer { interval: " + (secs * 1000) + "; running: true; onTriggered: { root.runAgentCommand(['notify-send', 'Orion Timer', " + JSON.stringify(msg) + "], 'timer_trigger'); destroy(); } }";
                                        Qt.createQmlObject(timerQml, root, "timer_" + Date.now());
                                        accumulatedToolResults += "Tool: set_timer\nResult: Timer set for " + secs + " seconds with message: " + msg + "\n\n";

                                    } else if (toolName === "get_weather") {
                                        currentActionText = "Checking weather...";
                                        var weatherStr = Weather.city + ": " + Weather.temp + " (" + Weather.description + "). Humidity: " + Weather.humidity + "%, Wind: " + Weather.windSpeed + " km/h";
                                        accumulatedToolResults += "Tool: get_weather\nResult: Local weather from system dashboard: " + weatherStr + "\n\n";

                                    } else if (toolName === "caelestia_command") {
                                        currentActionText = "Running caelestia...";
                                        var subcmd = String(args.subcommand || "");
                                        var subargs = String(args.args || "").trim();
                                        var cmdArr = ["caelestia", subcmd];
                                        if (subargs) cmdArr = cmdArr.concat(subargs.split(/\s+/));
                                        runAgentCommand(cmdArr, "exec_" + toolName);

                                    } else {
                                        Logger.log("[AI] Unknown tool: " + toolName);
                                        runningToolsCount--; // don't block on unknown tools
                                    }
                                }

                                // set_timer is synchronous — check if all async tools are already done
                                if (runningToolsCount === 0) {
                                    if (accumulatedToolResults !== "") {
                                        checkToolsFinished();
                                    } else {
                                        currentActionText = "Thinking...";
                                        isTyping = false;
                                        isThinking = false;
                                        inAgentLoop = false;
                                    }
                                }
                            } else {
                                currentActionText = "Thinking...";
                                isTyping = false;
                                isThinking = false;
                                inAgentLoop = false;
                            }
                        } else {
                            currentActionText = "Thinking...";
                            isTyping = false;
                            isThinking = false;
                            inAgentLoop = false;
                        }
                    } else {
                        var providerName = root.isClaude ? "Claude" : "Ollama";
                        var errMsg = (xhr.status === 0) ? "Generation cancelled" : (providerName + " request failed (status " + xhr.status + ")." + ((root.isClaude && xhr.status === 401) ? " Check your API key." : ""));
                        var currentText = chatHistory.get(chatHistory.count - 1).text;
                        if (currentText.trim() === "") {
                            chatHistory.setProperty(chatHistory.count - 1, "text", errMsg);
                        } else {
                            chatHistory.setProperty(chatHistory.count - 1, "text", currentText + "\n\n*[" + errMsg + "]*");
                        }
                        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                        isTyping = false;
                        isThinking = false;
                        inAgentLoop = false;
                        saveHistory();
                    }
                }
            }
        };

        var enableTools = GlobalConfig.ai.enableCelestialMode;
        var sysPrompt = "You are a helpful AI assistant integrated into the user's desktop OS shell (Caelestia, running on KDE Plasma/Wayland).";
        if (enableTools) {
            sysPrompt += "\n\nYou have access to the following tools. To call a tool, output a <tool_call> block containing ONLY valid JSON. Do not output any text inside the block other than the JSON object.\n\nFORMAT:\n<tool_call>\n{\"name\": \"TOOL_NAME\", \"args\": {ARGUMENTS}}\n</tool_call>\n\nAVAILABLE TOOLS:\n- take_screenshot: Captures the user's screen for visual analysis. Args: none.\n  Example: <tool_call>\n{\"name\": \"take_screenshot\", \"args\": {}}\n</tool_call>\n\n- web_search: Searches the web. Args: query (string, required), page (number, optional).\n  Example: <tool_call>\n{\"name\": \"web_search\", \"args\": {\"query\": \"latest news\"}}\n</tool_call>\n\n- read_webpage: Fetches and reads the text of a URL. Args: url (string, required).\n  Example: <tool_call>\n{\"name\": \"read_webpage\", \"args\": {\"url\": \"https://example.com\"}}\n</tool_call>\n\n- open_app: Launches an installed desktop application. Args: app_name (string, required).\n  Example: <tool_call>\n{\"name\": \"open_app\", \"args\": {\"app_name\": \"dolphin\"}}\n</tool_call>\n\n- set_timer: Sets a countdown timer that fires a desktop notification. Args: seconds (number, required), message (string, required).\n  Example: <tool_call>\n{\"name\": \"set_timer\", \"args\": {\"seconds\": 300, \"message\": \"Break time!\"}}\n</tool_call>\n\n- get_weather: Gets the current local weather from the system dashboard. Args: none.\n  Example: <tool_call>\n{\"name\": \"get_weather\", \"args\": {}}\n</tool_call>\n\n- caelestia_command: Runs a caelestia CLI command. Valid subcommands: shell, toggle, scheme, search, screenshot, record, clipboard, emoji, wallpaper, resizer, install, update. Args: subcommand (string, required), args (string, optional extra flags).\n  Example: <tool_call>\n{\"name\": \"caelestia_command\", \"args\": {\"subcommand\": \"wallpaper\", \"args\": \"--random\"}}\n</tool_call>\n\nCRITICAL RULES:\n1. ALWAYS use a <tool_call> block to call a tool. NEVER pretend to perform actions in plain text.\n2. You may output a brief acknowledgment before the <tool_call> block (e.g. 'Opening Dolphin for you!') but you MUST include the block.\n3. You can include multiple <tool_call> blocks in one response.\n4. After receiving tool results, respond naturally to the user based on what the tool returned.";
        }
        
        var requestBody;
        if (root.isClaude) {
            // Anthropic Messages API: system prompt is a top-level field; messages must
            // carry non-empty content and cannot include the streaming placeholder.
            var claudeMessages = [];
            for (var i = 0; i < chatHistory.count; i++) {
                var msg = chatHistory.get(i);
                if (!msg.isUser && !msg.isFinished && (msg.text || "") === "")
                    continue;
                if ((msg.text || "") === "")
                    continue;
                claudeMessages.push({
                    "role": msg.isUser ? "user" : "assistant",
                    "content": msg.text
                });
            }

            if (isSystemToolResult) {
                var claudeContent;
                if (base64Image) {
                    claudeContent = [
                        { "type": "text", "text": promptText },
                        { "type": "image", "source": { "type": "base64", "media_type": "image/jpeg", "data": base64Image } }
                    ];
                } else {
                    claudeContent = promptText;
                }
                claudeMessages.push({ "role": "user", "content": claudeContent });
            }

            requestBody = {
                "model": model,
                "max_tokens": 4096,
                "system": sysPrompt,
                "messages": claudeMessages,
                "stream": true
            };
        } else {
            var messages = [];
            messages.push({
                "role": "system",
                "content": sysPrompt
            });

            for (var j = 0; j < chatHistory.count; j++) {
                var m = chatHistory.get(j);
                messages.push({
                    "role": m.isUser ? "user" : "assistant",
                    "content": m.text || ""
                });
            }

            if (isSystemToolResult) {
                var toolMsg = {
                    "role": "user",
                    "content": promptText
                };
                if (base64Image) {
                    toolMsg["images"] = [base64Image];
                }
                messages.push(toolMsg);
            }

            // Native tool-calling API removed; using text-based <tool_call> parsing instead,
            // which is compatible with all models including llama3, mistral, phi, etc.
            requestBody = {
                "model": model,
                "messages": messages,
                "stream": true
            };
        }

        xhr.send(JSON.stringify(requestBody));
    }

    Item {
        id: mainWrapper
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium

         // Mode Switcher Row (Chat / History)
         RowLayout {
             id: modeSwitcherRow
             anchors.top: parent.top
             anchors.left: parent.left
             anchors.right: parent.right
             anchors.rightMargin: 0
             z: 10
             spacing: Tokens.spacing.small

             StyledRect {
                 id: modeSwitcherBg
                 implicitWidth: modeRow.width
                 implicitHeight: 32
                 radius: Tokens.rounding.full
                 color: Colours.tPalette.m3surfaceContainer

                 StyledClippingRect {
                     z: -1
                     anchors.fill: parent
                     radius: Tokens.rounding.full
                     ShaderEffectSource {
                         id: switcherBlurSource
                         sourceItem: contentStack
                         sourceRect: {
                             var p = parent.mapToItem(contentStack, 0, 0);
                             return Qt.rect(p.x, p.y, parent.width, parent.height);
                         }
                     }
                     MultiEffect {
                         anchors.fill: parent
                         source: switcherBlurSource
                         blurEnabled: true
                         blurMax: 32
                     }
                 }

                 StyledRect {
                     width: isHistoryTab ? historyTab.width : chatTab.width
                     height: parent.height
                     radius: Tokens.rounding.full
                     color: Colours.palette.m3primary
                     x: isHistoryTab ? historyTab.x : chatTab.x
                     
                     Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                     Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                 }

                 Row {
                     id: modeRow
                     height: parent.height

                     Item {
                         id: chatTab
                         height: parent.height
                         width: !isHistoryTab ? 40 : chatContent.implicitWidth + Tokens.padding.medium * 2
                         

                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                         StateLayer {
                             radius: Tokens.rounding.full
                             onClicked: isHistoryTab = false
                         }

                         Row {
                             id: chatContent
                             anchors.centerIn: parent
                             spacing: Tokens.spacing.small
                             MaterialIcon {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "chat"
                                 color: !isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }
                             Text {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "Chat"
                                 color: !isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.body.small
                                 visible: isHistoryTab
                             }
                         }
                     }

                     Item {
                         id: historyTab
                         height: parent.height
                         width: isHistoryTab ? 40 : historyContent.implicitWidth + Tokens.padding.medium * 2
                         

                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                         StateLayer {
                             radius: Tokens.rounding.full
                             onClicked: isHistoryTab = true
                         }

                         Row {
                             id: historyContent
                             anchors.centerIn: parent
                             spacing: Tokens.spacing.small
                             MaterialIcon {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "history"
                                 color: isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }
                             Text {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "History"
                                 color: isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.body.small
                                 visible: !isHistoryTab
                             }
                         }
                     }
                 }
             }

         }

         // Provider + model (+ account) selectors on their own row; a Flow so the
         // pills wrap to a second line instead of overflowing a narrow sidebar.
         Flow {
             id: selectorRow
             anchors.top: modeSwitcherRow.bottom
             anchors.left: parent.left
             anchors.right: parent.right
             anchors.topMargin: Tokens.spacing.small
             z: 10
             spacing: Tokens.spacing.small

             // Provider Selector Split Button (Ollama / Claude Code)
             SplitButton {
                 id: providerSelector
                 type: SplitButton.Tonal
                 verticalPadding: 4
                 visible: root.providerList.length > 1
                 Layout.preferredWidth: implicitWidth

                 active: menuItems.find(m => m.modelData === root.provider) ?? menuItems[0] ?? null
                 menu.onItemSelected: item => {
                     GlobalConfig.ai.defaultProvider = item.modelData;
                 }

                 menuItems: providerVariants.instances

                 fallbackIcon: "cloud"
                 fallbackText: qsTr("Provider")
                 stateLayer.disabled: true

                 Variants {
                     id: providerVariants
                     model: root.providerList

                     delegate: MenuItem {
                         required property string modelData
                         text: root.providerLabel(modelData)
                     }
                 }
             }

             // Model Selector Split Button
             SplitButton {
                 id: modelSelector
                 type: SplitButton.Tonal
                 verticalPadding: 4
                 Layout.preferredWidth: implicitWidth

                 active: menuItems.find(m => m.modelData === root.activeModel()) ?? menuItems[0] ?? null
                 menu.onItemSelected: item => {
                     if (root.isClaudeCode) {
                         GlobalConfig.ai.defaultClaudeCodeModel = item.modelData;
                         // Effort levels differ per model — reset to default on model change.
                         GlobalConfig.ai.claudeCodeEffort = "default";
                     } else if (root.isClaude)
                         GlobalConfig.ai.defaultClaudeModel = item.modelData;
                     else
                         GlobalConfig.ai.defaultOllamaModel = item.modelData;
                 }

                 menuItems: modelVariants.instances

                 fallbackIcon: "smart_toy"
                 fallbackText: qsTr("Select Model")
                 stateLayer.disabled: true

                 Variants {
                     id: modelVariants
                     model: {
                         if (root.isClaudeCode)
                             return root.claudeCodeModelsList;
                         if (root.isClaude)
                             return root.claudeModelsList;
                         return root.ollamaModelsList && root.ollamaModelsList.length > 0 ? root.ollamaModelsList : ["llama3", "mistral", "phi3", "gemma"];
                     }

                     delegate: MenuItem {
                         required property string modelData
                         text: modelData
                     }
                 }
             }

             // Effort / thinking-level Selector (Claude Code).
             SplitButton {
                 id: effortSelector
                 type: SplitButton.Tonal
                 verticalPadding: 4
                 visible: root.isClaudeCode && root.claudeCodeEffortOptions.length > 0

                 active: menuItems.find(m => m.modelData === (GlobalConfig.ai.claudeCodeEffort || "default")) ?? menuItems[0] ?? null
                 menu.onItemSelected: item => {
                     GlobalConfig.ai.claudeCodeEffort = item.modelData;
                 }

                 menuItems: effortVariants.instances

                 fallbackIcon: "neurology"
                 fallbackText: qsTr("Effort")
                 stateLayer.disabled: true

                 Variants {
                     id: effortVariants
                     model: root.claudeCodeEffortOptions

                     delegate: MenuItem {
                         required property string modelData
                         text: modelData
                     }
                 }
             }

             // Account Selector (Claude Code multi-login) — only when >1 account exists.
             SplitButton {
                 id: accountSelector
                 type: SplitButton.Tonal
                 verticalPadding: 4
                 visible: root.isClaudeCode && root.claudeAccountIds.length > 1

                 active: menuItems.find(m => m.modelData === (GlobalConfig.ai.activeClaudeAccount || "")) ?? menuItems[0] ?? null
                 menu.onItemSelected: item => {
                     GlobalConfig.ai.activeClaudeAccount = item.modelData;
                 }

                 menuItems: accountVariants.instances

                 fallbackIcon: "person"
                 fallbackText: qsTr("Account")
                 stateLayer.disabled: true

                 Variants {
                     id: accountVariants
                     model: root.claudeAccountIds

                     delegate: MenuItem {
                         required property string modelData
                         text: root.accountLabel(modelData)
                     }
                 }
             }


         }
         
         Item {
             id: contentStack
             anchors.top: selectorRow.bottom
             anchors.bottom: parent.bottom
             anchors.left: parent.left
             anchors.right: parent.right
             anchors.topMargin: Tokens.spacing.medium

             // Chat View
             Item {
                 anchors.fill: parent
                 opacity: !isHistoryTab ? 1 : 0
                 visible: opacity > 0
                 Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                 VerticalFadeListView {
                     id: listView
                     anchors.top: parent.top
                     anchors.bottom: inputBoxRow.top
                     anchors.left: parent.left
                     anchors.right: parent.right
                     anchors.bottomMargin: Tokens.spacing.medium
                     spacing: Tokens.spacing.medium
                     model: chatHistory
                     boundsBehavior: Flickable.StopAtBounds
                     
                     ColumnLayout {
                         anchors.centerIn: parent
                         opacity: chatHistory.count === 0 && !isTyping && !isThinking ? 1.0 : 0.0
                         visible: opacity > 0
                         Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                         spacing: Tokens.spacing.large

                         Item {
                             Layout.alignment: Qt.AlignHCenter
                             implicitWidth: 72
                             implicitHeight: 72

                             Logo {
                                 id: emptyStateLogo
                                 anchors.fill: parent
                                 visible: false // hide original for MultiEffect to take over
                             }

                             MultiEffect {
                                 anchors.fill: parent
                                 source: emptyStateLogo
                                 colorization: 1.0
                                 colorizationColor: Colours.palette.m3primary
                             }
                         }

                         StyledText {
                             id: greetingText
                             Layout.alignment: Qt.AlignHCenter
                             Layout.maximumWidth: listView.width - (Tokens.padding.large * 2)
                             horizontalAlignment: Text.AlignHCenter
                             wrapMode: Text.Wrap
                             font: Tokens.font.title.medium
                             color: Colours.palette.m3onSurfaceVariant

                             property var phrases: [
                                 "Ask away, %1!",
                                 "How can I help you today, %1?",
                                 "What's on your mind, %1?",
                                 "Ready when you are, %1!",
                                 "Let's get started, %1.",
                                 "What shall we explore today, %1?",
                                 "I'm all ears, %1!"
                             ]

                             Component.onCompleted: {
                                 var user = Quickshell.env("USER") || "user";
                                 var userCapitalized = user.charAt(0).toUpperCase() + user.slice(1);
                                 var phrase = phrases[Math.floor(Math.random() * phrases.length)];
                                 text = phrase.replace("%1", userCapitalized);
                             }
                         }
                     }

                     ScrollBar.vertical: StyledScrollBar {
                         flickable: listView
                     }

                     footer: Item {
                         width: listView.width
                         height: isThinking ? bubbleBg.height + Tokens.spacing.medium : 0
                         visible: opacity > 0
                         opacity: isThinking ? 1 : 0
                         
                         Behavior on height { Anim { type: Anim.DefaultSpatial } }
                         Behavior on opacity { Anim { type: Anim.DefaultSpatial } }

                         StyledRect {
                             id: bubbleBg
                             y: Tokens.spacing.medium / 2
                             width: Math.min(listView.width * 0.85, footerCol.implicitWidth + Tokens.padding.medium * 2 + 8)
                             height: footerCol.implicitHeight + Tokens.padding.medium * 2
                             radius: Tokens.rounding.large
                             color: Colours.tPalette.m3surfaceContainer

                             // Asymmetric corners
                             topLeftRadius: Tokens.rounding.large
                             topRightRadius: Tokens.rounding.large
                             bottomLeftRadius: 4
                             bottomRightRadius: Tokens.rounding.large

                             Column {
                                 id: footerCol
                                 anchors.fill: parent
                                 anchors.margins: Tokens.padding.medium
                                 spacing: Tokens.spacing.small
                                 
                                 Row {
                                     spacing: Tokens.spacing.small
                                     
                                     LoadingIndicator {
                                         width: 20
                                         height: 20
                                         color: Colours.palette.m3primary
                                     }
                                     
                                     // M3 Expressive Animated Text Wrapper
                                     Item {
                                         width: mainText.implicitWidth
                                         height: mainText.implicitHeight
                                         // The bubble smoothly expands/shrinks as the text width changes
                                         Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                         
                                         StyledText {
                                             id: mainText
                                             text: displayedText
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.body.small
                                             
                                             property string displayedText: root.currentActionText
                                             property string nextText: ""

                                             transform: Translate { id: textTrans; y: 0 }
                                             opacity: 1.0

                                             Connections {
                                                 target: root
                                                 function onCurrentActionTextChanged() {
                                                     if (root.currentActionText !== mainText.displayedText) {
                                                         mainText.nextText = root.currentActionText;
                                                         switchAnim.restart();
                                                     }
                                                 }
                                             }

                                             SequentialAnimation {
                                                 id: switchAnim
                                                 ParallelAnimation {
                                                     NumberAnimation { target: textTrans; property: "y"; to: -8; duration: 150; easing.type: Easing.InCubic }
                                                     NumberAnimation { target: mainText; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
                                                 }
                                                 PropertyAction { target: mainText; property: "displayedText"; value: mainText.nextText }
                                                 PropertyAction { target: textTrans; property: "y"; value: 8 }
                                                 ParallelAnimation {
                                                     NumberAnimation { target: textTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                                     NumberAnimation { target: mainText; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
                                                 }
                                             }

                                             SequentialAnimation {
                                                 running: isThinking && !switchAnim.running
                                                 loops: Animation.Infinite
                                                 NumberAnimation { target: mainText; property: "opacity"; from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                                 NumberAnimation { target: mainText; property: "opacity"; from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                             }
                                         }
                                     }
                                     
                                     Item {
                                         visible: root.currentThoughtText !== ""
                                         width: Tokens.spacing.medium
                                         height: 1
                                     }
                                     
                                     Item {
                                         visible: root.currentThoughtText !== ""
                                         width: thoughtRowFooter.implicitWidth
                                         height: thoughtRowFooter.implicitHeight
                                         Row {
                                             id: thoughtRowFooter
                                             spacing: Tokens.spacing.small
                                             MaterialIcon {
                                                 text: "expand_more"
                                                 color: Colours.palette.m3onSurfaceVariant
                                                 font: Tokens.font.icon.small
                                                 rotation: root.isThoughtExpanded ? 180 : 0
                                                 Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                             }
                                         }
                                         MouseArea {
                                             anchors.fill: parent
                                             anchors.margins: -10
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: root.isThoughtExpanded = !root.isThoughtExpanded
                                         }
                                     }
                                 }
                                 Item {
                                     id: footerThoughtContentWrapper
                                     width: footerThoughtContent.width
                                     height: root.isThoughtExpanded ? footerThoughtContent.implicitHeight : 0
                                     clip: true
                                     
                                     Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                                     TextEdit {
                                         id: footerThoughtContent
                                         width: Math.min(implicitWidth, listView.width * 0.85 - Tokens.padding.medium * 2)
                                         textFormat: Text.MarkdownText
                                         text: root.currentThoughtText
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.body.small
                                         wrapMode: Text.Wrap
                                         readOnly: true
                                         selectByMouse: true
                                         selectionColor: Colours.palette.m3primary
                                         selectedTextColor: Colours.palette.m3onPrimary
                                         opacity: root.isThoughtExpanded ? 1.0 : 0.0
                                         
                                         Behavior on opacity {
                                             SequentialAnimation {
                                                 PauseAnimation { duration: root.isThoughtExpanded ? 100 : 0 }
                                                 NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                             }
                                         }
                                     }
                                 }
                             }
                         }
                     }

                     delegate: Item {
                         id: delegateItem

                         required property string text
                         required property bool isUser
                         required property bool isFinished
                         required property string thoughtText

                         width: listView.width - Tokens.padding.large
                         visible: (!delegateItem.isFinished && isThinking) ? false : (delegateItem.text !== "" || delegateItem.thoughtText !== "")
                         height: visible ? bubbleRect.height : 0
                         
                         scale: 0.0
                         opacity: 0.0
                         
                         Component.onCompleted: {
                             popInAnim.start();
                         }
                         
                         ParallelAnimation {
                             id: popInAnim
                             NumberAnimation { target: delegateItem; property: "scale"; from: 0.8; to: 1.0; duration: 300; easing.type: Easing.OutBack }
                             NumberAnimation { target: delegateItem; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
                         }
                         
                         SequentialAnimation {
                             id: popDoneAnim
                             NumberAnimation { target: delegateItem; property: "scale"; from: 1.0; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                             NumberAnimation { target: delegateItem; property: "scale"; from: 1.02; to: 1.0; duration: 150; easing.type: Easing.OutSine }
                         }
                         
                         onIsFinishedChanged: {
                             if (isFinished) popDoneAnim.start();
                         }

                         StyledRect {
                             id: bubbleRect
                             readonly property real maxBubbleWidth: delegateItem.width * 0.85
                             anchors.right: delegateItem.isUser ? parent.right : undefined
                             anchors.left: delegateItem.isUser ? undefined : parent.left
                             
                             // Let implicitWidth dictate width (with +8 buffer for layout engine) to stop short words from splitting line breaks
                             width: Math.min(maxBubbleWidth, bubbleLayout.implicitWidth + Tokens.padding.medium * 2 + 8)
                             height: bubbleLayout.implicitHeight + Tokens.padding.medium * 2
                             radius: Tokens.rounding.large
                             color: delegateItem.isUser ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer

                             // Asymmetric corners
                             topLeftRadius: Tokens.rounding.large
                             topRightRadius: Tokens.rounding.large
                             bottomLeftRadius: delegateItem.isUser ? Tokens.rounding.large : 4
                             bottomRightRadius: delegateItem.isUser ? 4 : Tokens.rounding.large
                             
                             Column {
                                 id: bubbleLayout
                                 anchors.top: parent.top
                                 anchors.left: parent.left
                                 anchors.margins: Tokens.padding.medium
                                 spacing: Tokens.spacing.small

                                 property string delegateThought: delegateItem.thoughtText
                                 property bool isExpanded: false

                                 Item {
                                     visible: bubbleLayout.delegateThought !== ""
                                     implicitWidth: thoughtRow.implicitWidth
                                     implicitHeight: thoughtRow.implicitHeight
                                     height: visible ? implicitHeight : 0

                                     Row {
                                         id: thoughtRow
                                         spacing: Tokens.spacing.small
                                         Text {
                                             text: "Thought Process"
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.body.small
                                         }
                                         MaterialIcon {
                                             id: thoughtArrow
                                             text: "expand_more"
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.icon.small
                                             rotation: bubbleLayout.isExpanded ? 180 : 0
                                             Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                         }
                                     }
                                     MouseArea {
                                         anchors.fill: parent
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: bubbleLayout.isExpanded = !bubbleLayout.isExpanded
                                     }
                                 }

                                 Item {
                                     id: thoughtContentWrapper
                                     width: thoughtContent.width
                                     height: bubbleLayout.isExpanded ? thoughtContent.implicitHeight : 0
                                     clip: true
                                     
                                     Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                                     TextEdit {
                                         id: thoughtContent
                                         width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)
                                         textFormat: Text.MarkdownText
                                         
                                         property string fullThought: bubbleLayout.delegateThought
                                         
                                         property bool cursorVisible: true
                                         Timer {
                                             running: !delegateItem.isFinished
                                             repeat: true
                                             interval: 400
                                             onTriggered: thoughtContent.cursorVisible = !thoughtContent.cursorVisible
                                         }
                                         
                                         text: delegateItem.isFinished ? fullThought : fullThought + (cursorVisible ? "▌" : "")
                                         
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.body.small
                                         wrapMode: Text.Wrap
                                         readOnly: true
                                         selectByMouse: true
                                         selectionColor: Colours.palette.m3primary
                                         selectedTextColor: Colours.palette.m3onPrimary
                                         opacity: bubbleLayout.isExpanded ? 1.0 : 0.0
                                         
                                         Behavior on opacity {
                                             SequentialAnimation {
                                                 PauseAnimation { duration: bubbleLayout.isExpanded ? 100 : 0 }
                                                 NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                             }
                                         }
                                     }
                                 }

                                 TextEdit {
                                     id: messageText
                                     textFormat: Text.MarkdownText
                                     width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)
                                     
                                     property string fullText: delegateItem.text !== undefined ? delegateItem.text : ""
                                     
                                     property bool cursorVisible: true
                                     Timer {
                                         running: !delegateItem.isFinished
                                         repeat: true
                                         interval: 400
                                         onTriggered: messageText.cursorVisible = !messageText.cursorVisible
                                     }
                                     
                                     text: delegateItem.isFinished ? fullText : fullText + (cursorVisible ? "▌" : "")
                                     
                                     color: delegateItem.isUser ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                     font: Tokens.font.body.small
                                     wrapMode: Text.Wrap
                                     readOnly: true
                                     selectByMouse: true
                                     selectionColor: Colours.palette.m3primary
                                     selectedTextColor: Colours.palette.m3onPrimary

                                     MouseArea {
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.IBeamCursor
                                         propagateComposedEvents: true
                                         onPressed: mouse => mouse.accepted = false
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // Scroll to bottom button
                 Item {
                     id: scrollBtnWrapper
                     anchors.bottom: inputBoxRow.top
                     anchors.bottomMargin: Tokens.spacing.large
                     anchors.right: parent.right
                     anchors.rightMargin: Tokens.padding.large
                     width: 36
                     height: 36
                     z: 20
                     opacity: (!listView.atYEnd && chatHistory.count > 0) ? 1.0 : 0.0
                     visible: opacity > 0
                     Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                     StyledRect {
                         id: scrollBtnBg
                         anchors.fill: parent
                         radius: 18
                         color: Colours.tPalette.m3surfaceContainerHigh
                     }

                     MultiEffect {
                         anchors.fill: scrollBtnBg
                         source: scrollBtnBg
                         shadowEnabled: true
                         shadowOpacity: 0.3
                         shadowBlur: 0.5
                         shadowVerticalOffset: 2
                     }

                     MaterialIcon {
                         anchors.centerIn: parent
                         text: "arrow_downward"
                         font: Tokens.font.icon.small
                         color: Colours.palette.m3onSurface
                     }

                     MouseArea {
                         anchors.fill: parent
                         cursorShape: Qt.PointingHandCursor
                         onClicked: listView.positionViewAtEnd()
                     }
                 }

                 // Prompt suggestion chips (Claude Code) — float just above the input.
                 ColumnLayout {
                     id: suggestionBox
                     anchors.bottom: inputBoxRow.top
                     anchors.bottomMargin: Tokens.spacing.small
                     anchors.left: parent.left
                     anchors.right: parent.right
                     z: 11
                     spacing: Tokens.spacing.small
                     visible: root.isClaudeCode && root.promptSuggestions.length > 0

                     // Header with a close button.
                     RowLayout {
                         Layout.fillWidth: true
                         spacing: Tokens.spacing.small

                         StyledText {
                             Layout.fillWidth: true
                             text: qsTr("Suggestions")
                             color: Colours.palette.m3onSurfaceVariant
                             font: Tokens.font.label.small
                         }

                         Item {
                             Layout.preferredWidth: 24
                             Layout.preferredHeight: 24

                             MaterialIcon {
                                 anchors.centerIn: parent
                                 text: "close"
                                 color: closeSugMouse.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }

                             MouseArea {
                                 id: closeSugMouse
                                 anchors.fill: parent
                                 hoverEnabled: true
                                 cursorShape: Qt.PointingHandCursor
                                 onClicked: root.promptSuggestions = []
                             }
                         }
                     }

                     Repeater {
                         model: root.promptSuggestions

                         StyledRect {
                             required property string modelData
                             Layout.fillWidth: true
                             implicitHeight: sugChipText.implicitHeight + Tokens.padding.medium * 2
                             radius: Tokens.rounding.large
                             color: Colours.tPalette.m3surfaceContainerHigh

                             StateLayer {
                                 radius: Tokens.rounding.large
                                 onClicked: {
                                     inputArea.text = modelData;
                                     root.promptSuggestions = [];
                                     inputArea.forceActiveFocus();
                                 }
                             }

                             StyledText {
                                 id: sugChipText
                                 anchors.left: parent.left
                                 anchors.right: parent.right
                                 anchors.top: parent.top
                                 anchors.leftMargin: Tokens.padding.medium
                                 anchors.rightMargin: Tokens.padding.medium
                                 anchors.topMargin: Tokens.padding.medium
                                 text: parent.modelData
                                 color: Colours.palette.m3onSurface
                                 font: Tokens.font.body.small
                                 wrapMode: Text.Wrap
                             }
                         }
                     }
                 }

                 // Input Box Row
                 StyledRect {
                     id: inputBoxRow
                     anchors.bottom: parent.bottom
                     anchors.left: parent.left
                     anchors.right: parent.right
                     z: 10
                     implicitHeight: Math.max(48, inputArea.implicitHeight + Tokens.padding.medium * 2)
                     color: Colours.tPalette.m3surfaceContainer
                     radius: 24

                     StyledClippingRect {
                         z: -1
                         anchors.fill: parent
                         radius: 24
                         ShaderEffectSource {
                             id: inputBlurSource
                             sourceItem: contentStack
                             sourceRect: {
                                 var p = parent.mapToItem(contentStack, 0, 0);
                                 return Qt.rect(p.x, p.y, parent.width, parent.height);
                             }
                         }
                         MultiEffect {
                             anchors.fill: parent
                             source: inputBlurSource
                             blurEnabled: true
                             blurMax: 32
                         }
                     }

                     StateLayer {
                         id: inputStateLayer
                         anchors.fill: parent
                         radius: 24
                         hoverEnabled: false
                         cursorShape: Qt.IBeamCursor
                         onClicked: inputArea.forceActiveFocus()
                     }

                     RowLayout {
                         anchors.fill: parent
                         anchors.leftMargin: Tokens.padding.large
                         anchors.rightMargin: Tokens.padding.small
                         spacing: Tokens.spacing.small

                         ScrollView {
                             id: inputScroll
                             Layout.fillWidth: true
                             Layout.fillHeight: true
                             
                             TextArea {
                                 id: inputArea
                                 verticalAlignment: TextInput.AlignVCenter
                                 placeholderText: qsTr("Ask assistant...")
                                 color: Colours.palette.m3onSurface
                                 placeholderTextColor: Colours.palette.m3outline
                                 font: Tokens.font.body.small
                                 wrapMode: Text.Wrap
                                 selectByMouse: true
                                 background: null

                                 MouseArea {
                                     anchors.fill: parent
                                     hoverEnabled: true
                                     cursorShape: Qt.IBeamCursor
                                     propagateComposedEvents: true
                                     onPressed: mouse => {
                                          var mapped = mapToItem(inputStateLayer, mouse.x, mouse.y);
                                          inputStateLayer.press(mapped.x, mapped.y);
                                          mouse.accepted = false;
                                      }
                                 }

                                 Keys.onPressed: event => {
                                     if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                         event.accepted = true;
                                         root.sendPrompt(inputArea.text);
                                         inputArea.clear();
                                     }
                                 }
                             }
                         }

                         // Prompt suggestions trigger (Claude Code).
                         Item {
                             visible: root.isClaudeCode
                             Layout.preferredWidth: visible ? 32 : 0
                             Layout.preferredHeight: 32

                             MaterialIcon {
                                 anchors.centerIn: parent
                                 text: root.loadingSuggestions ? "hourglass_empty" : "lightbulb"
                                 color: sugMouse.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }

                             MouseArea {
                                 id: sugMouse
                                 anchors.fill: parent
                                 hoverEnabled: true
                                 cursorShape: Qt.PointingHandCursor
                                 onClicked: root.fetchPromptSuggestions()
                             }
                         }

                         Item {
                             Layout.preferredWidth: 36
                             Layout.preferredHeight: 36

                             MaterialShape {
                                 anchors.fill: parent
                                 color: root.isTyping ? Colours.palette.m3error : (inputArea.text.length > 0 ? Colours.palette.m3primary : Colours.layer(Colours.tPalette.m3surfaceContainerHigh, 2))
                                 shape: root.isTyping ? MaterialShape.Cookie4Sided : (inputArea.text.length > 0 ? MaterialShape.Arrow : MaterialShape.Circle)
                                 scale: (inputArea.text.length === 0 && !root.isTyping) ? 1 : sendMouse.pressed ? 0.6 : sendMouse.containsMouse ? 0.8 : 0.7
                                 rotation: 0
                                 
                                 Behavior on scale { Anim { type: Anim.FastSpatial } }
                                 Behavior on color { CAnim {} }

                                 MouseArea {
                                     id: sendMouse
                                     anchors.fill: parent
                                     hoverEnabled: true
                                     cursorShape: (inputArea.text.length > 0 || root.isTyping) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                     onClicked: {
                                         if (root.isTyping) {
                                             if (root.currentRequest) {
                                                 root.currentRequest.abort();
                                             }
                                             root.stopClaudeCode();
                                             root.isTyping = false;
                                             root.isThinking = false;
                                             root.inAgentLoop = false;
                                             typingTimer.stop();
                                             chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                                             saveHistory();
                                         } else if (inputArea.text.length > 0) {
                                             root.sendPrompt(inputArea.text);
                                             inputArea.clear();
                                         }
                                     }
                                 }
                             }

                             MaterialIcon {
                                 anchors.centerIn: parent
                                 text: "arrow_upward"
                                 color: Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                                 opacity: (inputArea.text.length > 0 || root.isTyping) ? 0 : 1
                                 Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                             }
                         }
                     }
                 }
             }

             // History Grid View
             Item {
                 anchors.fill: parent
                 opacity: isHistoryTab ? 1 : 0
                 visible: opacity > 0
                 Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                 GridView {
                     anchors.top: parent.top
                     anchors.left: parent.left
                     anchors.right: parent.right
                     anchors.bottom: newChatButton.top
                     anchors.bottomMargin: Tokens.spacing.medium
                     
                     cellWidth: width / 2
                     cellHeight: 90
                     model: historySessionsModel

                     delegate: Item {
                         required property var model
                         property string chatId: model && model.id ? String(model.id) : ""
                         property string chatTitle: model && model.title ? String(model.title) : ""

                         width: GridView.view.cellWidth
                         height: GridView.view.cellHeight

                         StyledRect {
                             anchors.fill: parent
                             anchors.margins: Tokens.spacing.small
                             radius: Tokens.rounding.medium
                             color: Colours.tPalette.m3surfaceContainerHigh

                             StateLayer {
                                 radius: Tokens.rounding.medium
                                 onClicked: loadChat(chatId)
                             }

                             RowLayout {
                                 anchors.fill: parent
                                 anchors.margins: Tokens.padding.small
                                 spacing: Tokens.spacing.medium

                                 StyledRect {
                                     Layout.preferredWidth: 32
                                     Layout.preferredHeight: 32
                                     radius: 16
                                     color: Colours.tPalette.m3surfaceContainerHighest

                                     MaterialIcon {
                                         anchors.centerIn: parent
                                         text: "chat"
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.icon.small
                                     }
                                 }

                                 ColumnLayout {
                                     Layout.fillWidth: true
                                     spacing: 0

                                     Text {
                                         Layout.fillWidth: true
                                         Layout.alignment: Qt.AlignVCenter
                                         text: chatTitle ? chatTitle : "New Chat"
                                         color: Colours.palette.m3onSurface
                                         font: Tokens.font.label.small
                                         elide: Text.ElideRight
                                          wrapMode: Text.Wrap
                                          maximumLineCount: 3
                                     }
                                 }

                                 Item {
                                     Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                     Layout.preferredWidth: 24
                                     Layout.preferredHeight: 24
                                     
                                     StyledRect {
                                         anchors.fill: parent
                                         radius: 12
                                         color: Colours.palette.m3onSurfaceVariant
                                         opacity: deleteMouseArea.containsMouse ? 0.12 : 0.0
                                         Behavior on opacity { NumberAnimation { duration: 150 } }
                                     }

                                     MaterialIcon {
                                         anchors.centerIn: parent
                                         text: "close"
                                         font: Tokens.font.icon.small
                                         color: Colours.palette.m3onSurfaceVariant
                                     }

                                     MouseArea {
                                         id: deleteMouseArea
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: deleteChat(chatId)
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // "Clear All" button
                 StyledRect {
                     id: clearAllButton
                     anchors.bottom: parent.bottom
                     anchors.left: parent.left
                     width: clearAllLayout.implicitWidth + Tokens.padding.large * 2
                     height: 32
                     radius: 16
                     color: Colours.palette.m3errorContainer

                     StateLayer {
                         radius: 16
                         onClicked: clearAllHistory()
                     }

                     RowLayout {
                         id: clearAllLayout
                         anchors.centerIn: parent
                         spacing: Tokens.spacing.small
                         MaterialIcon {
                             text: "delete"
                             color: Colours.palette.m3onErrorContainer
                             font: Tokens.font.icon.small
                         }
                         Text {
                             text: "Clear All"
                             color: Colours.palette.m3onErrorContainer
                             font: Tokens.font.body.small
                         }
                     }
                 }

                 // "New Chat" button
                 StyledRect {
                     id: newChatButton
                     anchors.bottom: parent.bottom
                     anchors.right: parent.right
                     width: newChatLayout.implicitWidth + Tokens.padding.large * 2
                     height: 32
                     radius: 16
                     color: Colours.palette.m3primaryContainer

                     StateLayer {
                         radius: 16
                         onClicked: createNewChat()
                     }

                     RowLayout {
                         id: newChatLayout
                         anchors.centerIn: parent
                         spacing: Tokens.spacing.small
                         MaterialIcon {
                             text: "add"
                             color: Colours.palette.m3onPrimaryContainer
                             font: Tokens.font.icon.small
                         }
                         Text {
                             text: "New Chat"
                             color: Colours.palette.m3onPrimaryContainer
                             font: Tokens.font.body.small
                         }
                     }
                 }
             }
         }
    }
}