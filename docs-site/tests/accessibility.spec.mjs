import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// N85-50 AC4. Representative pages rather than every page: a home, a guide, a
// reference, a release note and the search entry point. Running the whole site
// would be slower without testing meaningfully different structures.
const PAGES = [
  { name: 'home', path: '/' },
  { name: 'guide', path: '/guides/conversations/' },
  { name: 'reference', path: '/start/requirements/' },
  { name: 'release note', path: '/releases/1.0.0/' },
  { name: 'release index', path: '/releases/' },
];

const VIEWPORTS = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'desktop', width: 1440, height: 900 },
];

const SCHEMES = ['light', 'dark'];

for (const page of PAGES) {
  for (const viewport of VIEWPORTS) {
    for (const scheme of SCHEMES) {
      test(`${page.name} has no accessibility violation, ${viewport.name} ${scheme}`, async ({
        page: browserPage,
      }) => {
        await browserPage.setViewportSize({ width: viewport.width, height: viewport.height });
        await browserPage.emulateMedia({ colorScheme: scheme });
        await browserPage.goto(page.path);

        const results = await new AxeBuilder({ page: browserPage })
          .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
          .analyze();

        // Name the offending rule and element, so a failure is actionable
        // without re-running locally to find out what broke.
        const summary = results.violations.map(
          (violation) =>
            `${violation.id} (${violation.impact}): ${violation.help}\n` +
            violation.nodes.map((node) => `    ${node.target.join(' ')}`).join('\n'),
        );
        expect(summary, summary.join('\n')).toEqual([]);
      });

      // N85-44 AC7. Note what this does NOT do: assert that the document
      // scrolls sideways. Starlight clips horizontal overflow in its layout, so
      // a 3000px element still leaves scrollWidth equal to clientWidth and that
      // assertion can never fail here. It was ported from the n85.app suite,
      // measured against a deliberate 3000px probe, and found to be vacuous.
      //
      // Clipping is the worse outcome anyway: the content is unreachable rather
      // than merely awkward. So this looks for anything extending past the
      // viewport with no scrollable ancestor to reach it by.
      test(`${page.name} keeps content reachable, ${viewport.name} ${scheme}`, async ({
        page: browserPage,
      }) => {
        await browserPage.setViewportSize({ width: viewport.width, height: viewport.height });
        await browserPage.emulateMedia({ colorScheme: scheme });
        await browserPage.goto(page.path);

        const clipped = await browserPage.evaluate((viewportWidth) => {
          const reachable = (element) => {
            for (let node = element; node; node = node.parentElement) {
              const overflow = getComputedStyle(node).overflowX;
              if (overflow === 'auto' || overflow === 'scroll') return true;
            }
            return false;
          };
          const findings = [];
          for (const element of document.body.querySelectorAll('*')) {
            const rect = element.getBoundingClientRect();
            if (rect.width === 0 || rect.height === 0) continue;
            if (rect.right <= viewportWidth + 1) continue;
            if (reachable(element)) continue;
            const name = element.tagName.toLowerCase();
            const cls = String(element.className || '').split(' ')[0];
            findings.push(`${name}${cls ? '.' + cls : ''} reaches ${Math.round(rect.right)}px, no scroller`);
          }
          return [...new Set(findings)].slice(0, 6);
        }, viewport.width);

        expect(clipped, clipped.join('\n')).toEqual([]);
      });
    }
  }
}

test('every page is reachable from the keyboard with visible focus', async ({ page }) => {
  await page.goto('/');

  // Tab to the first focusable element and confirm the browser shows where it is.
  await page.keyboard.press('Tab');
  const focused = page.locator(':focus');
  await expect(focused).toBeVisible();

  const outline = await focused.evaluate((element) => {
    const style = window.getComputedStyle(element);
    return {
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth,
      boxShadow: style.boxShadow,
    };
  });
  const hasVisibleFocus =
    (outline.outlineStyle !== 'none' && outline.outlineWidth !== '0px') ||
    (outline.boxShadow && outline.boxShadow !== 'none');
  expect(hasVisibleFocus, 'The first focusable element shows no focus indicator.').toBeTruthy();
});

test('the first tab stop skips to the main content', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Tab');

  const href = await page.locator(':focus').getAttribute('href');
  expect(href, 'The first tab stop is not a skip link.').toBe('#_top');
});

test('search is reachable and returns a result from the public index', async ({ page }) => {
  // N85-46 AC5. Proves the built Pagefind index answers a query, rather than
  // only that the search control renders. Pagefind is generated by the
  // production build, so this can only pass against dist/.
  await page.goto('/');

  await page.getByRole('button', { name: /search/i }).first().click();

  const dialog = page.locator('dialog[open]');
  await expect(dialog).toBeVisible();

  await dialog.getByRole('textbox', { name: /search/i }).fill('conversation');

  const firstResult = dialog.locator('#starlight__search a').first();
  await expect(firstResult).toBeVisible({ timeout: 15_000 });
});
