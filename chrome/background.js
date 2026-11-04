import { PLACE_FRAGMENT_PREFIX, forgetMosque, mosqueInTab, rememberMosque } from "./mosques.js";

function placeIdIn(url) {
  return url.hash.startsWith(`#${PLACE_FRAGMENT_PREFIX}`) ? url.hash.slice(PLACE_FRAGMENT_PREFIX.length + 1) : null;
}

async function followTab(tabId, url) {
  const placeId = placeIdIn(url);
  if (placeId) {
    await rememberMosque(tabId, { placeId, host: url.host });
    return chrome.action.enable(tabId);
  }

  const mosque = await mosqueInTab(tabId);
  if (mosque?.host === url.host) return chrome.action.enable(tabId);

  await forgetMosque(tabId);
  return chrome.action.disable(tabId);
}

chrome.action.disable();

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (!changeInfo.url) return;
  followTab(tabId, new URL(changeInfo.url));
});

chrome.tabs.onRemoved.addListener((tabId) => {
  forgetMosque(tabId);
});
