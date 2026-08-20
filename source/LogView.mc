import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Professional scrolling log viewer. Single scrollable window (no paging):
//! swipe up/down slides through the lines, a scroll bar shows the position,
//! the text is centered and the font size is configurable.
class LogView extends WatchUi.View {

    const SCROLL_STEP = 3;

    private var _lines as Array<String>;
    private var _offset as Number;

    function initialize() {
        View.initialize();
        _lines = new Array<String>[0];
        _offset = 0;
    }

    function onShow() as Void {
        _lines = Logbook.readLines();
        _offset = 0;
    }

    private function logFont() as FontType {
        var f = SleepState.getLogFont();
        if (f == 3) {
            return Graphics.FONT_MEDIUM;
        }
        if (f == 2) {
            return Graphics.FONT_SMALL;
        }
        if (f == 1) {
            return Graphics.FONT_TINY;
        }
        return Graphics.FONT_XTINY;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var font = logFont();
        var lh = dc.getFontHeight(font);
        var total = _lines.size();

        var headerH = lh + 8;
        var maxLines = (height - headerH - 4) / lh;

        // Visible range [start, end).
        var end = total - _offset;
        if (end < 0) {
            end = 0;
        }
        var start = end - maxLines;
        if (start < 0) {
            start = 0;
        }

        drawHeader(dc, width, font, lh, start, end, total);

        var y = headerH;
        for (var i = start; i < end; i++) {
            var line = _lines[i];
            var color = lineColor(line);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var text = line;
            if (isShortMarker(line)) {
                text = (i + 1).toString() + " " + line;
            }
            dc.drawText(width / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
            y += lh;
        }

        // Footer hint when there is more content.
        if (total > maxLines) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - lh - 2, font, "Desliza para ver más", Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawScrollBar(dc, width, height, start, end, total);
    }

    private function drawHeader(dc as Dc, width as Number, font as FontType, lh as Number, start as Number, end as Number, total as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, width, lh + 6);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 3, font, "SLEEP ALARM", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var pos = (start + 1).toString() + "-" + end.toString() + "/" + total.toString();
        dc.drawText(width - 4, 3, font, pos, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, lh + 5, width, lh + 5);
    }

    private function lineColor(line as String) as Graphics.ColorType {
        if (line.find("ERR") != null || line.find("FALLO") != null) {
            return Graphics.COLOR_RED;
        }
        if (line.find("==") != null) {
            return Graphics.COLOR_LT_GRAY;
        }
        return Graphics.COLOR_WHITE;
    }

    //! Short marker lines (START/END, REG, EV, ERR) keep their number; the
    //! longer event lines do not so the content fits the screen.
    private function isShortMarker(line as String) as Boolean {
        return line.find("==") != null
            || line.find("REG") != null
            || line.find("EV ") != null
            || line.find("ERR") != null;
    }

    private function drawScrollBar(dc as Dc, width as Number, height as Number, start as Number, end as Number, total as Number) as Void {
        if (total <= end - start) {
            return;
        }
        var barH = height * (end - start) / total;
        if (barH < 8) {
            barH = 8;
        }
        var barY = height * start / total;
        if (barY + barH > height) {
            barY = height - barH;
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(width - 6, barY, 3, barH);
    }

    //! Slide towards older lines.
    function scrollOlder() as Void {
        if (_offset + SCROLL_STEP <= _lines.size()) {
            _offset += SCROLL_STEP;
        }
        WatchUi.requestUpdate();
    }

    //! Slide towards newer lines.
    function scrollNewer() as Void {
        _offset -= SCROLL_STEP;
        if (_offset < 0) {
            _offset = 0;
        }
        WatchUi.requestUpdate();
    }
}

class LogViewDelegate extends WatchUi.BehaviorDelegate {

    private var _view as LogView;

    function initialize(view as LogView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scrollOlder();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollNewer();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
