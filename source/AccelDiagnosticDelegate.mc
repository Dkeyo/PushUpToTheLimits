import Toybox.Lang;
import Toybox.WatchUi;

class AccelDiagnosticDelegate extends WatchUi.BehaviorDelegate {

    var view as AccelDiagnosticView;

    function initialize(viewRef as AccelDiagnosticView) {
        BehaviorDelegate.initialize();
        view = viewRef;
    }

    // Main button (SELECT/START) = toggle recording
    function onSelect() as Boolean {
        if (view.isRecording) {
            view.stopRecording();
        } else {
            view.startRecording();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // BACK = stop listener and exit
    function onBack() as Boolean {
        view.stopRecording();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
