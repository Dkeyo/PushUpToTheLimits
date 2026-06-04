import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Ustawienia"});

        // Załaduj aktualne wartości
        var dailyGoal = Application.Storage.getValue("dailyGoal");
        if (dailyGoal == null) { dailyGoal = 100; }

        var reminderHour = Application.Storage.getValue("reminderHour");
        if (reminderHour == null) { reminderHour = 19; }

        var reminderEnabled = Application.Storage.getValue("reminderEnabled");
        if (reminderEnabled == null) { reminderEnabled = true; }

        // Podglad czasu nastepnego zaplanowanego remindera
        var nextStr = "brak";
        var nextEpoch = Application.Storage.getValue("nextReminderEpoch");
        if (nextEpoch != null && nextEpoch instanceof Number) {
            var ni = Gregorian.info(new Time.Moment(nextEpoch), Time.FORMAT_SHORT);
            nextStr = ni.hour.format("%02d") + ":" + ni.min.format("%02d");
        }
        
        // Pozycja 1: Historia
        Menu2.addItem(new MenuItem("Historia 7 dni", "Wykres", :history, {}));
        
        // Pozycja 2: Cel dzienny
        Menu2.addItem(new MenuItem("Cel dzienny", dailyGoal.toString() + " pompek", :goal, {}));
        
        // Pozycja 3: Godzina remindera
        var hourStr = reminderHour.format("%02d") + ":00";
        Menu2.addItem(new MenuItem("Godzina remindera", hourStr, :reminderTime, {}));
        
        // Pozycja 4: Reminder ON/OFF
        Menu2.addItem(new ToggleMenuItem(
            "Reminder",
            {:enabled => "Wlaczony", :disabled => "Wylaczony"},
            :reminderToggle,
            reminderEnabled,
            {}
        ));

        // Pozycja 5: Podglad nastepnego remindera (tylko do odczytu)
        Menu2.addItem(new MenuItem("Nast. przypomnienie", nextStr, :reminderNext, {}));

        // Pozycja 6: Test remindera za ~5 min (debug)
        Menu2.addItem(new MenuItem("Test remindera", "za ~5 min", :reminderTest, {}));

        // Pozycja 7: Licznik pompek z akcelerometru
        Menu2.addItem(new MenuItem("Licznik pompek", "Auto-liczenie", :pushCounter, {}));

        // Pozycja 6: Diagnostyka akcelerometru
        Menu2.addItem(new MenuItem("Diagnostyka akcel.", "Pomiar sygnalu", :accelDiag, {}));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    var view;

    function initialize(viewRef) {
        Menu2InputDelegate.initialize();
        view = viewRef;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        
        if (id == :history) {
            // Otwórz wykres
            var historyView = new PushUpHistoryView();
            var historyDelegate = new PushUpHistoryDelegate();
            WatchUi.pushView(historyView, historyDelegate, WatchUi.SLIDE_LEFT);
        }
        else if (id == :goal) {
            // Otwórz wybór celu
            var goalMenu = new GoalMenu();
            var goalDelegate = new GoalMenuDelegate(view);
            WatchUi.pushView(goalMenu, goalDelegate, WatchUi.SLIDE_LEFT);
        }
        else if (id == :reminderTime) {
            // Otwórz wybór godziny
            var hourMenu = new HourMenu();
            var hourDelegate = new HourMenuDelegate(view);
            WatchUi.pushView(hourMenu, hourDelegate, WatchUi.SLIDE_LEFT);
        }
        else if (id == :reminderToggle) {
            // Zapisz nową wartość toggle i przeplanuj/usun reminder
            var toggleItem = item as ToggleMenuItem;
            Application.Storage.setValue("reminderEnabled", toggleItem.isEnabled());
            var app1 = Application.getApp() as PushUpToTheLimitsApp;
            app1.scheduleReminder();
        }
        else if (id == :reminderTest) {
            // Zaplanuj testowy reminder za ~5 min i daj znac
            var app2 = Application.getApp() as PushUpToTheLimitsApp;
            app2.scheduleTestReminder();
            if (WatchUi has :showToast) {
                WatchUi.showToast("Test za ~5 min", {});
            }
        }
        else if (id == :pushCounter) {
            var counterView = new PushUpCounterView();
            var counterDelegate = new PushUpCounterDelegate(counterView);
            WatchUi.pushView(counterView, counterDelegate, WatchUi.SLIDE_LEFT);
        }
        else if (id == :accelDiag) {
            var diagView = new AccelDiagnosticView();
            var diagDelegate = new AccelDiagnosticDelegate(diagView);
            WatchUi.pushView(diagView, diagDelegate, WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Menu wyboru celu dziennego
class GoalMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Cel dzienny"});
        Menu2.addItem(new MenuItem("50 pompek", null, 50, {}));
        Menu2.addItem(new MenuItem("100 pompek", null, 100, {}));
        Menu2.addItem(new MenuItem("150 pompek", null, 150, {}));
        Menu2.addItem(new MenuItem("200 pompek", null, 200, {}));
        Menu2.addItem(new MenuItem("300 pompek", null, 300, {}));
    }
}

class GoalMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    
    function initialize(viewRef) {
        Menu2InputDelegate.initialize();
        view = viewRef;
    }
    
    function onSelect(item as MenuItem) as Void {
        var newGoal = item.getId() as Number;
        Application.Storage.setValue("dailyGoal", newGoal);
        view.dailyGoal = newGoal;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);  // Wróć do głównego
    }
    
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Menu wyboru godziny remindera - pelna doba 0..23
class HourMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Godzina remindera"});
        for (var h = 0; h < 24; h++) {
            var label = h.format("%02d") + ":00";
            Menu2.addItem(new MenuItem(label, null, h, {}));
        }
    }
}

class HourMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    
    function initialize(viewRef) {
        Menu2InputDelegate.initialize();
        view = viewRef;
    }
    
    function onSelect(item as MenuItem) as Void {
        var newHour = item.getId() as Number;
        Application.Storage.setValue("reminderHour", newHour);
        // Przeplanuj reminder na nową godzinę
        var app = Application.getApp() as PushUpToTheLimitsApp;
        app.scheduleReminder();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);  // Wróć do głównego
    }
    
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}