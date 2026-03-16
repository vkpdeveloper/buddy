import { backfillBodyMeasurementsForUniqueDate } from '../src/services/bodyMeasurements';

async function main() {
  console.log('[backfill-body-measurements] Starting...');
  await backfillBodyMeasurementsForUniqueDate();
  console.log('[backfill-body-measurements] Done.');
}

main().catch((error) => {
  console.error('[backfill-body-measurements] Failed:', error);
  process.exit(1);
});
