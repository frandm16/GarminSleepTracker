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
        if (!SleepState.isActive() || SleepState.getAlarmFired()) {
            return;
        }
        var currentTimestamp = Time.now().value();
        var sessionStartTimestamp = SleepState.getStartEpoch();
        if (sessionStartTimestamp <= 0) {
            return;
        }

        var readStartTimestamp = sessionStartTimestamp - 600; // pre-start context
        if (readStartTimestamp < 0) {
            readStartTimestamp = 0;
        }

        var heartRateSamples = HistoryReader.readHeartRate(readStartTimestamp, currentTimestamp);
        var stressSamples = HistoryReader.readStress(readStartTimestamp, currentTimestamp);
        var bodyBatterySamples = HistoryReader.readBodyBattery(readStartTimestamp, currentTimestamp);
        var savedStartSleepTimestamp = SleepState.getOnsetEpoch();

        var sleepDetector = new SleepDetector();
        sleepDetector.run(heartRateSamples, stressSamples, bodyBatterySamples, readStartTimestamp, currentTimestamp, savedStartSleepTimestamp);

        var accumulatedSleepSeconds = sleepDetector.getSleepSeconds();
        var currentDetectionState = sleepDetector.getState();
        var detectedStartSleepTimestamp = sleepDetector.getOnsetEpoch();

        if (SleepState.getSleepSeconds() != accumulatedSleepSeconds) {
            SleepState.setSleepSeconds(accumulatedSleepSeconds);
        }
        if (SleepState.getDetState() != currentDetectionState) {
            SleepState.setDetState(currentDetectionState);
        }
        
        if (savedStartSleepTimestamp == 0 && detectedStartSleepTimestamp > 0) {
            SleepState.setOnsetEpoch(detectedStartSleepTimestamp);
        }

        var targetSleepSeconds = SleepState.getTargetMinutes() * 60;
        var remainingSleepSeconds = targetSleepSeconds - accumulatedSleepSeconds;
        var hasAlarmFired = SleepState.getAlarmFired();

        if (currentTimestamp - SleepState.getLastLog() >= 300) {
            var currentBattery = System.getSystemStats().battery;
            Logbook.appendEvent(currentTimestamp, accumulatedSleepSeconds, remainingSleepSeconds, currentDetectionState, SleepState.getOnsetEpoch(),
                sleepDetector.getRestingHr(), currentBattery.toNumber(),
                summarizeRange(heartRateSamples.size(), rangeOf(heartRateSamples)),
                summarizeRange(stressSamples.size(), rangeOf(stressSamples)),
                summarizeRange(bodyBatterySamples.size(), rangeOf(bodyBatterySamples)));
            SleepState.setLastLog(currentTimestamp);
        }

        if (!hasAlarmFired && remainingSleepSeconds <= 0) {
            SleepState.setAlarmFired(true);
            SleepState.setLastVib(currentTimestamp);
            Alarm.vibrate();
        }
    }

    //! [min, max] of a sample array (integer), or null if empty.
    private static function rangeOf(samples as Array<Dictionary>) as Array<Number> or Null {
        if (samples.size() == 0) {
            return null;
        }
        var min = (samples[0][:value] as Number).toNumber();
        var max = min;
        for (var i = 1; i < samples.size(); i++) {
            var value = (samples[i][:value] as Number).toNumber();
            if (value < min) { min = value; }
            if (value > max) { max = value; }
        }
        return [ min, max ];
    }

    //! "count[min-max]" for the log, or "0" if no data.
    private static function summarizeRange(count as Number, r as Array<Number> or Null) as String {
        if (r == null) {
            return "0";
        }
        return count.toString() + "[" + (r[0] as Number).toString() + "-" + (r[1] as Number).toString() + "]";
    }
}