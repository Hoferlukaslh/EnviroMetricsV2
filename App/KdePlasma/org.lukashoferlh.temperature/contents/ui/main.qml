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

    // Ce qui s'affiche DANS la barre des tâches / le panneau
    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: contentRow.implicitWidth + Kirigami.Units.mediumSpacing * 2
        implicitHeight: parent ? parent.height : Kirigami.Units.iconSizes.small
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        onClicked: root.expanded = !root.expanded

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.mediumSpacing

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
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.mediumSpacing

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.temperature
                font.pixelSize: 28
                font.bold: true
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Humidité : " + root.humidity
                font.pixelSize: 16
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: "CO2 : " + root.co2
                font.pixelSize: 16
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

    Component.onCompleted: fetchTemperature()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: fetchTemperature()
    }
}
