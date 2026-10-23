import QtQuick
import Quickshell
import "Lock"

// Benchmark harness: one lock screen design in a plain window, driven by
// tests/bench-lock-load.sh. BENCH_DESIGN picks the design, BENCH_SIZE the
// "WxH" of the window (the design animates as it would on a real screen).
ShellRoot {
  FloatingWindow {
    id: win
    color: "black"
    implicitWidth: parseInt((Quickshell.env("BENCH_SIZE") || "1920x1080").split("x")[0])
    implicitHeight: parseInt((Quickshell.env("BENCH_SIZE") || "1920x1080").split("x")[1])
    title: "lock-bench"

    LockHost {
      anchors.fill: parent
      designId: Quickshell.env("BENCH_DESIGN") || "card"
      // BENCH_WALLPAPER=/path/to/image.jpg measures the design with a wallpaper.
      loadBackground: (Quickshell.env("BENCH_WALLPAPER") || "") !== ""
      backgroundPath: Quickshell.env("BENCH_WALLPAPER") || ""
    }
  }
}
