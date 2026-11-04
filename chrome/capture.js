const PDF_URL = /\.pdf($|[?#])/i;

function readPage() {
  const MIN_IMAGE_SIDE_PIXELS = 300;
  const isPdf = (url) => /\.pdf($|[?#])/i.test(url);
  const absolute = (url) => new URL(url, document.baseURI).href;

  const links = [...document.querySelectorAll("a[href]")]
    .filter((link) => isPdf(link.href))
    .map((link) => ({ url: link.href, label: link.innerText.trim() }));
  const embedded = [...document.querySelectorAll("iframe[src], embed[src], object[data]")]
    .map((element) => element.getAttribute("src") ?? element.getAttribute("data"))
    .filter(isPdf)
    .map((url) => ({ url: absolute(url), label: "" }));
  const images = [...document.images]
    .filter((image) => image.naturalWidth >= MIN_IMAGE_SIDE_PIXELS && image.naturalHeight >= MIN_IMAGE_SIDE_PIXELS)
    .map((image) => image.currentSrc || image.src);

  return { title: document.title, text: document.body?.innerText ?? "", pdfs: [...links, ...embedded], images };
}

async function readTab(tab) {
  if (PDF_URL.test(tab.url)) {
    return { title: tab.title, text: "", pdfs: [{ url: tab.url, label: tab.title }], images: [] };
  }
  const [{ result }] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: readPage });
  return result;
}

function uniqueByUrl(pdfs) {
  return [...new Map(pdfs.map((pdf) => [pdf.url, pdf])).values()];
}

export async function capturePage(tab) {
  const page = await readTab(tab);
  const screenshot = await chrome.tabs.captureVisibleTab(tab.windowId, { format: "png" });
  return {
    url: tab.url,
    title: page.title,
    text: page.text,
    screenshot,
    pdfs: uniqueByUrl(page.pdfs),
    images: [...new Set(page.images)],
  };
}
