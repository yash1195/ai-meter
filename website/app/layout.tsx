import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "AI Meter — Local AI usage for your Mac",
    template: "%s — AI Meter",
  },
  description:
    "Track Codex and Claude Code token usage, electricity, and water estimates—entirely on your Mac.",
  metadataBase: new URL("https://yash1195.github.io/ai-meter"),
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
