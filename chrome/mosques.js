export const PLACE_FRAGMENT_PREFIX = "miqat-place=";

function keyFor(tabId) {
  return `tab-${tabId}`;
}

export async function mosqueInTab(tabId) {
  const key = keyFor(tabId);
  const saved = await chrome.storage.session.get(key);
  return saved[key] ?? null;
}

export function rememberMosque(tabId, mosque) {
  return chrome.storage.session.set({ [keyFor(tabId)]: mosque });
}

export function forgetMosque(tabId) {
  return chrome.storage.session.remove(keyFor(tabId));
}
