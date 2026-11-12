// Runs the behaviour tests headless under the standalone `luau` binary.
//
// The Roblox engine is not available there, so tests/stubs.luau models the
// parts the library touches: instances, signals, tweens, the task scheduler
// and executor file functions. The stubs, the bundle and one test file are
// joined into a single chunk so the bundle sees the stubs as upvalues. A test
// file may carry "-- setup: <code>" lines, which run before the bundle loads.
//
// This proves values, callbacks, ownership and saved data. It cannot prove
// pixels; those are checked in Roblox Studio.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { bundle } from "./bundle.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const TESTS = join(ROOT, "tests");
const BUILD = join(ROOT, ".build");
const LUAU = process.env.LUAU_BIN || "luau";

const read = (path) => readFileSync(path, "utf8").replace(/\r\n/g, "\n");
const indent = (text) => text.split("\n").map((line) => (line === "" ? "" : `\t${line}`)).join("\n");

const stubs = read(join(TESTS, "stubs.luau"));
const library = bundle();
const only = process.argv[2];
const suites = readdirSync(TESTS)
	.filter((name) => name.endsWith(".test.luau"))
	.filter((name) => !only || name.includes(only))
	.sort();

mkdirSync(BUILD, { recursive: true });
let failed = false;

for (const suite of suites) {
	const test = read(join(TESTS, suite));
	const setup = [...test.matchAll(/^-- setup: (.*)$/gm)].map((match) => match[1]).join("\n");
	const harness = [
		stubs,
		setup,
		`local Halcyon = (function()\n${indent(library)}\nend)()`,
		test,
		"Stub.report()",
		"",
	].join("\n\n");
	const path = join(BUILD, suite.replace(".test.luau", ".harness.luau"));
	writeFileSync(path, harness);
	try {
		const output = execFileSync(LUAU, [path], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
		process.stdout.write(`${suite}: ${output.trim()}\n`);
		if (!/^PASS/m.test(output)) {
			failed = true;
		}
	} catch (error) {
		failed = true;
		process.stdout.write(`${suite}: FAILED\n${error.stdout || ""}${error.stderr || ""}\n`);
	}
}

if (suites.length === 0) {
	console.error("no test suites matched");
	failed = true;
}
process.exit(failed ? 1 : 0);
