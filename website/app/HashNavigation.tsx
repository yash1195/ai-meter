"use client";

import { useEffect } from "react";

export function HashNavigation() {
  useEffect(() => {
    function scrollToHash() {
      const id = decodeURIComponent(window.location.hash.slice(1));

      if (!id) {
        return;
      }

      document.getElementById(id)?.scrollIntoView({
        behavior: "auto",
        block: "start",
      });
    }

    const frame = window.requestAnimationFrame(() => {
      window.requestAnimationFrame(scrollToHash);
    });
    const timeout = window.setTimeout(scrollToHash, 250);

    window.addEventListener("hashchange", scrollToHash);

    return () => {
      window.cancelAnimationFrame(frame);
      window.clearTimeout(timeout);
      window.removeEventListener("hashchange", scrollToHash);
    };
  }, []);

  return null;
}
