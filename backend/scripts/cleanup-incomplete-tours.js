#!/usr/bin/env node
/* eslint-disable no-console */

const path = require('path');
const integrationService = require(path.join(__dirname, '..', 'integration-service'));

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const yes = args.includes('--yes') || args.includes('-y');

async function main() {
  if (!integrationService.isFirebaseInitialized) {
    console.error(
      'Firebase is not initialized. Set FIREBASE_CREDENTIALS_PATH to the service account JSON path.',
    );
    process.exit(1);
  }

  console.log(`Scanning tourPackages for incomplete entries${dryRun ? ' (dry-run)' : ''}...`);

  if (dryRun) {
    const result = await integrationService.cleanupIncompleteTours({ dryRun: true });
    console.log(`Scanned: ${result.scanned}`);
    console.log(`Incomplete: ${result.incompleteCount}`);
    console.table(result.incomplete);
    return;
  }

  if (!yes) {
    const preview = await integrationService.cleanupIncompleteTours({ dryRun: true });
    console.log(`Found ${preview.incompleteCount} incomplete tour(s) out of ${preview.scanned}.`);
    console.table(preview.incomplete);
    console.log('\nRe-run with --yes to permanently delete these tours.');
    return;
  }

  const result = await integrationService.cleanupIncompleteTours({ dryRun: false });
  console.log(`Scanned: ${result.scanned}`);
  console.log(`Deleted: ${result.deleted}`);
  if (result.failed.length > 0) {
    console.log('Failed:');
    console.table(result.failed);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Cleanup failed:', error);
    process.exit(1);
  });
