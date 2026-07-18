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
    'href="https://github.com/foxly-it/adguard-home-updater"',
    'class="lang-button"',
    'data-en="Install" data-de="Installation"',
    'href="#project"',
    'class="terminal-shell"',
    'class="terminal-output" id="terminal"',
    'class="terminal-cursor"',
    "@keyframes terminal-settle",
    "root@homelab:~#",
    'class="log-time"',
    'class="curl-progress"',
    "Downloading AdGuardHome_linux_arm64.tar.gz from release v0.107.77",
    "Checking existing configuration with AdGuard Home 0.107.77",
    'id="copyrightYear"',
    "Mark Schenk",
    'id="project"',
    'id="releaseCount"',
    'id="projectLiveStatus"',
    "function loadProjectActivity",
    "releases?per_page=100",
    "commits?sha=main&per_page=1",
    "pulls?state=closed",
    "sessionStorage",
    "600000",
];
for (const token of requiredTokens) {
    if (!html.includes(token)) throw new Error(`Missing configurator token: ${token}`);
}

if (html.includes('src="assets/banner.webp"')) {
    throw new Error("Legacy hero banner is still rendered instead of the terminal preview");
}

if (html.includes("Progress: [")) {
    throw new Error("Website still uses the simulated progress format instead of curl's progress bar");
}

for (const step of [1, 2, 3, 4]) {
    if (!html.includes(`data-step="${step}"`)) throw new Error(`Missing wizard step ${step}`);
}

if (html.includes('scrollIntoView({behavior: "smooth", block: "start"})')) {
    throw new Error("Wizard navigation still uses the abrupt header anchor scroll");
}

const siteNav = html.match(/<nav class="site-nav"[\s\S]*?<\/nav>/)?.[0] || "";
if ((siteNav.match(/<a /g) || []).length !== 5 ||
    !siteNav.includes('href="#features"') || !siteNav.includes('href="#project"') ||
    !siteNav.includes('href="#assistant"') || siteNav.includes('class="github-link"')) {
    throw new Error("Top navigation does not match the Foxly MOTD structure");
}

for (const token of ["width: min(1400px, calc(100% - 40px))", "@media (max-width: 820px)",
    "@media (max-width: 560px)", ".lang-button.active"]) {
    if (!html.includes(token)) throw new Error(`Missing shared topbar rule: ${token}`);
}

if ((html.match(/class="activity-card"/g) || []).length !== 3) {
    throw new Error("Expected three project activity cards");
}

if (!html.includes("element.textContent = value") || html.includes('activity-title").innerHTML')) {
    throw new Error("External GitHub activity text is not rendered safely");
}

if (!html.includes("grid-template-columns: repeat(3, minmax(0, 1fr))") ||
    !html.includes("grid-template-columns: 1fr 1fr")) {
    throw new Error("Responsive project activity grid is missing");
}

const summaryHelpers = html.match(/function firstMeaningfulLine[\s\S]*?(?=        function setProjectText)/);
if (!summaryHelpers) throw new Error("Project activity summary helper missing");
const summary = new Function(`${summaryHelpers[0]}; return summarizeProjectActivity([{tag_name:"v3.0.0",name:"Release 3",body:"## Changes\\n* Improve website by @foxly-it in https://github.com/foxly-it/adguard-home-updater/pull/8",draft:false,prerelease:false,published_at:"2026-01-03",assets:[{name:"updater.tar.gz",download_count:17},{name:"checksums.txt",download_count:90}]}],[{sha:"abcdef123",html_url:"https://example.test/commit",commit:{message:"Ship release\\n\\nDetails",author:{name:"Foxly",date:"2026-01-02"}}}],[{number:8,title:"Merged work",merged_at:"2026-01-01",html_url:"https://example.test/pr",user:{login:"foxly"}}]);`)();
if (summary.version !== "v3.0.0" || summary.downloads !== 17 || summary.releases !== 1) {
    throw new Error("Project release statistics are incorrect");
}
if (summary.commit.title !== "Ship release" || summary.commit.sha !== "abcdef1" || summary.pull.number !== 8) {
    throw new Error("Commit or PR activity summary is incorrect");
}
if (summary.release.entries.length !== 1 || summary.release.entries[0].pr !== "8" || summary.release.entries[0].author !== "foxly-it") {
    throw new Error("Release log entries are incorrect");
}

console.log("Web configurator checks passed.");
