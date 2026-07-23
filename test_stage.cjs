const { chromium } = require('playwright');

/**
 * MixVy Stage Load Tester
 * This script spawns 3 "Bots" that join your live room.
 */
async function spawnBot(id) {
    const browser = await chromium.launch({ headless: false }); // Set to true to hide windows
    const context = await browser.newContext();
    const page = await context.newPage();

    console.log(`[Bot ${id}] Starting...`);

    // 1. Go to your site
    await page.goto('https://mix-and-mingle-v2.web.app/register');

    // 2. Sign up a fake account
    const randomSuffix = Math.floor(Math.random() * 10000);
    const username = `BotUser_${randomSuffix}`;
    const email = `bot_${randomSuffix}@test.com`;

    console.log(`[Bot ${id}] Registering as ${username}...`);

    // Adjust selectors based on your actual UI
    await page.fill('input[type="text"]', username);
    await page.fill('input[type="email"]', email);
    await page.fill('input[type="password"]', 'Password123!');
    await page.click('button:has-text("SIGN UP")');

    // 3. Wait for redirect and go to the specific room
    // Note: Change the ID below to your actual room ID from the URL
    const roomId = 'philadelphia-dj-chill';
    await page.waitForTimeout(3000); // Wait for login to settle
    await page.goto(`https://mix-and-mingle-v2.web.app/rooms/room/${roomId}`);

    console.log(`[Bot ${id}] Joined the room!`);

    // 4. Send a chat message
    try {
        await page.fill('input[placeholder="Type a message…"]', `Hello from Bot ${id}! The Stage architecture looks great.`);
        await page.press('input[placeholder="Type a message…"]', 'Enter');
    } catch (e) {
        console.log(`[Bot ${id}] Couldn't send chat, but I'm in the room.`);
    }

    // Keep the bot alive for 5 minutes
    await page.waitForTimeout(300000);
    await browser.close();
}

// Spawn 3 bots
(async () => {
    console.log("🚀 Spawning the MixVy Testing Crew...");
    await Promise.all([
        spawnBot(1),
        spawnBot(2),
        spawnBot(3)
    ]);
})();
