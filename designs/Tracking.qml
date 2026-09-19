import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The Omarchy logo on a worn tape: it tracks in with noise and glitch lines,
// slips every so often, and a wrong password tears it with red lines.
IconLock {
  logoEffect: "vhstape"
  failEffect: "tear"
  idleEffect: "blip"
  idleInterval: 9000
  backgroundDarkness: 1.4
  padColumns: 8
  padRows: 4
  effectOptions: ({
    vhstape: ["--total-glitch-time", "200", "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
    blip: { effect: "vhstape", args: ["--total-glitch-time", "40", "--glitch-line-chance", "0.25",
            "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)] },
    tear: { effect: "vhstape", args: ["--total-glitch-time", "90", "--glitch-line-chance", "0.4", "--noise-chance", "0.06",
            "--glitch-line-colors", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.textError), Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)),
            "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)] }
  })
}
