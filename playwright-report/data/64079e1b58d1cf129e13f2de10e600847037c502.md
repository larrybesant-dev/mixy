# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: runtime-validation.spec.ts >> restricted route validation for signed-out and guest sessions
- Location: tests\runtime-validation.spec.ts:164:1

# Error details

```
Error: expect(received).toBeFalsy()

Received: true
```

# Page snapshot

```yaml
- button "Enable accessibility" [ref=e2]
```

# Test source

```ts
  81  |   observer: RuntimeObserver,
  82  |   placeholder: string,
  83  |   value: string,
  84  | ): Promise<void> {
  85  |   const input = page.getByPlaceholder(placeholder).first();
  86  |   try {
  87  |     await expect(input).toBeVisible({ timeout: 15_000 });
  88  |     await input.fill(value);
  89  |   } catch (error) {
  90  |     observer.recordSelectorFailure(`placeholder:${placeholder}`, String(error));
  91  |     throw error;
  92  |   }
  93  | }
  94  | 
  95  | async function writeSummary(testInfo: TestInfo, summary: RuntimeSummary): Promise<void> {
  96  |   await fs.mkdir(artifactsDir, { recursive: true });
  97  |   const fileName = `${slugify(testInfo.title)}.json`;
  98  |   const filePath = path.join(artifactsDir, fileName);
  99  |   await fs.writeFile(filePath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  100 |   await testInfo.attach('runtime-summary', {
  101 |     body: JSON.stringify(summary, null, 2),
  102 |     contentType: 'application/json',
  103 |   });
  104 | }
  105 | 
  106 | test.beforeAll(async () => {
  107 |   liveBaseUrl = await detectLiveMixVyUrl();
  108 |   process.env.PLAYWRIGHT_LIVE_URL = liveBaseUrl;
  109 |   // eslint-disable-next-line no-console
  110 |   console.log(`[runtime-suite] Using base URL: ${liveBaseUrl}`);
  111 | });
  112 | 
  113 | test('auth redirect validation from root', async ({ page }, testInfo) => {
  114 |   const observer = new RuntimeObserver('auth-redirect-validation');
  115 |   observer.attach(page);
  116 | 
  117 |   await go(page, observer, `${liveBaseUrl}/`);
  118 |   await waitForFlutterWasmStable(page);
  119 |   await expect(page).toHaveURL(/\/(auth|home)(\?|$)/, { timeout: 45_000 });
  120 | 
  121 |   const summary = observer.summary(page.url());
  122 |   expect(summary.navigationLoopDetected).toBeFalsy();
  123 |   await writeSummary(testInfo, summary);
  124 | });
  125 | 
  126 | test('guest mode validation and target route access', async ({ page }, testInfo) => {
  127 |   const observer = new RuntimeObserver('guest-mode-validation');
  128 |   observer.attach(page);
  129 | 
  130 |   await go(page, observer, `${liveBaseUrl}/auth`);
  131 |   await waitForFlutterWasmStable(page);
  132 | 
  133 |   const guestButton = page.getByText(/enter\s+as\s+guest/i).first();
  134 |   if (await guestButton.isVisible().catch(() => false)) {
  135 |     await clickTextAnyRole(page, observer, /enter\s+as\s+guest/i, 'enter-as-guest');
  136 |     await expect(page).toHaveURL(/\/home(\?|$)/, { timeout: 45_000 });
  137 |   } else {
  138 |     // Session may already be routed to home after hydration.
  139 |     await expect(page).toHaveURL(/\/(home|auth)(\?|$)/, { timeout: 45_000 });
  140 |     const path = await currentPath(page);
  141 |     if (path !== '/home') {
  142 |       await go(page, observer, `${liveBaseUrl}/home`);
  143 |       await waitForFlutterWasmStable(page);
  144 |     }
  145 |   }
  146 | 
  147 |   await go(page, observer, `${liveBaseUrl}/profile/runtime-guest-profile`);
  148 |   await waitForFlutterWasmStable(page);
  149 |   await expect(page).toHaveURL(/\/profile\//, { timeout: 30_000 });
  150 | 
  151 |   await go(page, observer, `${liveBaseUrl}/room/runtime-guest-room`);
  152 |   await waitForFlutterWasmStable(page);
  153 |   await expect(page).toHaveURL(/\/room\//, { timeout: 30_000 });
  154 | 
  155 |   await go(page, observer, `${liveBaseUrl}/create-room`);
  156 |   await waitForFlutterWasmStable(page);
  157 |   await expect(page).toHaveURL(/\/(auth|create-room)(\?|$)/, { timeout: 45_000 });
  158 | 
  159 |   const summary = observer.summary(page.url());
  160 |   expect(summary.navigationLoopDetected).toBeFalsy();
  161 |   await writeSummary(testInfo, summary);
  162 | });
  163 | 
  164 | test('restricted route validation for signed-out and guest sessions', async ({ page }, testInfo) => {
  165 |   const observer = new RuntimeObserver('restricted-route-validation');
  166 |   observer.attach(page);
  167 | 
  168 |   await go(page, observer, `${liveBaseUrl}/auth`);
  169 |   await waitForFlutterWasmStable(page);
  170 |   const guestButton = page.getByText(/enter\s+as\s+guest/i).first();
  171 |   if (await guestButton.isVisible().catch(() => false)) {
  172 |     await clickTextAnyRole(page, observer, /enter\s+as\s+guest/i, 'enter-as-guest-restricted-flow');
  173 |     await expect(page).toHaveURL(/\/home(\?|$)/, { timeout: 45_000 });
  174 |   }
  175 | 
  176 |   await go(page, observer, `${liveBaseUrl}/create-room`);
  177 |   await waitForFlutterWasmStable(page);
  178 |   await expect(page).toHaveURL(/\/(auth|create-room)(\?|$)/, { timeout: 45_000 });
  179 | 
  180 |   const summary = observer.summary(page.url());
> 181 |   expect(summary.navigationLoopDetected).toBeFalsy();
      |                                          ^ Error: expect(received).toBeFalsy()
  182 |   await writeSummary(testInfo, summary);
  183 | });
  184 | 
  185 | test('runtime console and network capture on target flows', async ({ page }, testInfo) => {
  186 |   test.setTimeout(240_000);
  187 |   const observer = new RuntimeObserver('runtime-capture');
  188 |   observer.attach(page);
  189 | 
  190 |   const flows = [
  191 |     '/',
  192 |     '/auth',
  193 |     '/home',
  194 |     '/profile/runtime-capture-profile',
  195 |     '/room/runtime-capture-room',
  196 |     '/create-room',
  197 |   ];
  198 | 
  199 |   for (const route of flows) {
  200 |     await go(page, observer, `${liveBaseUrl}${route}`);
  201 |     await waitForRouteSettle(page);
  202 |   }
  203 | 
  204 |   const summary = observer.summary(page.url());
  205 |   await writeSummary(testInfo, summary);
  206 | });
  207 | 
  208 | test('authenticated room creation validation', async ({ page }, testInfo) => {
  209 |   const observer = new RuntimeObserver('authenticated-room-creation-validation');
  210 |   observer.attach(page);
  211 | 
  212 |   const email = process.env.MIXVY_TEST_EMAIL;
  213 |   const password = process.env.MIXVY_TEST_PASSWORD;
  214 | 
  215 |   test.skip(
  216 |     !email || !password,
  217 |     'MIXVY_TEST_EMAIL and MIXVY_TEST_PASSWORD are required for authenticated room creation validation.',
  218 |   );
  219 | 
  220 |   await go(page, observer, `${liveBaseUrl}/auth`);
  221 |   await waitForFlutterWasmStable(page);
  222 |   await fillByPlaceholder(page, observer, 'Email address', email!);
  223 |   await fillByPlaceholder(page, observer, 'Password', password!);
  224 |   await clickButtonByName(page, observer, 'SIGN IN');
  225 | 
  226 |   await page.waitForURL(/\/(home|onboarding)(\?|$)/, { timeout: 30_000 });
  227 |   const postLoginUrl = page.url();
  228 | 
  229 |   if (/\/onboarding(\?|$)/.test(postLoginUrl)) {
  230 |     throw new Error(
  231 |       'Authenticated user was redirected to /onboarding. Complete legal acceptance for this test account, then rerun.',
  232 |     );
  233 |   }
  234 | 
  235 |   await go(page, observer, `${liveBaseUrl}/create-room`);
  236 |   await waitForFlutterWasmStable(page);
  237 | 
  238 |   const roomName = `PW Runtime ${Date.now()}`;
  239 |   await fillByPlaceholder(page, observer, 'e.g. Late Night Music Session', roomName);
  240 | 
  241 |   observer.recordAction('create-room-submit');
  242 |   await clickTextAnyRole(page, observer, /start\s+room\s+now/i, 'start-room-now');
  243 | 
  244 |   await page.waitForURL(/\/room\/[^/?#]+/, { timeout: 45_000 });
  245 |   await waitForFlutterWasmStable(page);
  246 | 
  247 |   const summary = observer.summary(page.url());
  248 |   const roomNavigations = summary.urlTransitions.filter((u) => /\/room\/[^/?#]+/.test(u)).length;
  249 |   expect(roomNavigations).toBe(1);
  250 |   expect(summary.actionCounts['create-room-submit']).toBe(1);
  251 |   expect(summary.duplicateActions).not.toContain('create-room-submit');
  252 |   expect(summary.navigationLoopDetected).toBeFalsy();
  253 | 
  254 |   // Strong signal for duplicate room write attempts in browser runtime traffic.
  255 |   expect(summary.roomWriteSignals).toBeLessThanOrEqual(1);
  256 | 
  257 |   await writeSummary(testInfo, summary);
  258 | });
  259 | 
  260 | test('deep link survives refresh and auth bootstrap', async ({ page }, testInfo) => {
  261 |   const observer = new RuntimeObserver('deep-link-survival');
  262 |   observer.attach(page);
  263 | 
  264 |   // Use a deterministic room ID for testing the deep link path
  265 |   const testRoomId = `pw-deep-link-test-${Date.now()}`;
  266 |   const deepLink = `${liveBaseUrl}/rooms/room/${testRoomId}`;
  267 | 
  268 |   // Navigate directly to the deep link
  269 |   observer.recordAction(`goto-deeplink:${deepLink}`);
  270 |   await page.goto(deepLink);
  271 | 
  272 |   // Wait for Flutter and Auth bootstrap
  273 |   await waitForFlutterWasmStable(page);
  274 | 
  275 |   // Expect to stay on the room route (or be redirected to auth if forced)
  276 |   // The crucial part is that it shouldn't get stuck on / or redirect to /home prematurely
  277 |   await expect(page).toHaveURL(new RegExp(`/rooms/room/${testRoomId}`), { timeout: 30000 });
  278 | 
  279 |   // Verify the 'Joining room' loading scaffold appears (means it successfully targeted the room)
  280 |   const joiningText = page.getByText(/Joining room/i).first();
  281 |   await expect(joiningText).toBeVisible({ timeout: 15000 });
```