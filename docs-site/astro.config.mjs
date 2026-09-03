// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

/**
 * Public WootDesk documentation.
 *
 * This site is published at https://docs.n85.app and is readable without
 * authentication. It carries WootDesk product documentation only. Anything
 * concerning another N85 project, or any internal operational material,
 * belongs in the separate private site and never in this source tree. See
 * `docs/decisions/0007-documentation-publication-boundary.md` in the
 * repository root.
 */
export default defineConfig({
  site: 'https://docs.n85.app',
  // A static build: no server runtime, no database, no product credentials,
  // and no request to a Chatwoot server at build time.
  output: 'static',
  trailingSlash: 'ignore',
  integrations: [
    starlight({
      title: 'WootDesk Docs',
      description:
        'Documentation for WootDesk, an independent native Apple client for Chatwoot.',
      logo: {
        src: './src/assets/wootdesk-mark.svg',
        alt: 'WootDesk',
        replacesTitle: false,
      },
      favicon: '/favicon.svg',
      editLink: {
        baseUrl: 'https://github.com/N85UK/wootdesk/edit/main/docs-site/',
      },
      social: [
        {
          icon: 'github',
          label: 'WootDesk on GitHub',
          href: 'https://github.com/N85UK/wootdesk',
        },
      ],
      // The only permitted outbound N85 link from the public documentation is
      // the public app home. docs.n85.dev is private and must never appear.
      components: {
        Footer: './src/components/Footer.astro',
      },
      sidebar: [
        {
          label: 'Start here',
          items: [
            { label: 'What WootDesk is', slug: 'index' },
            { label: 'Requirements', slug: 'start/requirements' },
            { label: 'Install and connect', slug: 'start/getting-started' },
          ],
        },
        {
          label: 'Using WootDesk',
          items: [
            { label: 'Conversations', slug: 'guides/conversations' },
            { label: 'Replies and private notes', slug: 'guides/replies-and-notes' },
            { label: 'Attachments', slug: 'guides/attachments' },
            { label: 'Triage', slug: 'guides/triage' },
            { label: 'Availability', slug: 'guides/availability' },
            { label: 'Notifications', slug: 'guides/notifications' },
            { label: 'Server profiles', slug: 'guides/server-profiles' },
            { label: 'Working offline', slug: 'guides/offline' },
          ],
        },
        {
          label: 'Trust',
          items: [
            { label: 'Security', slug: 'trust/security' },
            { label: 'Privacy', slug: 'trust/privacy' },
          ],
        },
        {
          label: 'Help',
          items: [
            { label: 'Troubleshooting', slug: 'help/troubleshooting' },
            { label: 'Known issues', slug: 'help/known-issues' },
            { label: 'Getting support', slug: 'help/support' },
          ],
        },
        {
          // Release pages are generated from the `releases` collection in
          // `src/pages/releases/`, so they are linked rather than slugged.
          label: 'Releases',
          items: [
            { label: "What's new", link: '/releases' },
            { label: 'Changelog', link: '/releases/changelog' },
          ],
        },
      ],
      lastUpdated: true,
      pagination: true,
    }),
  ],
});
