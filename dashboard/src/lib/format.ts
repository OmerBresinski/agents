/** Format a USD cost value for display.
 * Per backend spec: $0.18, $1.23, $0.00 for zero, < $0.01 for tiny values */
export function formatCost(cost: number | undefined): string {
  if (cost === undefined || cost === 0) return '$0.00';
  if (cost < 0.01) return '< $0.01';
  return `$${cost.toFixed(2)}`;
}

/** Format a token count with K/M suffix.
 * Per backend spec: 12.5K for 12500, 1.2M for 1200000 */
export function formatTokens(count: number): string {
  if (count === 0) return '0';
  if (count < 1000) return `${count}`;
  if (count < 1000000) {
    const k = count / 1000;
    return `${k < 10 ? k.toFixed(1) : Math.round(k)}K`;
  }
  return `${(count / 1000000).toFixed(1)}M`;
}
