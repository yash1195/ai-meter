"use client";

import { useState } from "react";

const command =
  "curl -fsSL https://ai-meter.app/install.sh | sh";

export function InstallCommand() {
  const [copied, setCopied] = useState(false);

  async function copyCommand() {
    await navigator.clipboard.writeText(command);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  }

  return (
    <div className="command-block">
      <div className="terminal-dots" aria-hidden="true"><i /><i /><i /></div>
      <code><span>$</span> {command}</code>
      <button type="button" onClick={copyCommand} aria-label="Copy install command">
        {copied ? "COPIED" : "COPY"}
      </button>
    </div>
  );
}
