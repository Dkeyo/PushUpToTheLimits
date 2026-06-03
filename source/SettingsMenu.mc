import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;

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

        // Pozycja 5: Diagnostyka akcelerometru
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
            // Zapisz nową wartość toggle
            var toggleItem = item as ToggleMenuItem;
            Application.Storage.setValue("reminderEnabled", toggleItem.isEnabled());
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

// Menu wyboru godziny remindera
class HourMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Godzina remindera"});
        // Popularne godziny
        var hours = [7, 9, 12, 15, 17, 18, 19, 20, 21, 22];
        for (var i = 0; i < hours.size(); i++) {
            var h = hours[i];
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