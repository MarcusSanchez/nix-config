// The active desk look as a bar pill (icon + name), clicking opens a
// sticky picker of every look; selecting one runs its wallpaper:<name>
// command (dms.nix), which repaints all three monitors, swaps the DMS
// theme and the niri accent, and toggles the animated layer.
//
// Two out-of-store inputs, both written by the nix side:
//   ~/.config/DankMaterialShell/desk-looks.json  the menu (name/icon/
//     comment), a projection of dms.nix's looks table
//   ~/.local/state/desk-look                      the active look name,
//     stamped by each wallpaper:<name> run
// FileView watches both, so the pill and the highlighted row track the
// live desk without a shell restart. PluginComponent auto-anchors the
// popout under the pill (no pillClickAction — that path is the shared
// process list; popoutContent is the plugin-owned one).
//
// Keyboard-navigable: PluginPopout's own container keeps focus and only
// handles Escape, so the picker wraps its rows in a FocusScope that
// grabs focus on open and drives a selection cursor (Up/Down wrap,
// Enter applies, Escape closes). Mouse hover moves the same cursor, so
// the two input modes never disagree. The "active" look (currently
// applied) is marked by accent border/text independently of the cursor.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string activeLook: ""
    property var looks: []
    property int selectedIndex: -1

    readonly property string homeDir: Quickshell.env("HOME")

    function iconFor(name) {
        for (var i = 0; i < looks.length; i++)
            if (looks[i].name === name)
                return looks[i].icon;
        return "wallpaper";
    }

    function activeIndex() {
        for (var i = 0; i < looks.length; i++)
            if (looks[i].name === activeLook)
                return i;
        return 0;
    }

    function apply(i) {
        if (i >= 0 && i < looks.length)
            Quickshell.execDetached(["wallpaper:" + looks[i].name]);
    }

    FileView {
        id: activeFile
        path: root.homeDir + "/.local/state/desk-look"
        watchChanges: true
        printErrors: false
        onLoaded: root.activeLook = text().trim()
        onFileChanged: reload()
    }

    FileView {
        id: manifestFile
        path: root.homeDir + "/.config/DankMaterialShell/desk-looks.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.looks = JSON.parse(text());
            } catch (e) {
                root.looks = [];
            }
        }
        onFileChanged: reload()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.iconFor(root.activeLook)
                size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.activeLook.length ? root.activeLook : "look"
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 56 + root.looks.length * 60

    popoutContent: Component {
        PopoutComponent {
            id: pop
            headerText: "Desk Look"
            showCloseButton: true

            property var closePopout: null

            FocusScope {
                width: parent.width
                implicitHeight: lookColumn.implicitHeight
                focus: true

                // grab focus off PluginPopout's container so the arrow
                // keys reach us; seed the cursor on the active look
                Component.onCompleted: {
                    root.selectedIndex = root.activeIndex();
                    Qt.callLater(() => forceActiveFocus());
                }

                Keys.onPressed: event => {
                    const n = root.looks.length;
                    if (n === 0)
                        return;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.selectedIndex = (root.selectedIndex + 1) % n;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        root.selectedIndex = (root.selectedIndex - 1 + n) % n;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply(root.selectedIndex);
                        if (pop.closePopout)
                            pop.closePopout();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        if (pop.closePopout)
                            pop.closePopout();
                        event.accepted = true;
                    }
                }

                Column {
                    id: lookColumn
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.looks

                        Rectangle {
                            id: row
                            required property int index
                            required property var modelData
                            readonly property bool active: modelData.name === root.activeLook
                            readonly property bool selected: index === root.selectedIndex

                            width: parent.width
                            height: 52
                            radius: Theme.cornerRadius
                            color: row.selected ? Theme.primaryHoverLight : Theme.surfaceContainerHigh
                            border.color: row.active ? Theme.primary : "transparent"
                            border.width: row.active ? 2 : 0

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: row.modelData.icon
                                    size: Theme.iconSize
                                    color: row.active ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - Theme.iconSize - Theme.spacingM
                                    spacing: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: row.modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: row.active ? Theme.primary : Theme.surfaceText
                                    }

                                    StyledText {
                                        text: row.modelData.comment
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = row.index
                                onClicked: {
                                    root.apply(row.index);
                                    if (pop.closePopout)
                                        pop.closePopout();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
