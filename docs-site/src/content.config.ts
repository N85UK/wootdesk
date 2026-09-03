import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { glob } from 'astro/loaders';

/**
 * Release notes are a collection of their own rather than ordinary docs pages.
 *
 * Keeping them separate is what makes N85-46 AC4 enforceable: a draft is never
 * a route, so it cannot leak into navigation, the Pagefind index, the sitemap
 * or social metadata by being forgotten. Routing happens explicitly in
 * `src/pages/releases/`, which filters on `status` before generating anything.
 */
const releases = defineCollection({
  loader: glob({ base: './src/content/releases', pattern: '**/*.md' }),
  schema: z.object({
    /** Marketing version, used verbatim as the `/releases/{version}` route. */
    version: z
      .string()
      .regex(/^\d+\.\d+\.\d+$/, 'Use a three-part version, for example 1.0.0'),
    /** The date the release became available to its audience. */
    date: z.coerce.date(),
    /**
     * `draft` is never built. `testflight` and `released` are public.
     * A version that has not shipped must not be described as `released`.
     */
    status: z.enum(['draft', 'testflight', 'released']),
    /** One sentence for the release index. */
    summary: z.string().min(10).max(300),
    /** Where the build can actually be obtained, in plain words. */
    availability: z.string().min(3),
    highlights: z.array(z.string()).default([]),
    fixes: z.array(z.string()).default([]),
    security: z.array(z.string()).default([]),
    /** Supported platform or Chatwoot compatibility changes. */
    compatibility: z.array(z.string()).default([]),
    knownIssues: z.array(z.string()).default([]),
    /** What a reader must do before or after updating, if anything. */
    upgradeAction: z.string().default('No action is required.'),
    /** The matching Git tag, when one has been pushed. */
    sourceTag: z.string().optional(),
    sourceURL: z.string().url().optional(),
  }),
});

export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
  releases,
};
