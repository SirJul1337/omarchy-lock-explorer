#!/usr/bin/env python3
"""Keep the explorer facade in Service.qml in step with what the UI uses.

On Omarchy 4.0.3+ the explorer, editor and designer see the service only
through the facade published via Bridge.js. A member used in the UI but left
out of the facade fails silently at runtime (undefined), so this checks every
`service.<name>` reference and every signal handler on a service Connections
block against the facade's declarations.
"""

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
service = (root / "Service.qml").read_text(encoding="utf-8")

start = service.index("id: explorerApiComponent")
end = service.index("function publishExplorerApi", start)
facade = service[start:end]
declared = set(re.findall(r"property \w+ (\w+):", facade))
declared |= set(re.findall(r"function (\w+)\(", facade))
signals = set(re.findall(r"signal (\w+)\(", facade))

used = set()
handlers = set()
for name in ["Explorer.qml", "Designer.qml", "Editor.qml"]:
    text = (root / name).read_text(encoding="utf-8")
    used |= set(re.findall(r"\bservice\.([A-Za-z_]\w*)", text))
    for block in re.finditer(r"Connections \{\s*target: [\w.]*service\b(.*?)\n  \}", text, re.S):
        handlers |= set(re.findall(r"function on([A-Z]\w*)\(", block.group(1)))

missing = sorted(n for n in used if n not in declared and n not in signals)
def handled(h):
    name = h[0].lower() + h[1:]
    if name in signals:
        return True
    # onFooChanged is the change signal of a declared property.
    return name.endswith("Changed") and name[:-len("Changed")] in declared
missing_signals = sorted(h[0].lower() + h[1:] for h in handlers if not handled(h))
if missing or missing_signals:
    if missing:
        print("used in the UI but not in the explorer facade: " + ", ".join(missing))
    if missing_signals:
        print("handled in the UI but not re-emitted by the facade: " + ", ".join(missing_signals))
    sys.exit(1)

for forbidden in ["enteredPassword", "pendingPassword", "submitPassword", "passwordPam",
                  "fingerprintPam", "facePam", "respondToPasswordPrompt"]:
    if re.search(r"\b" + forbidden + r"\b", facade):
        print("the explorer facade must not expose " + forbidden)
        sys.exit(1)

print("service facade: OK (%d members used by the UI, %d declared)" % (len(used), len(declared)))
