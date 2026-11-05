// Pro Shop mockup, run locally: serves tools/proshop-mock/ at http://localhost:5181 (the item fitter is 5180).
// Run: node tools/proshop-mock.js
const http = require("http");
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

const DIR = path.join(__dirname, "proshop-mock");
const PORT = 5181;
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".json": "application/json",
  ".png": "image/png", ".jpg": "image/jpeg", ".webp": "image/webp", ".ttf": "font/ttf" };

http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split("?")[0]);
  if (p === "/") p = "/index.html";
  const file = path.join(DIR, p);
  if (!file.startsWith(DIR + path.sep)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end("not found"); }
    res.writeHead(200, { "Content-Type": TYPES[path.extname(file).toLowerCase()] || "application/octet-stream", "Cache-Control": "no-store" });
    res.end(data);
  });
}).listen(PORT, "127.0.0.1", () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Pro Shop mockup: ${url}`);
  if (!process.argv.includes("--no-open")) exec(`start "" ${url}`);
});
