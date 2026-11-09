pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.services
import qs.modules.components.kit
import "MetricsModel.js" as MetricsModel

// The metrics tab: who and where (MetricsProfile) over the live resource
// meters (MetricsResources) on the left; the load history (MetricsChart)
// with its zoom and refresh interval (MetricsChartControls) on the right.
Item {
    id: root

    property string hostname: ""
    property string osName: ""
    property var linuxLogos: null
    property real chartZoom: 1.0

    implicitWidth: 400
    implicitHeight: 400

    // Always store the maximum (250 points) so zooming out has history.
    onChartZoomChanged: {
        SystemResources.maxHistoryPoints = 250;
        chart.requestPaint();
    }

    Component.onCompleted: {
        SystemResources.maxHistoryPoints = 250;
        SystemResources.updateInterval = Math.max(100, StateService.get("metricsRefreshInterval", 2000));
        root.chartZoom = MetricsModel.clampZoom(StateService.get("metricsChartZoom", 1.0));
        hostnameReader.running = true;
        osReader.running = true;
        linuxLogosReader.running = true;
    }

    Process {
        id: linuxLogosReader
        command: ["cat", Qt.resolvedUrl("../../../../assets/linux-logos.json").toString().replace("file://", "")]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (!text || text.trim().length === 0) {
                        console.warn("linux-logos.json is empty");
                        return;
                    }
                    root.linuxLogos = JSON.parse(text);
                } catch (e) {
                    console.warn("Failed to parse linux-logos.json:", e);
                }
            }
        }
    }

    Process {
        id: hostnameReader
        command: ["hostname"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const host = text.trim();
                if (host)
                    root.hostname = host;
            }
        }
    }

    Process {
        id: osReader
        command: ["sh", "-c", "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const os = text.trim();
                if (os)
                    root.osName = os;
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Look.screenGap

        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            spacing: Space.m

            MetricsProfile {
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                hostname: root.hostname
                osName: root.osName
                osLogo: MetricsModel.osLogo(root.osName, root.linuxLogos)
            }

            SectionLabel {
                Layout.fillWidth: true
                text: I18n.t("settings.system")
            }

            MetricsResources {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Space.m

            MetricsChart {
                id: chart
                objectName: "metricsChart"
                Layout.fillWidth: true
                Layout.fillHeight: true
                zoom: root.chartZoom
            }

            MetricsChartControls {
                Layout.fillWidth: true
                zoom: root.chartZoom
                onZoomMoved: zoom => {
                    root.chartZoom = zoom;
                    StateService.set("metricsChartZoom", zoom);
                }
            }
        }
    }
}
