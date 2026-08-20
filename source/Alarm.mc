import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;

class Alarm {

    static function vibrate() as Void {
        if (Attention has :vibrate) {
            var vibes = [new Attention.VibeProfile(100, 2000)]; // 100% during 2s
            try {
                Attention.vibrate(vibes);
            } catch (e) {
                System.println("Error al vibrar: " + e.getErrorMessage());
            }
        }
    }
}
