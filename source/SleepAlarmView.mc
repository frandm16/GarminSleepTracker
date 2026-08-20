import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Main view: shows session status, runs the foreground detection loop and
//! renders current sleep statistics.
class SleepAlarmView extends WatchUi.View {

    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {

        startTimerIfNeeded();
    }

    function onHide() as Void {
        stopTimer();
    }

    function startTimerIfNeeded() as Void {
        if (SleepState.isActive() && _timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 120000, true);
            DetectionEngine.tick();
        }
    }

    function stopTimer() as Void {
        var t = _timer;

        if (t != null) {
            t.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        DetectionEngine.tick();
    }

    function refresh() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();

        if (!SleepState.isActive()) {
            drawIdle(dc, width);
        } else {
            drawRecording(dc, width);
        }
    }

    // -------------------------------------------------------------------------
    // IDLE
    // -------------------------------------------------------------------------

    private function drawIdle(dc as Dc, width as Number) as Void {

        var height = dc.getHeight();

        var fTitle = Graphics.FONT_MEDIUM;
        var fBig = Graphics.FONT_LARGE;
        var fInfo = Graphics.FONT_SMALL;
        var fSmall = Graphics.FONT_XTINY;

        var centerX = width / 2;
        var barY = height / 2 + 10;
    

        var targetSeconds = SleepState.getTargetMinutes() * 60;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            55,
            fTitle,
            "SLEEP ALARM",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            barY - dc.getFontHeight(fBig),
            fBig,
            Util.fmtDuration(targetSeconds),
            Graphics.TEXT_JUSTIFY_CENTER
        );


        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(
            25,
            barY,
            width - 25,
            barY
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            barY + 4,
            fSmall,
            "SLEEP TARGET",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            height - dc.getFontHeight(fSmall) - 55,
            fInfo,
            "Press START",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            centerX,
            height - 35,
            fSmall,
            "↑  MENU",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // -------------------------------------------------------------------------
    // RECORDING
    // -------------------------------------------------------------------------

    private function drawRecording(dc as Dc, width as Number) as Void {

        var targetSeconds = SleepState.getTargetMinutes() * 60;
        var sleepSeconds = SleepState.getSleepSeconds();

        var remaining = targetSeconds - sleepSeconds;

        if (remaining < 0) {
            remaining = 0;
        }

        var onsetEpoch = SleepState.getOnsetEpoch();
        var detState = SleepState.getDetState();

        if (SleepState.getAlarmFired()) {
            drawAlarm(dc, width, sleepSeconds, targetSeconds);
            return;
        }

        var height = dc.getHeight();
        var centerX = width / 2;

        var fState = Graphics.FONT_MEDIUM;
        var fTime = Graphics.FONT_LARGE;
        var fInfo = Graphics.FONT_SMALL;
        var fSmall = Graphics.FONT_XTINY;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX,
            55,
            fState,
            stateLabel(detState),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            55 + dc.getFontHeight(fState),
            fTime,
            Util.fmtDuration(sleepSeconds),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var progress = 0;

        if (targetSeconds > 0) {
            progress = (sleepSeconds * 100) / targetSeconds;

            if (progress > 100) {
                progress = 100;
            }
        }

        var barLeft = 24;
        var barRight = width - 24;
        var barY = 55 + 2 * dc.getFontHeight(fState) + 10;
        var barHeight = 8;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(
            barLeft,
            barY,
            barRight - barLeft,
            barHeight
        );

        if (progress > 0) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            var progressWidth =
                ((barRight - barLeft) * progress) / 100;

            dc.fillRectangle(
                barLeft,
                barY,
                progressWidth,
                barHeight
            );
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            centerX,
            barY + barHeight + 5,
            fSmall,
            progress + "% of target",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var infoY = barY + barHeight + dc.getFontHeight(fSmall) + 15;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            infoY,
            fInfo,
            "Target:  " + Util.fmtDuration(targetSeconds),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (onsetEpoch > 0 ) {
            infoY += dc.getFontHeight(fSmall) + 10;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                infoY,
                fInfo,
                "Start:  " + Util.fmtClock(onsetEpoch),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }


        infoY += dc.getFontHeight(fSmall) + 10;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            infoY,
            fInfo,
            "Rem:  " + Util.fmtDuration(remaining),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            height - 35,
            fSmall,
            "↑  MENU",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // -------------------------------------------------------------------------
    // ALARM
    // -------------------------------------------------------------------------

    private function drawAlarm( dc as Dc,width as Number,sleepSeconds as Number,targetSeconds as Number) as Void {

        var height = dc.getHeight();
        var centerX = width / 2;

        var fTitle = Graphics.FONT_MEDIUM;
        var fTime = Graphics.FONT_LARGE;
        var fInfo = Graphics.FONT_SMALL;
        var fSmall = Graphics.FONT_XTINY;

        var barY = height / 2 - 10;

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            55,
            fTitle,
            "WAKE UP!",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            barY - dc.getFontHeight(fTime),
            fTime,
            Util.fmtDuration(sleepSeconds),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawLine(
            25,
            barY,
            width - 25,
            barY
        );

        dc.drawText(
            centerX,
            barY + 4,
            fSmall,
            "SLEEP TIME",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            centerX,
            barY + 30,
            fInfo,
            "Target:  " + Util.fmtDuration(targetSeconds),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            height - dc.getFontHeight(fInfo) - 50,
            fInfo,
            "Press START",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            centerX,
            height - 40,
            fSmall,
            "STOP ALARM",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // -------------------------------------------------------------------------
    // STATE LABEL
    // -------------------------------------------------------------------------

    private function stateLabel(det as Number) as String {

        if (det == SleepDetector.STATE_ASLEEP) {
            return "ASLEEP";
        }

        if (det == SleepDetector.STATE_MAYBE_ASLEEP) {
            return "ASLEEP?";
        }

        if (det == SleepDetector.STATE_MAYBE_AWAKE) {
            return "WAKING UP";
        }

        return "AWAKE";
    }
}