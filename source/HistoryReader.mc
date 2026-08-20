import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;

//! Reads the device recorded sensor histories (heart rate, stress, body
//! battery) within a time window. These histories are recorded by the watch's
//! own health monitoring, so reading them costs almost no battery.
//!
//! The read is bounded to the requested window (a Duration period) so we never
//! pull back days of samples; that keeps each detection pass fast and under
//! the device watchdog.
module HistoryReader {

    //! Read heart rate samples in [fromEpoch, toEpoch].
    //! @return Array of { :when as Number, :value as Number }
    function readHeartRate(fromEpoch as Number, toEpoch as Number) as Array<Dictionary> {
        return readHistory(:heartRate, fromEpoch, toEpoch);
    }

    //! Read stress samples in [fromEpoch, toEpoch].
    //! @return Array of { :when as Number, :value as Number }
    function readStress(fromEpoch as Number, toEpoch as Number) as Array<Dictionary> {
        return readHistory(:stress, fromEpoch, toEpoch);
    }

    //! Read body battery samples in [fromEpoch, toEpoch].
    //! @return Array of { :when as Number, :value as Number }
    function readBodyBattery(fromEpoch as Number, toEpoch as Number) as Array<Dictionary> {
        return readHistory(:bodyBattery, fromEpoch, toEpoch);
    }

    //! Internal helper: read a specific history type within a window.
    function readHistory(kind as Symbol, fromEpoch as Number, toEpoch as Number) as Array<Dictionary> {
        var result = new Array<Dictionary>[0];
        if (fromEpoch >= toEpoch) {
            return result;
        }
        var duration = new Time.Duration(toEpoch - fromEpoch);
        var iter = null;
        try {
            if (kind == :heartRate && (Toybox has :SensorHistory) && (SensorHistory has :getHeartRateHistory)) {
                iter = SensorHistory.getHeartRateHistory({ :period => duration, :order => SensorHistory.ORDER_OLDEST_FIRST });
            } else if (kind == :stress && (Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
                iter = SensorHistory.getStressHistory({ :period => duration, :order => SensorHistory.ORDER_OLDEST_FIRST });
            } else if (kind == :bodyBattery && (Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
                iter = SensorHistory.getBodyBatteryHistory({ :period => duration, :order => SensorHistory.ORDER_OLDEST_FIRST });
            }
        } catch (e) {
            return result;
        }
        if (iter == null) {
            return result;
        }

        // Iterate defensively: the simulator and some devices can return
        // samples with null fields or throw during iteration.
        try {
            var sample = iter.next();
            while (sample != null) {
                var when = null;
                if (sample has :when && sample.when != null) {
                    when = sample.when.value();
                }
                var data = null;
                if (sample has :data) {
                    data = sample.data;
                }
                if (when != null && data != null && when >= fromEpoch && when <= toEpoch) {
                    result.add({ :when => when, :value => (data as Number).toNumber() });
                }
                sample = iter.next();
            }
        } catch (e) {
            return result;
        }
        return result;
    }
}
