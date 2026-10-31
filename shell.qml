import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    WlrLayershell.namespace: "tor-circuit-widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Position is user-owned: drag the card, it is remembered.
    property int posX: 300
    property int posY: 300
    readonly property string positionPath: Quickshell.env("HOME") + "/.config/quickshell/tor-circuit/position.json"

    anchors { top: true; left: true }
    margins { top: root.posY; left: root.posX }
    implicitWidth: 470
    implicitHeight: 252

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080

    function clampX(value) { return Math.max(0, Math.min(Number(value) || 0, screenW - implicitWidth)) }
    function clampY(value) { return Math.max(0, Math.min(Number(value) || 0, screenH - implicitHeight)) }

    property var info: ({ ok: false, error: "Tor bilgisi bekleniyor…" })
    property bool dragging: false

    function refresh() { if (!reader.running) reader.running = true }

    function friendly(raw) {
        const text = String(raw ?? "")
        if (text.indexOf("Authentication") >= 0 || text.indexOf("cookie") >= 0)
            return "Tor ControlPort izni gerekli · README"
        if (text.indexOf("Connection refused") >= 0 || text.indexOf("9051") >= 0)
            return "Tor ControlPort kapalı (127.0.0.1:9051)"
        return text.length > 0 ? text : "Tor durumu okunamadı"
    }

    function setResult(raw) {
        try {
            const parsed = JSON.parse(raw)
            if (!parsed.ok)
                parsed.error = friendly(parsed.error)
            info = parsed
        } catch (e) {
            info = ({ ok: false, error: "Tor yanıtı okunamadı" })
        }
    }

    Process {
        id: reader
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/tor-circuit/tor_status.py"]
        stdout: StdioCollector { id: result }
        onExited: root.setResult(result.text)
    }

    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()

    FileView {
        id: positionFile
        path: root.positionPath
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(positionFile.text())
                if (typeof saved.x === "number" && typeof saved.y === "number") {
                    root.posX = root.clampX(saved.x)
                    root.posY = root.clampY(saved.y)
                }
            } catch (e) {}
        }
    }

    function savePosition() {
        Quickshell.execDetached(["sh", "-c",
            "printf '{\"x\":%s,\"y\":%s}' \"$1\" \"$2\" > \"$3\"",
            "sh", String(root.posX), String(root.posY), root.positionPath])
    }

    Rectangle {
        anchors.fill: parent
        radius: 25
        color: "#ed1b202a"
        border.color: "#35ffffff"
        border.width: 1

        // The whole card is the drag handle. A movement under 3px is treated as
        // a click, so a stray click never nudges it; controls above win input.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real startX: 0
            property real startY: 0
            property bool armed: false
            onPressed: (mouse) => {
                armed = true
                startX = mouse.x
                startY = mouse.y
            }
            onReleased: {
                if (root.dragging)
                    root.savePosition()
                root.dragging = false
                armed = false
            }
            onPositionChanged: (mouse) => {
                if (!armed)
                    return
                const dx = mouse.x - startX
                const dy = mouse.y - startY
                if (!root.dragging && Math.abs(dx) + Math.abs(dy) < 3)
                    return
                root.dragging = true
                root.posX = root.clampX(root.posX + dx)
                root.posY = root.clampY(root.posY + dy)
                startX = mouse.x
                startY = mouse.y
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 15

            RowLayout {
                Layout.fillWidth: true
                spacing: 11

                Rectangle {
                    width: 38; height: 38; radius: 13
                    color: "#35e0563b"
                    Text { anchors.centerIn: parent; text: "◉"; color: "#e87358"; font.pixelSize: 22 }
                }
                ColumnLayout {
                    spacing: 1
                    Text { text: "TOR CIRCUIT"; color: "#9aa4b5"; font.pixelSize: 10; font.letterSpacing: 1.5 }
                    Text { text: "Tor devre rotası"; color: "#f3f4f7"; font.pixelSize: 17; font.weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 12; implicitWidth: badge.implicitWidth + 16; implicitHeight: 27
                    color: root.info.ok ? "#263f35" : "#3b302c"
                    Text {
                        id: badge; anchors.centerIn: parent
                        text: root.info.ok ? "●  BAĞLI" : "●  TOR BEKLENİYOR"
                        color: root.info.ok ? "#82d6a7" : "#e4a28e"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#24ffffff" }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Repeater {
                    model: [
                        { key: "entry", title: "GİRİŞ", hint: "Guard" },
                        { key: "middle", title: "ORTA", hint: "Middle" },
                        { key: "exit", title: "ÇIKIŞ", hint: "Exit" }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: modelData.title; color: "#9aa4b5"; font.pixelSize: 9; font.letterSpacing: 1.4 }
                            Text {
                                text: root.info.ok && root.info[modelData.key]
                                    ? root.info[modelData.key].flag + "  " + root.info[modelData.key].country : "—"
                                color: "#f3f4f7"; font.pixelSize: 14; font.weight: Font.DemiBold
                                elide: Text.ElideRight; Layout.maximumWidth: 126
                            }
                            Text {
                                text: root.info.ok && root.info[modelData.key]
                                    ? root.info[modelData.key].relay : modelData.hint
                                color: "#8993a4"; font.pixelSize: 10
                                elide: Text.ElideRight; Layout.maximumWidth: 126
                            }
                        }
                        Rectangle {
                            visible: modelData.key !== "exit"
                            width: 20; height: 1; color: "#8ae0563b"
                            Text { anchors.centerIn: parent; text: "›"; color: "#e87358"; font.pixelSize: 17 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.info.ok ? (root.info.bootstrap || "Tor ağına bağlı") : (root.info.error || "Tor ControlPort gerekli")
                    color: "#9aa4b5"; font.pixelSize: 10; elide: Text.ElideRight
                }
                Rectangle {
                    width: 30; height: 27; radius: 9; color: "#18ffffff"
                    Text { anchors.centerIn: parent; text: "↻"; color: "#e8eaf0"; font.pixelSize: 17 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                }
            }
        }
    }
}
