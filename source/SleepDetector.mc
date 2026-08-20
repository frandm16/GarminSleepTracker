import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

//! Heuristic sleep detector built on the device recorded histories.
//!
//! Every detection pass recomputes the whole night classification from the
//! raw histories, so the result is deterministic and self-healing.
//!
//! Signals (all from SensorHistory):
//!   - Heart rate level and stability (fall + low variance = resting)
//!   - Stress level (HRV based; low = relaxed)
//!   - Body battery slope (rising = Garmin's own sleep detector engaged)
//!
//! Classification is conservative but calibrated for recall: a bucket is
//! asleep if any of:
//!   1. Body battery rising over a ~20 min window PLUS one corroborating
//!      signal (low HR or low stress) - works even at sleep onset when stress
//!      is still high.
//!   2. During the night window (20:00-13:00): low + stable HR alone. This is
//!      the catch-all that catches sleep onset.
//!   3. Only heart rate history available: low + stable.
//! Buckets are built in a single pass over the samples (O(S)), keeping the
//! whole pass fast enough to stay under the device watchdog.
class SleepDetector {

    enum {
        STATE_AWAKE,
        STATE_MAYBE_ASLEEP,
        STATE_ASLEEP,
        STATE_MAYBE_AWAKE
    }

    const BUCKET_SECONDS = 300;   // 5 minutes
    const BB_REF_MIN_AGE = 1200;  // 20 minutes: body battery reference age
    const HRS_TO_MAYBE = 2;       // 2 consecutive asleep buckets -> maybe asleep
    const HRS_TO_ASLEEP = 4;      // 4 consecutive asleep buckets -> confirmed asleep
    const HRS_AWAKE_TO_MAYBE = 2; // 2 consecutive awake buckets -> maybe awake
    const HRS_AWAKE_TO_AWAKE = 4; // 4 consecutive awake buckets -> awake

    private var _state as Number;
    private var _asleepRun as Number;
    private var _awakeRun as Number;
    private var _sleepSeconds as Number;
    private var _pendingSeconds as Number;
    private var _onsetEpoch as Number;
    private var _restingHr as Number;
    private var _bbRing as Array<Dictionary>;
    private var _stressSeen as Boolean;
    private var _bbSeen as Boolean;

    function initialize() {
        _state = STATE_AWAKE;
        _asleepRun = 0;
        _awakeRun = 0;
        _sleepSeconds = 0;
        _pendingSeconds = 0;
        _onsetEpoch = 0;
        _restingHr = 65;
        _bbRing = new Array<Dictionary>[0];
        _stressSeen = false;
        _bbSeen = false;
    }

    //! Classify the whole window [startEpoch, endEpoch] from raw histories.
    function run(hrSamples as Array<Dictionary>, stressSamples as Array<Dictionary>, bbSamples as Array<Dictionary>, startEpoch as Number, endEpoch as Number) as Void {
        _restingHr = estimateRestingHr(hrSamples);
        _stressSeen = stressSamples.size() > 0;
        _bbSeen = bbSamples.size() > 0;
        var buckets = buildBuckets(hrSamples, stressSamples, bbSamples, startEpoch, endEpoch);
        for (var i = 0; i < buckets.size(); i++) {
            processBucket(buckets[i]);
        }
    }

    function getState() as Number { return _state; }
    function getSleepSeconds() as Number { return _sleepSeconds; }
    function getOnsetEpoch() as Number { return _onsetEpoch; }
    function getRestingHr() as Number { return _restingHr; }

    //! Resting HR used as the sleep baseline. Prefers the user's configured
    //! resting heart rate (stable across the night); otherwise falls back to
    //! the minimum HR seen during the session (clamped). A stable baseline is
    //! essential: a running minimum keeps dropping during the night and
    //! re-classifies earlier buckets, making the accumulated sleep oscillate.
    private function estimateRestingHr(hrSamples as Array<Dictionary>) as Number {
        if (Toybox has :UserProfile) {
            try {
                var profile = UserProfile.getProfile();
                if (profile != null && profile.restingHeartRate != null) {
                    var r = profile.restingHeartRate as Number;
                    if (r >= 40 && r <= 120) {
                        return r;
                    }
                }
            } catch (e) {
            }
        }
        if (hrSamples.size() == 0) {
            return 60;
        }
        var min = hrSamples[0][:value] as Number;
        for (var i = 1; i < hrSamples.size(); i++) {
            var v = hrSamples[i][:value] as Number;
            if (v < min) {
                min = v;
            }
        }
        if (min < 45) { return 45; }
        if (min > 90) { return 90; }
        return min;
    }

    //! Group raw samples into 5-minute buckets in a single pass.
    private function buildBuckets(hrSamples as Array<Dictionary>, stressSamples as Array<Dictionary>, bbSamples as Array<Dictionary>, startEpoch as Number, endEpoch as Number) as Array<Dictionary> {
        var first = startEpoch - (startEpoch % BUCKET_SECONDS);
        var numBuckets = ((endEpoch - first) / BUCKET_SECONDS) + 1;

        var bucketStart = new Array<Number>[numBuckets];
        var hrCount = new Array<Number>[numBuckets];
        var hrSum = new Array<Number>[numBuckets];
        var hrSq = new Array<Number>[numBuckets];
        var stressCount = new Array<Number>[numBuckets];
        var stressSum = new Array<Number>[numBuckets];
        var bbCount = new Array<Number>[numBuckets];
        var bbSum = new Array<Number>[numBuckets];

        for (var i = 0; i < numBuckets; i++) {
            bucketStart[i] = first + i * BUCKET_SECONDS;
            hrCount[i] = 0;
            hrSum[i] = 0;
            hrSq[i] = 0;
            stressCount[i] = 0;
            stressSum[i] = 0;
            bbCount[i] = 0;
            bbSum[i] = 0;
        }

        accumulate(hrSamples, first, numBuckets, hrCount, hrSum, hrSq);
        accumulate(stressSamples, first, numBuckets, stressCount, stressSum, null);
        accumulate(bbSamples, first, numBuckets, bbCount, bbSum, null);

        var buckets = new Array<Dictionary>[0];
        for (var i = 0; i < numBuckets; i++) {
            if (hrCount[i] > 0 || stressCount[i] > 0 || bbCount[i] > 0) {
                var hrAvg = null;
                var hrStd = null;
                if (hrCount[i] > 0) {
                    hrAvg = hrSum[i] / hrCount[i];
                    if (hrCount[i] >= 2) {
                        var mean = hrSum[i].toDouble() / hrCount[i];
                        var sq = hrSq[i].toDouble() - mean * mean * hrCount[i];
                        if (sq < 0) {
                            sq = 0;
                        }
                        hrStd = Math.sqrt(sq / hrCount[i]).toNumber();
                    }
                }
                var stressAvg = (stressCount[i] > 0) ? (stressSum[i] / stressCount[i]) : null;
                var bbAvg = (bbCount[i] > 0) ? (bbSum[i] / bbCount[i]) : null;
                buckets.add({
                    :start => bucketStart[i],
                    :hr => hrAvg,
                    :hrStd => hrStd,
                    :stress => stressAvg,
                    :bb => bbAvg
                });
            }
        }
        return buckets;
    }

    //! Single pass: assign each sample to its bucket and accumulate stats.
    private function accumulate(samples as Array<Dictionary>, first as Number, numBuckets as Number, count as Array<Number>, sum as Array<Number>, sq as Array<Number> or Null) as Void {
        for (var i = 0; i < samples.size(); i++) {
            var when = samples[i][:when] as Number;
            var idx = (when - first) / BUCKET_SECONDS;
            if (idx >= 0 && idx < numBuckets) {
                var v = samples[i][:value] as Number;
                count[idx] += 1;
                sum[idx] += v;
                if (sq != null) {
                    sq[idx] += v * v;
                }
            }
        }
    }

    //! Night window covering a normal night and this user's schedule
    //! (falls asleep early morning, wakes late morning).
    private function isNightTime(epoch as Number) as Boolean {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        var hour = info.hour;
        return (hour >= 20 || hour <= 13);
    }

    //! Decide if a 5-minute bucket is asleep. Calibrated for recall from real
    //! night data: stress at sleep onset can be 35-50, so the rules below rely
    //! on body battery trend and night-time low+stable HR rather than on a low
    //! stress threshold alone.
    private function classifyBucket(bucket as Dictionary) as Boolean {
        var hr = bucket[:hr];
        var hrStd = bucket[:hrStd];
        var stress = bucket[:stress];
        var bb = bucket[:bb];
        var bStart = bucket[:start] as Number;

        var hrLow = (hr != null) && ((hr as Number) < _restingHr + 8);
        var stable = (hrStd != null) && ((hrStd as Number) < 6);
        var stressLow = (stress != null) && ((stress as Number) < 35);
        var night = isNightTime(bStart);

        // Body battery rising vs a reading from ~20 minutes ago, judged on
        // every bucket (sliding window of the last ~40 minutes). This catches
        // slow, sustained rises (like this user's 8 -> 59) reliably, including
        // at sleep onset when stress is still high.
        var bbRise = false;
        if (bb != null) {
            var bbVal = bb as Number;
            var refBb = null;
            for (var i = 0; i < _bbRing.size(); i++) {
                if ((_bbRing[i][:start] as Number) <= bStart - BB_REF_MIN_AGE) {
                    refBb = _bbRing[i][:bb] as Number;
                }
            }
            _bbRing.add({ :start => bStart, :bb => bbVal });
            // Trim entries older than ~40 minutes.
            var trimmed = new Array<Dictionary>[0];
            for (var i = 0; i < _bbRing.size(); i++) {
                if ((_bbRing[i][:start] as Number) >= bStart - 2 * BB_REF_MIN_AGE) {
                    trimmed.add(_bbRing[i]);
                }
            }
            _bbRing = trimmed;
            bbRise = (refBb != null) && (bbVal > refBb);
        }

        if (_bbSeen && bbRise && (hrLow || stressLow)) {
            return true;
        }
        if (night && hrLow && stable) {
            return true;
        }
        if (!_bbSeen && !_stressSeen && hrLow && stable) {
            return true;
        }
        return false;
    }

    //! Feed one bucket through the hysteresis state machine.
    private function processBucket(bucket as Dictionary) as Void {
        var asleep = classifyBucket(bucket);
        var bStart = bucket[:start] as Number;
        if (asleep) {
            _asleepRun += 1;
            _awakeRun = 0;
            if (_state == STATE_ASLEEP) {
                _sleepSeconds += BUCKET_SECONDS;
            } else if (_state == STATE_MAYBE_AWAKE) {
                // Brief arousal resolved, back to confirmed sleep.
                _state = STATE_ASLEEP;
                _sleepSeconds += BUCKET_SECONDS;
            } else {
                _pendingSeconds += BUCKET_SECONDS;
                if (_state == STATE_AWAKE && _asleepRun >= HRS_TO_MAYBE) {
                    _state = STATE_MAYBE_ASLEEP;
                }
                if (_state == STATE_MAYBE_ASLEEP && _asleepRun >= HRS_TO_ASLEEP) {
                    _state = STATE_ASLEEP;
                    _sleepSeconds += _pendingSeconds;
                    _pendingSeconds = 0;
                    if (_onsetEpoch == 0) {
                        _onsetEpoch = bStart - (_asleepRun - 1) * BUCKET_SECONDS;
                    }
                }
            }
        } else {
            _awakeRun += 1;
            _asleepRun = 0;
            _pendingSeconds = 0;
            if (_state == STATE_ASLEEP && _awakeRun >= HRS_AWAKE_TO_MAYBE) {
                _state = STATE_MAYBE_AWAKE;
            } else if (_state == STATE_MAYBE_AWAKE && _awakeRun >= HRS_AWAKE_TO_AWAKE) {
                _state = STATE_AWAKE;
            }
        }
    }
}
