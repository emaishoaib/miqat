const HOST_NAME = "com.mashoaib.miqat.timetables";

export async function askHelper(message) {
  const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, message);
  if (reply?.type === "error") throw new Error(reply.error);
  return reply;
}

export async function helperStatus() {
  try {
    const reply = await askHelper({ type: "ping" });
    return reply?.type === "pong" ? "Connected to the Miqat helper." : "The Miqat helper replied unexpectedly.";
  } catch (error) {
    return `Can't reach the Miqat helper: ${error.message}`;
  }
}
