# Draft Coach for macOS

**Your little draft owl. Pick smarter. Learn why.**

[Download for Mac](https://github.com/attaluris/mtg-draft-coach/releases/latest) · [Start a practice draft](https://www.17lands.com/mock_draft) · [Report an issue](https://github.com/attaluris/mtg-draft-coach/issues)

A macOS app for learning to draft Magic: The Gathering on 17Lands. Press **Control–Option–D** to capture Chrome, get a brief pick recommendation and explanation, and read the answer in the app. Includes automatic coaching after each pick and deck reviews.

Uses your signed-in local Codex installation or Claude Code CLI. Draft Coach does not require an API key; provider access and usage limits still apply.

## Quickstart: install → start a practice draft → get coaching

**You need:** an Apple Silicon Mac (M1 or newer), macOS 14 Sonoma or newer, [Google Chrome](https://www.google.com/chrome/), and access to Claude Code or a compatible local Codex installation. Check your Mac in **Apple menu → About This Mac**.

### 1. Install Draft Coach

1. [Download the latest release](https://github.com/attaluris/mtg-draft-coach/releases/latest) and click **Draft-Coach-macOS-arm64.zip** under **Assets**, or use the ZIP your friend sent you. No coding or build tools needed.
2. Double-click the ZIP in **Finder → Downloads** to unzip it.
3. Drag **Draft Coach.app** into **Applications** in the Finder sidebar.
4. Double-click **Draft Coach.app** to open it.

If macOS blocks it: this personal build is not Apple-notarized. If you trust the sender, open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and follow the prompts. Do not disable Gatekeeper. You only need the source-build steps below if you want to compile the app yourself.

### 2. Connect a coach (one time)

**Claude route — no chat ID to copy:**

1. Press **Command–Space**, type **Terminal**, and press Return.
2. If Claude Code is not installed, paste this [official installation command](https://code.claude.com/docs/en/setup#install-claude-code) and press Return:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   ```

3. Close Terminal and reopen it. Type `claude` and press Return, then follow its sign-in prompts. Use your subscription account if you want subscription usage; account access and limits apply. Installing only the Claude desktop app does not provide the CLI used here.
4. Back in Draft Coach, choose **Claude** in the header. It creates the coaching conversation automatically.

**Already using Codex?** Choose **Codex** instead. Create a local coaching chat on this Mac, copy its task ID or `codex://threads/<id>` link, and paste it into **⋯ → Settings… → Codex task ID**. New installs have no preset destination. Your installed `codex` command must support `queue`; this integration depends on the local Codex version.

### 3. Start a practice draft

1. Click **Start a 17Lands simulation** in Draft Coach. It opens the [17Lands Mock Draft page](https://www.17lands.com/mock_draft) in Chrome. You can also open that link yourself in Chrome.
2. Log in to 17Lands (or register if needed), choose the set you want to practice, and click **Start!**.
3. Leave that draft tab active in Chrome. Click **Capture + Coach** in Draft Coach.

### 4. Allow capture (one time)

1. If asked to control **Google Chrome**, click **Allow**. This lets Draft Coach identify the draft and pack/pick.
2. If asked for screen capture access, open **System Settings → Privacy & Security → Screen & System Audio Recording** (called **Screen Recording** on some macOS versions) and enable **Draft Coach**.
3. Quit Draft Coach with **Command–Q**, reopen it from Applications, and click **Capture + Coach** again.

### 5. Draft and learn

Read **PICK** (recommended card), **RANK** (alternatives), and **LEARN** (one lesson). Choose your card yourself on 17Lands. For the next pack, press **Control–Option–D**, or enable **Auto-coach every pick** to get advice after each pick automatically.

For another practice run, click **Start a 17Lands simulation** again and start a new draft. Draft Coach detects the new draft on the next capture. The **New draft…** menu item only resets the coaching session; it does not create a draft on 17Lands.

For deck reviews, switch to **Deck**. Exact deck-list reading requires Chrome's **View → Developer → Allow JavaScript from Apple Events**; otherwise the app uses a screenshot.

The separate 17Lands Arena tracker is optional for coaching an existing website draft. Install it if you want your own Arena drafts uploaded to 17Lands.

### Install from source

Install Apple's Command Line Tools (`xcode-select --install`) if needed. From this repository folder:

```sh
./build.sh
open "$HOME/Applications/Draft Coach.app"
```

The script compiles the app, runs self-tests, quits any running Draft Coach, and replaces its copy in `~/Applications`. No Xcode project or third-party Swift packages are required.

### Quick troubleshooting

- **Capture fails:** check Screen Recording permission, relaunch, and keep the desired Chrome window visible.
- **Coach command missing:** install and sign in to the chosen CLI. Supported executable locations are in `Sources/Backend.swift`.
- **Codex answer missing:** check the local chat ID. The response reader depends on an internal Codex transcript format that can change.
- **Wrong pack or missing context:** keep the intended draft tab active in Chrome and allow Automation access. Screenshot fallback can misread small card text.

## Share with a friend

The source lives at [attaluris/mtg-draft-coach](https://github.com/attaluris/mtg-draft-coach). Source, icon assets, build script, and documentation are included; build outputs, local logs, and coaching transcripts are excluded. Licensed under [MIT](LICENSE).

Build, then create a release ZIP:

```sh
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "build/Draft Coach.app" "dist/Draft-Coach-macOS-arm64.zip"
zip -j "dist/Draft-Coach-macOS-arm64.zip" README.md
zip -j "dist/Draft-Coach-macOS-arm64.zip" LICENSE
```

Attach that ZIP to a GitHub Release and share the release link, or send the ZIP directly for a private test. Your friend needs their own signed-in coach and macOS permissions. The ZIP contains the app, not your saved preferences, screenshots, conversations, or credentials. For broader distribution, use Developer ID signing and Apple notarization.

## Use

1. Launch `Draft Coach.app` from `~/Applications` (Finder → Go → Go to Folder → `~/Applications`), or search Draft Coach in Spotlight.
2. Open your 17Lands draft. Click **Capture + Coach** or press **Control–Option–D**.
3. The whole frontmost visible Google Chrome window is captured automatically, including the toolbar. There is no region selector. With multiple Chrome windows, bring the desired one forward first. Minimized windows and windows on other desktops are not selected.
4. On a 17Lands live draft (`/site_draft/<id>`) or replay URL, Draft Coach reads the exact pack/pick and downloads a sanitized context file. It contains the current pack and your earlier picks, with each card's mana cost, colors, types, 17Lands games-in-hand win rate and average seen position. It excludes your recorded choice at the current pick and every later pick. The coach treats this data as ground truth for names and colors. If URL access or 17Lands data is unavailable, the coach uses the screenshot alone, and small mana symbols can then be misread.
5. Draft Coach submits the request directly to the selected coach. The reply gives PICK (best card), RANK (the next 3 in order, with 17Lands win rates when available) and LEARN (one lesson). No paste or Return step is needed. The coach reads the saved PNG and, when available, the sanitized JSON context.
6. The **response** section shows the latest completed answer. A timestamp and working indicator distinguish an earlier answer while a new response is running.

### Deck step

Switch the top control from **Draft** to **Deck** after your last pick. Auto-coach switches it for you when 17Lands shows the draft is complete.

1. Sort your 23 into Maindeck and Sideboard yourself in the 17Lands deck builder.
2. Optionally note your thinking in the text box, then press **Review my deck** (or ⌃⌥D). The 17Lands tab doesn't need to be in front.

With Chrome's **View → Developer → Allow JavaScript from Apple Events** on, Draft Coach reads your exact Maindeck and Sideboard from the 17Lands tab (in any window), locally and without switching tabs. It sends those lists, plus your full pool from 17Lands (exact names, colors, win rates), to the same coaching session. The deck builder doesn't track basic lands, so the coach recommends your land count and split. With that setting off, it falls back to a screenshot of the front Chrome window. In that case, shrink the cards with 17Lands' zoom slider until the whole Maindeck and Sideboard fit; the review stops and says what's cut off rather than guessing.

The reply gives VERDICT (how close you are), SWAPS ("Cut X → add Y" with reasons), LANDS & CURVE, and LEARN. Debug helper: `DraftCoach --read-deck` prints the lists it reads.

**Build from scratch** has the coach build its own 40 from the pool instead. **New draft** returns to the Draft step.

### Auto-coach

Turn on **Auto-coach every pick** to skip the button. While the frontmost Chrome tab is a live 17Lands draft (`/site_draft/<id>`), Draft Coach checks for pick changes and coaches the next pack. Network requests to 17Lands are spaced at least 15 seconds apart, with a 15-minute pause after a 403 or 429 response. Notes:

- Keep the draft tab frontmost in Chrome; the capture uses the frontmost visible Chrome window.
- If you pick again while a coach is still answering, it skips ahead to your latest pick once the answer lands.
- Opening a different 17Lands draft starts a new coaching session automatically.
- With the toggle off nothing is polled. With it on, the Chrome URL check is local and never launches Chrome; 17Lands is only contacted while the frontmost tab is a live draft.
- Replay pages aren't auto-coached; use the button there.

### Codex vs Claude

| | Codex | Claude |
|---|---|---|
| Sends via | `codex queue` into the task set in ⚙︎ | `claude -p` (Claude Code CLI, `~/.local/bin/claude`) |
| Conversation | Your chosen Codex task | One Claude session per draft, created on the first pick and resumed after that |
| Where to read replies | Overlay (polls the task transcript every 2 s) or the Codex app | Overlay (reply arrives when Claude finishes, usually 10–30 s) |
| Tools allowed | Whatever the task allows | None when 17Lands data is available; Read (screenshot folder only) for the screenshot fallback |

The toggle is remembered between launches. Replies render as Markdown. In Claude mode, **Full thread** opens a window with every pick in the current draft (screenshot, notes and coaching), and **Open in Terminal** resumes that Claude session interactively for follow-up questions. These sessions are run by the Claude Code CLI, so they do not appear in the Claude desktop app's sidebar.

Models: Claude mode uses your Claude Code default model (no `--model` flag is passed). Codex mode uses whatever model the destination Codex task is set to.

Claude sessions run in `~/Pictures/Draft Coach`, so you can also continue one by hand with `cd ~/Pictures/"Draft Coach" && claude --resume <id>` (the ID prefix is shown in ⋯ → Settings…).

In Codex mode, use **⋯ → Settings…** to set your local task ID (copy it from that task's menu) or a `codex://threads/<id>` link. There is no default destination on a fresh install. **New draft** resets the session ID so the coach does not mix drafts. In Codex mode it does not create a new Codex task; in Claude mode it starts a fresh Claude session. The window can be resized from any edge or corner.

The **⋯** menu in the header holds everything occasional: **Start a 17Lands simulation**, **New draft…** (asks first), **Full thread**, **Open in Terminal** (Claude) or **Open Codex task** (Codex), **Send again**, **Copy request** / **Copy image** (manual fallbacks if automatic submission fails), the screenshots folder, and Settings.

## macOS permissions

On first capture, macOS may ask for Screen Recording access. Allow Draft Coach in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch the app if requested. macOS may also ask whether Draft Coach can control Google Chrome; Apple Events read the active tab URL and, when enabled, deck lists. Denying Chrome access keeps screenshot-only coaching working. No Accessibility permission is needed: the app submits coaching requests through the selected CLI instead of simulating typing.

## Storage and behavior

- Screenshots and sanitized 17Lands context files: `~/Pictures/Draft Coach/`. They remain until you delete them.
- The overlay stays visible while capturing (only the Chrome window itself is captured) and is available across desktops.
- Draft Coach is a regular window: other windows can cover it, and it appears in the Dock and ⌘-Tab, plus a menu bar icon. Closing the window leaves the app and shortcut active; click the Dock icon or choose **Show window** to restore it, and **Quit Draft Coach** (⌘Q) to stop it.
- A successful capture submits directly through the installed Codex or Claude command. The clipboard is changed only when you choose a copy fallback or automatic submission fails.
- The screenshot is referenced by an absolute local path, not attached automatically. Use a local Codex task on this Mac with filesystem/image access.
- Draft Coach retrieves supported live-draft/replay data from `www.17lands.com`. The selected Codex or Claude CLI sends coaching requests and relevant card data or screenshots to its provider. A full Chrome-window screenshot can include the toolbar and other visible browser details; captures remain in `~/Pictures/Draft Coach/` until deleted.
- There is no automatic startup or continuous screen capture.
- Claude mode is lean: 17Lands data goes directly into the message, with a short coaching brief instead of Claude Code's default coding instructions and no tools. That's one model call and about 2–7k tokens per pick. Only the screenshot fallback (no 17Lands data) enables the Read tool, limited to the screenshot folder. Same model either way. Requests time out after four minutes.
- In Codex mode, the response viewer reads only the selected task’s transcript under `~/.codex/sessions`, incrementally and read-only. It ignores tool output and intermediate commentary. Local transcript format is an internal Codex implementation detail and could change after a Codex update. Cloud-only, remote-host, archived, or custom-CODEX_HOME tasks are not supported by this reader.
- Screenshots are captured through Apple ScreenCaptureKit; the overlay and other apps are excluded from the window image.

## Build

Requires Apple's Command Line Tools and macOS 14 or newer (Apple Silicon build).

```sh
./build.sh
open ~/Applications/"Draft Coach.app"
```

`build.sh` quits any running copy and installs the new build to `~/Applications`.

The build creates an ad-hoc signed native Swift app and runs self-tests for task URL validation, prompt construction, transcript filtering, partial JSON writes, response completion state, and Claude argument/output handling. End-to-end screen capture depends on macOS screen permissions and should be checked with a real draft screenshot.

## Contributing

Bug reports and pull requests are welcome. Include your macOS version, chosen coach, and steps to reproduce the issue. Remove private browser details and account information before sharing screenshots or logs. Run `./build.sh` before submitting source changes.

This is an independent hobby project, not affiliated with or endorsed by Wizards of the Coast, 17Lands, OpenAI, or Anthropic. Magic: The Gathering and third-party services retain their respective trademarks and rights.
