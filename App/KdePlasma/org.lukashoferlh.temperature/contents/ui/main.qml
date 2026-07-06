import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string temperature: "--°C"
    property string humidity: "--%"
    property string co2: "-- ppm"
    property var historyData: []

    property var tempPoints: root.historyData.map(function(p) {
        return { value: p.temperature, timestemp: p.timestemp };
    })
    property var humidityPoints: root.historyData.map(function(p) {
        return { value: p.humidite, timestemp: p.timestemp };
    })
    property var co2Points: root.historyData.map(function(p) {
        return { value: p.co2, timestemp: p.timestemp };
    })

    // Ce qui s'affiche DANS la barre des tâches / le panneau
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

            PlasmaComponents.Label {
                text: root.temperature
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
                font.bold: true
            }

            PlasmaComponents.Label {
                text: root.humidity
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
            }

            PlasmaComponents.Label {
                text: root.co2
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
            }
        }
    }

    // Ce qui s'affiche quand on clique dessus (popup) - optionnel mais recommandé
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                PlasmaComponents.Label {
                    text: root.temperature
                    font.pixelSize: 28
                    font.bold: true
                }

                PlasmaComponents.Label {
                    text: "Humidité : " + root.humidity
                    font.pixelSize: 16
                }

                PlasmaComponents.Label {
                    text: "CO2 : " + root.co2
                    font.pixelSize: 16
                }
            }

            MetricGraph {
                label: "Température - dernières 24h"
                points: root.tempPoints
                unit: "°C"
                decimals: 1
                lineColor: "#e74c3c"
            }

            MetricGraph {
                label: "Humidité - dernières 24h"
                points: root.humidityPoints
                unit: "%"
                decimals: 1
                lineColor: "#3498db"
            }

            MetricGraph {
                label: "CO2 - dernières 24h"
                points: root.co2Points
                unit: " ppm"
                decimals: 0
                lineColor: "#2ecc71"
            }
        }
    }

    function fetchTemperature() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://env.kreativcam.ch/api/mesures?app_id=2&limit=1&days=1", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    if (response.length > 0) {
                        var mesure = response[0];
                        root.temperature = mesure.temperature.toFixed(1) + "°C";
                        root.humidity = mesure.humidite.toFixed(1) + "%";
                        root.co2 = mesure.co2 + " ppm";
                    }
                } catch (e) {
                    console.log("Erreur parsing :", e);
                }
            }
        };
        xhr.send();
    }

    function fetchHistory() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://env.kreativcam.ch/api/mesures?app_id=2&days=1&limit=500", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    // L'API renvoie les résultats du plus récent au plus ancien (DESC),
                    // on inverse pour avoir un ordre chronologique pour le graphique
                    var points = [];
                    for (var i = response.length - 1; i >= 0; i--) {
                        points.push({
                            temperature: response[i].temperature,
                            humidite: response[i].humidite,
                            co2: response[i].co2,
                            timestemp: response[i].timestemp
                        });
                    }
                    root.historyData = points;
                } catch (e) {
                    console.log("Erreur parsing historique :", e);
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        fetchTemperature();
        fetchHistory();
    }

    onExpandedChanged: {
        if (expanded) {
            fetchHistory();
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            fetchTemperature();
            fetchHistory();
        }
    }
}
