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

        // Promień pierścienia żeby wiedzieć gdzie są narożniki
        var ringRadius = (width / 2 - 8).toFloat();
        
        // === NAROZNIKI - pozycje na podstawie geometrii kola ===
        // Dla kata 45 stopni: x = r*cos(45) = r*0.707, y = r*sin(45) = r*0.707
        // Narożniki powinny być WEWNATRZ pierścienia ale blisko niego
        var cornerOffset = (ringRadius * 0.62).toNumber();  // 62% promienia = wewnątrz pierścienia

        // GORA LEWY (kat 315 stopni = lewy gorny)
        var tlX = centerX - cornerOffset +20;
        var tlY = centerY - cornerOffset + 20;
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tlX, tlY, Graphics.FONT_XTINY, 
                    "STREAK", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tlX, tlY + 16, Graphics.FONT_TINY, 
                    streak.toString() + "d", Graphics.TEXT_JUSTIFY_CENTER);

        // GORA PRAWY (kat 45 stopni = prawy gorny)
        var trX = centerX + cornerOffset - 10;
        var trY = centerY - cornerOffset + 20;
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNames = ["NIE", "PON", "WT", "SR", "CZW", "PT", "SOB"];
        var dayName = dayNames[now.day_of_week - 1];
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(trX, trY, Graphics.FONT_XTINY, 
                    dayName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(trX, trY + 16, Graphics.FONT_TINY, 
                    now.day.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // DOL LEWY (kat 225 stopni = lewy dolny)
        var blX = centerX - cornerOffset + 40;
        var blY = centerY + cornerOffset - 30;
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blX, blY, Graphics.FONT_XTINY, 
                    "WCZORAJ", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blX, blY + 16, Graphics.FONT_TINY, 
                    yesterday.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // DOL PRAWY (kat 135 stopni = prawy dolny)
        var brX = centerX + cornerOffset - 40;
        var brY = centerY + cornerOffset - 30;
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(brX, brY, Graphics.FONT_XTINY, 
                    "REKORD", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(brX, brY + 16, Graphics.FONT_TINY, 
                    best.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // === SRODEK: Duza liczba ===
        if (todayCount >= dailyGoal) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        // Liczba wycentrowana na środku
        dc.drawText(centerX, centerY -100, Graphics.FONT_NUMBER_THAI_HOT, 
                    todayCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // === SEPARATOR poziomy pod liczba ===
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(centerX - 35, centerY +50, centerX + 50, centerY +50);

        // === Postep pod separatorem ===
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY + 52, Graphics.FONT_XTINY, 
                    todayCount.toString() + " / " + dailyGoal.toString(), 
                    Graphics.TEXT_JUSTIFY_CENTER);
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

        var fillColor = Graphics.COLOR_DK_RED;
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
                dc.setPenWidth(3);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
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
        
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(centerX - 80, centerY - 5, centerX + 80, centerY - 5);
        
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
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