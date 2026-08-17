# App Review notes

Paste into **App Review Information ▸ Notes** in App Store Connect. Kept here
so it isn't rewritten from memory each release, and so the Nearby explanation
stays accurate if the flow changes.

Donpa (the sibling app) drew reviewer questions about its local-network
multiplayer — a reviewer testing on one device sees a mode that appears to do
nothing. The fix is to say plainly where it is, that it needs a second device,
and that everything else is testable alone.

**Both apps also tripped the automated `com.apple.security.network.server`
check**, which flags the entitlement when it "does not appear to have matching
functionality". The entitlement IS required: hosting a Nearby duel advertises a
Bonjour service and accepts incoming connections, which the App Sandbox blocks
without it. Keep the explanation in the notes block below — the scan runs on
every submission, so leaving it out invites the same rejection next release.

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

WHY THE MAC APP NEEDS com.apple.security.network.server

Hosting a Nearby duel is the functionality that uses it. When a player taps "Advertise" in step 3 above, the Mac app becomes the host: it publishes a Bonjour service (_lattice-duel._tcp/._udp, declared in NSBonjourServices) via MCNearbyServiceAdvertiser and then LISTENS FOR AND ACCEPTS INCOMING connections from other players' devices — MCNearbyServiceAdvertiserDelegate's didReceiveInvitationFromPeer is what handles each join request, which the host approves under "Wants to join".

That is an incoming-connection listener, so the App Sandbox denies it without com.apple.security.network.server. With only the client entitlement, a Mac can join a game hosted elsewhere but can never host one, and the "Advertise" button silently fails to attract any joiner.

Both entitlements are needed because either device can take either role: client for browsing and joining (MCNearbyServiceBrowser), server for hosting. Nothing is exposed to the internet — MultipeerConnectivity is peer-to-peer over the local link (Wi-Fi/AWDL/Bluetooth) only, there is no server software, no open port for general traffic, and no connection leaves the local network.

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
