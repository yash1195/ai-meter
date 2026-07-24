import type { Metadata } from "next";
import Image from "next/image";
import { HashNavigation } from "./HashNavigation";
import { InstallCommand } from "./InstallCommand";

export const metadata: Metadata = {
  metadataBase: new URL("https://ai-meter.app"),
  title: "AI Meter — Local AI usage for your Mac",
  description:
    "See coding-agent token usage, electricity, and water estimates—entirely on your Mac.",
  openGraph: {
    title: "AI Meter — Measure your AI locally",
    description:
      "See Codex, Claude Code, Cursor, OpenCode, and Gemini CLI usage—entirely on your Mac.",
    url: "https://ai-meter.app/",
    siteName: "AI Meter",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "AI Meter — local coding-agent usage for macOS",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "AI Meter — Measure your AI locally",
    description:
      "See Codex, Claude Code, Cursor, OpenCode, and Gemini CLI usage—entirely on your Mac.",
    images: ["/og-image.png"],
  },
};

const github = "https://github.com/yash1195/ai-meter";
const download =
  "https://github.com/yash1195/ai-meter/releases/latest/download/AI-Meter.dmg";

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
      <HashNavigation />
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
            AI Meter shows your coding-agent token usage, electricity, and
            water estimates in the macOS menu bar. No accounts. No AI
            telemetry. No usage data leaves your Mac.
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
              width={1176}
              height={1546}
              priority
            />
          </div>
        </figure>
      </section>

      <section className="methodology shell" id="methodology">
        <div className="method-heading">
          <div>
            <span className="method-kicker">TRANSPARENT ESTIMATION</span>
            <h2>From tokens to estimated impact.</h2>
          </div>
          <p>
            AI Meter follows a SCI for AI-aligned consumer boundary. These are
            local scenarios based on published research—not measurements from
            OpenAI, Anthropic, or their data centers.
          </p>
        </div>

        <div className="method-flow">
          <article>
            <span className="method-step">01 / USAGE</span>
            <strong className="method-symbol">#</strong>
            <h3>Provider-reported tokens</h3>
            <p>
              Codex, Claude Code, Cursor, OpenCode, and Gemini CLI token counts
              are read from local records, deduplicated, and combined on your Mac.
            </p>
          </article>

          <article>
            <span className="method-step">02 / ELECTRICITY</span>
            <strong className="method-symbol">⚡</strong>
            <h3>Tokens ÷ 1M × 0.39 kWh</h3>
            <p>
              The default inference factor is 0.39 facility kWh per million
              tokens, with an indicative 0.20–0.75 kWh uncertainty range.
            </p>
          </article>

          <article>
            <span className="method-step">03 / WATER</span>
            <strong className="method-symbol">◒</strong>
            <h3>Energy ÷ PUE × WUE</h3>
            <p>
              Direct cooling water uses a 1.20 PUE and 0.45 L per IT kWh site
              WUE. Both assumptions are adjustable inside AI Meter.
            </p>
          </article>
        </div>

        <div className="method-note">
          <p>
            <strong>What is excluded:</strong> model training, embodied hardware,
            off-site electricity water, grid carbon, networking, and user-device
            energy.
          </p>
          <a href={`${github}/blob/main/METHODOLOGY.md`}>
            Read the full methodology <span aria-hidden="true">↗</span>
          </a>
        </div>
      </section>

      <footer className="footer shell">
        <span>Codex · Claude Code · Cursor · OpenCode · Gemini CLI</span>
        <span>Free for individuals and companies</span>
        <span>© 2026 AI Meter</span>
      </footer>
    </main>
  );
}
