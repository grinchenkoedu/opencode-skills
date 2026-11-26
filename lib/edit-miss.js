// Where an edit's oldString stops matching the file — the hint the guard adds to
// an edit result that reports the text wasn't found.
//
// Told which line stops matching and what the file has there, the model can send
// only the few lines it means to change instead of retrying large blocks from memory.

import { readFileSync } from "node:fs"
import { relative, resolve } from "node:path"

const MAX_WIDTH = 100
const MISS = /Could not find|not found in/i

const show = (line) => "`" + line.replace(/`/g, "'").slice(0, MAX_WIDTH) + "`"
const same = (a, b) => a.trimEnd() === b.trimEnd()

// Where one oldString stops matching the file's lines, as a sentence.
function place(oldString, lines, name) {
  const old = oldString.split("\n")
  // The longest run of oldString's first lines that are consecutive lines of the file.
  // A first line with no indentation may start mid-line, so it only has to end the
  // file's line; one with indentation has to be the whole line, indentation included.
  const opens = /^\s/.test(old[0]) || !old[0].trim() ? (l) => same(l, old[0]) : (l) => l.trimEnd().endsWith(old[0].trimEnd())
  let best = { at: -1, count: 0 }
  for (let s = 0; s < lines.length; s++) {
    if (!opens(lines[s])) continue
    let k = 1
    while (k < old.length && s + k < lines.length && same(lines[s + k], old[k])) k++
    if (k > best.count) best = { at: s, count: k }
  }
  if (best.count === 0) {
    const loose = lines.findIndex((l) => l.trim() && l.trim() === old[0].trim())
    if (loose >= 0) return `oldString line 1 ${show(old[0])} matches line ${loose + 1} ${show(lines[loose])} only with different indentation.`
    return `oldString line 1 ${show(old[0])} is not in ${name}.`
  }
  if (best.count === old.length) return null // every line matches: the miss is something this can't place
  const next = best.at + best.count
  const there = next < lines.length ? `line ${next + 1} is ${show(lines[next])}` : `the file ends at line ${lines.length}`
  const matched = best.count === 1 ? `oldString line 1 matches line ${next} of ${name}` : `oldString lines 1-${best.count} match lines ${best.at + 1}-${next} of ${name}`
  return `${matched}; its line ${best.count + 1} ${show(old[best.count])} is not what follows: ${there}.`
}

// The hint for an edit result, or null: only a miss, only a file it can read,
// only an oldString the file doesn't have.
export function editMissHint(args, resultText, cwd) {
  if (!args || typeof args !== "object" || typeof args.filePath !== "string" || typeof args.oldString !== "string") return null
  if (typeof resultText !== "string" || !MISS.test(resultText)) return null
  const full = resolve(cwd, args.filePath)
  let text
  try {
    text = readFileSync(full, "utf8")
  } catch {
    return null
  }
  if (!args.oldString || text.includes(args.oldString)) return null
  const lines = text.replace(/\r\n/g, "\n").replace(/\n$/, "").split("\n")
  const name = relative(cwd, full) || args.filePath
  const where = place(args.oldString.replace(/\r\n/g, "\n"), lines, name)
  if (!where) return null
  return `${where}\nPut only the lines you change in oldString, copied from the file.`
}
