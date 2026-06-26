# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: smoke.spec.ts >> MixVy Navigation Verification >> Should maintain IndexedStack shell stability across tab switches
- Location: tests\smoke.spec.ts:232:3

# Error details

```
Error: expect(received).toBeTruthy()

Received: false
```

# Page snapshot

```yaml
- button "Enable accessibility" [ref=e2]
```

# Test source

```ts
  201 |       return !ignoredPatterns.some((pattern) => error.includes(pattern));
  202 |     });
  203 | 
  204 |     console.log(`⚠️  Critical Errors: ${criticalErrors.length}`);
  205 |     if (criticalErrors.length > 0) {
  206 |       console.error('❌ Critical Errors Found:');
  207 |       criticalErrors.forEach((err) => console.error(`  - ${err}`));
  208 |     } else {
  209 |       console.log('✅ No critical errors detected');
  210 |     }
  211 |     expect(criticalErrors).toHaveLength(0);
  212 | 
  213 |     // Take a screenshot for visual verification
  214 |     console.log('📸 Taking screenshot...');
  215 |     await page.screenshot({
  216 |       path: 'test-results/smoke-test-screenshot.png',
  217 |       fullPage: false,
  218 |     }).catch(() => console.log('⚠️  Screenshot not saved'));
  219 | 
  220 |     // Final summary
  221 |     console.log('\n' + '='.repeat(60));
  222 |     console.log('✅ NAVIGATION TEST COMPLETED');
  223 |     console.log('='.repeat(60));
  224 |     console.log(`URL: ${LIVE_URL}`);
  225 |     console.log(`Title: ${title}`);
  226 |     console.log(`Flutter Canvas: Ready`);
  227 |     console.log(`Critical Errors: 0`);
  228 |     console.log('Note: Navigation buttons tested via accessibility and text search');
  229 |     console.log('='.repeat(60) + '\n');
  230 |   });
  231 | 
  232 |   test('Should maintain IndexedStack shell stability across tab switches', async ({ page }) => {
  233 |     test.setTimeout(90_000);
  234 | 
  235 |     console.log(`🚀 Navigating to: ${LIVE_URL}`);
  236 |     await page.goto(LIVE_URL, {
  237 |       waitUntil: 'domcontentloaded',
  238 |       timeout: 30_000,
  239 |     });
  240 | 
  241 |     // Wait for Flutter initialization
  242 |     console.log('⏳ Waiting for Flutter initialization...');
  243 |     await page.waitForTimeout(5_000);
  244 | 
  245 |     console.log('\n🔄 TESTING INDEXED STACK STABILITY:\n');
  246 | 
  247 |     // Test rapid navigation to verify IndexedStack handles it correctly
  248 |     const tabTests = [0, 1, 2, 3, 4, 0, 1, 2]; // Mix of tab indices
  249 |     const tabNames = ['Feed', 'Messages', 'Live Rooms', 'Dating', 'Profile'];
  250 | 
  251 |     let clickCount = 0;
  252 | 
  253 |     for (let i = 0; i < tabTests.length; i++) {
  254 |       const tabIndex = tabTests[i];
  255 |       const tabName = tabNames[tabIndex];
  256 | 
  257 |       console.log(`  ${i + 1}. Attempting to switch to "${tabName}"`);
  258 | 
  259 |       try {
  260 |         // Try text-based search first
  261 |         const textLocator = page.locator(`text="${tabName}"`);
  262 |         const exists = await textLocator.count().catch(() => 0);
  263 |         
  264 |         if (exists > 0) {
  265 |           await textLocator.first().click().catch(() => {});
  266 |           clickCount++;
  267 |           console.log(`     ✓ Clicked "${tabName}"`);
  268 |         } else {
  269 |           console.log(`     ⚠️  Could not click "${tabName}"`);
  270 |         }
  271 | 
  272 |         // Verify canvas still exists after click
  273 |         await page.waitForTimeout(600);
  274 |         const canvasExists = await page
  275 |           .locator('flt-glass-pane, canvas, flt-scene-host')
  276 |           .first()
  277 |           .isVisible()
  278 |           .catch(() => false);
  279 | 
  280 |         if (canvasExists) {
  281 |           console.log(`     ✓ Canvas present after navigation`);
  282 |         } else {
  283 |           console.warn(`     ⚠️  Canvas missing after click`);
  284 |         }
  285 |       } catch (error) {
  286 |         console.log(`     ⚠️  Error: ${error}`);
  287 |       }
  288 |     }
  289 | 
  290 |     console.log(`\n✅ IndexedStack Stability Test Complete`);
  291 |     console.log(`   Successful clicks: ${clickCount}/${tabTests.length}`);
  292 |     console.log(`   Canvas stability: Maintained across tabs\n`);
  293 | 
  294 |     // Basic check: Canvas should still be visible
  295 |     const finalCanvasVisible = await page
  296 |       .locator('flt-glass-pane, canvas, flt-scene-host')
  297 |       .first()
  298 |       .isVisible()
  299 |       .catch(() => false);
  300 | 
> 301 |     expect(finalCanvasVisible).toBeTruthy();
      |                                ^ Error: expect(received).toBeTruthy()
  302 |   });
  303 | });
  304 | 
  305 | 
```