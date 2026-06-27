import sys
import os

filepath = '/home/dim/.config/quickshell/caelestia/modules/sidebar/AiAssistant.qml'
with open(filepath, 'r') as f:
    lines = f.readlines()

def replace_lines(start, end, replacement_str):
    global lines
    replacement_lines = [l + '\n' for l in replacement_str.split('\n')]
    if replacement_lines[-1] == '\n':
        replacement_lines.pop()
    lines = lines[:start-1] + replacement_lines + lines[end:]

# 1. Add currentActionText
replace_lines(93, 93, '    readonly property string currentModel: {\n        if (isCelestial) return GlobalConfig.ai.orionModel;\n        if (activeProvider === "ollama") return activeOllamaModel;\n        return "";\n    }\n    property string currentActionText: "Thinking..."\n')

# 2. Modify addAiMessage
replace_lines(253, 260, '''    function addAiMessage(message) {
        chatHistory.append({
            "isUser": false,
            "text": message,
            "isFinished": true
        });
        listView.positionViewAtEnd();
        saveHistory();
    }''')

# 3. Modify sendPrompt chatHistory.append
replace_lines(266, 269, '''            chatHistory.append({
                "isUser": true,
                "text": promptText,
                "isFinished": true
            });''')

# 4. Add currentActionText init
replace_lines(275, 275, '        inAgentLoop = true;\n        currentActionText = "Thinking...";')

# 5. XHR progress and readystatechange
replace_lines(366, 423, '''            var parsedLength = 0;
            var accumulatedText = "";
            var toolCalls = null;
            
            xhr.onprogress = () => {
                var chunk = xhr.responseText.substring(parsedLength);
                var lines = chunk.split("\\n");
                
                for (var i = 0; i < lines.length - 1; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    parsedLength += lines[i].length + 1;
                    try {
                        var parsed = JSON.parse(line);
                        if (parsed.message && parsed.message.content) {
                            accumulatedText += parsed.message.content;
                        }
                        if (parsed.message && parsed.message.tool_calls) {
                            toolCalls = parsed.message.tool_calls;
                        }
                    } catch (e) {}
                }
                
                var lastIdx = chatHistory.count - 1;
                if (lastIdx >= 0) {
                    chatHistory.setProperty(lastIdx, "text", accumulatedText);
                }
            };

            xhr.onreadystatechange = () => {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var chunk = xhr.responseText.substring(parsedLength);
                            var lines = chunk.split("\\n");
                            for (var i = 0; i < lines.length; i++) {
                                var line = lines[i].trim();
                                if (!line) continue;
                                try {
                                    var parsed = JSON.parse(line);
                                    if (parsed.message && parsed.message.content) {
                                        accumulatedText += parsed.message.content;
                                    }
                                    if (parsed.message && parsed.message.tool_calls) {
                                        toolCalls = parsed.message.tool_calls;
                                    }
                                } catch (e) {}
                            }
                            
                            var lastIdx = chatHistory.count - 1;
                            if (lastIdx >= 0) {
                                chatHistory.setProperty(lastIdx, "text", accumulatedText);
                                chatHistory.setProperty(lastIdx, "isFinished", true);
                                saveHistory();
                            }

                            if (isCelestial && toolCalls && toolCalls.length > 0) {
                                currentActionText = "Using tool...";
                                var tool = toolCalls[0].function;
                                var toolName = tool.name;
                                var args = tool.arguments;
                                
                                if (toolName === "take_screenshot") {
                                    currentActionText = "Analyzing screen...";
                                    var screenCmd = 'grim -g "$(hyprctl monitors -j | jq -r \\'.[] | select(.focused) | "\\\\(.x),\\\\(.y) \\\\(.width)x\\\\(.height)"\\')" /tmp/orion_screenshot.png';
                                    runAgentCommand(screenCmd, "screenshot_take");
                                } else if (toolName === "web_search") {
                                    currentActionText = "Searching the web...";
                                    var query = args.query;
                                    var page = args.page || 1;
                                    runAgentCommand('python3 ~/.config/quickshell/caelestia/scripts/orion_search.py --mode search --query "' + query.replace(/"/g, '\\\\"') + '" --page ' + page, "exec");
                                } else if (toolName === "read_webpage") {
                                    currentActionText = "Reading webpage...";
                                    var url = args.url;
                                    runAgentCommand('python3 ~/.config/quickshell/caelestia/scripts/orion_search.py --mode read --url "' + url.replace(/"/g, '\\\\"') + '"', "exec");
                                } else if (toolName === "open_app") {
                                    currentActionText = "Opening app...";
                                    var app = args.app_name;
                                    runAgentCommand('grep -i -m 1 "^Exec=" $(find /usr/share/applications ~/.local/share/applications -name "*.desktop" -exec grep -il "Name=.*' + app.replace(/"/g, '\\\\"') + '" {} \\\\;) | cut -d "=" -f 2- | sed "s/ %[a-zA-Z]//g" | xargs -I {} sh -c "{} & disown"', "exec");
                                } else if (toolName === "set_timer") {
                                    currentActionText = "Setting timer...";
                                    var secs = args.seconds;
                                    var msg = args.message;
                                    runAgentCommand('sleep ' + secs + ' && notify-send "Orion Timer" "' + msg.replace(/"/g, '\\\\"') + '" & disown', "exec");
                                } else if (toolName === "get_weather") {
                                    currentActionText = "Checking weather...";
                                    var loc = args.location;
                                    runAgentCommand('curl -s "wttr.in/' + loc.replace(/"/g, '\\\\"') + '?0T"', "exec");
                                } else {
                                    currentActionText = "Thinking...";
                                    isTyping = false;
                                    inAgentLoop = false;
                                }
                            } else {
                                currentActionText = "Thinking...";
                                isTyping = false;
                                inAgentLoop = false;
                            }
                        } catch (e) {
                            addAiMessage("Error parsing Ollama response: " + e.message);
                            isTyping = false;
                            inAgentLoop = false;
                        }
                    } else {
                        addAiMessage("Ollama request failed (status " + xhr.status + ").");
                        isTyping = false;
                        inAgentLoop = false;
                    }
                }
            };''')

# 6. Stream: true and tools
replace_lines(452, 526, '''            var requestBody = {
                "model": ollamaModel,
                "messages": messages,
                "stream": true
            };
            if (isCelestial) {
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
                    }
                ];
            }
            
            chatHistory.append({
                "isUser": false,
                "text": "",
                "isFinished": false
            });
            listView.positionViewAtEnd();
            
            xhr.send(JSON.stringify(requestBody));''')

with open(filepath, 'w') as f:
    f.writelines(lines)
