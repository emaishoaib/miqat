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

async function askHelper(message) {
  const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, message);
  if (reply?.type === "error") throw new Error(reply.error);
  return reply;
}

function describe(timetable) {
  const { days, problems } = timetable;
  const found = days.length
    ? `Claude found ${days.length} days, from ${days[0].date} to ${days.at(-1).date}.`
    : "Claude found no days.";
  return [found, ...problems].join(" ");
}

async function readTimetable(tab, mosque) {
  readButton.disabled = true;
  try {
    result.textContent = "Capturing the page…";
    const capture = await capturePage(tab);
    const captured = await askHelper({ type: "capture", placeId: mosque.placeId, capture });
    result.textContent = "Claude is reading the timetable. Keep this open, it can take a minute…";
    const timetable = await askHelper({ type: "read", captureId: captured.id });
    result.textContent = describe(timetable);
  } catch (error) {
    result.textContent = `Couldn't read the timetable: ${error.message}`;
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
