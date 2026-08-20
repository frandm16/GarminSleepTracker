import Toybox.Lang;
import Toybox.WatchUi;

//! Log font size picker. Used both from the app menu and as the system
//! settings page.
class FontSizeMenu extends WatchUi.Menu {

    function initialize() {
        Menu.initialize();
        setTitle("Font Size");
        addItem("XS", :fontXtiny);
        addItem("S", :fontTiny);
        addItem("M", :fontSmall);
        addItem("L", :fontMedium);
    }
}

class FontSizeMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :fontXtiny) {
            SleepState.setLogFont(0);
        } else if (item == :fontTiny) {
            SleepState.setLogFont(1);
        } else if (item == :fontSmall) {
            SleepState.setLogFont(2);
        } else if (item == :fontMedium) {
            SleepState.setLogFont(3);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
