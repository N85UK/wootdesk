import { getCollection, type CollectionEntry } from 'astro:content';

export type Release = CollectionEntry<'releases'>;

/**
 * Every release that may appear on the public site.
 *
 * A `draft` release is filtered out here, once, and every route, listing,
 * sitemap entry and search record derives from this function. That is what
 * makes N85-46 AC4 an enforced property rather than a convention: there is no
 * second path by which a draft could become a page.
 */
export async function publishedReleases(): Promise<Release[]> {
  const all = await getCollection('releases');
  return all
    .filter((release) => release.data.status !== 'draft')
    .sort((a, b) => b.data.date.getTime() - a.data.date.getTime());
}

/** A human label for a release's publication state. */
export function statusLabel(status: Release['data']['status']): string {
  switch (status) {
    case 'released':
      return 'Released';
    case 'testflight':
      return 'TestFlight only';
    case 'draft':
      return 'Draft';
  }
}

export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

/** The fixed section order every release note renders in. */
export const RELEASE_SECTIONS = [
  { key: 'highlights', title: 'Highlights' },
  { key: 'fixes', title: 'Fixes' },
  { key: 'security', title: 'Security' },
  { key: 'compatibility', title: 'Compatibility' },
  { key: 'knownIssues', title: 'Known issues' },
] as const;

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

/**
 * The headings a release note will actually render.
 *
 * Starlight builds its "On this page" list from a page's Markdown headings,
 * and these are produced by a component instead, so they have to be handed
 * over explicitly or the table of contents shows nothing but the title.
 */
export function releaseHeadings(
  release: Release,
  depth = 2
): Array<{ depth: number; slug: string; text: string }> {
  const present = RELEASE_SECTIONS.filter(
    (section) => release.data[section.key].length > 0
  ).map((section) => section.title);

  return [...present, 'Action required'].map((text) => ({
    depth,
    slug: slugify(text),
    text,
  }));
}
