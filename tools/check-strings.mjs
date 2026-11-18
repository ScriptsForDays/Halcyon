// Keeps the translation packs in step with the source. Every text passed to
// Strings.get must be in every pack, and every pack key must still be a text
// the source uses (a pack key nobody asks for is a stale translation).
// Returns a list of problems; empty means the packs are complete.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(ROOT, "src");
const LOCALES = join(SRC, "Locales");

function walk(dir) {
	return readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
		entry.isDirectory() ? walk(join(dir, entry.name)) : entry.name.endsWith(".luau") ? [join(dir, entry.name)] : [],
	);
}

const unescape = (text) => text.replace(/\\(["'\\])/g, "$1");
// Double-quoted strings only: an apostrophe in a comment or a word like
// "can't" would pair single quotes across lines.
const LITERAL = /"((?:[^"\\]|\\.)*)"/g;

function packKeys(source) {
	const keys = new Set();
	for (const match of source.matchAll(/^\t\[(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')\] = /gm)) {
		keys.add(unescape(match[1] ?? match[2]));
	}
	return keys;
}

export function checkStrings() {
	const files = walk(SRC).filter((file) => !file.startsWith(LOCALES));
	const asked = new Set();
	const literals = new Set();
	for (const file of files) {
		const source = readFileSync(file, "utf8");
		for (const match of source.matchAll(/Strings\.get\(\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')/g)) {
			asked.add(unescape(match[1] ?? match[2]));
		}
		for (const line of source.split("\n")) {
			if (/^\s*--/.test(line)) {
				continue;
			}
			for (const match of line.matchAll(LITERAL)) {
				literals.add(unescape(match[1]));
			}
		}
	}
	for (const key of asked) {
		literals.add(key);
	}
	const problems = [];
	for (const name of readdirSync(LOCALES).filter((file) => file !== "Locales.luau")) {
		const keys = packKeys(readFileSync(join(LOCALES, name), "utf8"));
		for (const key of asked) {
			if (!keys.has(key)) {
				problems.push(`${name} has no translation for "${key}"`);
			}
		}
		for (const key of keys) {
			if (!literals.has(key)) {
				problems.push(`${name} translates "${key}", which the source no longer uses`);
			}
		}
	}
	return problems;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
	const problems = checkStrings();
	console.log(problems.length === 0 ? "translation packs are complete" : problems.join("\n"));
	process.exit(problems.length === 0 ? 0 : 1);
}
