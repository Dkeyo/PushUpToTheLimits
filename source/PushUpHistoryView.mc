import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

class PushUpHistoryView extends WatchUi.View {

    var pushUpHistory as Dictionary = {};
    var dailyGoal as Number = 100;
    var dayLabels as Array = ["Pn", "Wt", "Sr", "Cz", "Pt", "Sb", "Nd"];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        var saved = Application.Storage.getValue("pushUpHistory");
        if (saved != null && saved instanceof Dictionary) {
            pushUpHistory = saved;
        }
        var savedGoal = Application.Storage.getValue("dailyGoal");
        if (savedGoal != null && savedGoal instanceof Number) {
            dailyGoal = savedGoal;
        }
    }

    function getDateKey(daysAgo as Number) as String {
        var pastMoment = Time.now().subtract(new Time.Duration(daysAgo * 86400));
        var info = Gregorian.info(pastMoment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            info.year.format("%04d"),
            info.month.format("%02d"),
            info.day.format("%02d")
        ]);
    }

    function getDayOfWeek(daysAgo as Number) as Number {
        var pastMoment = Time.now().subtract(new Time.Duration(daysAgo * 86400));
        var info = Gregorian.info(pastMoment, Time.FORMAT_SHORT);
        // `info.day_of_week` is 1..7 (Mon..Sun). Return 1..7 so callers can use (dow-1) as index.
        return info.day_of_week;
    }

    function getCountForDay(daysAgo as Number) as Number {
        var key = getDateKey(daysAgo);
        var count = pushUpHistory[key];
        if (count == null) { return 0; }
        return count;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        // Naglowek: tytul (bialy) + cel (cyan) - wysoko, z dala od wykresu
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 24, Graphics.FONT_TINY,
                    "OSTATNIE 7 DNI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 50, Graphics.FONT_XTINY,
                    "CEL " + dailyGoal.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        drawBarChart(dc, width, height);
    }

    function drawBarChart(dc as Dc, width as Number, height as Number) as Void {
        // Skala: max z celu i wszystkich 7 dni (slupki nigdy nie przekrocza maxValue)
        var maxValue = dailyGoal;
        for (var j = 0; j < 7; j++) {
            var v = getCountForDay(6 - j);
            if (v > maxValue) { maxValue = v; }
        }
        if (maxValue <= 0) { maxValue = 1; }

        // Obszar wykresu - marginesy dobrane pod OKRAGLY ekran (nic nie ucina)
        var chartTop = 82;              // gora najwyzszego slupka
        var chartBottom = height - 56;  // linia bazowa (nad etykietami dni)
        var labelHeadroom = 16;         // miejsce na liczbe nad slupkiem
        var chartHeight = chartBottom - chartTop - labelHeadroom;

        var sideMargin = 60;            // szeroki margines - rogi kola nie ucinaja
        var chartWidth = width - 2 * sideMargin;
        var barAreaWidth = chartWidth / 7;
        var barWidth = barAreaWidth - 12;

        // Linia celu - przerywana cyan + etykieta na lewym koncu
        var goalY = (chartBottom - (chartHeight * dailyGoal / maxValue)).toNumber();
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var dashX = sideMargin;
        while (dashX < width - sideMargin) {
            dc.drawLine(dashX, goalY, dashX + 3, goalY);
            dashX += 6;
        }

        // Slupki
        for (var i = 0; i < 7; i++) {
            var daysAgo = 6 - i;  // i=0 = 6 dni temu, i=6 = dzis
            var count = getCountForDay(daysAgo);
            var isToday = (daysAgo == 0);
            var x = sideMargin + i * barAreaWidth;
            var barX = x + (barAreaWidth - barWidth) / 2;  // slupek wycentrowany w kolumnie

            var barHeight = 0;
            if (count > 0) {
                barHeight = (chartHeight * count / maxValue).toNumber();
                if (barHeight < 3) { barHeight = 3; }
            }

            if (count == 0) {
                // Pusty dzien - cienki szary kikut na linii bazowej
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barX, chartBottom - 3, barWidth, 3);
            } else if (count >= dailyGoal) {
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barX, chartBottom - barHeight, barWidth, barHeight);
            } else if (isToday) {
                dc.setColor(ACCENT_HI, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barX, chartBottom - barHeight, barWidth, barHeight);
            } else {
                dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barX, chartBottom - barHeight, barWidth, barHeight);
            }

            // Liczba nad slupkiem (nigdy nie wychodzi ponad chartTop)
            if (count > 0) {
                var textY = chartBottom - barHeight - 16;
                if (textY < chartTop - 16) { textY = chartTop - 16; }
                if (isToday) {
                    dc.setColor(ACCENT_HI, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(barX + barWidth / 2, textY,
                            Graphics.FONT_XTINY, count.toString(),
                            Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Etykieta dnia pod linia bazowa
            var dow = getDayOfWeek(daysAgo);
            var label = dayLabels[dow - 1];
            if (isToday) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(barX + barWidth / 2, chartBottom + 6,
                        Graphics.FONT_XTINY, label,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }
}