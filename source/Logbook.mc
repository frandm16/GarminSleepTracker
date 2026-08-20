import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

//! Bounded CSV diagnostics log stored in the Object Store as a small ring of
//! chunk keys. Each background event appends one compact line so the whole
//! night fits in a few KB. The raw histories themselves stay on the device.
module Logbook {

    const KEY_HEAD = "logHead";
    const CHUNKS = 8;
    const CHUNK_MAX = 1500;

    //! Append a line (newline terminated by the caller or added here).
    function append(line as String) as Void {
        var head = getHead();
        var chunk = getChunk(head);
        var combined = chunk + line + "\n";
        if (combined.length() > CHUNK_MAX) {
            head = (head + 1) % CHUNKS;
            setHead(head);
            setChunk(head, line + "\n");
        } else {
            setChunk(head, combined);
        }
    }

    //! Log one detection pass for offline analysis, split into three short
    //! lines so every field is visible on the watch screen. Includes the
    //! detected onset, resting HR, battery %, and the value ranges.
    function appendEvent(nowEpoch as Number, sleepSeconds as Number, remaining as Number, detState as Number, onsetEpoch as Number, rhr as Number, bat as Number, hrSummary as String, stressSummary as String, bbSummary as String) as Void {
        var line1 = Util.fmtClockFull(nowEpoch)
            + " sl=" + (sleepSeconds / 60).toNumber().toString()
            + "m rem=" + (remaining / 60).toNumber().toString()
            + "m st=" + detState.toString();
        var onsetStr = (onsetEpoch > 0) ? Util.fmtClock(onsetEpoch) : "-";
        var line2 = "bat=" + bat.toString()
            + " ini=" + onsetStr
            + " rhr=" + rhr.toString();
        var line3 = "H=" + hrSummary + " S=" + stressSummary + " B=" + bbSummary;
        append(line1);
        append(line2);
        append(line3);
    }

    function appendSessionStart() as Void {
        append("== START " + Util.fmtClockFull(Time.now().value()) + " ==");
    }

    function appendSessionEnd() as Void {
        append("== END " + Util.fmtClockFull(Time.now().value()) + " ==");
    }

    //! Erase the whole log.
    function clear() as Void {
        for (var i = 0; i < CHUNKS; i++) {
            setChunk(i, "");
        }
        setHead(0);
    }

    //! Read all log lines in chronological order (oldest first).
    function readLines() as Array<String> {
        var lines = new Array<String>[0];
        var head = getHead();
        for (var i = 1; i <= CHUNKS; i++) {
            var idx = (head + i) % CHUNKS;
            var chunk = getChunk(idx);
            var rest = chunk;
            while (rest.length() > 0) {
                var nl = rest.find("\n");
                var line;
                if (nl != null) {
                    line = rest.substring(0, nl);
                    rest = rest.substring(nl + 1, rest.length());
                } else {
                    line = rest;
                    rest = "";
                }
                if (line != null && line.length() > 0) {
                    lines.add(line);
                }
            }
        }
        return lines;
    }

    function getHead() as Number {
        var v = null;
        try {
            v = Storage.getValue(KEY_HEAD);
        } catch (e) {
            return 0;
        }
        return (v == null) ? 0 : (v as Number);
    }

    function setHead(v as Number) as Void {
        try {
            Storage.setValue(KEY_HEAD, v);
        } catch (e) {
        }
    }

    function getChunk(i as Number) as String {
        var v = null;
        try {
            v = Storage.getValue("log" + i.toString());
        } catch (e) {
            return "";
        }
        return (v == null) ? "" : (v as String);
    }

    function setChunk(i as Number, v as String) as Void {
        try {
            Storage.setValue("log" + i.toString(), v);
        } catch (e) {
        }
    }
}
