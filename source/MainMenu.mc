import Toybox.Lang;
import Toybox.WatchUi;

//! Main menu: access to target, diagnostics log, log font size and clearing.
class MainMenu extends WatchUi.Menu {

    function initialize() {
        Menu.initialize();
        setTitle("Menu");
        addItem("Target", :target);
        addItem("View Log", :log);
        addItem("Font Size", :fontSize);
        addItem("Delete Log", :clearLog);
        addItem("Test Alarm", :testAlarm);
        
    }
}

class MainMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :target) {
            WatchUi.pushView(new TargetPicker(), new TargetPickerDelegate(), WatchUi.SLIDE_UP);
        } else if (item == :log) {
            var logView = new LogView();
            WatchUi.pushView(logView, new LogViewDelegate(logView), WatchUi.SLIDE_LEFT);
        } else if (item == :fontSize) {
            WatchUi.pushView(new FontSizeMenu(), new FontSizeMenuDelegate(), WatchUi.SLIDE_UP);
        } else if (item == :testAlarm) {
            Alarm.vibrate();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :clearLog) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete log?"), new ClearLogDelegate(), WatchUi.SLIDE_UP);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

//! Confirmation handler for clearing the log.
class ClearLogDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            Logbook.clear();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
