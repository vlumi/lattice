# App Review notes

Paste into **App Review Information ▸ Notes** in App Store Connect. Kept here
so it isn't rewritten from memory each release, and so the Nearby explanation
stays accurate if the flow changes.

Donpa (the sibling app) drew reviewer questions about its local-network
multiplayer — a reviewer testing on one device sees a mode that appears to do
nothing. The fix is to say plainly where it is, that it needs a second device,
and that everything else is testable alone.

---

```
Lattice Five is a single-player pen-and-paper puzzle (Morpion Solitaire). No account, no server, no data collection — everything is on-device.

Everything except one mode is fully testable on a single device: the Free, Daily, Versus (pass-and-play on one device) and History tabs.

NEARBY DUEL — needs two devices

The one exception is "Nearby", an optional local-multiplayer mode. It uses Apple's MultipeerConnectivity over the local network (Wi-Fi/Bluetooth) — there is no server and no internet connection involved.

To reach it:
  1. Open the "Versus" tab.
  2. Tap the two-people icon in the header (top row, beside the score).
  3. Tap "Host a game", pick a mode and variant, then tap "Advertise".
  4. On a SECOND device on the same network, repeat steps 1-2. The hosted
     game appears under "Games nearby"; tap it to ask to join.
  5. Back on the host, accept under "Wants to join", then tap "Start".

With only one device, the second device never appears and the lobby stays on "Looking for a game to join…" — that is expected, not a failure. iOS asks for Local Network permission on first use; discovery cannot work if it's declined.

The app is a Universal Purchase: one binary family for iPhone, iPad and Mac.
```

---

## Also worth knowing at submission

- **Export compliance:** nothing to do. `ITSAppUsesNonExemptEncryption: false`
  is in both targets' Info.plist, which is the whole declaration — uploads skip
  the prompt and ASC asks nothing further. The compliance *document* upload only
  applies to apps that use non-exempt encryption; Lattice uses none (Nearby and
  iCloud ride Apple's own transport, which is exempt).
- **Support URL** routes to the GitHub issue tracker, with no public email.
  Donpa ships the same arrangement and passed review; the private contact
  email belongs in App Review Information, not on the site.
- **Category:** Games → Puzzle, second subcategory Board (see ROADMAP).
