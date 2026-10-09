import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Ttfx.js" as Ttfx

// Streams of ones and zeros snake in from the edges and settle as the cells
// of the Omarchy logo. A wrong password blows it apart.
IconLock {
  logoEffect: "binarypath"
  logoRate: 180
  failEffect: "unstable"
  backgroundDarkness: 2.2
  padColumns: 40
  padRows: 12
  logoScale: 0.36
  effectOptions: ({
    binarypath: ["--binary-colors", Ttfx.hex(Commons.Color.muted), Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text),
                 "--active-binary-groups", "0.1",
                 "--final-gradient-stops", Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text)],
    unstable: ["--unstable-color", Ttfx.hex(Commons.Color.lock.textError),
               "--final-gradient-stops", Ttfx.hex(Commons.Color.lock.borderActive), Ttfx.hex(Commons.Color.lock.text)]
  })
}
