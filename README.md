# Draft Coach 🦉

Brief coaching for your 17Lands drafts: what to pick, what to avoid, and why.

**Requires:** an Apple Silicon Mac (M1+), macOS 14+, Google Chrome, and access to Claude Code or a compatible local Codex installation.

## Get started

1. **[Download the app](https://github.com/attaluris/mtg-draft-coach/releases/latest/download/Draft-Coach-macOS-arm64.zip)**, unzip it, and drag **Draft Coach.app** into **Applications**.
2. **Open Draft Coach.** If macOS blocks it and you trust the app, go to **System Settings → Privacy & Security → Open Anyway**.
3. **Connect Claude:** if you haven't installed Claude Code, open **Terminal** and run:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   ```

   Reopen Terminal, run `claude`, and follow the sign-in prompts. Choose **Claude** in Draft Coach. Your account's usage limits apply.

4. **[Start a practice draft](https://www.17lands.com/mock_draft)** in Chrome. Log in, choose a set, and click **Start!**
5. **Click Capture + Coach.** Allow Chrome access and Screen Recording when prompted. If needed, enable Draft Coach under **System Settings → Privacy & Security → Screen Recording**, then quit and reopen the app.

Keep the draft tab active in Chrome. Press **Control–Option–D** for advice, or turn on **Auto-coach every pick**. Make your picks yourself on 17Lands.

**Using Codex instead?** Choose **Codex**, then paste your local chat's task ID or `codex://threads/<id>` link into **⋯ → Settings → Codex task ID**. Your Codex installation must support `codex queue`.
