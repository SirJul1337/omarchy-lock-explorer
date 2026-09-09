#!/usr/bin/env python3
"""Exercise the actual clip generator without starting the lock service."""

import re
import subprocess
import tempfile
from pathlib import Path


source = (Path(__file__).resolve().parents[1] / "Service.qml").read_text()
script = source.split("readonly property string clipDesignScript: '\n", 1)[1].split("\n'", 1)[0]
# Decode the escapes used by this embedded QML string.
script = script.replace("\\'", "'").replace("\\\\", "\\")

with tempfile.TemporaryDirectory(prefix="clip-filenames-") as temporary:
    root = Path(temporary)
    incoming = root / "incoming"
    incoming.mkdir()
    videos = root / "videos"
    designs = root / "designs"

    def generate(name, content=b"original video bytes"):
        original = incoming / name
        original.write_bytes(content)
        result = subprocess.run(
            ["bash", "-c", script, "clipdesign", str(original), str(videos),
             str(designs), 'import "../designs"'],
            check=True, capture_output=True, text=True,
        )
        lines = result.stdout.splitlines()
        assert len(lines) == 1, result.stdout
        target, copied_name = lines[0].split("\t")
        assert re.fullmatch(r"[A-Za-z0-9._-]+", copied_name), copied_name
        assert original.read_bytes() == content
        assert (videos / copied_name).read_bytes() == content
        qml = Path(target).read_text()
        assert len(qml.splitlines()) == 5, qml
        assert qml.splitlines()[-1] == f'ClipDesign {{ clipName: "{copied_name}" }}'
        # The existing service scanner must recover the same name after reload.
        assert re.search(r'clipName: "([^"]*)"', qml).group(1) == copied_name
        return copied_name

    assert generate("normal.mp4") == "normal.mp4"
    for name in [
        'demo"; property bool injected: (console.log("REVIEW_MARKER"), true); property string tail: ".mp4',
        'line\nbreak.mp4', 'tab\tname.mp4', 'carriage\rreturn.mp4',
        'back\\slash.mp4', "single'quote.mp4", "space name.mp4",
        'café🎬.mp4', '-leading.mp4', '$(harmless).mp4',
    ]:
        generate(name)
    first = generate("collision name.mp4", b"first")
    second = generate("collision?name.mp4", b"second")
    assert first != second
    assert (videos / first).read_bytes() == b"first"
    assert (videos / second).read_bytes() == b"second"
    assert generate("collision name.mp4", b"first") == first

print("clip filename regression tests: OK")
