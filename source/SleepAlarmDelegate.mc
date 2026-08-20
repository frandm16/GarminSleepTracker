import Toybox.Lang;
import Toybox.WatchUi;

//! Main input handling for the sleep alarm view (standard BehaviorDelegate).
//!
//! Note: with the standard BehaviorDelegate, onSelect fires for BOTH the
//! physical START button and a tap on the screen (as the docs state), so
//! touching the screen also toggles the session.
class SleepAlarmDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SleepAlarmView;

    function initialize(view as SleepAlarmView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            toggleSession();
            return true;
        }

        return false;
    }

    function onBack() as Boolean {
        if (SleepState.isActive()) {
            return true;
        }

        return false;
    }

    function onMenu() as Boolean {
        if (SleepState.isActive()) {
            return true;
        }
        openMenu();
        return true;
    }

    function onNextPage() as Boolean {
        if (SleepState.isActive()) {
            return true;
        }
        openMenu();
        return true;
    }

    private function openMenu() as Void {
        WatchUi.pushView(
            new MainMenu(),
            new MainMenuDelegate(),
            WatchUi.SLIDE_UP
        );
    }

    private function toggleSession() as Void {
        if (SleepState.isActive()) {
            SleepState.stopSession();
            _view.stopTimer();
            _view.refresh();
        } else {
            var target = SleepState.getTargetMinutes();
            SleepState.startSession(target);
            _view.startTimerIfNeeded();
            _view.refresh();
            Notify.vibrate();
        }
    }
}