import { capturePage } from "./capture.js";
import { mosqueInTab } from "./mosques.js";

const HOST_NAME = "com.mashoaib.miqat.timetables";

const status = document.getElementById("status");
const readButton = document.getElementById("read");
const result = document.getElementById("result");
const helper = document.getElementById("helper");

async function helperStatus() {
  try {
    const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, { type: "ping" });
    return reply?.type === "pong" ? "Connected to the Miqat helper." : "The Miqat helper replied unexpectedly.";
  } catch (error) {
    return `Can't reach the Miqat helper: ${error.message}`;
  }
}

function describe(reply) {
  if (reply?.type === "error") return `The Miqat helper couldn't save it: ${reply.error}`;
  const failed = reply.failed.length ? ` Couldn't download ${reply.failed.join(", ")}.` : "";
  return `Saved ${reply.files.join(", ")} to ${reply.folder}.${failed}`;
}

async function readTimetable(tab, mosque) {
  readButton.disabled = true;
  result.textContent = "Reading the page…";
  try {
    const capture = await capturePage(tab);
    const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, { type: "capture", placeId: mosque.placeId, capture });
    result.textContent = describe(reply);
  } catch (error) {
    result.textContent = `Couldn't read the page: ${error.message}`;
  } finally {
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
