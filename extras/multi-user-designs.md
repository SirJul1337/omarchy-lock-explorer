# Multiple users on the lock screen — design notes

Ideas only. Nothing here is implemented; the plugin is single-user by construction today
(`DesignBase.qml:43` reads `$USER` from the environment and that is the entire identity model).
This note sketches what multi-user *could* look like in Omarchy's visual language, and what the
base would have to grow for a design to draw it.

## The constraint that shapes every idea

"Multiple users on a lock screen" is three different features wearing one name, and they have
different security stories. Getting this wrong is how a lock screen becomes a way around itself.

**1. Lock.** The Wayland session belongs to one user. `WlSessionLock` (`Service.qml:1953`) locks
*that* session, and the three PAM contexts (`Service.qml:2104-2154`) authenticate
`root.userName` — the running user. Another person's password must never drop this lock. So in
lock mode, multi-user can only mean a **switch-user affordance**: pick someone else, this session
*stays locked*, and the compositor hands the screen to their session (`loginctl activate`) or to
a greeter on a free VT (`chvt`). The picker is a departure gate, not a second door.

**2. Greeter.** If the same design engine ran as a greetd greeter, a full user picker is exactly
right — there is no session to protect yet. Omarchy autologins by default, so this is opt-in
territory, but it is where a roster genuinely belongs. Most of the concepts below are drawn for
the greeter first and degrade gracefully into a switcher.

**3. Personas.** One human, several identities — work / personal — differing only in avatar,
name, wallpaper and design. No security boundary at all; PAM still authenticates the one real
account. Cheapest to build, and it makes the rest of the plugin's customisation shine.

They can share one visual vocabulary. They must not share one mental model, and the *design* is
what communicates which one you are in. A rule worth holding to: **whenever picking a face will
not unlock this screen, the design has to say so before the click, not after.**

## What the base would need

Designs currently get `userName`, `userInitial`, `hasAvatar`, `avatarUrl`. Multi-user needs a
model, and existing designs must keep working untouched:

```qml
// on DesignBase
readonly property var users          // [{ name, realName, avatarUrl, initial, index,
                                     //    hasSession, sessionActive, tty, lastSeen }]
readonly property int  selectedUser  // index into users; 0 is the session owner
readonly property bool canSwitchUser // false ⇒ single-user, draw the old way
signal selectUser(int index)         // move the highlight
signal switchToUser(int index)       // leave; hand the screen over
```

`users` is a one-element array on a normal machine, so a design that renders a rail of
`lock.users` collapses to today's layout for free — the same degrade-quietly move
`VideoWallpaper` makes when no video is set. `realName` means a GECOS lookup
(`getent passwd`), which the repo does not do
anywhere yet; avatar discovery would have to generalise beyond `$HOME` and
`/var/lib/AccountsService/icons/$USER` (`Service.qml:718-725`).

## The identity kit

Shared pieces, so the concepts stay concepts instead of eight separate reinventions.

**Colour.** The tempting move is a per-user hue hashed from the username. Resist that specific
version of it: Omarchy themes are narrow — one accent against a near-monochrome ground — and
arbitrary hues drop foreign colour into Tokyo Night or Gruvbox and instantly read as a different
program. Differentiate by **position, number and face** instead, and keep
`Color.lock.borderActive` as the single accent marking *the current selection only*; everyone
else is `withAlpha(Color.lock.text, 0.45)`.

If users must be colour-coded, the in-repo precedent is Aurora, which derives its palette by
`Qt.hsla` hue-shifting `Color.lock.borderActive` rather than picking colours outright. A small
rotation off the theme accent — say ±25° across at most four users — stays inside the theme's
character the way Aurora does. It is the hash that breaks the look, not the hue.

**Face.** `Avatar { lock: lock; width: 96 }` already handles picture-or-initial, and takes
`borderWidth` / `borderColor` / `shadow` — enough to build every state below without touching it,
once `source`/`initial` can be set per user (they already can: `Avatar.qml:14-15`).

**Ring states.** One ring, four readings, no legend needed:

| ring | meaning |
| --- | --- |
| solid accent | selected, this is who you are about to authenticate as |
| solid dim | logged in, session locked |
| solid dim + accent dot | logged in, session live on another VT |
| dashed / ghost | not logged in — picking them starts a session |

**Index.** Every user gets a number, shown small and monospace next to the name. It is the
keyboard affordance (`1`–`9`), it doubles as the thing that distinguishes two users with no
avatars, and numbered rows are already the Omarchy idiom from the menu and Walker.

**Typography.** `Style.font.family` throughout, names at `Style.font.subtitle`, usernames and
indices at `Style.font.caption`, lowercase. The nerd-font glyphs already in `PasswordField`
(`󰍁`, `󰌾`) extend naturally: `󰀄` for an account, `󰿅` for a live session elsewhere.

## Eight concepts

Each one extends a design that already exists, so they read as members of the same family rather
than a bolted-on feature.

### 1. Roster — the launcher
*Extends: Zen / the Walker idiom.*

A single centred box. It starts as the password field. Press `Ctrl+U` and it becomes a filter:
type any part of a name and the list below narrows, rows showing `󰀄  Nina  nina · tty3`.
Enter picks; the box turns straight back into a password field, now labelled with the chosen
name, and the list collapses upward. One control, two modes, no new chrome — the most Omarchy
solution on the list, and the one that scales past six users without redesign.

The switch-user warning lives in the row itself: a row for a user other than the owner is
prefixed `→` and the footer reads `hands the screen over · this session stays locked`.

### 2. Rail
*Extends: Split (`Split.qml:9`, a 420–560px side panel).*

The panel keeps the clock and the field; a narrow column of avatars runs down its inner edge
with an accent bar that slides between them — the nav-sidebar pattern, at rest. Selecting a user
cross-fades only the name and the avatar in the panel, so the clock and field never move. Quiet,
obvious, and the sliding bar is one `Behavior on y` away from existing code.

### 3. Login — the honest one
*Extends: Terminal, which already draws `hostname login: username` (`Terminal.qml:56`).*

Make that line editable. `omarchy login: ` with a real cursor, Tab completing across known users,
then the password prompt beneath it, then `Last login: Tue Sep 9 08:14 on tty2`. Nothing about
the design changes except that one field becomes live. It is the cheapest concept here and the
most in keeping with Omarchy's terminal-forward character — and it is the one that makes the
greeter case feel native rather than skinned.

### 4. Deck
*Extends: Card + Flip.*

One frosted card per user, stacked with the inactive ones peeking behind by ~12px. Arrow keys
riffle the deck: the chosen card springs forward and the others fan back. Each card carries that
user's own wallpaper blurred behind its glass, which is the single most legible
"this is a different person" signal available and costs nothing new — `Wallpaper` already does
blur/dim/vignette per design. Best at three or four users; a nine-user deck is a mess.

### 5. Bench
*Extends: Dock (`Dock.qml:8`, a 72px bar).*

Avatars sit in the dock along the bottom, macOS-login-window by way of a Wayland bar. The
selected one lifts out of the bar and gains the accent ring; the rest stay small and dim at 45%.
The password field sits directly above the lifted avatar and travels with it horizontally, so the
field is always visually attached to the face it belongs to. That attachment is the whole idea —
it removes any doubt about who you are typing at.

### 6. Pill
*Extends: Island.*

The island already carries an avatar and a slim field in a 64px pill. Click it (or `Ctrl+U`) and
the pill stretches into a row of faces, then collapses back around whichever you pick, the name
morphing in place as it closes. The best micro-interaction of the set and the least useful at
scale — but on a two-person laptop it is the one people will show other people.

### 7. Orbit
*Extends: Constellation / Pond.*

The selected user sits at the centre; the others drift slowly in a wide, dim orbit. Choosing one
swaps the orbit — the new face eases to centre while the old one is let go into the ring. That
family is typing-reactive through `Typing.qml`, so the obvious extra move is for keystrokes to
perturb the orbit rather than the centre: the person you are authenticating as stays perfectly
still while everyone else reacts. Decorative and unapologetic about it, which is the point.

### 8. Marquee
*Extends: Poster / Editorial.*

The selected user's name set enormous (`Poster.qml:10` already runs at 22× base), bled to the
margin. The other users are a small numbered index stacked in the opposite corner —
`2 nina`, `3 jo` — and pressing the digit swaps which name is huge, with the two trading places.
Typographic, keyboard-only, no avatars at all. The design for people who do not want profile
pictures on their lock screen.

## Interaction, shared across all eight

- `Tab` / `Shift+Tab` move the selection; `1`–`9` jump to it; `Esc` always returns to the session
  owner, so a stray keypress never leaves you typing your password at someone else's prompt.
- Typing anything that is not a selection key goes to the password field. The picker never eats
  the keystrokes of someone who just wants to unlock normally.
- Selection is free and reversible; **departure is not**, so `switchToUser` wants a deliberate
  second action — Enter on an already-selected foreign user, not the first Enter. The handover
  itself should be a real transition (the existing unlock animations are right there) so the
  screen visibly *leaves* rather than blinking.
- Failed attempts are per-user. `failedAttempts` is currently global (`DesignBase.qml:17`);
  showing the owner a count that another person earned is misleading.
- The picker must never expose who is logged in when the machine is otherwise locked down. That
  is a policy question worth a setting — `names`, `faces`, or `off` — defaulting to showing only
  the session owner until someone opts in.

## Where it meets the rest of the plugin

Four places the feature touches that are easy to miss until they look broken:

- **The explorer preview.** Designs are previewed against the real user, so every concept here
  would render as a rail of one and the whole category would look broken in the picker. They need
  **seeded fake users**, the way boot snapshots seed a clock.
- **Multiple monitors.** Secondary screens get `Companion` (`Designs.js:57-59`), which is
  deliberately chrome-free — clock, date, invisible input. A user picker belongs on exactly one
  screen, and Companion is already the mechanism that makes that true. Worth stating as a rule
  rather than discovering it on a three-monitor desk: *the roster draws where the field draws.*
- **Boot snapshots.** A design captured as a Plymouth splash (`snapshotMode`, `bootKind:
  "styling"`) has no session and no logged-in state to show. Multi-user designs should either
  collapse to the owner under `snapshotMode` or opt out of `boot:` entirely — Plymouth is before
  any of this exists.
- **Registry.** A new design needs its `Designs.js` entry and a category; these want their own
  chip (`CATEGORIES`, `Designs.js:5-16`) rather than being scattered through Minimal and
  Typography, because "does this machine have several people on it" is exactly the filter a user
  would reach for.

The designer gains a **User rail** piece (`Designer.js:220` already has `username`, `:270` has
`avatar`), with inspector rows for direction, size and overflow behaviour. `lock.users` goes into
Custom QML scope alongside `lock.now` and `lock.userName`, and into the README's design API list.

## If you build one

**Login (3)** first — it is a single editable field in a design that already draws the prompt,
it forces the `users` model and the PAM-user plumbing to be real, and it is honest about the
security model by nature. **Roster (1)** second, because it is the one that scales and the one
that gives the switcher a home in every other design via `Ctrl+U`. The rest are variations on a
picker that works by then, and can land one per release.

Personas (mode 3) are worth considering as a separate, earlier shipment: no PAM changes, no
session switching, no enumeration policy — just the identity kit and a per-persona design and
wallpaper. It would exercise every one of these layouts against zero security surface.
