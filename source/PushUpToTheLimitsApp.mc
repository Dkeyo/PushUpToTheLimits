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

    // Wywolywane gdy uzytkownik akceptuje dialog wybudzenia (requestApplicationWake)
    // data = wartosc przekazana przez Background.exit() w ReminderServiceDelegate
    function onBackgroundData(data as Application.PersistableType) as Void {
        // Aplikacja jest juz w foreground - nic dodatkowego nie robimy.
        // getInitialView() zostalo juz wywolane, licznik jest widoczny.
        System.println(">>> onBackgroundData: " + data);
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new ReminderServiceDelegate()];
    }

    // Liczy najblizsze wystapienie godziny:minuty (dzis, a jesli minelo - jutro)
    function nextOccurrence(hour as Number, minute as Number) as Time.Moment {
        var now = Time.now();
        var nowInfo = Gregorian.info(now, Time.FORMAT_SHORT);
        var moment = Gregorian.moment({
            :year => nowInfo.year,
            :month => nowInfo.month,
            :day => nowInfo.day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
        if (!moment.greaterThan(now)) {
            moment = moment.add(new Time.Duration(86400));  // juz minelo dzis -> jutro
        }
        return moment;
    }

    // Rejestruje zdarzenie + ZAPISUJE czas nastepnego remindera (do podgladu w ustawieniach)
    function registerReminder(moment as Time.Moment) as Void {
        Background.deleteTemporalEvent();
        Background.registerForTemporalEvent(moment);
        Application.Storage.setValue("nextReminderEpoch", moment.value());
        System.println(">>> Reminder zarejestrowany, epoch=" + moment.value());
    }

    // Planuje reminder na USTAWIONA godzine (klucz reminderHour - ten sam ktory ustawia UI)
    function scheduleReminder() as Void {
        var enabled = Application.Storage.getValue("reminderEnabled");
        if (enabled == null) { enabled = true; }

        if (!enabled) {
            Background.deleteTemporalEvent();
            Application.Storage.setValue("nextReminderEpoch", null);
            System.println(">>> Reminder wylaczony");
            return;
        }

        var hour = Application.Storage.getValue("reminderHour");
        if (hour == null || !(hour instanceof Number)) { hour = 19; }
        registerReminder(nextOccurrence(hour, 0));
    }

    // TEST: reminder za 5 minut (minimum Garmina) - do szybkiego debugowania
    function scheduleTestReminder() as Void {
        registerReminder(Time.now().add(new Time.Duration(300)));
        System.println(">>> TEST reminder za 5 min");
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
            msg = "Cel " + dailyGoal + " osiagniety! Swietna robota!";
        } else {
            var remaining = dailyGoal - todayCount;
            msg = "Czas na pompki! " + todayCount + "/" + dailyGoal + " (zostalo: " + remaining + ")";
        }

        scheduleNextReminder();

        // KLUCZOWE: prosi system o wyswietlenie dialogu z trescia msg.
        // Bez tego wywolania background odpala sie po cichu - uzytkownik nic nie widzi.
        // Wymaga jednego argumentu typu String (max 255 bajtow) - to tekst dialogu.
        // Dziala dla watch app (device app). Ignorowane tylko dla watch face.
        if (Background has :requestApplicationWake) {
            Background.requestApplicationWake(msg);
        }

        // exit() musi byc ostatnie - konczy proces background
        // msg trafia do AppBase.onBackgroundData() gdy uzytkownik zaakceptuje dialog
        Background.exit(msg);
    }
    
    // Po odpaleniu planuje kolejny reminder na ustawiona godzine (klucz reminderHour)
    function scheduleNextReminder() as Void {
        var hour = Application.Storage.getValue("reminderHour");
        if (hour == null || !(hour instanceof Number)) { hour = 19; }

        var now = Time.now();
        var nowInfo = Gregorian.info(now, Time.FORMAT_SHORT);
        var moment = Gregorian.moment({
            :year => nowInfo.year,
            :month => nowInfo.month,
            :day => nowInfo.day,
            :hour => hour,
            :minute => 0,
            :second => 0
        });
        if (!moment.greaterThan(now)) {
            moment = moment.add(new Time.Duration(86400));  // juz minelo dzis -> jutro
        }

        Background.deleteTemporalEvent();
        Background.registerForTemporalEvent(moment);
        Application.Storage.setValue("nextReminderEpoch", moment.value());
    }
}

function getApp() as PushUpToTheLimitsApp {
    return Application.getApp() as PushUpToTheLimitsApp;
}