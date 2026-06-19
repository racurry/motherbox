#!/usr/bin/env node

/**
 * Airtable Data Extraction Script
 *
 * Extracts all data from any Airtable base including:
 * - All table records
 * - All attachments (images, files, etc.)
 *
 * Get an API Token
 *
 * 1. Go to [Airtable Developer Hub](https://airtable.com/create/tokens)
 * 2. Click **Create new token**
 * 3. Name your token and select scopes:
 *    - `schema.bases:read` (required)
 *    - `data.records:read` (required)
 *    - `data.records:write` (optional, for write access)
 * 4. Select which bases/workspaces the token can access
 * 5. Copy the token (shown only once)
 *
 * Usage:
 *   export AIRTABLE_API_TOKEN="pat..."
 *   node scripts/extract-airtable-data.js <base-id-or-name>
 *   node scripts/extract-airtable-data.js apphIp20oHxZ7JbW1
 *   node scripts/extract-airtable-data.js "Stay Home Travel"
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Configuration
const AIRTABLE_API_KEY = process.env.AIRTABLE_API_TOKEN || process.env.AIRTABLE_API_KEY;

if (!AIRTABLE_API_KEY) {
  console.error('ERROR: AIRTABLE_API_TOKEN environment variable is not set');
  console.error('Please set it with: export AIRTABLE_API_TOKEN=your_api_key_here');
  process.exit(1);
}

// Get base identifier from command line
const baseIdentifier = process.argv[2];

// Create output directories
function setupDirectories(outputDir, tableNames) {
  const dataDir = path.join(outputDir, 'data');
  const imagesDir = path.join(outputDir, 'images');

  [outputDir, dataDir, imagesDir].forEach((dir) => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });

  // Create subdirectories for each table (for potential images)
  tableNames.forEach((tableName) => {
    const tableImageDir = path.join(imagesDir, tableName.toLowerCase().replace(/\s+/g, '-'));
    if (!fs.existsSync(tableImageDir)) {
      fs.mkdirSync(tableImageDir, { recursive: true });
    }
  });

  return { dataDir, imagesDir };
}

// Fetch from Airtable API
async function airtableRequest(endpoint) {
  const url = `https://api.airtable.com/v0${endpoint}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${AIRTABLE_API_KEY}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Airtable API error (${response.status}): ${errorText}`);
  }

  return response.json();
}

// Get all accessible bases
async function listBases() {
  const data = await airtableRequest('/meta/bases');
  return data.bases;
}

// Find base by ID or name
async function findBase(identifier) {
  // If it looks like a base ID, use it directly
  if (identifier.startsWith('app')) {
    return { id: identifier, name: null };
  }

  // Otherwise, search by name
  const bases = await listBases();
  const base = bases.find((b) => b.name.toLowerCase() === identifier.toLowerCase());

  if (!base) {
    console.error(`\nERROR: Could not find base "${identifier}"`);
    console.error('\nAvailable bases:');
    bases.forEach((b) => console.error(`  - ${b.name} (${b.id})`));
    process.exit(1);
  }

  return base;
}

// Get base schema (all tables and fields)
async function getBaseSchema(baseId) {
  const data = await airtableRequest(`/meta/bases/${baseId}/tables`);
  return data.tables;
}

// Download a file from URL
function downloadFile(url, filepath) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const file = fs.createWriteStream(filepath);

    protocol
      .get(url, (response) => {
        if (response.statusCode === 200) {
          response.pipe(file);
          file.on('finish', () => {
            file.close();
            resolve(filepath);
          });
        } else {
          file.close();
          fs.unlinkSync(filepath);
          reject(new Error(`Failed to download: ${response.statusCode}`));
        }
      })
      .on('error', (err) => {
        file.close();
        if (fs.existsSync(filepath)) {
          fs.unlinkSync(filepath);
        }
        reject(err);
      });
  });
}

// Fetch all records from a table
async function fetchTableRecords(baseId, tableId, tableName) {
  const records = [];
  let offset = null;

  console.log(`\nFetching records from ${tableName}...`);

  do {
    const endpoint = `/${baseId}/${tableId}${offset ? `?offset=${offset}` : ''}`;
    const data = await airtableRequest(endpoint);

    records.push(...data.records);
    offset = data.offset;

    console.log(`  Fetched ${records.length} records...`);

    // Small delay to respect rate limits (5 req/sec)
    if (offset) {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  } while (offset);

  console.log(`✓ Completed ${tableName}: ${records.length} total records`);
  return records;
}

// Find all attachment fields in a table schema
function findAttachmentFields(tableSchema) {
  return tableSchema.fields.filter((field) => field.type === 'multipleAttachments').map((field) => field.name);
}

// Download all attachments from records
async function downloadAttachments(records, tableName, attachmentFields, imagesDir) {
  if (attachmentFields.length === 0) return { downloaded: 0, errors: [] };

  const tableImageDir = path.join(imagesDir, tableName.toLowerCase().replace(/\s+/g, '-'));
  let downloaded = 0;
  const errors = [];

  console.log(`\nDownloading attachments from ${tableName}...`);
  console.log(`  Attachment fields: ${attachmentFields.join(', ')}`);

  for (const record of records) {
    for (const fieldName of attachmentFields) {
      const attachments = record.fields[fieldName];
      if (!attachments || !Array.isArray(attachments)) continue;

      for (const attachment of attachments) {
        try {
          // Create safe filename
          const sanitizedFilename = attachment.filename.replace(/[^a-z0-9.-]/gi, '_');
          const filename = `${record.id}_${sanitizedFilename}`;
          const filepath = path.join(tableImageDir, filename);

          // Skip if already downloaded
          if (fs.existsSync(filepath)) {
            console.log(`  Skipping ${filename} (already exists)`);
            continue;
          }

          await downloadFile(attachment.url, filepath);
          console.log(`  ✓ Downloaded ${filename}`);
          downloaded++;

          // Update the record to include local file path
          attachment.localPath = path.relative(path.join(imagesDir, '..'), filepath);
        } catch (err) {
          console.error(`  ✗ Failed to download ${attachment.filename}: ${err.message}`);
          errors.push({ record: record.id, file: attachment.filename, error: err.message });
        }
      }
    }
  }

  if (downloaded === 0 && errors.length === 0) {
    console.log(`  No attachments found`);
  }

  return { downloaded, errors };
}

// Generate migration report
function generateReport(baseInfo, stats, outputDir) {
  const report = {
    timestamp: new Date().toISOString(),
    base: baseInfo,
    tables: stats,
    summary: {
      totalTables: stats.length,
      totalRecords: stats.reduce((sum, t) => sum + t.recordCount, 0),
      totalAttachments: stats.reduce((sum, t) => sum + t.attachmentsDownloaded, 0),
      totalErrors: stats.reduce((sum, t) => sum + t.errors.length, 0),
    },
  };

  const reportPath = path.join(outputDir, 'migration-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  // Also create a human-readable version
  const readablePath = path.join(outputDir, 'migration-report.txt');
  const lines = ['='.repeat(60), 'AIRTABLE EXTRACTION REPORT', '='.repeat(60), `Date: ${new Date().toISOString()}`, `Base: ${baseInfo.name}`, `Base ID: ${baseInfo.id}`, '', 'TABLES:', ...stats.map((t) => `  - ${t.tableName}: ${t.recordCount} records, ${t.attachmentsDownloaded} attachments`), '', 'SUMMARY:', `  Total Tables: ${report.summary.totalTables}`, `  Total Records: ${report.summary.totalRecords}`, `  Total Attachments: ${report.summary.totalAttachments}`, `  Total Errors: ${report.summary.totalErrors}`, '', ...(report.summary.totalErrors > 0 ? ['ERRORS:', ...stats.filter((t) => t.errors.length > 0).flatMap((t) => t.errors.map((e) => `  - [${t.tableName}] ${e.file}: ${e.error}`))] : ['All data extracted successfully!']), '='.repeat(60)];

  fs.writeFileSync(readablePath, lines.join('\n'));

  return report;
}

// List all available bases
async function listAllBases() {
  console.log('='.repeat(60));
  console.log('AVAILABLE AIRTABLE BASES');
  console.log('='.repeat(60));
  console.log();

  const bases = await listBases();

  if (bases.length === 0) {
    console.log('No bases found.');
    console.log('Make sure your API token has access to bases.');
    return;
  }

  console.log(`Found ${bases.length} base${bases.length === 1 ? '' : 's'}:\n`);

  bases.forEach((base) => {
    console.log(`  ${base.name}`);
    console.log(`    ID: ${base.id}`);
    console.log(`    Permission: ${base.permissionLevel}`);
    console.log();
  });

  console.log('='.repeat(60));
  console.log('USAGE:');
  console.log('  node scripts/extract-airtable-data.js <base-id-or-name>');
  console.log();
  console.log('EXAMPLES:');
  console.log(`  node scripts/extract-airtable-data.js "${bases[0].name}"`);
  console.log(`  node scripts/extract-airtable-data.js ${bases[0].id}`);
  console.log('='.repeat(60));
}

// Main extraction function
async function extractAllData() {
  // If no base identifier provided, list all bases
  if (!baseIdentifier) {
    await listAllBases();
    return;
  }

  console.log('='.repeat(60));
  console.log('AIRTABLE DATA EXTRACTION');
  console.log('='.repeat(60));

  // Find the base
  console.log(`Looking for base: ${baseIdentifier}...`);
  const base = await findBase(baseIdentifier);
  console.log(`✓ Found base: ${base.name || base.id} (${base.id})`);

  // Get base schema
  console.log(`\nFetching base schema...`);
  const tables = await getBaseSchema(base.id);
  console.log(`✓ Found ${tables.length} tables`);

  // Setup output directory
  const outputDir = path.join(__dirname, '..', 'airtable-export', base.id);
  const { dataDir, imagesDir } = setupDirectories(
    outputDir,
    tables.map((t) => t.name),
  );

  console.log(`\nOutput Directory: ${outputDir}`);
  console.log('='.repeat(60));

  const stats = [];

  for (const table of tables) {
    try {
      // Fetch all records
      const records = await fetchTableRecords(base.id, table.id, table.name);

      // Find attachment fields
      const attachmentFields = findAttachmentFields(table);

      // Download attachments if applicable
      const { downloaded, errors } = await downloadAttachments(records, table.name, attachmentFields, imagesDir);

      // Save records to JSON
      const safeTableName = table.name.toLowerCase().replace(/\s+/g, '-');
      const dataPath = path.join(dataDir, `${safeTableName}.json`);
      fs.writeFileSync(
        dataPath,
        JSON.stringify(
          {
            tableId: table.id,
            tableName: table.name,
            schema: table,
            records: records,
          },
          null,
          2,
        ),
      );
      console.log(`✓ Saved data to ${path.relative(process.cwd(), dataPath)}`);

      stats.push({
        tableName: table.name,
        tableId: table.id,
        recordCount: records.length,
        attachmentFields: attachmentFields,
        attachmentsDownloaded: downloaded,
        errors: errors,
      });
    } catch (err) {
      console.error(`✗ Error processing ${table.name}: ${err.message}`);
      stats.push({
        tableName: table.name,
        tableId: table.id,
        recordCount: 0,
        attachmentFields: [],
        attachmentsDownloaded: 0,
        errors: [{ error: err.message }],
      });
    }
  }

  // Generate report
  console.log('\n' + '='.repeat(60));
  console.log('GENERATING REPORT');
  console.log('='.repeat(60));

  const report = generateReport({ id: base.id, name: base.name }, stats, outputDir);
  console.log(`\n✓ Report saved to ${path.relative(process.cwd(), path.join(outputDir, 'migration-report.txt'))}`);

  console.log('\n' + '='.repeat(60));
  console.log('EXTRACTION COMPLETE');
  console.log('='.repeat(60));
  console.log(`Total Tables: ${report.summary.totalTables}`);
  console.log(`Total Records: ${report.summary.totalRecords}`);
  console.log(`Total Attachments: ${report.summary.totalAttachments}`);
  console.log(`Total Errors: ${report.summary.totalErrors}`);
  console.log('='.repeat(60));
}

// Run the extraction
extractAllData().catch((err) => {
  console.error('\nFatal error:', err.message);
  console.error(err.stack);
  process.exit(1);
});
