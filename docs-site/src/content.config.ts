// Astro 5 requires the docs collection to be declared explicitly. Without this
// file the build silently succeeds and emits ONE page — the site looks like it
// works and contains nothing.
import { defineCollection } from 'astro:content'
import { docsLoader } from '@astrojs/starlight/loaders'
import { docsSchema } from '@astrojs/starlight/schema'

export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
}
