// Switches which deployment the WebView loads, then syncs it into the native
// project. Capacitor reads server.url from the ROOT config at build time, so a
// forgotten sync ships the previous environment's URL inside the APK.
import { copyFileSync, existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const envs = ["lan", "preview", "prod"];
const env = process.argv[2];

if (!envs.includes(env)) {
  console.error(`Usage: node scripts/use-env.mjs <${envs.join("|")}>`);
  process.exit(1);
}

const source = `config/capacitor.config.${env}.json`;
if (!existsSync(source)) {
  console.error(`Missing ${source}`);
  process.exit(1);
}

copyFileSync(source, "capacitor.config.json");
const { server, android } = JSON.parse(readFileSync("capacitor.config.json", "utf8"));
console.log(`capacitor.config.json <- ${source}`);
console.log(`  server.url            ${server.url}`);
console.log(`  server.cleartext      ${server.cleartext ?? false}`);
console.log(`  allowMixedContent     ${android.allowMixedContent}`);

execFileSync("npx", ["cap", "sync", "android"], { stdio: "inherit", shell: true });
