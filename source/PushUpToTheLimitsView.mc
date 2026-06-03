import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Attention;
import Toybox.System;
import Toybox.Math;
import Toybox.Timer;

class PushUpToTheLimitsView extends WatchUi.View {

    var pushUpHistory as Dictionary = {};
    var dailyGoal as Number = 100;
    var celebrating as Boolean = false;
    var currentMessage as String = "";
    var currentSubMessage as String = "";
    var celebrationTimerObj as Timer.Timer or Null = null;

    var celebrationMessages as Array = [

        ["BRAWO!", "Cel osiagniety!"],
        ["SUPER!", "Dalej tak!"],
        ["3MAJ TAK DALEJ", ""],
        
    ];

    function initialize() {
        View.initialize();
    }

    function getTodayKey() as String {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            now.year.format("%04d"),
            now.month.format("%02d"),
            now.day.format("%02d")
        ]);
    }

    function getDateKeyDaysAgo(daysAgo as Number) as String {
        var pastMoment = Time.now().subtract(new Time.Duration(daysAgo * 86400));
        var info = Gregorian.info(pastMoment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            info.year.format("%04d"),
            info.month.format("%02d"),
            info.day.format("%02d")
        ]);
    }

    function getTodayCount() as Number {
        var today = getTodayKey();
        var count = pushUpHistory[today];
        if (count == null) {
            return 0;
        }
        return count;
    }

    function getYesterdayCount() as Number {
        var key = getDateKeyDaysAgo(1);
        var count = pushUpHistory[key];
        if (count == null) {
            return 0;
        }
        return count;
    }

    function getBestDay() as Number {
        var best = 0;
        var keys = pushUpHistory.keys();
        for (var i = 0; i < keys.size(); i++) {
            var count = pushUpHistory[keys[i]];
            if (count != null && count > best) {
                best = count;
            }
        }
        return best;
    }

    function getStreak() as Number {
        var streak = 0;
        for (var i = 0; i < 365; i++) {
            var key = getDateKeyDaysAgo(i);
            var count = pushUpHistory[key];
            if (count == null) {
                count = 0;
            }
            if (count >= dailyGoal) {
                streak += 1;
            } else {
                if (i == 0) {
                    continue;
                }
                break;
            }
        }
        return streak;
    }

    function addPushUps(amount as Number) as Void {
        var today = getTodayKey();
        var current = getTodayCount();
        var newCount = current + amount;
        if (newCount < 0) {
            newCount = 0;
        }
        
        var justReachedGoal = (current < dailyGoal) && (newCount >= dailyGoal);
        pushUpHistory.put(today, newCount);
        saveData();
        
        if (justReachedGoal) {
            celebrate();
        }
    }

    function pickRandomMessage() as Void {
        var randomIndex = Math.rand() % celebrationMessages.size();
        var picked = celebrationMessages[randomIndex];
        currentMessage = picked[0];
        currentSubMessage = picked[1];
    }

    function celebrate() as Void {
        celebrating = true;
        pickRandomMessage();
        
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(75, 150),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(75, 150),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 300)
            ];
            Attention.vibrate(vibeData);
        }
        
        celebrationTimerObj = new Timer.Timer();
        celebrationTimerObj.start(method(:endCelebration), 5000, false);
    }

    function endCelebration() as Void {
        celebrating = false;
        WatchUi.requestUpdate();
    }

    function loadData() as Void {
        var saved = Application.Storage.getValue("pushUpHistory");
        if (saved != null && saved instanceof Dictionary) {
            pushUpHistory = saved;
        } else {
            pushUpHistory = {};
        }
        var savedGoal = Application.Storage.getValue("dailyGoal");
        if (savedGoal != null && savedGoal instanceof Number) {
            dailyGoal = savedGoal;
        }
    }

    function saveData() as Void {
        Application.Storage.setValue("pushUpHistory", pushUpHistory);
        Application.Storage.setValue("dailyGoal", dailyGoal);
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        loadData();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var todayCount = getTodayCount();
        var streak = getStreak();
        var yesterday = getYesterdayCount();
        var best = getBestDay();

        if (celebrating) {
            drawCelebration(dc, centerX, centerY, width, height);
            return;
        }

        // === PIERSCIEN ===
        drawTickRing(dc, centerX, centerY, width, todayCount);

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNames = ["NIE", "PON", "WT", "SR", "CZW", "PT", "SOB"];
        var dayName = dayNames[now.day_of_week - 1];

        // === SYMETRYCZNE RZEDY POL DANYCH (zamiast krzywych 4 katow) ===
        // Dwie rowne kolumny wzgledem srodka + gorny i dolny rzad = symetria
        var colL = centerX - 72;
        var colR = centerX + 72;
        drawField(dc, colL, 56, "STREAK", streak.toString() + "d");
        drawField(dc, colR, 56, dayName, now.day.toString());
        drawField(dc, colL, 330, "WCZ", yesterday.toString());
        drawField(dc, colR, 330, "MAX", best.toString());

        // === HERO: dwukolorowa liczba - pompki (biel/zielen) / cel (cyan) ===
        drawHero(dc, centerX, centerY, todayCount, dailyGoal);

        // === MINI wykres 7 dni - podglad pod liczba ===
        drawMiniBars(dc, centerX, 312);
    }

    // Pole danych: mala cyan etykieta + biala wartosc pod spodem (wycentrowane)
    function drawField(dc as Dc, x as Number, y as Number, label as String, value as String) as Void {
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 16, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Hero: wielka liczba pompek (biel/zielen) + mniejsze "/cel" w cyan,
    // wyrownane do wspolnej dolnej krawedzi - dwukolorowy efekt jak "20:33" na tarczy
    function drawHero(dc as Dc, centerX as Number, centerY as Number,
                      today as Number, goal as Number) as Void {
        var fBig = Graphics.FONT_NUMBER_THAI_HOT;
        var fSmall = Graphics.FONT_NUMBER_MEDIUM;
        var s1 = today.toString();
        var s2 = "/" + goal.toString();
        var w1 = dc.getTextWidthInPixels(s1, fBig);
        var w2 = dc.getTextWidthInPixels(s2, fSmall);
        var hBig = dc.getFontHeight(fBig);
        var hSmall = dc.getFontHeight(fSmall);
        var startX = centerX - (w1 + w2) / 2;
        var topBig = centerY - 100;
        var topSmall = topBig + (hBig - hSmall);  // wyrownanie dolnych krawedzi

        if (today >= goal) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(startX, topBig, fBig, s1, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + w1, topSmall, fSmall, s2, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Maly wykres ostatnich 7 dni - slupki bordo, dzisiejszy jasniejszy
    function drawMiniBars(dc as Dc, centerX as Number, baselineY as Number) as Void {
        var barW = 6;
        var gap = 5;
        var maxH = 30;
        var totalW = 7 * barW + 6 * gap;  // 7 slupkow + 6 odstepow = 72px
        var startX = centerX - totalW / 2;

        // Skala: wzgledem max z 7 dni lub celu (cokolwiek wieksze)
        var maxValue = dailyGoal;
        for (var d = 0; d < 7; d++) {
            var key = getDateKeyDaysAgo(d);
            var c = pushUpHistory[key];
            if (c != null && c > maxValue) { maxValue = c; }
        }
        if (maxValue <= 0) { maxValue = 1; }

        for (var i = 0; i < 7; i++) {
            var daysAgo = 6 - i;  // i=6 = dzis (ostatni slupek po prawej)
            var key = getDateKeyDaysAgo(daysAgo);
            var count = pushUpHistory[key];
            if (count == null) { count = 0; }

            var x = startX + i * (barW + gap);

            var h = 0;
            if (count > 0) {
                h = (maxH * count / maxValue).toNumber();
                if (h < 2) { h = 2; }  // minimalna widoczna wysokosc
            }

            var isToday = (daysAgo == 0);
            if (count == 0) {
                // pusty dzien - szary kikut przy linii bazowej
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, baselineY - 2, barW, 2);
            } else if (isToday) {
                // dzisiejszy slupek - jasny cyan
                dc.setColor(ACCENT_HI, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, baselineY - h, barW, h);
            } else {
                // pozostale dni - cyan
                dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, baselineY - h, barW, h);
            }
        }
    }

    function drawTickRing(dc as Dc, centerX as Number, centerY as Number, 
                          screenWidth as Number, count as Number) as Void {
        var totalTicks = 100;
        var radiusOuter = (screenWidth / 2 - 8).toFloat();
        var radiusInner = radiusOuter - 12;
        var radiusInnerLong = radiusOuter - 20;

        var progress = count.toFloat() / dailyGoal.toFloat();
        if (progress > 1.0) {
            progress = 1.0;
        }
        var filledTicks = (totalTicks * progress).toNumber();

        var fillColor = ACCENT;
        if (count >= dailyGoal) {
            fillColor = Graphics.COLOR_DK_GREEN;
        }

        for (var i = 0; i < totalTicks; i++) {
            var angleDeg = (i * 360.0 / totalTicks) - 90.0;
            var angleRad = angleDeg * Math.PI / 180.0;
            
            var cosA = Math.cos(angleRad);
            var sinA = Math.sin(angleRad);
            
            // Markery co 25 (0%, 25%, 50%, 75%)
            var rIn = radiusInner;
            if (i % 25 == 0) {
                rIn = radiusInnerLong;
            }
            
            var x1 = centerX + (radiusOuter * cosA).toNumber();
            var y1 = centerY + (radiusOuter * sinA).toNumber();
            var x2 = centerX + (rIn * cosA).toNumber();
            var y2 = centerY + (rIn * sinA).toNumber();
            
            if (i < filledTicks) {
                dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
            }
            
            dc.drawLine(x1, y1, x2, y2);
        }
        
        dc.setPenWidth(1);
    }

    function drawCelebration(dc as Dc, centerX as Number, centerY as Number, 
                              width as Number, height as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var todayCount = getTodayCount();
        drawTickRing(dc, centerX, centerY, width, todayCount);

        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY - 90, Graphics.FONT_XTINY, 
                    "CEL OSIAGNIETY", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY - 70, Graphics.FONT_NUMBER_MEDIUM, 
                    todayCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(centerX - 80, centerY - 5, centerX + 80, centerY - 5);

        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY + 5, Graphics.FONT_TINY,
                    currentMessage, Graphics.TEXT_JUSTIFY_CENTER);
        
        if (!currentSubMessage.equals("")) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY + 30, Graphics.FONT_TINY, 
                        currentSubMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        var streak = getStreak();
        if (streak > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY + 70, Graphics.FONT_XTINY, 
                        "Dzien " + streak.toString() + " z rzedu", 
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
        saveData();
    }
}