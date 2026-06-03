import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Math;
import Toybox.Attention;
import Toybox.System;

class AccelDiagnosticView extends WatchUi.View {

    var isRecording as Boolean = false;
    var curX as Float = 0.0;
    var curY as Float = 0.0;
    var curZ as Float = 0.0;
    var curMag as Float = 0.0;
    var peakCount as Number = 0;
    var prevMag as Float = 0.0;
    var lastPeakTime as Number = 0;
    var magBuffer as Array = new [75];
    var bufferIndex as Number = 0;
    var bufferFull as Boolean = false;

    function initialize() {
        View.initialize();
        for (var i = 0; i < 75; i++) {
            magBuffer[i] = 1.0;
        }
    }

    function startRecording() as Void {
        peakCount = 0;
        prevMag = 0.0;
        lastPeakTime = 0;
        bufferIndex = 0;
        bufferFull = false;
        for (var i = 0; i < 75; i++) {
            magBuffer[i] = 1.0;
        }

        var sampleRate = 25;
        if (Sensor has :getMaxSampleRateForSensorType) {
            var maxRate = Sensor.getMaxSampleRateForSensorType(:accelerometer);
            if (maxRate instanceof Number && maxRate < 25) {
                sampleRate = maxRate;
            }
        }

        var options = {
            :period => 1,
            :accelerometer => { :enabled => true, :sampleRate => sampleRate }
        };
        Sensor.registerSensorDataListener(method(:onSensorData), options);
        isRecording = true;
    }

    function stopRecording() as Void {
        if (isRecording) {
            Sensor.unregisterSensorDataListener();
            isRecording = false;
        }
    }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        var accel = sensorData.accelerometerData;
        if (accel == null) { return; }
        var xs = accel.x;
        var ys = accel.y;
        var zs = accel.z;
        if (xs == null || ys == null || zs == null) { return; }
        var count = xs.size();
        if (count == 0) { return; }

        for (var i = 0; i < count; i++) {
            var xRaw = xs[i];
            var yRaw = ys[i];
            var zRaw = zs[i];
            if (xRaw == null || yRaw == null || zRaw == null) { continue; }

            var xG = xRaw / 1000.0;
            var yG = yRaw / 1000.0;
            var zG = zRaw / 1000.0;
            var mag = Math.sqrt(xG * xG + yG * yG + zG * zG);

            magBuffer[bufferIndex] = mag;
            bufferIndex++;
            if (bufferIndex >= 75) {
                bufferIndex = 0;
                bufferFull = true;
            }

            // Peak detection: rising edge past 1.15g with 600ms debounce
            if (prevMag < 1.15 && mag >= 1.15) {
                var nowMs = System.getTimer();
                if (nowMs - lastPeakTime > 600) {
                    peakCount++;
                    lastPeakTime = nowMs;
                    if (Attention has :vibrate) {
                        var vibeData = [new Attention.VibeProfile(70, 100)];
                        Attention.vibrate(vibeData);
                    }
                }
            }
            prevMag = mag;
        }

        // Update display values from last sample in this batch
        var last = count - 1;
        var lxRaw = xs[last];
        var lyRaw = ys[last];
        var lzRaw = zs[last];
        if (lxRaw != null && lyRaw != null && lzRaw != null) {
            curX = lxRaw / 1000.0;
            curY = lyRaw / 1000.0;
            curZ = lzRaw / 1000.0;
            curMag = Math.sqrt(curX * curX + curY * curY + curZ * curZ);
        }

        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {}
    function onShow() as Void {}

    function onHide() as Void {
        stopRecording();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;

        // --- Status top-left ---
        if (isRecording) {
            dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(10, 12, Graphics.FONT_XTINY,
            isRecording ? "REC" : "STOP",
            Graphics.TEXT_JUSTIFY_LEFT);

        // --- Peak counter top-right ---
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 10, 10, Graphics.FONT_XTINY, "PEAKS", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 10, 24, Graphics.FONT_TINY, peakCount.toString(), Graphics.TEXT_JUSTIFY_RIGHT);

        // --- "MAG (g)" label ---
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, Graphics.FONT_XTINY, "MAG (g)", Graphics.TEXT_JUSTIFY_CENTER);

        // --- Large magnitude number ---
        if (isRecording) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, 55, Graphics.FONT_NUMBER_HOT,
            curMag.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);

        // --- X / Y / Z individual values ---
        // y=168 zostawia wyrazny odstep pod FONT_NUMBER_HOT (konczy sie ok. y=150)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 72, 168, Graphics.FONT_XTINY,
            "X:" + curX.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 168, Graphics.FONT_XTINY,
            "Y:" + curY.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + 72, 168, Graphics.FONT_XTINY,
            "Z:" + curZ.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);

        // --- Separator ---
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(15, 185, width - 15, 185);

        // --- Live chart ---
        drawChart(dc, width, height);

        // --- Bottom hint ---
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 18, Graphics.FONT_XTINY,
            isRecording ? "BTN=stop  BACK=exit" : "BTN=start  BACK=exit",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawChart(dc as Dc, width as Number, height as Number) as Void {
        var cL  = 12;
        var cR  = width - 12;
        var cTop = 192;
        var cBot = height - 28;
        var cH  = (cBot - cTop).toFloat();
        var cW  = (cR - cL).toFloat();
        var maxG = 2.5;

        // Subtle gray baseline at 1.0g (stationary wrist)
        var restY = cBot - (1.0 / maxG * cH).toNumber();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cL, restY, cR, restY);

        // Dashed DK_RED threshold line at 1.15g
        var thrY = cBot - (1.15 / maxG * cH).toNumber();
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        var dx = cL;
        while (dx < cR - 3) {
            dc.drawLine(dx, thrY, dx + 3, thrY);
            dx += 6;
        }
        dc.drawText(cR - 2, thrY - 14, Graphics.FONT_XTINY, "1.15", Graphics.TEXT_JUSTIFY_RIGHT);

        // Draw signal as connected line segments (oldest → newest = left → right)
        var drawCount = bufferFull ? 75 : bufferIndex;
        if (drawCount < 2) { return; }

        var pxPerSmp = cW / 75.0;
        var prevPx = -1;
        var prevPy = -1;

        for (var i = 0; i < drawCount; i++) {
            var idx = bufferFull ? ((bufferIndex + i) % 75) : i;
            var raw = magBuffer[idx];
            var fmag = 1.0;
            if (raw != null) {
                fmag = raw.toFloat();
            }

            var px = (cL + i * pxPerSmp).toNumber();
            var norm = fmag / maxG;
            if (norm < 0.0) { norm = 0.0; }
            if (norm > 1.0) { norm = 1.0; }
            var py = cBot - (norm * cH).toNumber();

            if (prevPx >= 0) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.drawLine(prevPx, prevPy, px, py);
            }
            prevPx = px;
            prevPy = py;
        }
    }
}
