import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The Omarchy logo burns into place in the theme's colors, from the text
// through the accent to the error red, and cools to the theme. A wrong password
// crumbles it to dust and sweeps it back together.
IconLock {
  logoEffect: "burn"
  logoRate: 120
  failEffect: "crumble"
  failRate: 120
  backgroundDarkness: 2
  effectOptions: ({
    burn: ["--starting-color", Ttfx.hex(Color.muted), "--burn-colors", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Qt.lighter(Color.lock.borderActive, 1.3)),
           Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.textError), Ttfx.hex(Qt.darker(Color.lock.textError, 2.2)),
           "--smoke-chance", "0.2", "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
  })
}
