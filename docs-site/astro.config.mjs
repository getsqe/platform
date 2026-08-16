// @ts-check
import { defineConfig } from 'astro/config'
import starlight from '@astrojs/starlight'
import starlightOpenAPI, { openAPISidebarGroups } from 'starlight-openapi'
import { passthroughImageService } from 'astro/config'

// LOCAL config — authored here, NOT synced from $DP. sync-docs-from-dp.sh
// copies content only, so this file survives a re-sync. It differs from the
// source config in exactly four ways, all of them publishing concerns:
//
//   1. site/base   — served under platform.getsqe.com/docs, not at a root
//   2. title       — public framing; the source says "Chameleon Data Platform"
//   3. noindex     — /docs is unlinked and non-indexed (obscurity, not privacy)
//   4. script src  — must carry the /docs base or it 404s
//
// Everything else mirrors the source. If the source adds a sidebar directory,
// this file will silently omit it — re-read $DP/docs-site/astro.config.mjs on
// every refresh. That is a known, accepted drift risk.
const OPENAPI_SPEC = './src/openapi.json'

export default defineConfig({
  site: 'https://platform.getsqe.com',
  base: '/docs',
  outDir: './dist',
  // NO IMAGE PROCESSING. Astro's default image service is sharp, which ships
  // libvips binaries under LGPL-3.0-or-later — blocked by the licence policy.
  // Screenshots are served at the size they were committed at.
  image: { service: passthroughImageService() },
  integrations: [
    starlight({
      title: 'Cloud Independent Data Platform',
      description:
        'Sovereign data platform — Iceberg catalog, per-user authorization, and the engines, pipelines and agents on top of it.',
      // starlight-openapi is a STARLIGHT PLUGIN, not an Astro integration —
      // passing it to `integrations` type-checks and silently generates nothing.
      plugins: [
        starlightOpenAPI([
          {
            base: 'reference/api',
            label: 'REST API',
            schema: OPENAPI_SPEC,
            collapsed: true,
          },
        ]),
      ],
      expressiveCode: {
        themes: ['github-dark', 'github-light'],
      },
      customCss: ['./src/styles/image-zoom.css'],
      head: [
        // Unlinked and non-indexed. This does NOT make the content private —
        // it is served publicly and the markdown is in a public repo.
        {
          tag: 'meta',
          attrs: { name: 'robots', content: 'noindex, nofollow' },
        },
        // Absolute path must include the base, or it 404s under /docs.
        {
          tag: 'script',
          attrs: { src: '/docs/scripts/image-zoom.js', defer: true },
        },
      ],
      sidebar: [
        { label: 'Start here', items: [{ autogenerate: { directory: 'start' } }] },
        { label: 'Concepts', items: [{ autogenerate: { directory: 'concepts' } }] },
        { label: 'Guides', items: [{ autogenerate: { directory: 'guides' } }] },
        { label: 'Reference', items: [{ autogenerate: { directory: 'reference' } }] },
        ...openAPISidebarGroups,
      ],
    }),
  ],
})
