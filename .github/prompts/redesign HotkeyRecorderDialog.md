need to redesign HotkeyRecorderDialog according to new design below that made in react, but make it using css and existing vendor/windows-ui* components and styles (examples on components are in https://windows-ui.github.io/index.html  or also in includes\ui\ui_demo.html) but for buttons and modifiers we better create some new kinda component, basically button that become active/inactive to simulate a checkbox


import { useState } from "react";

export default function HotkeySettings() {
  const [mode, setMode] = useState("auto");
  const [distinguishLR, setDistinguishLR] = useState(false);
  const [modOnly, setModOnly] = useState(false);

  const baseModifiers = ["Ctrl", "Alt", "Shift", "Win"];
  const lrModifiers = [
    "LCtrl","RCtrl","LAlt","RAlt","LShift","RShift","LWin","RWin"
  ];

  const modifiers = distinguishLR ? lrModifiers : baseModifiers;

  return (
    <div className="min-h-screen bg-neutral-900 text-white flex items-center justify-center p-6">
      <div className="w-full max-w-xl bg-neutral-800 rounded-2xl shadow-xl p-6 space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-xl font-semibold">Reload App Hotkey</h1>
          <p className="text-sm text-neutral-400">Set a global shortcut</p>
        </div>

        {/* New Hotkey (Primary Focus) */}
        <div className="bg-neutral-700 rounded-xl p-4 text-center">
          <div className="text-sm text-neutral-400">New Hotkey</div>
          <div className="text-lg font-mono mt-1">Ctrl + Alt + K</div>
        </div>

        {/* Mode Switch */}
        <div className="flex bg-neutral-700 rounded-xl p-1">
          <button
            onClick={() => setMode("auto")}
            className={`flex-1 py-2 rounded-lg ${mode === "auto" ? "bg-neutral-600" : ""}`}
          >
            Auto Detect
          </button>
          <button
            onClick={() => setMode("manual")}
            className={`flex-1 py-2 rounded-lg ${mode === "manual" ? "bg-neutral-600" : ""}`}
          >
            Manual Setup
          </button>
        </div>

        {/* AUTO MODE */}
        {mode === "auto" && (
          <div className="space-y-4">
            <div className="text-center space-y-2">
              <div className="text-lg">Press your shortcut</div>
              <button className="px-4 py-2 bg-blue-600 rounded-xl">
                Start Recording
              </button>
              <div className="text-sm text-neutral-400">Listening for input...</div>
            </div>

            <div className="bg-neutral-700 rounded-xl p-3 text-center font-mono">
              Ctrl + Alt + R
            </div>
          </div>
        )}

        {/* MANUAL MODE */}
        {mode === "manual" && (
          <div className="space-y-5">

            {/* Step 1 */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <div className="text-sm text-neutral-400">Step 1: Modifiers</div>
                <label className="text-xs text-neutral-400 flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={distinguishLR}
                    onChange={() => setDistinguishLR(!distinguishLR)}
                  />
                  Distinguish L/R
                </label>
              </div>
              <div className="flex flex-wrap gap-2">
                {modifiers.map((key) => (
                  <button key={key} className="px-3 py-1 bg-neutral-700 rounded-lg">{key}</button>
                ))}
              </div>
            </div>

            {/* Step 2 */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <div className="text-sm text-neutral-400">Step 2: Main Key</div>
                <label className="text-xs text-neutral-400 flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={modOnly}
                    onChange={() => setModOnly(!modOnly)}
                  />
                  Modifiers only
                </label>
              </div>

              {!modOnly && (
                <>
                  <input
                    placeholder="Search key..."
                    className="w-full p-2 rounded-lg bg-neutral-700"
                  />
                  <div className="mt-2 grid grid-cols-6 gap-2 text-center">
                    {"ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((k) => (
                      <div key={k} className="bg-neutral-700 rounded-lg p-2">{k}</div>
                    ))}
                  </div>
                </>
              )}
            </div>
          </div>
        )}

        {/* Shared Advanced Options */}
        <details className="text-sm text-neutral-400">
          <summary className="cursor-pointer">Advanced Options</summary>
          <div className="mt-2 space-y-2">
            <label className="block"><input type="checkbox" /> Capture Mouse Input</label>
            <label className="block"><input type="checkbox" /> Capture Gamepad Input</label>
            <label className="block"><input type="checkbox" /> Allow Passthrough</label>
            <label className="block"><input type="checkbox" /> Allow extra keys (Wildcard)</label>
            <label className="block"><input type="checkbox" /> Allow risky hotkeys (Esc, Enter, Mouse, etc.)</label>
          </div>
        </details>

        {/* Footer */}
        <div className="flex justify-between">
          <button className="px-4 py-2 bg-neutral-700 rounded-xl">Cancel</button>
          <button className="px-4 py-2 bg-blue-600 rounded-xl">Apply Hotkey</button>
        </div>
      </div>
    </div>
  );
}
