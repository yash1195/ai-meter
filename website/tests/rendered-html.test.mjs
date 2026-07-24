import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const siteRoot = new URL("../", import.meta.url);

test("exports a static AI Meter landing page", async () => {
  await access(new URL("out/index.html", siteRoot));
  const html = await readFile(new URL("out/index.html", siteRoot), "utf8");

  assert.match(html, /AI Meter/);
  assert.match(html, /Measure your AI/);
  assert.match(html, /No usage data leaves your Mac/);
  assert.match(html, /install\.sh/);
  assert.match(html, /AI-Meter\.dmg/);
  assert.match(html, /rel="icon"/);
  assert.match(html, /rel="apple-touch-icon"/);
  assert.match(html, /Direct download/);
  assert.match(html, /View on GitHub/);
  assert.match(html, /ai-meter-app\.png/);
  assert.match(html, /From tokens to estimated impact/);
  assert.match(html, /0\.39 kWh/);
  assert.match(html, /Energy ÷ PUE × WUE/);
  assert.match(html, /METHODOLOGY\.md/);
  assert.doesNotMatch(html, /Your site is taking shape/);
});
