import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SleepAlarmApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new SleepAlarmView();
        return [ view, new SleepAlarmDelegate(view) ];
    }
}
