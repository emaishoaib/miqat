import { askHelper } from "./helper.js";

const PRAYERS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];

const captureId = new URLSearchParams(location.search).get("capture");
const source = document.getElementById("source");
const status = document.getElementById("status");
const problems = document.getElementById("problems");
const table = document.getElementById("timetable");
const actions = document.getElementById("actions");
const uploadButton = document.getElementById("upload");
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

async function upload(days) {
  uploadButton.disabled = true;
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
    showList(rejections, reply.problems);
  } catch (error) {
    result.textContent = `Couldn't upload: ${error.message}`;
  }
  uploadButton.disabled = false;
}

async function review() {
  status.textContent = "Claude is reading the timetable. This can take a minute…";
  try {
    const timetable = await askHelper({ type: "read", captureId });
    source.textContent = `${timetable.source.title} · ${timetable.source.url}`;
    status.textContent = timetable.days.length
      ? `Claude found ${timetable.days.length} days. Check them against the mosque's timetable before uploading.`
      : "Claude found no days.";
    showList(problems, timetable.problems);
    showDays(timetable.days);
    if (timetable.days.length) {
      uploadButton.textContent = `Upload ${timetable.days.length} days`;
      uploadButton.addEventListener("click", () => upload(timetable.days));
      actions.hidden = false;
    }
  } catch (error) {
    status.textContent = `Couldn't read the timetable: ${error.message}`;
  }
}

review();
