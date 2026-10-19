import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Ttfx.js" as Ttfx

// Beams sweep across the Omarchy logo and light it row by row, then a wave of
// the theme colors rolls out from its center every few seconds. A wrong
// password blows it apart and pulls it back in.
IconLock {
  logoEffect: "beams"
  failEffect: "unstable"
  idleEffect: "pulse"
  idleInterval: 6000
  padColumns: 30
  padRows: 8
  effectOptions: ({
    beams: ["--beam-gradient-stops", Ttfx.hex(Qt.lighter(Commons.Color.lock.text, 1.25)), Ttfx.hex(Commons.Color.lock.borderActive),
            "--final-gradient-stops", Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text)],
    pulse: { effect: "colorshift", args: ["--cycles", "1", "--travel-direction", "radial",
             "--gradient-stops", Ttfx.hex(Commons.Color.lock.text), Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text),
             "--final-gradient-stops", Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text)] },
    unstable: ["--unstable-color", Ttfx.hex(Commons.Color.lock.textError),
               "--final-gradient-stops", Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text)]
  })
}
