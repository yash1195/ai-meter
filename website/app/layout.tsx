import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "AI Meter — Local AI usage and impact estimates",
    template: "%s — AI Meter",
  },
  description:
    "Measure local coding-agent token usage and estimate associated electricity and direct cooling-water use—entirely on your Mac.",
  metadataBase: new URL("https://ai-meter.app"),
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
