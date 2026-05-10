#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require('fs');
const path = require('path');
const integrationService = require(path.join(__dirname, '..', 'integration-service'));

async function main() {
  if (!integrationService.isFirebaseInitialized) {
    console.error(
      'Firebase is not initialized. Set FIREBASE_CREDENTIALS_PATH to the service account JSON path.',
    );
    process.exit(1);
  }

  console.log('Exporting backup...');
  const backup = await integrationService.exportBackup();

  const backupsDir = path.join(__dirname, '..', 'data', 'backups');
  if (!fs.existsSync(backupsDir)) {
    fs.mkdirSync(backupsDir, { recursive: true });
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filePath = path.join(backupsDir, `backup-${stamp}.json`);
  fs.writeFileSync(filePath, JSON.stringify(backup, null, 2), 'utf8');

  console.log(`Backup written to: ${filePath}`);
  const sizeKb = (fs.statSync(filePath).size / 1024).toFixed(1);
  console.log(`Size: ${sizeKb} KB`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Backup failed:', error);
    process.exit(1);
  });
