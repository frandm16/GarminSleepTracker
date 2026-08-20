import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;

class Notify {

    static function vibrate() as Void {
        if (Attention has :vibrate) {
            var vibes = [
                new Attention.VibeProfile(50, 100), // 50% during 0.1s
                new Attention.VibeProfile(0, 25), // 0% during 0.025s
                new Attention.VibeProfile(75, 100)]; // 75% during 0.1s
            try {
                Attention.vibrate(vibes);
            } catch (e) {
                System.println("Notify.vibrate(): " + e.getErrorMessage());
            }
        }
    }
}
