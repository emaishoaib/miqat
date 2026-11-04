import { mosqueInTab } from "./mosques.js";

const HOST_NAME = "com.mashoaib.miqat.timetables";

async function helperStatus() {
  try {
    const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, { type: "ping" });
    return reply?.type === "pong" ? "Connected to the Miqat helper." : "The Miqat helper replied unexpectedly.";
  } catch (error) {
    return `Can't reach the Miqat helper: ${error.message}`;
  }
}

const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
const mosque = await mosqueInTab(tab.id);

document.getElementById("status").textContent = mosque
  ? `Mosque place ID: ${mosque.placeId}`
  : "Open this mosque's website from Miqat's globe button first.";
document.getElementById("helper").textContent = await helperStatus();
