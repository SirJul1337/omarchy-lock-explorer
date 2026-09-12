#!/usr/bin/env python3
"""Directory-descriptor backed implementation of the safe-paths rules.

safe-paths.sh used to walk a target as a pathname -- a chain of `[[ -L ]]`,
`[[ -d ]]` and `[[ -O ]]` tests -- and then hand the same pathname to
`cd -P`. Every one of those tests resolves the path again, so nothing tied
the directory that was checked to the directory that was written to: an
attacker able to write to any ancestor could swap a component in between and
`cd -P` would follow it. The ownership test was also `-O` alone, which says
who owns a directory but not who may write to it, so an owned but
group- or world-writable ancestor passed.

So the walk happens on file descriptors instead. Each component is opened
with O_NOFOLLOW | O_DIRECTORY relative to its parent's descriptor, which
refuses a symlink outright rather than resolving it, and is then checked
with fstat on that descriptor -- the object itself, not a name that may
since have been pointed elsewhere. Every later step (creating the temporary,
renaming it into place, unlinking) is made relative to the descriptor that
was checked, so no pathname is ever resolved a second time and there is no
window to swap anything into.

Usage, called from safe-paths.sh -- not a public interface:
    safe-paths.py dir  DIR
    safe-paths.py put  DIR NAME MODE   (content on stdin)
    safe-paths.py drop DIR NAME
"""

import errno
import os
import stat
import sys

# A directory anyone but the owner can write to is a directory anyone but the
# owner can swap entries in, so ownership alone is not enough to trust one.
FORBIDDEN_DIR_BITS = stat.S_IWGRP | stat.S_IWOTH


def fail(message):
    sys.stderr.write("safe-paths: %s\n" % message)
    raise SystemExit(1)


def check_dir_fd(fd, shown):
    """Validate an already-open directory: the fstat is on the descriptor, so
    it describes the object we hold and will use, not a name."""
    st = os.fstat(fd)
    if not stat.S_ISDIR(st.st_mode):
        fail("not a directory: %s" % shown)
    if st.st_uid != os.geteuid():
        fail("not a directory we own: %s" % shown)
    if st.st_mode & FORBIDDEN_DIR_BITS:
        fail("refusing a group- or world-writable directory: %s (mode %04o)"
             % (shown, stat.S_IMODE(st.st_mode)))
    return st


def open_home():
    home = os.environ.get("HOME", "")
    if not home or not os.path.isabs(home):
        fail("$HOME is not an absolute path")
    try:
        fd = os.open(home, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as exc:
        fail("cannot open $HOME (%s): %s" % (exc.strerror, home))
    check_dir_fd(fd, home)
    return fd, home


def split_under_home(target, home):
    target = os.path.normpath(target)
    if target != home and not target.startswith(home.rstrip("/") + "/"):
        fail("refusing to write outside $HOME: %s" % target)
    rel = target[len(home.rstrip("/")):].strip("/")
    parts = [p for p in rel.split("/") if p]
    for part in parts:
        if part in (".", ".."):
            fail("bad path component in %s" % target)
    return parts


def descend(target, create):
    """Walk from $HOME to target one component at a time, holding each
    directory open. Returns the descriptor for the final directory."""
    fd, home = open_home()
    shown = home
    try:
        for part in split_under_home(target, home):
            shown = shown + "/" + part
            child = open_child_dir(fd, part, shown, create)
            os.close(fd)
            fd = child
    except BaseException:
        os.close(fd)
        raise
    return fd


def open_child_dir(parent_fd, part, shown, create):
    try:
        child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                        dir_fd=parent_fd)
    except OSError as exc:
        if exc.errno == errno.ELOOP:
            fail("refusing to go through a symlink: %s" % shown)
        if exc.errno == errno.ENOTDIR:
            fail("not a directory: %s" % shown)
        if exc.errno != errno.ENOENT:
            fail("cannot open %s (%s)" % (shown, exc.strerror))
        if not create:
            fail("no such directory: %s" % shown)
        child = make_child_dir(parent_fd, part, shown)
    check_dir_fd(child, shown)
    return child


def make_child_dir(parent_fd, part, shown):
    try:
        os.mkdir(part, 0o755, dir_fd=parent_fd)
    except FileExistsError:
        pass  # raced with someone else creating it; the open below decides
    except OSError as exc:
        fail("cannot create %s (%s)" % (shown, exc.strerror))
    try:
        child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                        dir_fd=parent_fd)
    except OSError as exc:
        fail("cannot open %s after creating it (%s)" % (shown, exc.strerror))
    # mkdir's mode is masked by the umask; restate it on the descriptor so a
    # restrictive umask does not leave a directory the checks then reject.
    try:
        os.fchmod(child, 0o755)
    except OSError:
        pass
    return child


def check_name(name):
    if not name or "/" in name or name in (".", ".."):
        fail("bad file name: %s" % name)
    return name


def refuse_symlink_at(dir_fd, name, shown):
    try:
        st = os.lstat(name, dir_fd=dir_fd)
    except FileNotFoundError:
        return None
    except OSError as exc:
        fail("cannot inspect %s (%s)" % (shown, exc.strerror))
    if stat.S_ISLNK(st.st_mode):
        fail("refusing to replace a symlink: %s" % shown)
    return st


def put(target_dir, name, mode):
    check_name(name)
    dir_fd = descend(target_dir, create=True)
    shown = target_dir.rstrip("/") + "/" + name
    tmp_name = None
    try:
        refuse_symlink_at(dir_fd, name, shown)
        tmp_name, tmp_fd = create_temp(dir_fd, name, shown)
        with os.fdopen(tmp_fd, "wb") as out:
            data = sys.stdin.buffer.read()
            out.write(data)
            out.flush()
            os.fchmod(out.fileno(), mode)
            os.fsync(out.fileno())
        # Re-check immediately before the rename: a symlink that appeared
        # while we were writing must not be replaced silently either.
        refuse_symlink_at(dir_fd, name, shown)
        os.rename(tmp_name, name, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
        tmp_name = None
    finally:
        if tmp_name is not None:
            try:
                os.unlink(tmp_name, dir_fd=dir_fd)
            except OSError:
                pass
        os.close(dir_fd)


def create_temp(dir_fd, name, shown):
    for _ in range(64):
        candidate = ".%s.%s" % (name, os.urandom(6).hex())
        try:
            fd = os.open(candidate,
                         os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=dir_fd)
        except FileExistsError:
            continue
        except OSError as exc:
            fail("cannot create a temporary beside %s (%s)"
                 % (shown, exc.strerror))
        return candidate, fd
    fail("cannot create a temporary beside %s" % shown)


def drop(target_dir, name):
    # Removal is best effort by design: a target that is already gone, or a
    # directory we do not own, is not an error worth stopping an uninstall.
    if not name or "/" in name or name in (".", ".."):
        return
    try:
        dir_fd = descend(target_dir, create=False)
    except SystemExit:
        return
    try:
        st = os.lstat(name, dir_fd=dir_fd)
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
            return
        os.unlink(name, dir_fd=dir_fd)
    except OSError:
        pass
    finally:
        os.close(dir_fd)


def main(argv):
    if len(argv) < 2:
        fail("usage: safe-paths.py dir|put|drop ...")
    action = argv[1]
    if action == "dir" and len(argv) == 3:
        os.close(descend(argv[2], create=True))
    elif action == "put" and len(argv) == 5:
        try:
            mode = int(argv[4], 8)
        except ValueError:
            fail("bad mode: %s" % argv[4])
        if mode & ~0o7777:
            fail("bad mode: %s" % argv[4])
        put(argv[2], argv[3], mode)
    elif action == "drop" and len(argv) == 4:
        drop(argv[2], argv[3])
    else:
        fail("usage: safe-paths.py dir|put|drop ...")


if __name__ == "__main__":
    main(sys.argv)
