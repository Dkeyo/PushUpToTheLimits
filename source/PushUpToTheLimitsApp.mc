import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;
import Toybox.Attention;

class PushUpToTheLimitsApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        System.println(">>> APP onStart");
        scheduleReminder();
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new PushUpToTheLimitsView();
        var delegate = new PushUpToTheLimitsDelegate(view);
        return [ view, delegate ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new ReminderServiceDelegate()];
    }

    // Pobiera tablice godzin z Storage
    // Domyslnie [12, 16, 19] - trzy reminders
    function getReminderHours() as Array {
        var hours = Application.Storage.getValue("reminderHours");
        if (hours == null || !(hours instanceof Array) || hours.size() == 0) {
            return [12, 16, 19];  // default
        }
        return hours;
    }

    // Planuje NAJBLIZSZY reminder z listy
    function scheduleReminder() as Void {
        var enabled = Application.Storage.getValue("reminderEnabled");
        if (enabled == null) { enabled = true; }
        
        if (!enabled) {
            Background.deleteTemporalEvent();
            System.println(">>> Reminder wylaczony");
            return;
        }
        
        var hours = getReminderHours();
        var now = Time.now();
        var nowInfo = Gregorian.info(now, Time.FORMAT_SHORT);
        
        // Znajdz nastepny reminder
        var nextReminder = null;
        for (var i = 0; i < hours.size(); i++) {
            var h = hours[i];
            var moment = Gregorian.moment({
                :year => nowInfo.year,
                :month => nowInfo.month,
                :day => nowInfo.day,
                :hour => h,
                :minute => 0,
                :second => 0
            });
            if (moment.greaterThan(now)) {
                if (nextReminder == null || moment.lessThan(nextReminder)) {
                    nextReminder = moment;
                }
            }
        }
        
        // Jesli wszystkie godziny dzisiaj juz minely - bierzemy pierwsza z jutra
        if (nextReminder == null) {
            var firstHour = hours[0];
            for (var i = 0; i < hours.size(); i++) {
                if (hours[i] < firstHour) {
                    firstHour = hours[i];
                }
            }
            var tomorrowMoment = Gregorian.moment({
                :year => nowInfo.year,
                :month => nowInfo.month,
                :day => nowInfo.day,
                :hour => firstHour,
                :minute => 0,
                :second => 0
            });
            nextReminder = tomorrowMoment.add(new Time.Duration(86400));
        }
        
        Background.deleteTemporalEvent();
        Background.registerForTemporalEvent(nextReminder);
        System.println(">>> Nastepny reminder zarejestrowany");
    }
}

(:background)
class ReminderServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        System.println("=== TEMPORAL EVENT ===");
        
        var pushUpHistory = Application.Storage.getValue("pushUpHistory");
        var dailyGoal = Application.Storage.getValue("dailyGoal");
        if (dailyGoal == null) { dailyGoal = 100; }
        
        var todayCount = 0;
        if (pushUpHistory != null && pushUpHistory instanceof Dictionary) {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var todayKey = Lang.format("$1$-$2$-$3$", [
                now.year.format("%04d"),
                now.month.format("%02d"),
                now.day.format("%02d")
            ]);
            var count = pushUpHistory[todayKey];
            if (count != null) {
                todayCount = count;
            }
        }
        
        // Wibracja zawsze
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(80, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(80, 300)
            ];
            Attention.vibrate(vibeData);
        }
        
        var msg;
        if (todayCount >= dailyGoal) {
            msg = "GG! Cel " + dailyGoal + " zrobiony!";
        } else {
            var remaining = dailyGoal - todayCount;
            msg = "Pompki: " + todayCount + "/" + dailyGoal + " (zostalo " + remaining + ")";
        }
        
        scheduleNextReminder();
        Background.exit(msg);
    }
    
    // Planuje NAJBLIZSZY z listy godzin
    function scheduleNextReminder() as Void {
        var hours = Application.Storage.getValue("reminderHours");
        if (hours == null || !(hours instanceof Array) || hours.size() == 0) {
            hours = [12, 16, 19];
        }
        
        var now = Time.now();
        var nowInfo = Gregorian.info(now, Time.FORMAT_SHORT);
        
        var nextReminder = null;
        for (var i = 0; i < hours.size(); i++) {
            var h = hours[i];
            var moment = Gregorian.moment({
                :year => nowInfo.year,
                :month => nowInfo.month,
                :day => nowInfo.day,
                :hour => h,
                :minute => 0,
                :second => 0
            });
            if (moment.greaterThan(now)) {
                if (nextReminder == null || moment.lessThan(nextReminder)) {
                    nextReminder = moment;
                }
            }
        }
        
        if (nextReminder == null) {
            var firstHour = hours[0];
            for (var i = 0; i < hours.size(); i++) {
                if (hours[i] < firstHour) {
                    firstHour = hours[i];
                }
            }
            var tomorrowMoment = Gregorian.moment({
                :year => nowInfo.year,
                :month => nowInfo.month,
                :day => nowInfo.day,
                :hour => firstHour,
                :minute => 0,
                :second => 0
            });
            nextReminder = tomorrowMoment.add(new Time.Duration(86400));
        }
        
        Background.deleteTemporalEvent();
        Background.registerForTemporalEvent(nextReminder);
    }
}

function getApp() as PushUpToTheLimitsApp {
    return Application.getApp() as PushUpToTheLimitsApp;
}