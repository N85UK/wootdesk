import { readdir, readFile } from "node:fs/promises"
import { extname, join } from "node:path"
import { spawnSync } from "node:child_process"

const root = new URL("..", import.meta.url).pathname
const sourceFiles = await collect(join(root, "src"))
const testFiles = await collect(join(root, "tests"))
const scriptFiles = await collect(join(root, "scripts"))
const javascriptFiles = [...sourceFiles, ...testFiles, ...scriptFiles].filter(
  (path) => [".js", ".mjs"].includes(extname(path)),
)

for (const path of javascriptFiles) {
  const result = spawnSync(process.execPath, ["--check", path], {
    encoding: "utf8",
  })
  if (result.status !== 0) {
    process.stderr.write(result.stderr)
    process.exit(result.status ?? 1)
  }
}

const packageJSON = JSON.parse(await readFile(join(root, "package.json"), "utf8"))
if (
  Object.keys(packageJSON.dependencies ?? {}).length > 0 ||
  Object.keys(packageJSON.devDependencies ?? {}).length > 0
) {
  throw new Error("The gateway must remain dependency-free.")
}

const textFiles = [
  ...javascriptFiles,
  join(root, "README.md"),
  join(root, ".env.example"),
  join(root, "Dockerfile"),
]
for (const path of textFiles) {
  const contents = await readFile(path, "utf8")
  if (contents.includes("\u2013") || contents.includes("\u2014")) {
    throw new Error(`${path} contains a forbidden dash character.`)
  }
}

process.stdout.write(
  `Checked ${javascriptFiles.length} JavaScript files and dependency policy.\n`,
)

async function collect(directory) {
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) {
      files.push(...(await collect(path)))
    } else {
      files.push(path)
    }
  }
  return files
}
