/** Deliberately illustrative data, NOT market quotes or a live feed. */
export const illustrativeRates = {
  JPY: 150,
  USD: 1,
  INR: 83,
  NPR: 133,
  VND: 25000,
  KRW: 1350,
  EUR: 0.92,
  SAR: 3.75,
  LKR: 300,
};

export function convertAmount(amount, from, to) {
  if (!Number.isFinite(amount) || amount < 0)
    throw new RangeError("Enter a non-negative amount.");
  if (!(from in illustrativeRates) || !(to in illustrativeRates))
    throw new RangeError("Unsupported currency.");
  return (amount / illustrativeRates[from]) * illustrativeRates[to];
}

/** Replace this adapter with your backend; preserve the source disclosure. */
export const demoFxProvider = {
  async quote(amount, from, to) {
    return {
      amount: convertAmount(amount, from, to),
      source: "Illustrative rate · not live",
      kind: "illustrative",
    };
  },
};
/** A live provider must supply provenance and an actual update timestamp. */
export function rateDisclosure(quote) {
  if (quote.kind !== "live") return "Illustrative rate · not live";
  if (
    !quote.provider ||
    !quote.updatedAt ||
    !Number.isFinite(Date.parse(quote.updatedAt))
  )
    return "Exchange rate unavailable";
  const time = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "UTC",
  }).format(new Date(quote.updatedAt));
  return `Live rate · Updated ${time} UTC · ${quote.provider}`;
}
