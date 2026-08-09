// Combined GPU pill: "usage% | temp°" behind one icon. Temperature
// rides the shell's DgopService like the stock gpuTemp widget (the
// pciId registration is what makes dgop resolve the hwmon — index 0
// picked dynamically, so each machine finds its own card). Utilization
// has no dgop metric, so nvidia-smi is polled on a 3s timer; on a
// machine where that binary is missing the usage side just reads "--".
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property var gpu: (DgopService.availableGpus && DgopService.availableGpus.length > 0) ? DgopService.availableGpus[0] : null
    readonly property real temp: gpu ? (gpu.temperature || 0) : 0
    property int usage: -1
    property string registeredPciId: ""

    onGpuChanged: {
        if (gpu && gpu.pciId && registeredPciId !== gpu.pciId) {
            if (registeredPciId)
                DgopService.removeGpuPciId(registeredPciId);
            DgopService.addGpuPciId(gpu.pciId);
            registeredPciId = gpu.pciId;
        }
    }

    Component.onCompleted: DgopService.addRef(["gpu"])
    Component.onDestruction: {
        DgopService.removeRef(["gpu"]);
        if (registeredPciId)
            DgopService.removeGpuPciId(registeredPciId);
    }

    Process {
        id: usageProbe
        command: ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.usage = isNaN(v) ? -1 : v;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: usageProbe.running = true
    }

    content: Component {
        Item {
            implicitWidth: comboRow.implicitWidth
            implicitHeight: comboRow.implicitHeight

            Row {
                id: comboRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "auto_awesome_mosaic"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (root.usage > 80 || root.temp > 80)
                            return Theme.tempDanger;
                        if (root.usage > 60 || root.temp > 65)
                            return Theme.tempWarning;
                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (root.usage >= 0 ? root.usage : "--") + "%"
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
