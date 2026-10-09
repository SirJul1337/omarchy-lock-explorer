import QtQuick
import qs.Commons
import qs.Commons as Commons

// The theme color behind a role name, for the inspector's color swatches.
// Same table as DesignerItem.roleColor, kept here so the panel can draw the
// choices without instantiating a design piece.
QtObject {
  function roleColor(role) {
    var r = String(role || "text")
    if (r.charAt(0) === "#") return r
    switch (r) {
    case "accent": return Commons.Color.lock.borderActive
    case "error": return Commons.Color.lock.textError
    case "placeholder": return Commons.Color.lock.placeholder
    case "surface": return Commons.Color.lock.background
    case "background": return Commons.Color.background
    case "black": return "#000000"
    case "white": return "#ffffff"
    }
    return Commons.Color.lock.text
  }
}
