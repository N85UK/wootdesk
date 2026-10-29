import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

for (const viewport of [{ width: 375, height: 812 }, { width: 1440, height: 900 }]) {
  for (const scheme of ['light', 'dark']) {
    for (const route of ['/', '/help/support/']) {
      test(`retirement ${route} ${viewport.width} ${scheme}`, async ({ page }) => {
        await page.route('**/*', (request) => request.request().url().startsWith('http://127.0.0.1:4337/')
          ? request.continue() : request.abort());
        await page.setViewportSize(viewport); await page.emulateMedia({ colorScheme: scheme });
        const response = await page.goto(route);
        expect(response.status()).toBe(410);
        await expect(page.getByRole('heading', { level: 1 })).toHaveText('WootDesk has been retired.');
        expect(await page.locator('a, button, input, select, textarea, [tabindex]').count()).toBe(0);
        await page.keyboard.press('Tab');
        expect(await page.evaluate(() => document.activeElement === document.body)).toBe(true);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
        const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
        expect(result.violations.map((value) => value.id)).toEqual([]);
      });
    }
  }
}
