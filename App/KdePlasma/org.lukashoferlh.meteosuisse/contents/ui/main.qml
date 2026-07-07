import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/stations.js" as Stations

PlasmoidItem {
    id: root

    readonly property string stationId: Plasmoid.configuration.station
    readonly property string plzCode: Plasmoid.configuration.plz
    readonly property int refreshMinutes: Plasmoid.configuration.refreshMinutes
    readonly property bool showGraphs: Plasmoid.configuration.showGraphs
    readonly property string stationName: Stations.findName(stationId)

    // Dernière lecture de la station (temps réel)
    property var current: ({})
    // Réponse complète de plzDetail (prévisions + courbes horaires)
    property var forecastData: ({})
    property string errorMessage: ""

    readonly property bool hasCurrentIcon: forecastData.currentWeather !== undefined
    readonly property var dailyForecast: forecastData.forecast ? forecastData.forecast.slice(0, 6) : []

    readonly property var tempPoints: buildPoints(forecastData.graph, "temperatureMean1h")
    readonly property var precipPoints: buildPoints(forecastData.graph, "precipitation1h")
    readonly property var windPoints: buildPoints(forecastData.graph, "windSpeed1h")

    // --- Aides ---------------------------------------------------------

    function buildPoints(graph, key) {
        if (!graph || !graph[key] || !graph.start) return [];
        var arr = graph[key];
        var pts = [];
        for (var i = 0; i < arr.length; i++) {
            pts.push({
                value: arr[i],
                timestemp: localTimestamp(graph.start + i * 3600000)
            });
        }
        return pts;
    }

    function pad(n) { return (n < 10 ? "0" : "") + n; }

    // Reconstruit un "timestemp" local (heure du système) au format attendu
    // par MetricGraph.qml (YYYY-MM-DDTHH:MM:SS).
    function localTimestamp(ms) {
        var d = new Date(ms);
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
            + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":00";
    }

    function windDirLabel(deg) {
        if (deg === undefined || deg === null) return "--";
        var dirs = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"];
        return dirs[Math.round(deg / 45) % 8];
    }

    // Icônes météo officielles MétéoSuisse (1-50 jour, 101-150 nuit)
    function iconUrl(code) {
        if (!code) return "";
        return "https://www.meteoschweiz.admin.ch/static/resources/weather-symbols/" + code + ".svg";
    }

    // --- Représentation compacte (barre des tâches) ---------------------

    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: contentRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: parent ? parent.height : Kirigami.Units.iconSizes.small
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        onClicked: root.expanded = !root.expanded

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                fillMode: Image.PreserveAspectFit
                visible: root.hasCurrentIcon
                source: root.hasCurrentIcon ? root.iconUrl(root.forecastData.currentWeather.iconV2) : ""
            }

            PlasmaComponents.Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.current.temperature !== undefined
                    ? root.current.temperature.toFixed(1) + "°C"
                    : "--°C"
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
                font.bold: true
            }
        }
    }

    // --- Représentation complète (popup) ---------------------------------

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * (root.showGraphs ? 34 : 16)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.stationName + " (" + root.stationId + ")"
                font.pixelSize: 16
                font.bold: true
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: Kirigami.Theme.negativeTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                Image {
                    width: Kirigami.Units.iconSizes.huge
                    height: width
                    fillMode: Image.PreserveAspectFit
                    visible: root.hasCurrentIcon
                    source: root.hasCurrentIcon ? root.iconUrl(root.forecastData.currentWeather.iconV2) : ""
                }

                PlasmaComponents.Label {
                    text: root.current.temperature !== undefined
                        ? root.current.temperature.toFixed(1) + "°C"
                        : "--°C"
                    font.pixelSize: 32
                    font.bold: true
                }
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 4
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.largeSpacing

                PlasmaComponents.Label { text: i18n("Humidité :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.humidity !== undefined ? root.current.humidity + " %" : "--"
                }
                PlasmaComponents.Label { text: i18n("Vent :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.windSpeed !== undefined
                        ? root.current.windSpeed.toFixed(1) + " km/h " + root.windDirLabel(root.current.windDirection)
                        : "--"
                }

                PlasmaComponents.Label { text: i18n("Rafales :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.windGust !== undefined ? root.current.windGust.toFixed(1) + " km/h" : "--"
                }
                PlasmaComponents.Label { text: i18n("Pression :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.pressureStandard !== undefined
                        ? root.current.pressureStandard.toFixed(1) + " hPa"
                        : "--"
                }

                PlasmaComponents.Label { text: i18n("Précipitation :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.precipitation !== undefined ? root.current.precipitation + " mm" : "--"
                }
                PlasmaComponents.Label { text: i18n("Point de rosée :"); opacity: 0.7 }
                PlasmaComponents.Label {
                    text: root.current.dewPoint !== undefined ? root.current.dewPoint.toFixed(1) + "°C" : "--"
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.dailyForecast

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDate(new Date(modelData.dayDate), "ddd")
                            font.pixelSize: 11
                            opacity: 0.7
                        }

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            fillMode: Image.PreserveAspectFit
                            source: root.iconUrl(modelData.iconDayV2)
                        }

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round(modelData.temperatureMax) + "°"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round(modelData.temperatureMin) + "°"
                            font.pixelSize: 11
                            opacity: 0.6
                        }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; visible: root.showGraphs }

            PlasmaComponents.Label {
                visible: root.showGraphs
                Layout.fillWidth: true
                text: i18n("Prévisions horaires (env. 6 jours) — pas une mesure historique")
                font.pixelSize: 10
                font.italic: true
                opacity: 0.6
                horizontalAlignment: Text.AlignHCenter
            }

            MetricGraph {
                visible: root.showGraphs
                label: i18n("Température prévue (°C)")
                points: root.tempPoints
                unit: "°C"
                decimals: 1
                lineColor: "#e74c3c"
            }

            MetricGraph {
                visible: root.showGraphs
                label: i18n("Précipitations prévues (mm/h)")
                points: root.precipPoints
                unit: " mm"
                decimals: 1
                lineColor: "#3498db"
            }

            MetricGraph {
                visible: root.showGraphs
                label: i18n("Vent prévu (km/h)")
                points: root.windPoints
                unit: " km/h"
                decimals: 1
                lineColor: "#2ecc71"
            }
        }
    }

    // --- Appels réseau ----------------------------------------------------

    function fetchStation() {
        if (!root.stationId) return;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://app-prod-ws.meteoswiss-app.ch/v1/stationOverview?station=" + root.stationId, true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    root.current = response[root.stationId] || {};
                    root.errorMessage = "";
                } catch (e) {
                    console.log("Erreur parsing station :", e);
                    root.errorMessage = i18n("Erreur de lecture des données de la station");
                }
            } else {
                root.errorMessage = i18n("Impossible de contacter MétéoSuisse (station)");
            }
        };
        xhr.send();
    }

    function fetchForecast() {
        if (!root.plzCode) return;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://app-prod-ws.meteoswiss-app.ch/v1/plzDetail?plz=" + root.plzCode + "00", true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    root.forecastData = JSON.parse(xhr.responseText);
                } catch (e) {
                    console.log("Erreur parsing prévisions :", e);
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        fetchStation();
        fetchForecast();
    }

    onExpandedChanged: {
        if (expanded) {
            fetchStation();
            fetchForecast();
        }
    }

    Timer {
        interval: Math.max(1, root.refreshMinutes) * 60000
        running: true
        repeat: true
        onTriggered: root.fetchStation()
    }

    // Les prévisions/courbes horaires changent peu : on les rafraîchit
    // moins souvent que la mesure de station en temps réel.
    Timer {
        interval: 30 * 60000
        running: true
        repeat: true
        onTriggered: root.fetchForecast()
    }
}
