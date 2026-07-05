// Merges the repo's plugins/known_marketplaces.json into the local
// ~/.claude/plugins/known_marketplaces.json, filling in a machine-local
// installLocation. Prints "<name> <owner/repo>" lines (for github sources)
// to stdout so the caller can clone/pull each marketplace.
const fs = require("fs");

const [, , repoMktPath, localMktPath, claudeDir] = process.argv;

const repoMkt = JSON.parse(fs.readFileSync(repoMktPath, "utf8"));
const local = JSON.parse(fs.readFileSync(localMktPath, "utf8"));

for (const [name, entry] of Object.entries(repoMkt)) {
  const installLocation = `${claudeDir}/plugins/marketplaces/${name}`;
  local[name] = {
    source: entry.source,
    installLocation,
    lastUpdated: new Date().toISOString(),
  };
  if (entry.source && entry.source.source === "github") {
    console.log(`${name} ${entry.source.repo}`);
  }
}

fs.writeFileSync(localMktPath, JSON.stringify(local, null, 2));
