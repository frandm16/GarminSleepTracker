import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Detection pass run by the foreground timer. Reads the device histories,
//! recomputes the sleep classification for the whole session, updates the
//! persisted state, logs rich diagnostics and fires the alarm when the target
//! is reached.
class DetectionEngine {

    //! Run one detection pass. Safe to call from the foreground.
    static function tick() as Void {
        if (!SleepState.isActive()) {
            return;
        }
        var nowEpoch = Time.now().value();
        var startEpoch = SleepState.getStartEpoch();
        if (startEpoch <= 0) {
            return;
        }

        var fromEpoch = startEpoch - 600; // include a little pre-start context
        if (fromEpoch < 0) {
            fromEpoch = 0;
        }

        var hr = HistoryReader.readHeartRate(fromEpoch, nowEpoch);
        var stress = HistoryReader.readStress(fromEpoch, nowEpoch);
        var bb = HistoryReader.readBodyBattery(fromEpoch, nowEpoch);

        var det = new SleepDetector();
        det.run(hr, stress, bb, fromEpoch, nowEpoch);

        var sleepSeconds = det.getSleepSeconds();
        var detState = det.getState();
        var onsetEpoch = det.getOnsetEpoch();

        // Write the persisted state only when it changes, to avoid flash
        // writes on every tick (the value only moves at 5-min bucket edges).
        if (SleepState.getSleepSeconds() != sleepSeconds) {
            SleepState.setSleepSeconds(sleepSeconds);
        }
        if (SleepState.getDetState() != detState) {
            SleepState.setDetState(detState);
        }
        var currentOnset = SleepState.getOnsetEpoch();
        if (currentOnset == 0 && onsetEpoch > 0) {
            SleepState.setOnsetEpoch(onsetEpoch);
        }

        var targetSeconds = SleepState.getTargetMinutes() * 60;
        var remaining = targetSeconds - sleepSeconds;
        var alarmFired = SleepState.getAlarmFired();

        // Write the diagnostics line at most every 5 minutes to save battery
        // (the state itself is updated on every tick).
        if (nowEpoch - SleepState.getLastLog() >= 300) {
            var bat = System.getSystemStats().battery;
            Logbook.appendEvent(nowEpoch, sleepSeconds, remaining, detState, onsetEpoch,
                det.getRestingHr(), bat.toNumber(),
                summarizeRange(hr.size(), rangeOf(hr)),
                summarizeRange(stress.size(), rangeOf(stress)),
                summarizeRange(bb.size(), rangeOf(bb)));
            SleepState.setLastLog(nowEpoch);
        }

        if (!alarmFired && remaining <= 0) {
            // Goal reached: fire the alarm.
            SleepState.setAlarmFired(true);
            SleepState.setLastVib(nowEpoch);
            Alarm.vibrate();
        } else if (alarmFired) {
            // Alarm sounding: repeat every 5 minutes until the user stops.
            var lastVib = SleepState.getLastVib();
            if (lastVib <= 0 || nowEpoch - lastVib >= 300) { // every 6 min
                SleepState.setLastVib(nowEpoch);
                Alarm.vibrate();
            }
        }
    }

    //! [min, max] of a sample array (integer), or null if empty.
    private static function rangeOf(samples as Array<Dictionary>) as Array<Number> or Null {
        if (samples.size() == 0) {
            return null;
        }
        var lo = (samples[0][:value] as Number).toNumber();
        var hi = lo;
        for (var i = 1; i < samples.size(); i++) {
            var v = (samples[i][:value] as Number).toNumber();
            if (v < lo) { lo = v; }
            if (v > hi) { hi = v; }
        }
        return [ lo, hi ];
    }

    //! "count[lo-hi]" for the log, or "0" if no data.
    private static function summarizeRange(count as Number, r as Array<Number> or Null) as String {
        if (r == null) {
            return "0";
        }
        return count.toString() + "[" + (r[0] as Number).toString() + "-" + (r[1] as Number).toString() + "]";
    }
}
