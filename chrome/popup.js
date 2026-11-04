import { capturePage } from "./capture.js";
import { askHelper, helperStatus } from "./helper.js";
import { mosqueInTab } from "./mosques.js";

const status = document.getElementById("status");
const readButton = document.getElementById("read");
const result = document.getElementById("result");
const helper = document.getElementById("helper");

async function readTimetable(tab, mosque) {
  readButton.disabled = true;
  try {
    result.textContent = "Capturing the page…";
    const capture = await capturePage(tab);
    const captured = await askHelper({ type: "capture", placeId: mosque.placeId, capture });
    const review = chrome.runtime.getURL(`review.html?capture=${encodeURIComponent(captured.id)}`);
    await chrome.tabs.create({ url: review, index: tab.index + 1 });
    window.close();
  } catch (error) {
    result.textContent = `Couldn't capture the page: ${error.message}`;
    readButton.disabled = false;
  }
}

const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
const mosque = await mosqueInTab(tab.id);

status.textContent = mosque
  ? `Mosque place ID: ${mosque.placeId}`
  : "Open this mosque's website from Miqat's globe button first.";
if (mosque) {
  readButton.hidden = false;
  readButton.addEventListener("click", () => readTimetable(tab, mosque));
}
helper.textContent = await helperStatus();
