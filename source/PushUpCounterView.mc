import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Math;
import Toybox.Attention;
import Toybox.System;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Licznik pompek z akcelerometru.
// Detekcja: magnitude (g) z histereza - jeden rep gdy sygnal przekroczy PROG
// w gore, a potem wroci ponizej (PROG - histereza). Refrakcja chroni przed
// podwojnym liczeniem. Prog regulowany na zegarku (UP/DOWN), zapamietywany.
class PushUpCounterView extends WatchUi.View {

    var counting as Boolean = false;
    var repCount as Number = 0;
    var lastSaved as Number = 0;        // ile ostatnio zapisano (komunikat)
    var curMag as Float = 1.0;
    var threshold as Float = 1.30;      // PROG (HIGH) - regulowany
    var lowGap as Float = 0.16;         // histereza: LOW = PROG - lowGap
    var state as Number = 0;            // 0 = czekam na peak, 1 = czekam na powrot
    var lastRepMs as Number = 0;
    var flashUntil as Number = 0;       // migniecie liczby przy repie

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        // Wczytaj zapamietany prog czulosci
        var t = Application.Storage.getValue("repThreshold");
        if (t != null && (t instanceof Float || t instanceof Number)) {
            threshold = t.toFloat();
        }
    }

    function onHide() as Void {
        // KRYTYCZNE dla baterii: zwolnij sensor; zapisz to co policzone
        stopSession();
    }

    function startSession() as Void {
        repCount = 0;
        state = 0;
        lastRepMs = 0;
        try {
            var options = {
                :period => 1,
                :accelerometer => { :enabled => true, :sampleRate => 25 }
            };
            Sensor.registerSensorDataListener(method(:onSensorData), options);
            counting = true;
        } catch (e) {
            counting = false;
        }
    }

    function stopSession() as Void {
        if (counting) {
            try {
                Sensor.unregisterSensorDataListener();
            } catch (e) {
            }
            counting = false;
            if (repCount > 0) {
                addToToday(repCount);
                lastSaved = repCount;
                repCount = 0;
            }
        }
    }

    // UP/DOWN: regulacja czulosci (delta < 0 = bardziej czuly)
    function adjustThreshold(delta as Float) as Void {
        threshold += delta;
        if (threshold < 1.05) { threshold = 1.05; }
        if (threshold > 1.80) { threshold = 1.80; }
        Application.Storage.setValue("repThreshold", threshold);
        WatchUi.requestUpdate();
    }

    function todayKey() as String {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            now.year.format("%04d"),
            now.month.format("%02d"),
            now.day.format("%02d")
        ]);
    }

    // Dopisuje policzone pompki do dzisiejszego dnia (ta sama struktura co reszta apki)
    function addToToday(amount as Number) as Void {
        var hist = Application.Storage.getValue("pushUpHistory");
        if (hist == null || !(hist instanceof Dictionary)) {
            hist = {};
        }
        var key = todayKey();
        var cur = hist[key];
        if (cur == null) { cur = 0; }
        hist[key] = cur + amount;
        Application.Storage.setValue("pushUpHistory", hist);
    }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        var accel = sensorData.accelerometerData;
        if (accel == null) { return; }
        var xs = accel.x;
        var ys = accel.y;
        var zs = accel.z;
        if (xs == null || ys == null || zs == null) { return; }
        var n = xs.size();
        if (n == 0) { return; }

        var low = threshold - lowGap;
        var detected = false;

        for (var i = 0; i < n; i++) {
            var xr = xs[i];
            var yr = ys[i];
            var zr = zs[i];
            if (xr == null || yr == null || zr == null) { continue; }
            var xg = xr / 1000.0;
            var yg = yr / 1000.0;
            var zg = zr / 1000.0;
            var mag = Math.sqrt(xg * xg + yg * yg + zg * zg);

            if (state == 0) {
                // czekamy na przekroczenie progu w gore
                if (mag >= threshold) {
                    var nowMs = System.getTimer();
                    if (nowMs - lastRepMs > 400) {  // refrakcja
                        repCount++;
                        lastRepMs = nowMs;
                        detected = true;
                    }
                    state = 1;  // i tak czekamy az opadnie
                }
            } else {
                // czekamy az sygnal wroci ponizej LOW (histereza)
                if (mag <= low) {
                    state = 0;
                }
            }
        }

        // Ostatnia probka do podgladu MAG
        var lx = xs[n - 1];
        var ly = ys[n - 1];
        var lz = zs[n - 1];
        if (lx != null && ly != null && lz != null) {
            var fx = lx / 1000.0;
            var fy = ly / 1000.0;
            var fz = lz / 1000.0;
            curMag = Math.sqrt(fx * fx + fy * fy + fz * fz);
        }

        if (detected) {
            flashUntil = System.getTimer() + 250;
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(60, 80)]);
            }
        }

        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {}

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        // --- Status u gory ---
        if (counting) {
            dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 30, Graphics.FONT_XTINY, "LICZE...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 30, Graphics.FONT_XTINY, "GOTOWY - START", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- Wielka liczba repow (miga zielono przy zaliczeniu) ---
        var flashing = (System.getTimer() < flashUntil);
        if (flashing) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, cy - 100, Graphics.FONT_NUMBER_THAI_HOT,
                    repCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // --- Etykieta ---
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 38, Graphics.FONT_XTINY, "POMPKI (auto)", Graphics.TEXT_JUSTIFY_CENTER);

        // --- Pasek MAG vs PROG (do strojenia czulosci) ---
        drawMagBar(dc, cx, cy + 68, w);

        // --- Prog + podpowiedz UP/DOWN ---
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 96, Graphics.FONT_XTINY,
                    "PROG " + threshold.format("%.2f") + "g  (UP/DOWN)",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // --- Komunikat o zapisie ---
        if (!counting && lastSaved > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h - 52, Graphics.FONT_XTINY,
                        "Zapisano: " + lastSaved.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- Sterowanie ---
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, Graphics.FONT_XTINY,
                    counting ? "START=stop+zapis  BACK=wyjscie" : "START=licz  BACK=wyjscie",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Poziomy pasek: zakres 1.0g..2.0g, wypelnienie = aktualne MAG, znacznik = PROG
    function drawMagBar(dc as Dc, cx as Number, y as Number, w as Number) as Void {
        var bl = 55;
        var br = w - 55;
        var bw = (br - bl).toFloat();
        var bh = 10;

        // tlo
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bl, y, (bw).toNumber(), bh);

        // wypelnienie wg MAG (1.0..2.0 -> 0..1)
        var fill = (curMag - 1.0);
        if (fill < 0.0) { fill = 0.0; }
        if (fill > 1.0) { fill = 1.0; }
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bl, y, (bw * fill).toNumber(), bh);

        // znacznik progu
        var tp = (threshold - 1.0);
        if (tp < 0.0) { tp = 0.0; }
        if (tp > 1.0) { tp = 1.0; }
        var tx = bl + (bw * tp).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 1, y - 4, 3, bh + 8);
    }
}
