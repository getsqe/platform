// @ts-check
import { defineConfig } from 'astro/config';

// Static marketing site for platform.getsqe.com. No SSR, no adapter.
export default defineConfig({
  site: 'https://platform.getsqe.com',
  // Single-page site: former standalone routes resolve to in-page anchors so
  // bookmarks / external links don't 404.
  redirects: {
    '/pricing': '/#pricing',
    '/roadmap': '/#roadmap',
    '/about': '/#about',
  },
  markdown: {
    shikiConfig: {
      theme: 'github-dark',
      wrap: false,
    },
  },
});
