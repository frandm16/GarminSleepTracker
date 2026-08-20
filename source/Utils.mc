import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

module Util {

    // Pad a number to two digits as a String.
    function pad2(n as Number) as String {
        if (n < 10) {
            return "0" + n;
        }
        return n.toString();
    }

    // Format a duration in seconds as "7h 30m"
    function fmtDuration(seconds as Number) as String {
        var totalMin = (seconds / 60).toNumber();
        var h = totalMin / 60;
        var m = totalMin % 60;
        if (h > 0) {
            return h.toString() + "h " + m.toString() + "m";
        }
        return m.toString() + "m";
    }

    // Format time as "HH:MM"
    function fmtClock(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return pad2(info.hour) + ":" + pad2(info.min);
    }

    // Format time as "HH:MM:SS"
    function fmtClockFull(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return pad2(info.hour) + ":" + pad2(info.min) + ":" + pad2(info.sec);
    }

    function fmtDateTime(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return pad2(info.day) + "/" + pad2(info.month) + "/" + pad2(info.year) + " - " + pad2(info.hour) + ":" + pad2(info.min) + ":" + pad2(info.sec);
    }
}
