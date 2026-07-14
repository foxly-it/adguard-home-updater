#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const projectDir = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(projectDir, "docs", "index.html"), "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];

if (scripts.length === 0) throw new Error("No inline website script found");
scripts.forEach((match, index) => new vm.Script(match[1], {filename: `inline-${index}.js`}));

const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]);
const duplicateIds = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
if (duplicateIds.length > 0) throw new Error(`Duplicate HTML IDs: ${duplicateIds.join(", ")}`);

const requiredTokens = [
    "activeWizardSteps",
    "validateWizardStep",
    "keepWizardInView",
    "nextWizardStep",
    "previousWizardStep",
    'id="wizardProgress"',
    'id="wizardReview"',
    'id="presetTools"',
    'id="advancedToggle"',
    'class="github-link"',
    'id="copyrightYear"',
    "Mark Schenk",
];
for (const token of requiredTokens) {
    if (!html.includes(token)) throw new Error(`Missing configurator token: ${token}`);
}

for (const step of [1, 2, 3, 4]) {
    if (!html.includes(`data-step="${step}"`)) throw new Error(`Missing wizard step ${step}`);
}

if (html.includes('scrollIntoView({behavior: "smooth", block: "start"})')) {
    throw new Error("Wizard navigation still uses the abrupt header anchor scroll");
}

console.log("Web configurator checks passed.");
