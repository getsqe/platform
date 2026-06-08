// @ts-check
import { defineConfig } from 'astro/config';

// Static marketing site for platform.getsqe.com. No SSR, no adapter.
export default defineConfig({
  site: 'https://platform.getsqe.com',
  markdown: {
    shikiConfig: {
      theme: 'github-dark',
      wrap: false,
    },
  },
});
