interface ExactDecimal {
  atoms: bigint;
  scale: number;
}
function decimal(value: string): ExactDecimal {
  const [whole = '0', fraction = ''] = value.split('.');
  return { atoms: BigInt(whole + fraction), scale: fraction.length };
}
function exactText(value: ExactDecimal): string {
  if (!value.atoms) return '0';
  if (!value.scale) return String(value.atoms);
  const digits = value.atoms.toString().padStart(value.scale + 1, '0');
  return `${digits.slice(0, -value.scale)}.${digits.slice(-value.scale)}`.replace(/\.?0+$/, '');
}
function roundedText(value: ExactDecimal, places: number): string {
  let atoms: bigint;
  if (value.scale > places) {
    const divisor = 10n ** BigInt(value.scale - places);
    atoms = value.atoms / divisor;
    if ((value.atoms % divisor) * 2n >= divisor) atoms++;
  } else atoms = value.atoms * 10n ** BigInt(places - value.scale);
  if (!places) return String(atoms);
  const digits = atoms.toString().padStart(places + 1, '0');
  return `${digits.slice(0, -places)}.${digits.slice(-places)}`;
}

/** Internal primitive for schema-validated inputs: dimensional scaling, not an agronomic model. */
export function scaleAreaRate<Unit extends 'KG' | 'G' | 'TONNE'>(input: {
  area: string;
  areaUnit: 'HECTARE' | 'ACRE';
  rateKgPerHectare: string;
  outputUnit: Unit;
  decimalPlaces: number;
}) {
  const area = decimal(input.area);
  // Exact international acre; survey acres and local land units are unsupported.
  const hectares =
    input.areaUnit === 'ACRE' ? { atoms: area.atoms * 40468564224n, scale: area.scale + 11 } : area;
  const rate = decimal(input.rateKgPerHectare);
  const quantity = { atoms: hectares.atoms * rate.atoms, scale: hectares.scale + rate.scale };
  if (input.outputUnit === 'G') quantity.atoms *= 1000n;
  if (input.outputUnit === 'TONNE') quantity.scale += 3;
  const value = roundedText(quantity, input.decimalPlaces);
  return {
    normalizedArea: { value: exactText(hectares), unit: 'HECTARE' as const },
    quantity: { value, unit: input.outputUnit, unroundedValue: exactText(quantity) },
    positiveRoundedZero: value.replace(/[0.]/g, '') === '' && quantity.atoms > 0n,
  };
}
