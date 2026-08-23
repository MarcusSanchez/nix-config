-- Hammerspoon: per-application key remapping — the macOS half of
-- dotfiles/xremap.yml, which does the same job on the laptop.
--
-- Why Hammerspoon and not Karabiner-Elements, which is the obvious
-- choice: the rules below need the FOCUSED WINDOW'S TITLE (to leave a
-- terminal alone while nvim is running in it), and Karabiner matches on
-- bundle identifiers only — a window-title condition has been an open
-- request there for years. Karabiner also drives a DriverKit virtual
-- keyboard, and that driver has open breakage on macOS 26 (remaps
-- silently not applying even with the extension loaded). Hammerspoon
-- works through a CGEventTap instead: no kernel driver, and it can read
-- both the bundle id and the window title itself.
--
-- Live-editable, like xremap's --watch=config: this file is symlinked
-- out of the nix store, and the watcher at the bottom reloads on save.
-- No rebuild needed to change a binding.
--
-- Needs Accessibility (System Settings > Privacy & Security >
-- Accessibility). Without it the tap silently receives nothing.

-- Opens Hammerspoon's message port so the bundled CLI can talk to it:
--   /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "expr"
-- Worth having because the failure mode here is silent — a tap that
-- never started looks exactly like a key that does nothing.
require("hs.ipc")

local home = os.getenv("HOME")
local DOTFILES = home .. "/nix-config/home/marcus/common/dotfiles/"

-- Apps that already speak vim, where alt+h/l must stay untouched.
local VIM_BUNDLES = {
  ["dev.zed.Zed"] = true,
}
-- Toolbox installs one bundle id per IDE and the casing is inconsistent
-- (com.jetbrains.goland but com.jetbrains.WebStorm), so match the prefix
-- case-insensitively rather than listing them.
local VIM_BUNDLE_PREFIX = "com.jetbrains."

-- Only terminals can be "running nvim", so the window title — the
-- expensive lookup, it goes through the accessibility API — is only
-- fetched for these. Everything else decides on the bundle id alone.
local TERMINAL_BUNDLES = {
  ["com.mitchellh.ghostty"] = true,
}

-- ghostty's shell integration titles the window after the foreground
-- command, so a terminal running nvim reports "nvim" (usually with the
-- file after it). %f[%W] is Lua's frontier pattern — the equivalent of
-- \b, so this matches "nvim foo.txt" but not "nvimrc".
local NVIM_TITLE = "^nvim%f[%W]"

local function speaksVim()
  local app = hs.application.frontmostApplication()
  local bundle = app and app:bundleID() or ""

  if VIM_BUNDLES[bundle] then
    return true
  end
  if bundle:sub(1, #VIM_BUNDLE_PREFIX):lower() == VIM_BUNDLE_PREFIX then
    return true
  end

  if TERMINAL_BUNDLES[bundle] then
    local win = hs.window.focusedWindow()
    local title = win and win:title() or ""
    if title:match(NVIM_TITLE) then
      return true
    end
  end

  return false
end

-- always = true  -> fires everywhere, vim-speaking apps included
-- always = false -> suppressed wherever speaksVim() is true
--
-- J is UP and K is DOWN. That is inverted from the usual vim habit and
-- it is deliberate: it matches the laptop's xremap.yml and niri binds.
local RULES = {
  { mods = { "alt" },          key = "j", send = "up",    always = true },
  { mods = { "alt" },          key = "k", send = "down",  always = true },
  { mods = { "alt" },          key = "h", send = "left",  always = false },
  { mods = { "alt" },          key = "l", send = "right", always = false },
  -- h/l stay the horizontal pair when shifted: h to the start of the
  -- line, l to the end. Suppressed in vim-speaking apps like the
  -- unshifted h/l above — those bind alt+shift+h/l themselves.
  -- containExactly is what keeps the two apart, so alt+shift+l is End
  -- and never Right.
  { mods = { "alt", "shift" }, key = "h", send = "home",  always = false },
  { mods = { "alt", "shift" }, key = "l", send = "end",   always = false },
}

-- Exposed as a global for `hs -c "hs.inspect(remapRules)"`, so what is
-- actually loaded can be read back rather than inferred from the file.
remapRules = RULES

-- Replace the keystroke: swallow the original and post the substitute
-- with no modifiers held, so the receiving app sees a bare arrow/Home/End
-- rather than alt+arrow (which would be word-wise navigation on macOS).
local function replacement(keyName)
  return true, {
    hs.eventtap.event.newKeyEvent({}, keyName, true),
    hs.eventtap.event.newKeyEvent({}, keyName, false),
  }
end

-- Global on purpose: an eventtap held only in a local is garbage
-- collected and stops firing, usually minutes later.
remapTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local key = hs.keycodes.map[event:getKeyCode()]
  if not key then
    return false
  end
  local flags = event:getFlags()

  for _, rule in ipairs(RULES) do
    -- containExactly, not contains: alt+shift+l must not also trigger
    -- the plain alt+l rule.
    if key == rule.key and flags:containExactly(rule.mods) then
      if rule.always or not speaksVim() then
        return replacement(rule.send)
      end
      return false
    end
  end

  return false
end)
remapTap:start()

-- alt+tab drives the NATIVE cmd+tab app switcher, with real held-key
-- semantics: the first alt+tab posts a synthetic cmd-down and a
-- cmd-tab, every further tab while alt stays held cycles (shift+tab
-- cycles backwards), and releasing the REAL alt posts the cmd-up that
-- commits the selection. The system switcher only reads the synthetic
-- cmd state, so it behaves exactly as if cmd were the held key. A
-- plain quick alt+tab therefore flips to the most recent app, same as
-- a quick cmd+tab tap.
altTabActive = false

altTabTap = hs.eventtap.new(
  { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged },
  function(event)
    local eventType = event:getType()
    local flags = event:getFlags()

    if eventType == hs.eventtap.event.types.keyDown then
      local key = hs.keycodes.map[event:getKeyCode()]
      if key == "tab" and flags.alt and not flags.cmd and not flags.ctrl then
        if not altTabActive then
          altTabActive = true
          hs.eventtap.event.newKeyEvent({}, "cmd", true):post()
        end
        local mods = flags.shift and { "cmd", "shift" } or { "cmd" }
        return true, {
          hs.eventtap.event.newKeyEvent(mods, "tab", true),
          hs.eventtap.event.newKeyEvent(mods, "tab", false),
        }
      end
      return false
    end

    -- flagsChanged: the real alt going up ends the cycle
    if altTabActive and not flags.alt then
      altTabActive = false
      hs.eventtap.event.newKeyEvent({}, "cmd", false):post()
    end
    return false
  end
)
altTabTap:start()

-- Reload when this file changes, so edits apply on save. Watches the
-- repo directory rather than ~/.hammerspoon: the file there is a symlink
-- INTO the repo, and FSEvents reports writes against the real path.
configWatcher = hs.pathwatcher.new(DOTFILES, function(paths)
  for _, path in ipairs(paths) do
    if path:match("hammerspoon%.init%.lua$") then
      hs.reload()
      return
    end
  end
end)
configWatcher:start()

if hs.accessibilityState() then
  hs.alert.show("Hammerspoon: remaps loaded")
else
  hs.alert.show("Hammerspoon needs Accessibility — remaps are inactive")
end
