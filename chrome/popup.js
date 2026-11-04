import { mosqueInTab } from "./mosques.js";

const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
const mosque = await mosqueInTab(tab.id);

document.getElementById("status").textContent = mosque
  ? `Mosque place ID: ${mosque.placeId}`
  : "Open this mosque's website from Miqat's globe button first.";
