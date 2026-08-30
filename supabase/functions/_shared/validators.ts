export const GDPR_CNP_PLACEHOLDER = "0000000000000";

export function isGDPRCNPPlaceholder(cnp: string): boolean {
  return cnp === GDPR_CNP_PLACEHOLDER;
}

export function isValidCNP(cnp: string): boolean {
  if (!/^\d{13}$/.test(cnp)) return false;
  if (isGDPRCNPPlaceholder(cnp)) return true;

  const controlKey = "279146358279";
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    sum += Number(cnp[i]) * Number(controlKey[i]);
  }
  const remainder = sum % 11;
  const control = remainder === 10 ? 1 : remainder;
  return control === Number(cnp[12]);
}
