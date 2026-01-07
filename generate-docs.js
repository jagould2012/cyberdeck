#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const DOCS_DIR = 'docs';
const MEDIA_DIR = path.join(DOCS_DIR, '_media');
const MENU_FILE = path.join(DOCS_DIR, 'menu.json');
const SIDEBAR_FILE = path.join(DOCS_DIR, '_sidebar.md');
const GALLERY_FILE = path.join(DOCS_DIR, 'gallery.json');

// Load menu configuration
function loadMenu() {
	if (!fs.existsSync(MENU_FILE)) {
		console.error(`Error: ${MENU_FILE} not found`);
		process.exit(1);
	}
	return JSON.parse(fs.readFileSync(MENU_FILE, 'utf-8'));
}

// Get all prefixes from menu (including children)
function getAllPrefixes(menu) {
	const prefixes = [];
	for (const item of Object.values(menu)) {
		if (item.prefix) {
			prefixes.push(item.prefix);
		}
		if (item.children) {
			for (const child of item.children) {
				if (child.prefix) {
					prefixes.push(child.prefix);
				}
			}
		}
	}
	return prefixes;
}

// Scan _media directory for images matching each prefix
function scanImages(menu) {
	const images = {};

	if (!fs.existsSync(MEDIA_DIR)) {
		console.warn(`Warning: ${MEDIA_DIR} directory not found`);
		return images;
	}

	const files = fs.readdirSync(MEDIA_DIR);

	// Build prefix to title mapping
	const prefixMap = {};
	for (const item of Object.values(menu)) {
		if (item.prefix) {
			prefixMap[item.prefix] = item.title;
		}
		if (item.children) {
			for (const child of item.children) {
				if (child.prefix) {
					prefixMap[child.prefix] = child.title;
				}
			}
		}
	}

	for (const [prefix, title] of Object.entries(prefixMap)) {
		// Find all files matching prefix*.jpeg (case-insensitive)
		const matches = files
			.filter(file => {
				const lower = file.toLowerCase();
				return lower.startsWith(prefix.toLowerCase()) &&
					(lower.endsWith('.jpeg') || lower.endsWith('.jpg'));
			})
			.sort((a, b) => {
				// Sort numerically by extracting number from filename
				const numA = parseInt(a.match(/(\d+)/)?.[1] || '0');
				const numB = parseInt(b.match(/(\d+)/)?.[1] || '0');
				return numA - numB;
			});

		// Store paths relative to docs folder (for use in markdown)
		images[prefix] = {
			title: title,
			files: matches.map(file => `_media/${file}`)
		};
	}

	return images;
}

// Generate _sidebar.md from menu
function generateSidebar(menu) {
	const lines = ['<!-- GENERATED FILE - DO NOT EDIT -->'];

	for (const [key, item] of Object.entries(menu)) {
		if (item.children) {
			// Parent with children (like Instructions)
			lines.push(`* ${item.title}`);
			for (const child of item.children) {
				const slug = child.prefix || child.title.toLowerCase().replace(/\s+/g, '-');
				lines.push(`  * [${child.title}](/${key}/${slug}.md)`);
			}
		} else if (item.prefix === null) {
			// Home link
			lines.push(`* [${item.title}](/)`);
		} else {
			// Regular page
			lines.push(`* [${item.title}](/${item.prefix}.md)`);
		}
	}

	lines.push(''); // trailing newline
	return lines.join('\n');
}

// Generate gallery.json
function generateGallery(images) {
	return JSON.stringify({ images }, null, 2);
}

// Main
function main() {
	console.log(`Loading ${MENU_FILE}...`);
	const menu = loadMenu();

	const prefixes = getAllPrefixes(menu);
	console.log(`Found prefixes: ${prefixes.join(', ')}\n`);

	console.log(`Scanning images in ${MEDIA_DIR}...`);
	const images = scanImages(menu);

	// Log what was found
	for (const [prefix, data] of Object.entries(images)) {
		console.log(`  ${prefix} (${data.title}): ${data.files.length} images`);
	}

	console.log(`\nGenerating ${SIDEBAR_FILE}...`);
	const sidebar = generateSidebar(menu);
	fs.writeFileSync(SIDEBAR_FILE, sidebar);
	console.log(`  ✓ Created ${SIDEBAR_FILE}`);

	console.log(`\nGenerating ${GALLERY_FILE}...`);
	const gallery = generateGallery(images);
	fs.writeFileSync(GALLERY_FILE, gallery);
	console.log(`  ✓ Created ${GALLERY_FILE}`);

	console.log('\nDone!');
}

main();