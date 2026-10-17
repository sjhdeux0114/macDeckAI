# Steam integration validation — 2026-10-17

- Official Valve SteamSetup.exe completed `/S` with exit 0 under WS12WineSikarugir10.0_8.
- Actual Steam client downloaded and installed its 336,229 KB update.
- Actual Windows Steam Big Picture displayed its account and QR sign-in screen.
- Steam credentials and Steam Guard are entered by the user in Steam, never in MacDeck.
- Fresh Steam launch through the installed app also reached Big Picture (window 4266, wine PID 83940).
- Native app package built and signed, 19 self-checks passed.
- Final installed v0.2 app revalidated Brogue Windows x64 dungeon rendering with Apple M5 Metal HUD; see ../macdeck-v02-game-metal.png.
- Login authentication, Steam game download and Steam game execution remain unverified pending user login.
- Dedicated prefix persists at ~/Library/Application Support/MacDeck/Bottles/Steam.
- Installed app: ~/Applications/MacDeck.app.
