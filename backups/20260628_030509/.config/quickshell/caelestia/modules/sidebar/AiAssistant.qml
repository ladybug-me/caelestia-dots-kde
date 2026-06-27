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
    
    onVisibleChanged: {
        if (visible) {
            fetchOllamaModels();
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
        loadHistory();
    }

    property var ollamaModelsList: []
    property bool isTyping: false
    property bool isThinking: false
    property string currentThoughtText: ""
    property bool isThoughtExpanded: false
    onIsTypingChanged: {
        if (isTyping) listView.positionViewAtEnd();
    }
    property bool inAgentLoop: false

    function runAgentCommand(cmd, type) {
        var processQml = "import QtQuick\n" +
                         "import Quickshell.Io\n" +
                         "Process {\n" +
                         "    id: proc\n" +
                         "    command: [\"sh\", \"-c\", " + JSON.stringify(cmd) + "]\n" +
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
        var obj = Qt.createQmlObject(processQml, root, "agentProcess");
        obj.running = true;
    }

    property int runningToolsCount: 0
    property string accumulatedToolResults: ""
    property string accumulatedToolImage: ""

    function handleAgentProcessResult(type, stdout, stderr, cmd) {
        if (type === "screenshot_take") {
            var convertCmd = "magick /tmp/orion_screenshot.png -resize '1024x1024>' -quality 85 /tmp/orion_screenshot.jpg && base64 /tmp/orion_screenshot.jpg";
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
                        console.log("Error parsing Ollama models: " + e.message);
                        ollamaModelsList = ["llama3", "mistral", "phi3", "gemma"];
                    }
                } else {
                    console.log("Ollama tags request failed (status " + xhr.status + ")");
                    ollamaModelsList = ["llama3", "mistral", "phi3", "gemma"];
                }
            }
        };
        xhr.send();
    }

    property var allChatSessions: []

    function createNewChat() {
        typingTimer.stop();
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        currentChatId = "chat_" + Date.now();
        chatHistory.clear();
        isHistoryTab = false;
    }

    function loadChat(id) {
        typingTimer.stop();
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

    function generateChatTitleAsync(chatId, firstMessage) {
        if (!firstMessage) return;
        
        var xhr = new XMLHttpRequest();
        var url = (GlobalConfig.ai.ollamaUrl || "http://localhost:11434") + "/api/generate";
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var parsed = JSON.parse(xhr.responseText);
                    if (parsed.response) {
                        var title = parsed.response.trim().replace(/^"|"$/g, '').replace(/\n/g, ' ');
                        if (title.length > 40) title = title.substring(0, 40) + "...";
                        if (title.length > 0) {
                            updateChatTitle(chatId, title);
                        }
                        return;
                    }
                } catch (e) {}
            }
        };
        
        var safeMsg = firstMessage.substring(0, 200);
        xhr.send(JSON.stringify({
            model: GlobalConfig.ai.defaultOllamaModel || "llama3",
            system: "You are a title generator. Output ONLY a 2-4 word title representing the user's message. NO quotes, NO explanation.",
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
        var xhr = new XMLHttpRequest();
        root.currentRequest = xhr;

        var ollamaModel = GlobalConfig.ai.defaultOllamaModel || "llama3";
        var ollamaUrl = GlobalConfig.ai.ollamaUrl || "http://localhost:11434";
        var url = ollamaUrl + "/api/chat";
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        
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
                        var line = lines[i].trim();
                        if (line === "") {
                            processedTextLength += lines[i].length + 1;
                            continue;
                        }
                        
                        try {
                            var parsed = JSON.parse(line);
                            processedTextLength += lines[i].length + 1;
                            
                            if (parsed.message) {
                                var chunkReasoning = parsed.message.thinking || parsed.message.reasoning || parsed.message.reasoning_content || "";
                                if (chunkReasoning) {
                                    accumulatedThoughtText += chunkReasoning;
                                }
                                
                                var chunkContent = parsed.message.content || "";
                                if (chunkContent) {
                                    rawAccumulatedContentText += chunkContent;
                                }
                                
                                var displayContent = rawAccumulatedContentText;
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
                                
                                if (parsed.message.tool_calls) {
                                    finalToolCalls = parsed.message.tool_calls;
                                }
                            }
                        } catch (e) {
                            break;
                        }
                    }
                }
                
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                        saveHistory();
                        
                        if (finalToolCalls && finalToolCalls.length > 0) {
                            var enableTools = GlobalConfig.ai.enableCelestialMode;
                            if (enableTools) {
                                currentActionText = "Using tools...";
                                accumulatedToolResults = "";
                                accumulatedToolImage = "";
                                runningToolsCount = 0;
                                
                                for (var t = 0; t < finalToolCalls.length; t++) {
                                    var tool = finalToolCalls[t].function;
                                    var toolName = tool.name;
                                    var args = tool.arguments;
                                    
                                    if (toolName === "take_screenshot" || toolName === "web_search" || toolName === "read_webpage" || toolName === "open_app" || toolName === "get_weather" || toolName === "caelestia_command") {
                                        runningToolsCount++;
                                    }
                                    
                                    if (toolName === "take_screenshot") {
                                        currentActionText = "Analyzing screen...";
                                        var screenCmd = 'grim -g "$(hyprctl monitors -j | jq -r \'.[] | select(.focused) | "\\(.x),\\(.y) \\(.width)x\\(.height)"\')" /tmp/orion_screenshot.png';
                                        runAgentCommand(screenCmd, "screenshot_take");
                                    } else if (toolName === "web_search") {
                                        currentActionText = "Searching the web...";
                                        var query = args.query;
                                        var page = args.page || 1;
                                        runAgentCommand('PYTHONIOENCODING=utf8 python3 ~/.config/quickshell/caelestia/scripts/orion_search.py --mode search --query "' + query.replace(new RegExp("\"", "g"), '\"') + '" --page ' + page, "exec_" + toolName);
                                    } else if (toolName === "read_webpage") {
                                        currentActionText = "Reading webpage...";
                                        var url = args.url;
                                        runAgentCommand('PYTHONIOENCODING=utf8 python3 ~/.config/quickshell/caelestia/scripts/orion_search.py --mode read --url "' + url.replace(new RegExp("\"", "g"), '\"') + '"', "exec_" + toolName);
                                    } else if (toolName === "open_app") {
                                        currentActionText = "Opening app...";
                                        var app = args.app_name;
                                        runAgentCommand('grep -i -m 1 "^Exec=" $(find /usr/share/applications ~/.local/share/applications -name "*.desktop" -exec grep -il "Name=.*' + app.replace(new RegExp("\"", "g"), '\"') + '" {} \;) | cut -d "=" -f 2- | sed "s/ %[a-zA-Z]//g" | xargs -I {} sh -c "{} & disown"', "exec_" + toolName);
                                    } else if (toolName === "set_timer") {
                                        currentActionText = "Setting timer...";
                                        var secs = args.seconds || 5;
                                        var msg = args.message || "Timer finished";
                                        var safeMsg = msg.replace(new RegExp("\"", "g"), '\"');
                                        var timerQml = "import QtQuick; Timer { interval: " + (secs * 1000) + "; running: true; onTriggered: { root.runAgentCommand('notify-send \"Orion Timer\" \"" + safeMsg + "\"', \"timer_trigger\"); destroy(); } }";
                                        Qt.createQmlObject(timerQml, root, "timer_" + Date.now());
                                        accumulatedToolResults += "Tool: set_timer\nResult: Timer successfully set for " + secs + " seconds in the background.\n\n";
                                    } else if (toolName === "get_weather") {
                                        currentActionText = "Checking weather...";
                                        var loc = args.location;
                                        runAgentCommand('curl -s "wttr.in/' + loc.replace(new RegExp("\"", "g"), '\"') + '?0T"', "exec_" + toolName);
                                    } else if (toolName === "caelestia_command") {
                                        currentActionText = "Running caelestia...";
                                        var subcmd = args.subcommand || "";
                                        var subargs = args.args || "";
                                        var cmd = "caelestia " + subcmd;
                                        if (subargs) cmd += " " + subargs;
                                        runAgentCommand(cmd, "exec_" + toolName);
                                    }
                                }
                                
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
                        var errMsg = (xhr.status === 0) ? "Generation cancelled" : "Ollama request failed (status " + xhr.status + ").";
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

        var messages = [];
        var enableTools = GlobalConfig.ai.enableCelestialMode;
        var sysPrompt = "You are a helpful AI assistant integrated into the user's OS. You can use tools to assist the user.";
        if (enableTools) {
            sysPrompt += "\nCRITICAL RULES:\n1. You ARE integrated into the OS. NEVER say you don't have access to visual information. Call the take_screenshot tool if asked to look at the screen.\n2. You CAN browse the web using the web_search tool.\n3. DO NOT apologize for errors, simply explain what happened.\n4. When using tools, you don't need to explain that you are using a tool, just do it and respond to the user smoothly.";
        }
        
        messages.push({
            "role": "system",
            "content": sysPrompt
        });

        for (var i = 0; i < chatHistory.count; i++) {
            var msg = chatHistory.get(i);
            messages.push({
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text || ""
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

        var requestBody = {
            "model": ollamaModel,
            "messages": messages,
            "stream": true
        };
        
        if (enableTools) {
            requestBody["tools"] = [
                {
                    "type": "function",
                    "function": {
                        "name": "take_screenshot",
                        "description": "Takes a screenshot of the user's screen and provides it to you for visual analysis.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Searches the web using a headless Firefox browser. Returns the top 5 results with snippets and URLs.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "The search query" },
                                "page": { "type": "number", "description": "The page number to fetch (1-indexed, default is 1)" }
                            },
                            "required": ["query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_webpage",
                        "description": "Navigates to a specific URL and returns the main text content of the page.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": { "type": "string", "description": "The absolute URL to read" }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_app",
                        "description": "Searches for and launches an application installed on the user's system via its .desktop file.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app_name": { "type": "string", "description": "The name of the app to launch (e.g. firefox, kitty)" }
                            },
                            "required": ["app_name"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_timer",
                        "description": "Sets a timer that will trigger a desktop notification when finished.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "number", "description": "Duration in seconds" },
                                "message": { "type": "string", "description": "Notification message" }
                            },
                            "required": ["seconds", "message"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "description": "Gets the current weather for a specific location.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "location": { "type": "string", "description": "City name" }
                            },
                            "required": ["location"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "caelestia_command",
                        "description": "Execute a caelestia CLI command to manage the system. Valid subcommands: shell, toggle, scheme, search, screenshot, record, clipboard, emoji, wallpaper, resizer, install, update.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "subcommand": { "type": "string", "description": "The subcommand to run (e.g., scheme, wallpaper, toggle, record)" },
                                "args": { "type": "string", "description": "Additional arguments to pass to the subcommand" }
                            },
                            "required": ["subcommand"]
                        }
                    }
                }
            ];
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

             Item { Layout.fillWidth: true } // Spacer pushes Model Selector to the right

             // Model Selector Split Button
             SplitButton {
                 id: modelSelector
                 type: SplitButton.Tonal
                 verticalPadding: 4
                 Layout.preferredWidth: implicitWidth

                 active: menuItems.find(m => m.modelData === GlobalConfig.ai.defaultOllamaModel) ?? menuItems[0] ?? null
                 menu.onItemSelected: item => {
                     GlobalConfig.ai.defaultOllamaModel = item.modelData;
                 }

                 menuItems: modelVariants.instances

                 fallbackIcon: "smart_toy"
                 fallbackText: qsTr("Select Model")
                 stateLayer.disabled: true

                 Variants {
                     id: modelVariants
                     model: {
                         return root.ollamaModelsList && root.ollamaModelsList.length > 0 ? root.ollamaModelsList : ["llama3", "mistral", "phi3", "gemma"];
                     }

                     delegate: MenuItem {
                         required property string modelData
                         text: modelData
                     }
                 }
             }


         }
         
         Item {
             id: contentStack
             anchors.top: modeSwitcherRow.bottom
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