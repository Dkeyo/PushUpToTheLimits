import Toybox.Lang;
import Toybox.WatchUi;

class PushUpHistoryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // BACK = wróć do głównego ekranu
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}