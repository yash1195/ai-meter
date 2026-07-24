# AI Meter website

The static marketing site for AI Meter. It contains no analytics, cookies,
database, server API, or runtime dependency.

## Local preview

```sh
npm install
npm run dev
```

Open `http://localhost:3000`.

## Build

```sh
npm test
```

The production site is exported to `out/` as plain static files. Upload that
directory to GitHub Pages, S3, CloudFront, or any other static host.

### S3 or a root domain

```sh
npm run build
```

Upload the contents of `out/`.

### GitHub Pages

```sh
npm run build:github
```

This adds the repository base path (`/ai-meter`) to generated asset URLs. Publish
the contents of `out/` with GitHub Pages Actions. The included `.nojekyll` file
ensures GitHub serves Next.js `_next` assets.

## Installer

The curl command shown on the page points to the repository-root `install.sh`.
That script downloads the latest `AI-Meter.zip` GitHub release asset and verifies:

- the bundle identifier is `com.zeko.aimeter`;
- the app has a valid Apple code signature;
- the Developer ID team is `L6AR4H8B39`.

The release asset must be signed and notarized before publication.
