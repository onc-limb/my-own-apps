import { load, save } from "./storage";

export interface Settings {
  llmEnabled: boolean;
  bridgeUrl: string;
}

const KEY = "telos:settings";

const DEFAULTS: Settings = {
  llmEnabled: false,
  bridgeUrl: "http://localhost:8787",
};

export function getSettings(): Settings {
  return { ...DEFAULTS, ...load<Partial<Settings>>(KEY, {}) };
}

export function saveSettings(patch: Partial<Settings>): Settings {
  const next = { ...getSettings(), ...patch };
  save(KEY, next);
  return next;
}
