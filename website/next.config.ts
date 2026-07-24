import type { NextConfig } from "next";

const isGitHubPages = process.env.GITHUB_PAGES === "true";
const githubBasePath = "/ai-meter";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  devIndicators: false,
  images: {
    unoptimized: true,
  },
  basePath: isGitHubPages ? githubBasePath : undefined,
  assetPrefix: isGitHubPages ? githubBasePath : undefined,
};

export default nextConfig;
