/** Deliberately illustrative data, NOT market quotes or a live feed. */
export const illustrativeRates = { JPY: 150, USD: 1, INR: 83, NPR: 133, VND: 25000, KRW: 1350, EUR: 0.92, SAR: 3.75, LKR: 300 };

export function convertAmount(amount, from, to) {
  if (!Number.isFinite(amount) || amount < 0) throw new RangeError('Enter a non-negative amount.');
  if (!(from in illustrativeRates) || !(to in illustrativeRates)) throw new RangeError('Unsupported currency.');
  return amount / illustrativeRates[from] * illustrativeRates[to];
}

/** Replace this adapter with your backend; preserve the source disclosure. */
export const demoFxProvider = {
  async quote(amount, from, to) {
    return { amount: convertAmount(amount, from, to), source: 'Illustrative rate · not live', kind: 'illustrative' };
  },
};
