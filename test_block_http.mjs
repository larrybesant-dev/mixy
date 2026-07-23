#!/usr/bin/env node

/**
 * Quick test to verify checkBlockStatus endpoint is deployed and callable
 */

import https from "https";
import { URL } from "url";

const CHECK_BLOCK_ENDPOINT = "https://us-central1-mixvy-v2.cloudfunctions.net/checkBlockStatus";

async function httpsPost(url, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const postData = JSON.stringify(data);

    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname + urlObj.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
        ...headers,
      },
    };

    const req = https.request(options, (res) => {
      let responseData = "";

      res.on("data", (chunk) => {
        responseData += chunk;
      });

      res.on("end", () => {
        try {
          const parsed = JSON.parse(responseData);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: responseData });
        }
      });
    });

    req.on("error", reject);
    req.write(postData);
    req.end();
  });
}

async function testEndpointAccess() {
  console.log("=".repeat(70));
  console.log("TESTING CHECKBLOCKSTATUS ENDPOINT ACCESSIBILITY");
  console.log("=".repeat(70));

  console.log(`\n🌐 Endpoint: ${CHECK_BLOCK_ENDPOINT}`);

  try {
    // Try to call the endpoint - it will fail auth but we can see if it's deployed
    console.log(`\n📡 Attempting to call endpoint...`);
    
    const response = await httpsPost(
      CHECK_BLOCK_ENDPOINT,
      {
        data: {
          conversationId: "test",
        },
      },
      {
        Authorization: "Bearer test_token",
      }
    );

    console.log(`\n✅ Got response from endpoint!`);
    console.log(`   Status: ${response.status}`);
    console.log(`   Response:`, JSON.stringify(response.data, null, 2));
    
    if (response.status === 401) {
      console.log(`\n✅ Status 401 = Endpoint is deployed and requires authentication`);
      console.log(`   This is EXPECTED - the endpoint needs a valid ID token`);
      return true;
    } else if (response.status === 200) {
      console.log(`\n✅ Status 200 = Endpoint responded successfully`);
      return true;
    } else if (response.status === 404) {
      console.log(`\n❌ Status 404 = Endpoint not found`);
      return false;
    } else {
      console.log(`\n⚠️  Unexpected status`);
      return false;
    }
  } catch (error) {
    console.error(`\n❌ Error:`, error.message);
    return false;
  }
}

async function main() {
  const success = await testEndpointAccess();
  console.log("\n" + "=".repeat(70));
  if (success) {
    console.log("✅ ENDPOINT IS DEPLOYED AND CALLABLE");
  } else {
    console.log("❌ ENDPOINT NOT ACCESSIBLE");
  }
  console.log("=".repeat(70));
  
  process.exit(success ? 0 : 1);
}

main();
