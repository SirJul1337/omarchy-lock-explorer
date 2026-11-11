import QtQuick
import Quickshell
import "Bridge.js" as Bridge

// The overlay entry point. The manifest keeps this plugin loaded so the lock
// service survives a plugin reload, and the shell then builds the overlay at
// login as well. The explorer is most of the plugin's QML, so building it
// there made the shell seconds slower to start on slower machines (issue
// #91). This stands in for it and builds it the first time it is needed: an
// open, or a request from the service the explorer has to act on. Once built
// it stays, as before.
Item {
  id: host

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  // What the shell reads to decide whether a toggle hides or summons.
  readonly property bool opened: explorer.item ? explorer.item.opened === true : false

  // The same adoption as the explorer's (Omarchy 4.0.3+ hands this overlay
  // no service; the service publishes a facade through Bridge.js), so the
  // requests below are heard before the explorer exists.
  readonly property var serviceApi: service ? service : bridged
  property var bridged: Bridge.current()
  property var bridgeUnsubscribe: null
  Component.onCompleted: host.bridgeUnsubscribe = Bridge.subscribe(function(api) { host.bridged = api })
  Component.onDestruction: if (host.bridgeUnsubscribe) host.bridgeUnsubscribe()

  // Calls and service requests that came before the explorer was built,
  // replayed in order once it is.
  property var pending: []

  function deliver(entry) {
    if (explorer.item) { host.run(entry); return }
    host.pending = host.pending.concat([entry])
    explorer.active = true
  }

  function run(entry) {
    var item = explorer.item
    if (entry.call) item[entry.call].apply(item, entry.args)
    else item.replayServiceEvent(entry.event, entry.args)
  }

  function open(payloadJson) { host.deliver({ call: "open", args: [payloadJson] }) }
  function toggle() { host.deliver({ call: "toggle", args: [] }) }
  function close() {
    if (explorer.item) explorer.item.close()
    else host.pending = host.pending.filter(function(e) { return e.call !== "open" && e.call !== "toggle" })
  }

  // Only the requests that do something while the explorer is closed: the
  // rest are about a window that is open, so it already exists.
  Connections {
    target: explorer.item ? null : host.serviceApi
    ignoreUnknownSignals: true
    function onExploreTabRequested(tab) { host.deliver({ event: "onExploreTabRequested", args: [tab] }) }
    function onExploreViewRequested(view) { host.deliver({ event: "onExploreViewRequested", args: [view] }) }
    function onBootDesignLoaded(name, content) { host.deliver({ event: "onBootDesignLoaded", args: [name, content] }) }
    function onBootResnapshotRequested(designId, persist) { host.deliver({ event: "onBootResnapshotRequested", args: [designId, persist] }) }
    function onClipDesignAdded(id) { host.deliver({ event: "onClipDesignAdded", args: [id] }) }
  }

  Loader {
    id: explorer
    active: false
    asynchronous: true
    source: "Explorer.qml"
    onLoaded: {
      item.omarchyPath = Qt.binding(function() { return host.omarchyPath })
      item.shell = Qt.binding(function() { return host.shell })
      item.manifest = Qt.binding(function() { return host.manifest })
      if (host.service) item.service = host.service
      var queue = host.pending
      host.pending = []
      for (var i = 0; i < queue.length; i++) {
        try { host.run(queue[i]) } catch (e) { console.warn("lock-explorer: " + e) }
      }
    }
  }
  // The explorer adopts the bridged facade itself when it has none; a service
  // the shell hands over later still reaches it.
  onServiceChanged: if (explorer.item && host.service) explorer.item.service = host.service
}
