// Keeps src/Core/Schema.luau honest: every option an element reads must be
// listed there (or Debug would call a real option unknown). With --docs it
// also checks that LLM.txt mentions every option the schema lists.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// Option names are the keys written as `Name = "type"` inside Schema.luau.
export function schemaKeys() {
	const source = readFileSync(join(ROOT, "src", "Core", "Schema.luau"), "utf8");
	return new Set([...source.matchAll(/\b([A-Z][A-Za-z]*) = (?:"|values\b)/g)].map((match) => match[1]));
}

export function checkSchema({ docs = false } = {}) {
	const known = schemaKeys();
	const problems = [];
	const elements = join(ROOT, "src", "Elements");
	for (const name of readdirSync(elements).filter((file) => file.endsWith(".luau"))) {
		const source = readFileSync(join(elements, name), "utf8");
		for (const match of source.matchAll(/\boptions\.([A-Z][A-Za-z]*)/g)) {
			if (!known.has(match[1])) {
				problems.push(`${name} reads options.${match[1]}, which Schema.luau doesn't list`);
			}
		}
	}
	if (docs) {
		const guide = readFileSync(join(ROOT, "LLM.txt"), "utf8");
		for (const key of known) {
			if (!new RegExp(`\\b${key}\\b`).test(guide)) {
				problems.push(`LLM.txt never mentions the option ${key}`);
			}
		}
	}
	return [...new Set(problems)];
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
	const problems = checkSchema({ docs: process.argv.includes("--docs") });
	console.log(problems.length === 0 ? "schema matches the sources" : problems.join("\n"));
	process.exit(problems.length === 0 ? 0 : 1);
}
