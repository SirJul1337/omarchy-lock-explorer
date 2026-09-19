import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The cells of the Omarchy logo scatter as stars, fall into a black hole and
// burst out as the logo. A wrong password spins it into rings.
IconLock {
  logoEffect: "blackhole"
  logoRate: 150
  failEffect: "rings"
  backgroundDarkness: 2.6
  padColumns: 50
  padRows: 14
  logoScale: 0.34
  effectOptions: ({
    blackhole: ["--blackhole-color", Ttfx.hex(Color.lock.borderActive),
                "--star-colors", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
    rings: ["--spin-duration", "80", "--disperse-duration", "50", "--spin-disperse-cycles", "1",
            "--ring-colors", Ttfx.hex(Color.lock.textError), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
            "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
  })
}
