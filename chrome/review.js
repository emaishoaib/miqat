import { askHelper } from "./helper.js";

const PRAYERS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];

const captureId = new URLSearchParams(location.search).get("capture");
const source = document.getElementById("source");
const status = document.getElementById("status");
const problems = document.getElementById("problems");
const table = document.getElementById("timetable");
const actions = document.getElementById("actions");
const uploadButton = document.getElementById("upload");
const fixButton = document.getElementById("fix");
const result = document.getElementById("result");
const rejections = document.getElementById("rejections");

function showList(list, items) {
  list.replaceChildren(
    ...items.map((item) => {
      const entry = document.createElement("li");
      entry.textContent = item;
      return entry;
    }),
  );
  list.hidden = items.length === 0;
}

function formattedDate(date) {
  return new Date(`${date}T00:00:00Z`).toLocaleDateString(undefined, {
    weekday: "short",
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  });
}

function timeCell(time) {
  const cell = document.createElement("td");
  cell.textContent = time?.begins ?? "";
  if (time?.jamaat) {
    const jamaat = document.createElement("span");
    jamaat.className = "jamaat";
    jamaat.textContent = `Jamaat ${time.jamaat}`;
    cell.append(jamaat);
  }
  return cell;
}

function showDays(days) {
  table.tBodies[0].replaceChildren(
    ...days.map((day) => {
      const row = document.createElement("tr");
      const date = document.createElement("td");
      date.textContent = formattedDate(day.date);
      row.append(date, ...PRAYERS.map((prayer) => timeCell(day.times[prayer])));
      return row;
    }),
  );
  table.hidden = days.length === 0;
}

let days = [];
let lastRejections = [];

async function upload() {
  uploadButton.disabled = true;
  fixButton.hidden = true;
  rejections.hidden = true;
  result.textContent = "Uploading…";
  try {
    const reply = await askHelper({ type: "upload", captureId, days });
    if (reply.type === "uploaded") {
      result.textContent = `Saved ${reply.daysSaved} days to Miqat.`;
      uploadButton.hidden = true;
      return;
    }
    result.textContent = "The server didn't save anything, because:";
    lastRejections = reply.problems;
    showList(rejections, lastRejections);
    fixButton.hidden = false;
  } catch (error) {
    result.textContent = `Couldn't upload: ${error.message}`;
  }
  uploadButton.disabled = false;
}

async function read(rejected) {
  actions.hidden = true;
  status.textContent = rejected.length
    ? "Claude is fixing what the server rejected. This can take a minute…"
    : "Claude is reading the timetable. This can take a minute…";
  try {
    const timetable = await askHelper({ type: "read", captureId, rejections: rejected });
    days = timetable.days;
    source.textContent = `${timetable.source.title} · ${timetable.source.url}`;
    status.textContent = days.length
      ? `Claude found ${days.length} days. Check them against the mosque's timetable before uploading.`
      : "Claude found no days.";
    showList(problems, timetable.problems);
    showDays(days);
    result.textContent = "";
    rejections.hidden = true;
    fixButton.hidden = true;
    uploadButton.textContent = `Upload ${days.length} days`;
    uploadButton.disabled = false;
    actions.hidden = days.length === 0;
  } catch (error) {
    status.textContent = `Couldn't read the timetable: ${error.message}`;
    actions.hidden = days.length === 0;
  }
}

uploadButton.addEventListener("click", upload);
fixButton.addEventListener("click", () => read(lastRejections));
read([]);
