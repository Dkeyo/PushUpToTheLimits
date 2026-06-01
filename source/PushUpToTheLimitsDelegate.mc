import Toybox.Lang;
import Toybox.WatchUi;

class PushUpToTheLimitsDelegate extends WatchUi.BehaviorDelegate {

    var view;

    function initialize(viewRef) {
        BehaviorDelegate.initialize();
        view = viewRef;
    }

    function onSelect() as Boolean {
        view.addPushUps(10);
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        view.addPushUps(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        view.addPushUps(-1);
        WatchUi.requestUpdate();
        return true;
    }

    // MENU = otwórz ustawienia (a stamtąd wykres albo zmiana opcji)
    function onMenu() as Boolean {
        var menu = new SettingsMenu();
        var delegate = new SettingsMenuDelegate(view);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Boolean {
        view.saveData();
        return false;
    }
}