import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.utils
import qs.services

Item {
    id: root
    
    // Smoothly animated theme color
    property color activeColor: isInverted ? Colours.palette.m3inverseOnSurface : Colours.palette.m3onSurface
    property color bgColor: isInverted ? Colours.palette.m3inverseSurface : "transparent"
    Behavior on activeColor { CAnim { duration: 500 } }
    Behavior on bgColor { CAnim { duration: 500 } }
    
    // Game variables
    property bool isPlaying: false
    property bool isGameOver: false
    property real gameSpeed: 6.0
    property real score: 0
    property real highScore: 0
    property bool isDucking: false
    property bool isInverted: false
    
    property bool _previousDnd: false
    
    // Dino Physics
    property real dinoY: 0
    property real dinoVelocityY: 0
    property real gravity: 0.8
    property real duckGravity: 1.5
    property real jumpForce: -13.0
    
    // Obstacles
    property var obstacles: []
    property real obstacleTimer: 0
    
    // Environment
    property var clouds: []
    property real cloudTimer: 0
    property real groundX: 0
    
    // Animation
    property int frameCount: 0
    
    implicitWidth: Math.max(250, parent.width * 0.8)
    implicitHeight: 200
    clip: true
    focus: true
    
    Process {
        id: readScore
        command: ["cat", Paths.config + "/dino_highscore.txt"]
        stdout: StdioCollector {
            id: scoreCollector
            onStreamFinished: {
                var val = parseFloat(scoreCollector.text.trim());
                if (!isNaN(val)) root.highScore = val;
            }
        }
    }
    
    Process {
        id: writeScore
        property string scoreStr: "0"
        command: ["sh", "-c", "mkdir -p " + Paths.config + " && echo '" + scoreStr + "' > " + Paths.config + "/dino_highscore.txt"]
    }
    
    Component.onCompleted: readScore.running = true
    
    function startGame() {
        if (isGameOver) {
            score = 0;
            obstacles = [];
            clouds = [];
            groundX = 0;
            gameSpeed = 6.0;
            frameCount = 0;
            isInverted = false;
        }
        _previousDnd = Notifs.dnd;
        if (!Notifs.dnd) Notifs.dnd = true;
        
        isPlaying = true;
        isGameOver = false;
        dinoY = 0;
        dinoVelocityY = 0;
        gameLoop.start();
    }
    
    function gameOver() {
        isPlaying = false;
        isGameOver = true;
        gameLoop.stop();
        if (!_previousDnd) Notifs.dnd = false;
        
        if (score > highScore) {
            highScore = score;
            writeScore.scoreStr = Math.floor(highScore).toString();
            writeScore.running = true;
        }
    }
    
    function jump() {
        if (dinoY === 0 && isPlaying) {
            dinoVelocityY = jumpForce;
        } else if (!isPlaying) {
            startGame();
        }
    }
    
    Shortcut {
        sequence: "Space"
        onActivated: {
            root.forceActiveFocus();
            root.jump();
        }
    }
    Shortcut {
        sequence: "Up"
        onActivated: {
            root.forceActiveFocus();
            root.jump();
        }
    }
    
    Keys.onDownPressed: (event) => {
        if (event.isAutoRepeat) return;
        if (root.isPlaying) root.isDucking = true;
    }
    
    Keys.onReleased: (event) => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Down) root.isDucking = false;
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            root.jump()
        }
    }
    
    // Background Block for Day/Night Cycle
    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        z: -1
    }
    
    // Scrolling Authentic Ground
    Item {
        visible: root.isPlaying || root.isGameOver
        width: parent.width
        height: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        clip: true
        
        Image {
            x: -root.groundX
            width: 2400
            height: 24
            source: Paths.absolutePath("root:/assets/dino_ground.png")
            fillMode: Image.PreserveAspectFit
            
            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                brightness: 1
            }
        }
        
        Image {
            x: 2400 - root.groundX
            width: 2400
            height: 24
            source: Paths.absolutePath("root:/assets/dino_ground.png")
            fillMode: Image.PreserveAspectFit
            
            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                brightness: 1
            }
        }
    }
    
    // Static Scene (when not playing)
    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.isPlaying && !root.isGameOver
        spacing: Tokens.spacing.extraLarge
        
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 250
            height: 109.375

            Image {
                anchors.centerIn: parent
                width: 250
                height: 109.375
                source: Paths.absolutePath("root:/assets/dino.png")
                fillMode: Image.PreserveAspectFit
                opacity: Visibilities.isCaelestiaMode ? 0 : 1
                Behavior on opacity { Anim { type: Anim.Standard } }

                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    brightness: 1
                }
            }

            Item {
                anchors.centerIn: parent
                width: 250
                height: 109.375
                opacity: Visibilities.isCaelestiaMode ? 1 : 0
                Behavior on opacity { Anim { type: Anim.Standard } }

                Item {
                    anchors.fill: parent
                    clip: true

                    Image {
                        x: 0
                        y: 86
                        width: 250
                        height: 24
                        source: Paths.absolutePath("root:/assets/dino_ground.png")
                        fillMode: Image.Pad
                        horizontalAlignment: Image.AlignLeft
                        verticalAlignment: Image.AlignTop

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: root.activeColor
                            brightness: 1
                        }
                    }

                    Image {
                        x: 130
                        y: 20
                        width: 46
                        height: 13.5
                        source: Paths.absolutePath("root:/assets/dino_cloud.png")
                        fillMode: Image.PreserveAspectFit

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: root.activeColor
                            brightness: 1
                        }
                    }
                    
                    Image {
                        x: 40
                        y: 40
                        width: 46
                        height: 13.5
                        source: Paths.absolutePath("root:/assets/dino_cloud.png")
                        fillMode: Image.PreserveAspectFit

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: root.activeColor
                            brightness: 1
                        }
                    }

                    Image {
                        x: 10
                        y: 43
                        width: 55
                        height: 47
                        source: Paths.absolutePath("root:/assets/kurukuru_stand.png")
                        fillMode: Image.PreserveAspectFit
                    }

                    Image {
                        x: 195
                        y: 44
                        width: 25
                        height: 50
                        source: Paths.absolutePath("root:/assets/cactus_large.png")
                        fillMode: Image.PreserveAspectFit

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: root.activeColor
                            sourceColor: "white"
                        }
                    }
                }
            }
        }
        
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("All up to date!")
            color: root.activeColor
            font: Tokens.font.headline.builders.small.width(90).build()
        }
    }
    
    // Dynamic Scene (when playing)
    Item {
        anchors.fill: parent
        visible: root.isPlaying || root.isGameOver
        
        // Parallax Clouds
        Repeater {
            model: root.clouds
            Image {
                x: modelData.x
                y: modelData.y
                width: 92
                height: 27
                source: Paths.absolutePath("root:/assets/dino_cloud.png")
                fillMode: Image.PreserveAspectFit
                
                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    brightness: 1
                }
            }
        }
        
        // Dino
        Image {
            id: dino
            width: root.isDucking ? 59 : 44
            height: root.isDucking ? 30 : 47
            source: {
                var prefix = Visibilities.isCaelestiaMode ? "kurukuru" : "dino";
                if (root.isGameOver) return Paths.absolutePath("root:/assets/" + prefix + (Visibilities.isCaelestiaMode ? "_stand.png" : "_crash.png"));
                if (root.dinoY < 0) return Paths.absolutePath("root:/assets/" + prefix + "_stand.png");
                if (root.isDucking) return Math.floor(root.frameCount / 5) % 2 === 0 ? Paths.absolutePath("root:/assets/" + prefix + "_duck1.png") : Paths.absolutePath("root:/assets/" + prefix + "_duck2.png");
                return Math.floor(root.frameCount / 5) % 2 === 0 ? Paths.absolutePath("root:/assets/" + prefix + "_run1.png") : Paths.absolutePath("root:/assets/" + prefix + "_run2.png");
            }
            x: 30
            y: parent.height - 30 - height + root.dinoY
            
            layer.enabled: !Visibilities.isCaelestiaMode
            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                sourceColor: "white"
            }
        }
        
        // Score
        StyledText {
            text: "HI " + ("00000" + Math.floor(root.highScore)).slice(-5) + "  " + ("00000" + Math.floor(root.score)).slice(-5)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            font: Tokens.font.label.large
            color: root.activeColor
            Component.onCompleted: font.features = {"tnum": 1}
        }
        
        // Obstacles renderer
        Repeater {
            model: root.obstacles
            Image {
                width: modelData.width
                height: modelData.height
                source: {
                    if (modelData.type === "bird") return Math.floor(root.frameCount / 7) % 2 === 0 ? Paths.absolutePath("root:/assets/bird_1.png") : Paths.absolutePath("root:/assets/bird_2.png");
                    return modelData.type === "small" ? Paths.absolutePath("root:/assets/cactus_small.png") : Paths.absolutePath("root:/assets/cactus_large.png");
                }
                x: modelData.x
                y: parent.height - 30 - height - (modelData.yOffset || 0)
                
                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    sourceColor: "white"
                }
            }
        }
    }
    
    // Game Over Text
    StyledText {
        visible: root.isGameOver && Math.floor(root.score) < 99999
        text: "G A M E   O V E R\nClick to restart"
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        font: Tokens.font.title.large
        color: root.activeColor
    }
    
    // Win Text
    StyledText {
        visible: root.isGameOver && Math.floor(root.score) >= 99999
        text: "Y O U   W I N !\nNow go touch grass"
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        font: Tokens.font.title.large
        color: root.activeColor
    }
    
    Timer {
        id: gameLoop
        interval: 16
        repeat: true
        onTriggered: {
            root.dinoVelocityY += (root.isDucking ? root.duckGravity : root.gravity);
            root.dinoY += root.dinoVelocityY;
            if (root.dinoY > 0) {
                root.dinoY = 0;
                root.dinoVelocityY = 0;
            }
            
            root.frameCount++;
            root.score += 0.15;
            
            // Environment Simulation
            root.groundX = (root.groundX + root.gameSpeed) % 2400;
            
            var newClouds = [];
            for (var c = 0; c < root.clouds.length; c++) {
                var cloud = root.clouds[c];
                cloud.x -= root.gameSpeed * 0.25;
                if (cloud.x + 92 > 0) newClouds.push(cloud);
            }
            root.clouds = newClouds;
            
            root.cloudTimer++;
            if (root.cloudTimer > 150 + Math.random() * 200) {
                root.cloudTimer = 0;
                root.clouds.push({ x: root.width, y: 10 + Math.random() * 80 });
            }
            
            // Invert cleanly using primary color
            root.isInverted = (Math.floor(root.score / 700) % 2 === 1);
            
            if (Math.floor(root.score) >= 99999) {
                root.score = 99999;
                root.gameOver();
                return;
            }
            
            if (Math.floor(root.score) > 0 && Math.floor(root.score) % 100 === 0) {
                root.gameSpeed += 0.05;
            }
            
            var newObstacles = [];
            for (var i = 0; i < root.obstacles.length; i++) {
                var obs = root.obstacles[i];
                obs.x -= root.gameSpeed;
                
                var dWidth = root.isDucking ? 59 : 44;
                var dHeight = root.isDucking ? 30 : 47;
                var dRect = {x: 30 + 10, y: parent.height - 30 - dHeight + root.dinoY + 10, w: dWidth - 20, h: dHeight - 15};
                var oRect = {x: obs.x + 8, y: parent.height - 30 - obs.height - (obs.yOffset || 0) + 8, w: obs.width - 16, h: obs.height - 16};
                
                if (dRect.x < oRect.x + oRect.w && dRect.x + dRect.w > oRect.x &&
                    dRect.y < oRect.y + oRect.h && dRect.y + dRect.h > oRect.y) {
                    root.gameOver();
                    return;
                }
                
                if (obs.x + obs.width > 0) {
                    newObstacles.push(obs);
                }
            }
            root.obstacles = newObstacles;
            
            root.obstacleTimer++;
            if (root.obstacleTimer > 60 + Math.random() * 80) {
                root.obstacleTimer = 0;
                var canSpawnBird = root.score > 300;
                var spawnType = (canSpawnBird && Math.random() > 0.7) ? "bird" : (Math.random() > 0.5 ? "small" : "large");
                var newObs = { x: root.width };
                if (spawnType === "bird") {
                    newObs.type = "bird";
                    newObs.width = 46;
                    newObs.height = 40;
                    var heights = [10, 35, 60];
                    newObs.yOffset = heights[Math.floor(Math.random() * heights.length)];
                } else if (spawnType === "small") {
                    newObs.type = "small";
                    newObs.width = 34;
                    newObs.height = 35;
                    newObs.yOffset = 0;
                } else {
                    newObs.type = "large";
                    newObs.width = 25;
                    newObs.height = 50;
                    newObs.yOffset = 0;
                }
                root.obstacles.push(newObs);
            }
        }
    }
}
