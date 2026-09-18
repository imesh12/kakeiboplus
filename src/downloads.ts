/** Only verified backend totals may be returned by an implementation of this contract. */
export interface DownloadStatsProvider {
  getStats(): Promise<{ total: number; verifiedAt: string; source: string } | null>;
}
export const downloadStatsProvider: DownloadStatsProvider = { async getStats() { return null; } };
export async function mountDownloadCounter(provider: DownloadStatsProvider = downloadStatsProvider) {
  const root = document.querySelector<HTMLElement>('[data-download-counter]');
  if (!root) return;
  root.dataset.state = 'loading';
  const oldTotal = Number(root.dataset.total);
  try {
    const stats = await provider.getStats();
    if (!stats || !Number.isSafeInteger(stats.total) || stats.total < 0 || !stats.source || !Number.isFinite(Date.parse(stats.verifiedAt))) throw new Error('No verified statistics');
    root.dataset.state = 'available';
    root.dataset.total = String(stats.total);
    root.textContent = `${new Intl.NumberFormat('en-US').format(stats.total)} downloads`;
    root.title = `Source: ${stats.source}. Verified ${stats.verifiedAt}`;
    if (Number.isFinite(oldTotal) && stats.total > oldTotal && !matchMedia('(prefers-reduced-motion: reduce)').matches) root.animate([{ opacity: .5 }, { opacity: 1 }], { duration: 250 });
  } catch {
    root.dataset.state = 'unavailable';
    root.textContent = 'App launch coming soon';
    delete root.dataset.total;
    root.removeAttribute('title');
  }
}
