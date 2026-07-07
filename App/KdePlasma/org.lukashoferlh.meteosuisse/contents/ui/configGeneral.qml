import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../code/stations.js" as Stations

Kirigami.FormLayout {
    id: page

    // cfg_plz, cfg_refreshMinutes et cfg_showGraphs sont liées directement aux
    // contrôles via "property alias". cfg_station est gérée manuellement car
    // le champ de recherche a besoin de logique (filtrage) qu'un simple alias
    // ne permet pas d'exprimer.
    property string cfg_station: ""
    property alias cfg_plz: plzField.text
    property alias cfg_refreshMinutes: refreshSpin.value
    property alias cfg_showGraphs: showGraphsCheck.checked

    QQC2.ComboBox {
        id: stationCombo
        Kirigami.FormData.label: i18n("Station météo :")
        Layout.fillWidth: true
        editable: true
        textRole: "label"

        property bool initializing: true
        property bool suppressFilter: false

        Component.onCompleted: {
            var full = Stations.stationList.map(function (s) {
                return { id: s.id, label: s.name + " (" + s.id + ")" };
            });
            model = full;
            for (var i = 0; i < full.length; i++) {
                if (full[i].id === page.cfg_station) {
                    currentIndex = i;
                    editText = full[i].label;
                    break;
                }
            }
            initializing = false;
        }

        onEditTextChanged: {
            if (initializing || suppressFilter) return;
            var filterText = editText.toLowerCase();
            model = Stations.stationList
                .filter(function (s) {
                    return s.name.toLowerCase().indexOf(filterText) !== -1
                        || s.id.toLowerCase().indexOf(filterText) !== -1;
                })
                .map(function (s) {
                    return { id: s.id, label: s.name + " (" + s.id + ")" };
                });
            if (model.length > 0) popup.open();
        }

        onActivated: function (index) {
            if (index < 0 || index >= model.length) return;
            page.cfg_station = model[index].id;
            suppressFilter = true;
            editText = model[index].label;
            suppressFilter = false;
            popup.close();
        }
    }

    QQC2.Label {
        text: i18n("Tape un nom de lieu ou un code de station pour filtrer la liste.")
        font.pixelSize: Kirigami.Units.gridUnit * 0.7
        opacity: 0.6
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    QQC2.TextField {
        id: plzField
        Kirigami.FormData.label: i18n("NPA pour les prévisions :")
        placeholderText: "2800"
        validator: RegularExpressionValidator { regularExpression: /^[0-9]{4}$/ }
    }

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Rafraîchissement (minutes) :")
        from: 1
        to: 60
        value: 5
    }

    QQC2.CheckBox {
        id: showGraphsCheck
        Kirigami.FormData.label: i18n("Graphiques :")
        text: i18n("Afficher les graphiques (température, pluie, vent)")
        checked: true
    }
}
