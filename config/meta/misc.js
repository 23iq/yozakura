.pragma library
.import "Enums.js" as Enums

// Catalog metadata of the small domains (general, lockscreen, overview,
// performance, prefix, weather). Format: config/meta/Meta.js.

var general = {
    "description": "General integration: the terminal used to run commands.",
    "keys": {
        "terminal": {
            "description": "Terminal emulator used by the shell (kitty, foot, alacritty, ...)."
        },
        "terminalAdvanced": {
            "description": "Use terminalCommand instead of the built-in launch rule."
        },
        "terminalCommand": {
            "format": "command",
            "description": "Terminal launch template; $TERMINAL and $COMMAND are substituted."
        },
        "onboardingDone": {
            "description": "The first-run setup wizard was finished or skipped. Set to false (or run `onboarding`) to show it again."
        },
        "newLookOffered": {
            "description": "The one-time \"Try the new look\" card was answered (tried, kept, reverted or dismissed); it is not shown again."
        },
        "autoSavePreset": {
            "description": "Save setting changes into the active preset automatically (debounced) when it is one of your own presets; built-in presets are never changed. Off: use \"Save to current preset\" (settings sidebar, preset switcher, `preset save --current`)."
        },
        "settingsShowAll": {
            "title": "Show all settings",
            "description": "Settings window view. false = Simple: each page shows its essentials; true = All: expert rows (flagged advanced) too. Search always covers everything."
        }
    }
};

var lockscreen = {
    "description": "Lock screen (and the SDDM login theme that mirrors it): style, tone, layout and media.",
    "keys": {
        "position": {
            "enum": Enums.VERTICAL_EDGES,
            "description": "Edge of the lock screen password/info panel."
        },
        "style": {
            "enum": Enums.lockStyles(),
            "description": "Lock screen style (registry: modules/lockscreen/styles/LockStyleRegistry.js); the SDDM theme follows it."
        },
        "tone": {
            "enum": Enums.LOCK_TONES,
            "description": "style = the style's own tone, theme = follow light/dark mode, light/dark = force one (when the style has it)."
        },
        "blur": {
            "min": -1,
            "max": 1,
            "description": "Wallpaper blur behind the lock screen (0..1); -1 = the style's own."
        },
        "showMedia": {
            "description": "Show the now-playing card while music plays."
        },
        "showVisualizer": {
            "description": "Audio visualizer in the lock screen media card."
        },
        "showStatus": {
            "description": "Status strip (user, network, battery)."
        },
        "pamService": {
            "pattern": "^$|^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}$",
            "description": "PAM service the lock screen authenticates against. Empty = the bundled config/pam/password.conf (pam_unix). A plain service name uses /etc/pam.d/<name> (LDAP/sssd, systemd-homed, fingerprint) when that file exists, else the bundled config."
        }
    }
};

var overview = {
    "description": "Workspace overview (mission control) grid.",
    "keys": {
        "style": {
            "enum": Enums.OVERVIEW_STYLES,
            "description": "Overview layout: grid of workspaces, or a horizontal filmstrip with the current workspace centered."
        },
        "rows": {
            "min": 1,
            "max": 10,
            "description": "Workspace rows in the overview."
        },
        "columns": {
            "min": 1,
            "max": 10,
            "description": "Workspace columns in the overview."
        },
        "scale": {
            "min": 0.05,
            "max": 0.5,
            "description": "Size of workspace previews relative to the screen."
        },
        "workspaceSpacing": {
            "min": 0,
            "max": 64,
            "unit": "px",
            "description": "Gap between workspace previews."
        }
    }
};

var performance = {
    "description": "Performance switches for costly effects.",
    "keys": {
        "blurTransition": {
            "description": "Blur during panel transitions."
        },
        "windowPreview": {
            "description": "Live window previews (overview, dock)."
        },
        "wavyLine": {
            "description": "Animated wavy progress line in the media player."
        },
        "pauseWallpaperOnFullscreen": {
            "description": "Pause video wallpapers while a fullscreen window is shown."
        },
        "pauseWallpaperWhenCovered": {
            "description": "Pause video wallpapers while tiled windows cover the whole screen."
        },
        "pauseWallpaperOnIdle": {
            "description": "Pause video wallpapers while the session is idle (no input and no idle inhibitor)."
        },
        "pauseWallpaperIdleDelay": {
            "min": 5,
            "max": 3600,
            "description": "Seconds without input before an idle session pauses video wallpapers."
        },
        "pauseWallpaperOnBattery": {
            "description": "Pause video wallpapers while running on battery."
        },
        "videoWallpaperDownscale": {
            "description": "Play a cached copy scaled to the screen at 30 fps or less when a video wallpaper is larger (needs ffmpeg)."
        },
        "dashboardPersistTabs": {
            "description": "Keep dashboard tabs loaded after leaving them (faster, more memory)."
        },
        "dashboardMaxPersistentTabs": {
            "min": 1,
            "max": 3,
            "description": "Most dashboard tabs kept loaded."
        },
        "unloadIdleViews": {
            "description": "Release kept-loaded dashboard tabs a minute after the dashboard closes."
        },
        "settingsKeepAliveMinutes": {
            "min": 0,
            "max": 120,
            "description": "Minutes the closed Settings window stays loaded (hidden) so it reopens instantly; 0 releases it on close."
        },
        "visualizerFps": {
            "min": 15,
            "max": 60,
            "description": "Frames per second of the audio visualizer (cava); lower uses less CPU."
        },
        "batterySaver": {
            "description": "While on battery: stop the audio visualizer, draw the media progress line straight and pause video wallpapers."
        },
        "warmViews": {
            "description": "Create the launcher a few seconds after startup, hidden, so its first open is instant. Turn off to save the memory it holds until the launcher is first opened."
        }
    }
};

var prefix = {
    "description": "Launcher prefixes that switch the launcher into a mode (type the prefix, then a space or your query).",
    "keys": {
        "clipboard": {
            "description": "Prefix for clipboard history."
        },
        "emoji": {
            "description": "Prefix for the emoji picker."
        },
        "tmux": {
            "description": "Prefix for tmux sessions."
        },
        "wallpapers": {
            "description": "Prefix for wallpapers."
        },
        "notes": {
            "description": "Prefix for notes."
        },
        "calculator": {
            "description": "Prefix that shows only calculator, unit and currency results (e.g. \"= 5 kg in lb\")."
        },
        "commands": {
            "description": "Prefix for shell commands from assets/commands/commands.json (e.g. \"> preset Neon Tokyo\", \"> dnd\")."
        },
        "files": {
            "description": "Prefix for file search in the home directory (fd or plocate)."
        },
        "ai": {
            "description": "Prefix that sends the query to the AI quick ask."
        },
        "timers": {
            "description": "Prefix for timers, reminders and the stopwatch (e.g. \"t 10m tea\", \"t 18:00 call mom\", \"t sw\")."
        },
        "routines": {
            "description": "Prefix that searches only saved routines (e.g. \"@backup\"; empty lists them all)."
        },
        "launcher.order": {
            "items": {"enum": Enums.LAUNCHER_PROVIDERS},
            "uniqueItems": true,
            "description": "Order of result groups when no prefix is typed (provider ids)."
        },
        "launcher.disabled": {
            "items": {"enum": Enums.LAUNCHER_PROVIDERS.concat(Enums.LAUNCHER_TABS)},
            "uniqueItems": true,
            "description": "Launcher providers (and prefix tabs) that are turned off."
        },
        "launcher.aiOnTab": {
            "description": "Tab sends the current query to the AI quick ask."
        },
        "launcher.filesInMixed": {
            "description": "Show a few file matches in normal searches (3+ characters), not only after the files prefix."
        },
        "launcher.fileBackend": {
            "enum": ["auto", "fd", "plocate"],
            "description": "File search tool: auto prefers fd, then plocate."
        },
        "launcher.fileMaxResults": {
            "min": 5,
            "max": 200,
            "description": "Maximum file results after the files prefix."
        },
        "launcher.fileExcludes": {
            "items": {"type": "string"},
            "description": "Path segments excluded from file search."
        },
        "launcher.currencyRefreshHours": {
            "min": 1,
            "max": 168,
            "unit": "h",
            "description": "How often currency rates are refreshed (cached; offline uses the last rates)."
        }
    }
};

var weather = {
    "description": "Weather widget.",
    "keys": {
        "location": {
            "description": "City or \"lat,lon\" (empty = detect by IP)."
        },
        "unit": {
            "enum": Enums.TEMPERATURE_UNITS,
            "description": "Temperature unit."
        }
    }
};
