import Toybox.Lang;
import Toybox.WatchUi;

class PushUpCounterDelegate extends WatchUi.BehaviorDelegate {

    var view as PushUpCounterView;

    function initialize(viewRef as PushUpCounterView) {
        BehaviorDelegate.initialize();
        view = viewRef;
    }

    // START/SELECT = zacznij liczyc / zatrzymaj i zapisz serie
    function onSelect() as Boolean {
        if (view.counting) {
            view.stopSession();
        } else {
            view.startSession();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // UP = bardziej czuly (nizszy prog)
    function onPreviousPage() as Boolean {
        view.adjustThreshold(-0.03);
        return true;
    }

    // DOWN = mniej czuly (wyzszy prog)
    function onNextPage() as Boolean {
        view.adjustThreshold(0.03);
        return true;
    }

    // BACK = zatrzymaj (zapisuje to co policzone) i wyjdz
    function onBack() as Boolean {
        view.stopSession();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
