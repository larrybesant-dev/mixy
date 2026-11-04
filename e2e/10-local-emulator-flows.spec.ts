import { expect, test, type Page } from '@playwright/test';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import {
  authenticateTestUser,
  enableFlutterSemantics,
  waitForAppReady,
} from './utils/auth';

type LocalAccount = {
  email: string;
  password: string;
};

const emulatorEnabled = process.env.FIREBASE_EMULATOR_E2E === '1';

function localAccounts(): LocalAccount[] {
  const parsed = JSON.parse(process.env.TEST_ACCOUNTS_JSON ?? '{}') as {
    accounts?: LocalAccount[];
  };
  return parsed.accounts ?? [];
}

async function signIn(page: Page, account: LocalAccount): Promise<void> {
  process.env.TEST_ACCOUNTS_JSON = JSON.stringify({ accounts: [account] });
  process.env.E2E_ACCOUNT_INDEX = '0';
  expect(await authenticateTestUser(page)).toBe(true);
  await waitForAppReady(page);
  await enableFlutterSemantics(page);
  await expect(page).not.toHaveURL(/\/auth(?:$|[/?#])/);
}

async function openConversation(
  page: Page,
  participantName: string,
  rowY: number,
): Promise<void> {
  if (/\/rooms\/room\//.test(new URL(page.url()).pathname)) {
    await page.mouse.click(28, 28);
    await expect(page).toHaveURL(/\/rooms(?:$|[/?#])/);
  }
  const messages = page.getByText('Messages', { exact: true }).first();
  if (await messages.isVisible().catch(() => false)) {
    await messages.click();
  } else {
    await page.mouse.click(100, 160);
  }
  await expect(page).toHaveURL(/\/messages(?:$|[/?#])/);
  const participant = page.getByText(participantName, { exact: true }).first();
  if (await participant.isVisible().catch(() => false)) {
    await participant.click();
  } else {
    await page.mouse.click(390, rowY);
  }
  await page.waitForTimeout(500);
}

async function openRooms(page: Page): Promise<void> {
  const rooms = page.getByText('Rooms', { exact: true }).first();
  if (await rooms.isVisible().catch(() => false)) {
    await rooms.click();
  } else {
    await page.mouse.click(100, 203);
  }
  await expect(page).toHaveURL(/\/rooms(?:$|[/?#])/);
}

async function openRoomCreator(page: Page): Promise<void> {
  const startRoom = page.getByText('Start a Room', { exact: true }).first();
  if (await startRoom.isVisible().catch(() => false)) {
    await startRoom.click();
  } else {
    await page.mouse.click(700, 196);
  }
  await expect(page).toHaveURL(/\/rooms\/create(?:$|[?#])/);
}

test.describe('Firebase emulator user journeys', () => {
  test.skip(
    !emulatorEnabled,
    'Run through npm run test:e2e:emulator with Firebase emulators.',
  );

  test('authenticates, creates a room, and delivers a realtime message', async ({
    browser,
  }) => {
    const accounts = localAccounts();
    expect(accounts).toHaveLength(2);
    const conversationId = process.env.LOCAL_E2E_CONVERSATION_ID;
    expect(conversationId).toBeTruthy();

    const alphaContext = await browser.newContext();
    const betaContext = await browser.newContext();
    const alphaPage = await alphaContext.newPage();
    const betaPage = await betaContext.newPage();

    try {
      await signIn(alphaPage, accounts[0]);

      await openRooms(alphaPage);
      await openRoomCreator(alphaPage);
      const roomTitle = alphaPage.getByPlaceholder(
        'e.g. Late Night Music Session',
      );
      if (await roomTitle.isVisible().catch(() => false)) {
        await roomTitle.fill('Local Emulator Room');
      } else {
        await alphaPage.mouse.click(500, 225);
        await alphaPage.keyboard.type('Local Emulator Room');
      }
      const startRoom = alphaPage.getByRole('button', {
        name: /START ROOM NOW/,
      });
      if (await startRoom.isVisible().catch(() => false)) {
        await startRoom.click();
      } else {
        await alphaPage.mouse.click(640, 645);
      }
      await expect(alphaPage).toHaveURL(/\/rooms\/room\/[^/?#]+/);

      const roomId = new URL(alphaPage.url()).pathname.split('/').pop();
      expect(roomId).toBeTruthy();
      const adminApp =
        getApps().find((candidate) => candidate.name === 'local-e2e') ??
        initializeApp({ projectId: 'mixvy-v2' }, 'local-e2e');
      const firestore = getFirestore(adminApp);
      await expect
        .poll(async () => (await firestore.collection('rooms').doc(roomId!).get()).exists)
        .toBe(true);

      await signIn(betaPage, accounts[1]);
      await openConversation(alphaPage, 'LocalBeta', 260);
      await openConversation(betaPage, 'LocalAlpha', 200);

      const message = `Realtime emulator message ${Date.now()}`;
      const betaConversationBefore = await betaPage.screenshot({
        clip: { x: 590, y: 200, width: 650, height: 430 },
      });
      const composer = alphaPage.getByPlaceholder('message…');
      if (await composer.isVisible().catch(() => false)) {
        await composer.fill(message);
      } else {
        await alphaPage.mouse.click(850, 685);
        await alphaPage.keyboard.type(message);
      }
      const send = alphaPage.getByRole('button', { name: /send/i }).last();
      if (await send.isVisible().catch(() => false)) {
        await send.click();
      } else {
        await alphaPage.mouse.click(1222, 685);
      }

      const receivedMessage = betaPage.getByText(message, { exact: true });
      if (await receivedMessage.isVisible().catch(() => false)) {
        await expect(receivedMessage).toBeVisible();
      } else {
        await expect
          .poll(async () => {
            const current = await betaPage.screenshot({
              clip: { x: 590, y: 200, width: 650, height: 430 },
            });
            return !current.equals(betaConversationBefore);
          })
          .toBe(true);
      }
      await expect
        .poll(async () => {
          const snapshot = await firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('content', '==', message)
            .get();
          return snapshot.size;
        })
        .toBe(1);
    } finally {
      await alphaContext.close();
      await betaContext.close();
    }
  });
});
