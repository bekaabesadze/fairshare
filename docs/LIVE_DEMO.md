# Live demo on two iPhones — runbook

| Phone | Sign in with | Role |
|---|---|---|
| Beka's iPhone | `abesbe01@luther.edu` | Officer, Up to Us (scans + submits) |
| Sab's iPhone | `abessa01@luther.edu` | Student Accounts (sees photo + numbers, approves) |

Both emails are also one-tap chips under **Demo accounts** on the sign-in screen.

## How it connects (no Firebase, no accounts)

The Mac Studio runs the sync server. A free Cloudflare tunnel gives it a public address:

**https://integrated-leonard-particle-comparisons.trycloudflare.com**

The app tries that address, the Mac's campus address (`10.28.3.217:4000`) and its Bonjour name all at once, and uses whichever answers. Phones can be on any Wi-Fi **or cellular**.

- Receipt photos are uploaded with the numbers and stored on the Mac (`server/data/files/`).
- Changes the phone hasn't delivered yet are retried until the server confirms. After **Submit**, the card shows **Sending… → ✓ Delivered**.
- Updates reach the other phone within about 1 second.

## Must stay running on the Mac (Terminal panel tabs)

1. **FairShare server (keep open)**: `node server/index.ts`. It prints `✓ iPhone app online` for each phone, and a line for every action, e.g. `expense/submit (with photo)`.
2. **Public tunnel (keep open)**: `cloudflared …`. **Don't close it.** If it restarts, the address changes (see "If something breaks").
3. **Keep Mac awake**: `caffeinate`.

Don't let the Mac sleep, shut down or go offline.

## 10 minutes before presenting

1. On the Mac, `curl -s localhost:4000/api/health`. `devices` should list two `iPhone app` entries once both phones have the app open.
2. On each phone, open FairShare, then **avatar → Settings → Sync**. It should say **Live sync** and show "Connected to …".
3. If iOS asks to allow **Local Network**, tap **Allow**. Turn on notifications on Sab's phone if you want the banner.
4. Reset the books (either phone): **Settings → Reset demo data**. Up to Us should show **$600 remaining**.
5. Do one full rehearsal (scan → submit → approve), then **Reset demo data** again.
6. Turn off Focus / Do Not Disturb, set brightness to max, and set auto-lock to Never on both phones.

## The live moment

1. **Beka**: Home → **Receipt** → **Take a photo** → scan the real receipt → check the numbers → type a short description → **Submit for review**.
   The card shows the photo, then **✓ Delivered**.
2. **Sab**: within about 1 second a banner appears: "New expense from Up to Us". Open **Review queue**, then tap it.
   Show the **real photo** at the top (tap to zoom), the scanned numbers, "Submitted by Beka Abesadze", and the budget impact.
3. **Sab**: **Approve**.
4. **Beka**: the banner "$X approved" appears and the balance drops.

Safe backup if the real receipt scans badly: **Try a sample** on the scan screen uses the bundled Luther Book Shop receipt ($52).

## If something breaks

| Symptom | Fix |
|---|---|
| A phone shows the Wi-Fi-slash icon / "Offline demo" | Pull down to refresh on Home, or Settings → Sync → **Reconnect**. Then switch the phone to cellular (turn Wi-Fi off). |
| Server tab was closed | In the project folder run `node server/index.ts`. The books are saved on disk, and phones reconnect by themselves within a few seconds. |
| Tunnel tab was closed | Run `cloudflared tunnel --no-autoupdate --url http://localhost:4000` and copy the new `https://….trycloudflare.com` address. On each phone: Settings → Sync → paste it into **Server address** → **Reconnect**. |
| Sab's phone can't run the app | Open the tunnel address in Safari, choose **Sab Abesadze · Student Accounts**, and review there. It is the same live data. |

## Installing on another iPhone

Plug the iPhone into the Mac, unlock it, and tap **Trust**. The first time, also turn on **Settings → Privacy & Security → Developer Mode** (the phone restarts). Then:

```bash
cd ~/Desktop/projectforhackathon/ios && xcodebuild -project FairShare.xcodeproj -scheme FairShare -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates build
```

```bash
xcrun devicectl list devices
```

```bash
xcrun devicectl device install app --device <identifier> ~/Desktop/projectforhackathon/ios/build/device/Build/Products/Debug-iphoneos/FairShare.app
```

On the phone, go to **Settings → General → VPN & Device Management** and trust the developer profile if it asks.
