#!/usr/bin/env python3
"""Typed text reaches the screen only as plain text.

Qt's Text defaults to AutoText: a string that looks like markup is rendered as
rich text, and rich text loads <img src=...> under the session user. On the
lock screen anyone at the keyboard types the password, and every design can
reveal it (the eye button, Ctrl+E), so a revealed password drawn through
AutoText lets an unauthenticated person make the shell read local files.

This walks every QML file, works out which properties carry typed text
(passwordText, the preview's typed text and anything bound from them), and
fails on any Text-based item whose text binding uses one without
`textFormat: Text.PlainText` on that item or its component. Canvas fillText
and TextInput render plain text and are not checked.
"""

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]

# Expressions that carry what was typed into the lock (or the explorer's preview).
SOURCES = [r"\bpasswordText\b", r"\benteredPassword\b", r"\bpreviewTyped\b",
           r"\bTtfx\.masked\s*\(", r"\btyping\.text\b"]
# Uses that cannot carry markup: lengths and comparisons.
HARMLESS = re.compile(r"\b(passwordText|enteredPassword|previewTyped)\.length\b")

ELEMENT = re.compile(r"^\s*(?:component\s+(\w+)\s*:\s*)?([A-Z][\w.]*)\s*\{")
PROPERTY = re.compile(r"^\s*(?:readonly\s+)?(?:required\s+)?property\s+\w+\s+(\w+)\s*:\s*(.*)$")
BINDING = re.compile(r"^\s*([a-z][\w.]*)\s*:\s*(.*)$")
TEXT_TYPES = {"Text", "Label", "Controls.Label"}


def strip_strings(line):
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', line)


def tainted(expr, names):
    e = HARMLESS.sub("0", strip_strings(expr))
    if any(re.search(s, e) for s in SOURCES):
        return True
    return any(re.search(r"\b" + re.escape(n) + r"\b(?!\s*\.length)", e) for n in names)


def parse(path):
    """Element blocks with their direct bindings, and same-file components."""
    lines = path.read_text(encoding="utf-8").splitlines()
    stack = []  # entries: dict(type, comp, bindings, line) or None for a JS block
    blocks, components = [], {}
    for n, raw in enumerate(lines, 1):
        # Strings blanked first so braces or // inside them count for nothing.
        line = strip_strings(raw).split("//")[0]
        m = ELEMENT.match(line)
        opened = line.count("{")
        closed = line.count("}")
        if m:
            el = {"type": m.group(2), "comp": m.group(1), "bindings": [], "line": n, "file": path}
            if el["comp"]:
                components[el["comp"]] = el
            # Bindings on the same line: Mono { text: x; textFormat: ... }
            rest = line[m.end():]
            for part in rest.split(";"):
                b = BINDING.match(part)
                if b:
                    el["bindings"].append((b.group(1), b.group(2), n))
            blocks.append(el)
            stack.append(el)
            opened -= 1
            if "}" in rest:
                closed -= 1
                stack.pop()
        else:
            cur = next((e for e in reversed(stack) if e is not None), None)
            # Only direct bindings of an element: not inside a JS block.
            if cur is not None and (not stack or stack[-1] is cur):
                p = PROPERTY.match(line)
                b = BINDING.match(line)
                if p:
                    cur["bindings"].append(("property:" + p.group(1), p.group(2), n))
                elif b:
                    cur["bindings"].append((b.group(1), b.group(2), n))
        for _ in range(opened):
            stack.append(None)
        for _ in range(closed):
            if stack:
                stack.pop()
    return blocks, components


def main():
    failures = []
    checked = 0
    files = sorted(p for p in root.rglob("*.qml") if ".claude" not in p.parts and ".git" not in p.parts)
    # A QML file is a component named after it: Caption.qml whose root is a Text
    # makes every Caption { } a Text, plain or not by its own root.
    parsed = {path: parse(path) for path in files}
    file_components = {path.stem: blocks[0] for path, (blocks, _) in parsed.items() if blocks}
    for path in files:
        blocks, local = parsed[path]
        components = dict(file_components)
        components.update(local)
        # Properties bound from typed text, to a fixed point.
        names = set()
        changed = True
        while changed:
            changed = False
            for el in blocks:
                for key, expr, _ in el["bindings"]:
                    if key.startswith("property:") and key[9:] not in names and tainted(expr, names):
                        names.add(key[9:])
                        changed = True

        def text_like(el, seen=()):
            if el["type"] in TEXT_TYPES:
                return True
            c = components.get(el["type"])
            return bool(c and c is not el and el["type"] not in seen and text_like(c, seen + (el["type"],)))

        def plain(el, seen=()):
            for key, expr, _ in el["bindings"]:
                if key == "textFormat":
                    return "Text.PlainText" in expr
            c = components.get(el["type"])
            return bool(c and c is not el and el["type"] not in seen and plain(c, seen + (el["type"],)))

        for el in blocks:
            if not text_like(el):
                continue
            for key, expr, n in el["bindings"]:
                if key == "text" and tainted(expr, names):
                    checked += 1
                    if not plain(el):
                        failures.append(f"{path.relative_to(root)}:{n}: typed text in a {el['type']} without textFormat: Text.PlainText")
    if failures:
        print("typed text rendered as AutoText:")
        print("\n".join("  " + f for f in failures))
        sys.exit(1)
    print(f"typed text: OK ({checked} text bindings carry typed text, all plain)")


if __name__ == "__main__":
    main()
