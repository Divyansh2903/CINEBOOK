export const seatPrice = (basePrice: number, multiplier: number): number =>
  Math.round(basePrice * multiplier);

export const applyPromo = (amount: number, percentOff: number): number =>
  Math.max(0, Math.round(amount * (1 - percentOff / 100)));
