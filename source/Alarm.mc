import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;

class Alarm {

    //! Vibrate with the alarm pattern.
    static function vibrate() as Void {
        if (Attention has :vibrate) {
            var vibes = new Array<Attention.VibeProfile>[5];
            vibes[0] = new Attention.VibeProfile(100, 2000); // 100% during 2s
            vibes[1] = new Attention.VibeProfile(0, 600); // 0% during 600ms
            vibes[2] = new Attention.VibeProfile(100, 2000); // 100% during 2s
            vibes[3] = new Attention.VibeProfile(0, 600); // 0% during 600ms
            vibes[4] = new Attention.VibeProfile(100, 2000); // 100% during 2s
            try {
                Attention.vibrate(vibes);
                System.println("Sonando Alarma!");
            } catch (e) {
            }
        }
    }
}
