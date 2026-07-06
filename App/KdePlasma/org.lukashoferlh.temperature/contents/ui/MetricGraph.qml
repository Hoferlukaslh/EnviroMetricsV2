import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: root

    // points: tableau de { value: number, timestemp: string }
    property var points: []
    property color lineColor: Kirigami.Theme.highlightColor
    property string unit: ""
    property string label: ""
    property int decimals: 1

    property int hoverIndex: -1
    property real leftMargin: 26

    Layout.fillWidth: true
    Layout.preferredHeight: Kirigami.Units.gridUnit * 6

    PlasmaComponents.Label {
        id: titleLabel
        text: root.label
        font.pixelSize: 11
        opacity: 0.7
        anchors.top: parent.top
        anchors.left: parent.left
    }

    Canvas {
        id: canvas
        anchors.top: titleLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 2

        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        property var graphData: root.points
        onGraphDataChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Component.onCompleted: requestPaint()

        Connections {
            target: root
            function onHoverIndexChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var data = canvas.graphData;
            if (!data || data.length < 2) {
                ctx.fillStyle = Kirigami.Theme.textColor;
                ctx.font = "11px sans-serif";
                ctx.fillText("Chargement...", 8, height / 2);
                return;
            }

            var m = root.leftMargin;
            var w = width - m - 4;
            var h = height - 8;
            var top = 4;

            var values = data.map(function(d) { return d.value; });
            var minV = Math.min.apply(null, values);
            var maxV = Math.max.apply(null, values);
            if (minV === maxV) { minV -= 1; maxV += 1; }
            var pad = (maxV - minV) * 0.1;
            minV -= pad; maxV += pad;

            function xAt(i) { return m + w * (i / (values.length - 1)); }
            function yAt(v) { return top + h - h * ((v - minV) / (maxV - minV)); }

            // grille horizontale + labels
            ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15);
            ctx.fillStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.6);
            ctx.font = "9px sans-serif";
            ctx.lineWidth = 1;
            for (var g = 0; g <= 2; g++) {
                var gy = top + (h * g / 2);
                ctx.beginPath();
                ctx.moveTo(m, gy);
                ctx.lineTo(m + w, gy);
                ctx.stroke();
                var val = maxV - (maxV - minV) * (g / 2);
                ctx.fillText(val.toFixed(root.decimals), 0, gy + 3);
            }

            // courbe
            ctx.strokeStyle = root.lineColor;
            ctx.lineWidth = 2;
            ctx.beginPath();
            for (var i = 0; i < values.length; i++) {
                var x = xAt(i);
                var y = yAt(values[i]);
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();

            // remplissage léger
            ctx.lineTo(xAt(values.length - 1), top + h);
            ctx.lineTo(m, top + h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.15);
            ctx.fill();

            // ligne + point de survol
            if (root.hoverIndex >= 0 && root.hoverIndex < values.length) {
                var hx = xAt(root.hoverIndex);
                var hy = yAt(values[root.hoverIndex]);

                ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.4);
                ctx.setLineDash([2, 2]);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(hx, top);
                ctx.lineTo(hx, top + h);
                ctx.stroke();
                ctx.setLineDash([]);

                ctx.beginPath();
                ctx.fillStyle = root.lineColor;
                ctx.arc(hx, hy, 3, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    MouseArea {
        anchors.fill: canvas
        hoverEnabled: true
        onPositionChanged: {
            var data = root.points;
            if (!data || data.length < 2) return;
            var m = root.leftMargin;
            var w = width - m - 4;
            var relX = mouseX - m;
            var ratio = Math.max(0, Math.min(1, relX / w));
            root.hoverIndex = Math.round(ratio * (data.length - 1));
        }
        onExited: root.hoverIndex = -1
    }

    // Tooltip qui suit le curseur
    Rectangle {
        id: tooltip
        visible: root.hoverIndex >= 0 && root.hoverIndex < root.points.length
        radius: 4
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.textColor
        border.width: 1
        width: tooltipText.implicitWidth + 10
        height: tooltipText.implicitHeight + 6
        z: 10

        property real tipX: {
            if (root.hoverIndex < 0 || root.points.length < 2) return 0;
            var m = root.leftMargin;
            var w = canvas.width - m - 4;
            return m + w * (root.hoverIndex / (root.points.length - 1));
        }

        x: Math.min(Math.max(tipX - width / 2, 0), root.width - width)
        y: canvas.y + 2

        PlasmaComponents.Label {
            id: tooltipText
            anchors.centerIn: parent
            font.pixelSize: 10
            text: {
                if (root.hoverIndex < 0 || root.hoverIndex >= root.points.length) return "";
                var p = root.points[root.hoverIndex];
                var timeLabel = p.timestemp ? p.timestemp.substring(11, 16) : "";
                return timeLabel + " : " + p.value.toFixed(root.decimals) + root.unit;
            }
        }
    }
}
