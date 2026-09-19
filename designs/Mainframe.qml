import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The Omarchy logo types itself out in ciphertext and decrypts. A wrong
// password knocks cells out of place and corrects them one pair at a time.
IconLock {
  logoEffect: "decrypt"
  logoRate: 120
  failEffect: "errorcorrect"
  failRate: 150
  backgroundDarkness: 2.3
  placeholder: "passphrase"
  effectOptions: ({
    decrypt: ["--typing-speed", "40", "--ciphertext-colors", Ttfx.hex(Color.muted), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
              "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
    errorcorrect: ["--error-pairs", "0.05", "--error-color", Ttfx.hex(Color.lock.textError), "--correct-color", Ttfx.hex(Color.lock.borderActive),
                   "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
  })
}
