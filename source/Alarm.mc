import Toybox.Attention;
import Toybox.Lang;

class Alarm {

    //! Vibrate with the alarm pattern.
    static function vibrate() as Void {
        if (Attention has :vibrate) {
            var vibes = new Array<Attention.VibeProfile>[5];
            vibes[0] = new Attention.VibeProfile(100, 2000);
            vibes[1] = new Attention.VibeProfile(0, 600);
            vibes[2] = new Attention.VibeProfile(100, 2000);
            vibes[3] = new Attention.VibeProfile(0, 600);
            vibes[4] = new Attention.VibeProfile(100, 2000);
            try {
                Attention.vibrate(vibes);
            } catch (e) {
            }
        }
    }
}
