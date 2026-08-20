import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

//! Persistent session state. All reads/writes go through the Object Store so
//! the state survives app exits and reboots.
module SleepState {

    const KEY_ACTIVE = "active";
    const KEY_TARGET = "target";
    const KEY_START = "start";
    const KEY_SLEEP = "sleep";
    const KEY_DETSTATE = "det";
    const KEY_ONSET = "onset";
    const KEY_ALARM = "alarm";
    const KEY_LAST_VIB = "lastVib";
    const KEY_FONT = "logFont";
    const KEY_LAST_LOG = "lastLog";

    // Detector state (matches SleepDetector enum).
    const DET_AWAKE = 0;

    //! Whether a sleep session is currently recording.
    function isActive() as Boolean {
        return getValue(KEY_ACTIVE, false) as Boolean;
    }

    //! Target sleep duration in minutes.
    function getTargetMinutes() as Number {
        return getValue(KEY_TARGET, 450) as Number;
    }

    //! Session start epoch (seconds).
    function getStartEpoch() as Number {
        return getValue(KEY_START, 0) as Number;
    }

    //! Accumulated confirmed sleep in seconds.
    function getSleepSeconds() as Number {
        return getValue(KEY_SLEEP, 0) as Number;
    }

    //! Current detector state.
    function getDetState() as Number {
        return getValue(KEY_DETSTATE, DET_AWAKE) as Number;
    }

    //! Detected sleep onset epoch (0 = unknown).
    function getOnsetEpoch() as Number {
        return getValue(KEY_ONSET, 0) as Number;
    }

    //! Whether the alarm has already fired.
    function getAlarmFired() as Boolean {
        return getValue(KEY_ALARM, false) as Boolean;
    }

    //! Epoch of the last alarm vibration (for the repeat-every-5-min rule).
    function getLastVib() as Number {
        return getValue(KEY_LAST_VIB, 0) as Number;
    }

    function setLastVib(v as Number) as Void {
        setValue(KEY_LAST_VIB, v);
    }

    //! Log font size: 0 = XTINY (muy chico), 1 = TINY, 2 = SMALL, 3 = MEDIUM.
    function getLogFont() as Number {
        return getValue(KEY_FONT, 0) as Number;
    }

    function setLogFont(v as Number) as Void {
        setValue(KEY_FONT, v);
    }

    //! Epoch of the last diagnostics log line (to avoid writing every tick).
    function getLastLog() as Number {
        return getValue(KEY_LAST_LOG, 0) as Number;
    }

    function setLastLog(v as Number) as Void {
        setValue(KEY_LAST_LOG, v);
    }

    function setTargetMinutes(v as Number) as Void {
        setValue(KEY_TARGET, v);
    }

    //! Begin a new recording session.
    function startSession(targetMinutes as Number) as Void {
        setValue(KEY_ACTIVE, true);
        setValue(KEY_TARGET, targetMinutes);
        setValue(KEY_START, Time.now().value());
        setValue(KEY_SLEEP, 0);
        setValue(KEY_DETSTATE, DET_AWAKE);
        setValue(KEY_ONSET, 0);
        setValue(KEY_ALARM, false);
        setValue(KEY_LAST_VIB, 0);
        Logbook.appendSessionStart();
    }

    //! Stop the current session (keeps the last values for review).
    function stopSession() as Void {
        setValue(KEY_ACTIVE, false);
        Logbook.appendSessionEnd();
    }

    function setSleepSeconds(v as Number) as Void {
        setValue(KEY_SLEEP, v);
    }

    function setDetState(v as Number) as Void {
        setValue(KEY_DETSTATE, v);
    }

    function setOnsetEpoch(v as Number) as Void {
        setValue(KEY_ONSET, v);
    }

    function setAlarmFired(v as Boolean) as Void {
        setValue(KEY_ALARM, v);
    }

    //! Read a value with a fallback default.
    function getValue(key as String, def as Object or Null) as Object or Null {
        var v = null;
        try {
            v = Storage.getValue(key);
        } catch (e) {
            return def;
        }
        if (v == null) {
            return def;
        }
        return v;
    }

    //! Write a value, ignoring storage errors.
    function setValue(key as String, v as Object or Null) as Void {
        try {
            Storage.setValue(key, v);
        } catch (e) {
        }
    }
}
