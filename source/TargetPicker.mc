import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const MINUTE_FORMAT = "%02d";

class DurationNumberFactory extends WatchUi.PickerFactory {

    private var _start as Number;
    private var _stop as Number;
    private var _increment as Number;
    private var _formatString as String;
    private var _font as FontDefinition;

    function initialize(start as Number, stop as Number, increment as Number, options as {
        :font as FontDefinition,
        :format as String
    }) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _increment = increment;
        var format = options.get(:format);
        _formatString = (format == null) ? "%d" : (format as String);
        var font = options.get(:font);
        _font = (font == null) ? Graphics.FONT_NUMBER_HOT : (font as FontDefinition);
    }

    function getIndex(value as Number) as Number {
        return (value / _increment) - _start;
    }

    function getDrawable(index as Number, selected as Boolean) as Drawable or Null {
        var value = getValue(index);
        var text = "?";
        if (value != null) {
            text = (value as Number).format(_formatString);
        }
        return new WatchUi.Text({ :text => text, :color => Graphics.COLOR_WHITE, :font => _font,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_CENTER });
    }

    function getValue(index as Number) as Object or Null {
        return _start + (index * _increment);
    }

    function getSize() as Number {
        return (_stop - _start) / _increment + 1;
    }
}

//! Picker to adjust the target sleep duration (hours + minutes).
class TargetPicker extends WatchUi.Picker {

    function initialize() {
        var title = new WatchUi.Text({ :text => "Target", :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM, :color => Graphics.COLOR_WHITE });

        var factories = new Array<PickerFactory or Text>[2];
        factories[0] = new DurationNumberFactory(0, 12, 1, {});
        factories[1] = new DurationNumberFactory(0, 59, 5, { :format => MINUTE_FORMAT });

        var target = SleepState.getTargetMinutes();
        var hour = target / 60;
        var min = target % 60;

        var defaults = new Array<Number>[2];
        defaults[0] = (factories[0] as DurationNumberFactory).getIndex(hour);
        defaults[1] = (factories[1] as DurationNumberFactory).getIndex(min);

        Picker.initialize({ :title => title, :pattern => factories, :defaults => defaults });
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class TargetPickerDelegate extends WatchUi.PickerDelegate {

    function initialize() {
        PickerDelegate.initialize();
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var hour = values[0] as Number;
        var min = values[1] as Number;
        var target = hour * 60 + min;
        if (target > 720) {
            target = 720;
        }
        SleepState.setTargetMinutes(target);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
