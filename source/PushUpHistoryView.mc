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
        var dow = info.day_of_week - 1;
        if (dow == 0) {
            dow = 7;
        }
        return dow;
    }

    function getCountForDay(daysAgo as Number) as Number {
        var key = getDateKey(daysAgo);
        var count = pushUpHistory[key];
        if (count == null) {
            return 0;
        }
        return count;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        // Tytul - bialy
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 25, Graphics.FONT_TINY, 
                    "OSTATNIE 7 DNI", Graphics.TEXT_JUSTIFY_CENTER);

        // Cel mniejsza czcionka pod tytulem
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 50, Graphics.FONT_XTINY, 
                    "Cel: " + dailyGoal.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        drawBarChart(dc, width, height);
    }

    function drawBarChart(dc as Dc, width as Number, height as Number) as Void {
        // SZTYWNA SKALA: max = cel
        var maxValue = dailyGoal;

        // Obszar wykresu - od 80px od gory do 50px od dolu
        var chartTop = 85;
        var chartBottom = height - 50;
        var chartHeight = chartBottom - chartTop;
        
        // Margines z bokow zeby zmiescic na okraglym ekranie
        var sideMargin = 35;
        var chartWidth = width - 2 * sideMargin;
        var barAreaWidth = chartWidth / 7;
        var barWidth = barAreaWidth - 6;  // wieksze odstepy miedzy slupkami
        var startX = sideMargin;

        // === LINIA CELU (przerywana czerwona pozioma) ===
        var goalY = chartTop;  // gora wykresu = cel
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Rysujemy "przerywana" linie z malych kresek
        var dashLength = 4;
        var gapLength = 3;
        var dashX = startX;
        var endX = startX + chartWidth;
        while (dashX < endX) {
            var dashEnd = dashX + dashLength;
            if (dashEnd > endX) {
                dashEnd = endX;
            }
            dc.drawLine(dashX, goalY, dashEnd, goalY);
            dashX = dashEnd + gapLength;
        }

        // === SLUPKI ===
        for (var i = 6; i >= 0; i--) {
            var count = getCountForDay(i);
            var dayIndex = 6 - i;
            var x = startX + dayIndex * barAreaWidth + 3;
            
            // Wysokosc slupka - max ograniczone do chartHeight
            var displayCount = count;
            var overflow = false;
            if (displayCount > maxValue) {
                displayCount = maxValue;
                overflow = true;
            }
            
            var barHeight = 0;
            if (maxValue > 0) {
                barHeight = (chartHeight * displayCount / maxValue).toNumber();
            }
            
            // Kolor: zielony jesli osiagniety cel, czerwony jesli nie, ciemny jesli 0
            if (count == 0) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            } else if (count >= dailyGoal) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            }
            
            // Slupek
            if (barHeight > 0) {
                dc.fillRectangle(x, chartBottom - barHeight, barWidth, barHeight);
            } else {
                // Cienka linia dla 0
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, chartBottom - 2, barWidth, 2);
            }
            
            // STRZALKA gdy overflow (przekroczony cel)
            if (overflow) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                var arrowX = x + barWidth / 2;
                var arrowY = chartTop - 2;
                // Trojkat skierowany w gore
                dc.fillPolygon([
                    [arrowX, arrowY - 6],
                    [arrowX - 4, arrowY],
                    [arrowX + 4, arrowY]
                ]);
            }
            
            // Etykieta dnia pod slupkiem
            var dow = getDayOfWeek(i);
            var label = dayLabels[dow - 1];
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + barWidth / 2, chartBottom + 5, Graphics.FONT_XTINY, 
                        label, Graphics.TEXT_JUSTIFY_CENTER);
            
            // Liczba nad slupkiem (tylko jesli > 0)
            if (count > 0) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                var textY = chartBottom - barHeight - 18;
                if (overflow) {
                    textY = chartTop - 22;  // pod strzalka jesli overflow
                }
                dc.drawText(x + barWidth / 2, textY, 
                            Graphics.FONT_XTINY, count.toString(), 
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    function onHide() as Void {
    }
}