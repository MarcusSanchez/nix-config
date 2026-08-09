// Combined CPU pill: "usage% | temp°" behind one icon, replacing the
// separate cpuUsage/cpuTemp stock widgets. Both numbers come from the
// shell's DgopService (plugins share the QML engine, so qs.Services
// imports work); addRef keeps the cpu module polled while the pill
// lives. Color thresholds mirror the stock widgets'.
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property real usage: DgopService.cpuUsage || 0
    readonly property real temp: DgopService.cpuTemperature || 0

    Component.onCompleted: DgopService.addRef(["cpu"])
    Component.onDestruction: DgopService.removeRef(["cpu"])

    content: Component {
        Item {
            implicitWidth: comboRow.implicitWidth
            implicitHeight: comboRow.implicitHeight

            Row {
                id: comboRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "memory"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (root.usage > 80 || root.temp > 85)
                            return Theme.tempDanger;
                        if (root.usage > 60 || root.temp > 69)
                            return Theme.tempWarning;
                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (root.usage > 0 ? root.usage.toFixed(0) : "--") + "%"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "|"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (root.temp > 0 ? Math.round(root.temp).toString() : "--") + "°"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
