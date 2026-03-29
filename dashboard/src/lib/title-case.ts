/** Capitalise the first letter of each word: "agent-1" → "Agent-1" */
export function titleCase(str: string): string {
  return str.replace(/\b\w/g, (c) => c.toUpperCase());
}
