// Minimal app.asar extractor (no dependencies). Usage: node asar-extract.js <app.asar> <outDir>
// Files marked "unpacked" live next to the archive in app.asar.unpacked and are skipped.
'use strict';
const fs = require('fs');
const path = require('path');

const [, , file, outDir] = process.argv;
if (!file || !outDir) {
  console.error('usage: node asar-extract.js <app.asar> <outDir>');
  process.exit(2);
}
const fd = fs.openSync(file, 'r');
const head = Buffer.alloc(16);
fs.readSync(fd, head, 0, 16, 0);
const headerSize = head.readUInt32LE(4);
const jsonSize = head.readUInt32LE(12);
const jsonBuf = Buffer.alloc(jsonSize);
fs.readSync(fd, jsonBuf, 0, jsonSize, 16);
const header = JSON.parse(jsonBuf.toString('utf8'));
const base = 8 + headerSize;
let count = 0;

function walk(node, dir) {
  for (const [name, entry] of Object.entries(node.files)) {
    const target = path.join(dir, name);
    if (!path.resolve(target).startsWith(path.resolve(outDir))) continue; // no path escape
    if (entry.files) {
      fs.mkdirSync(target, { recursive: true });
      walk(entry, target);
    } else if (!entry.unpacked && !entry.link) {
      const buf = Buffer.alloc(entry.size);
      if (entry.size) fs.readSync(fd, buf, 0, entry.size, base + Number(entry.offset));
      fs.writeFileSync(target, buf);
      count++;
    }
  }
}
fs.mkdirSync(outDir, { recursive: true });
walk(header, outDir);
console.log(`extracted ${count} files to ${outDir}`);
