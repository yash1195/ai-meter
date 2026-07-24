import type { Metadata } from "next";
import Image from "next/image";
import { InstallCommand } from "./InstallCommand";

export const metadata: Metadata = {
  title: "AI Meter — Local AI usage for your Mac",
  description:
    "See Codex and Claude Code token usage, electricity, and water estimates—entirely on your Mac.",
};

const github = "https://github.com/yash1195/ai-meter";
const download =
  "https://github.com/yash1195/ai-meter/releases/latest/download/AI-Meter.zip";

function Mark() {
  return (
    <span className="mark" aria-hidden="true">
      <i />
      <i />
      <i />
    </span>
  );
}

export default function Home() {
  return (
    <main className="page">
      <nav className="nav shell" aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="AI Meter home">
          <Mark />
          <span>AI METER</span>
        </a>

        <a className="nav-download" href={download}>
          Direct download <span aria-hidden="true">↓</span>
        </a>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <div className="eyebrow">
            <span aria-hidden="true" />
            Private by default
          </div>

          <h1>
            Measure your AI.
            <br />
            <em>Locally.</em>
          </h1>

          <p className="lede">
            AI Meter shows your Codex and Claude Code token usage, electricity,
            and water estimates in the macOS menu bar. No accounts. No analytics.
            No usage data leaves your Mac.
          </p>

          <div className="actions">
            <a className="button primary" href={download}>
              Download for macOS <span aria-hidden="true">↓</span>
            </a>
            <a className="button secondary" href={github}>
              View on GitHub <span aria-hidden="true">↗</span>
            </a>
          </div>

          <div className="terminal-wrap">
            <span className="terminal-label">INSTALL FROM TERMINAL</span>
            <InstallCommand />
          </div>

          <p className="local-note">
            <span aria-hidden="true">●</span>
            Reads local provider files. The only network request is a public
            update check.
          </p>
        </div>

        <figure className="product">
          <div className="product-label">
            <span>THE ACTUAL APP</span>
            <span>MACOS · LOCAL ONLY</span>
          </div>
          <div className="screenshot-frame">
            <Image
              src="/ai-meter-app.png"
              alt="AI Meter macOS widget showing local token usage, electricity, water, and an interactive usage chart"
              width={1080}
              height={1440}
              priority
            />
          </div>
        </figure>
      </section>

      <footer className="footer shell">
        <span>Codex + Claude Code</span>
        <span>Free for individuals and companies</span>
        <span>© 2026 AI Meter</span>
      </footer>
    </main>
  );
}
