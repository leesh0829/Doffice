const wideCharacterPattern =
  /[\u1100-\u115f\u2329\u232a\u2e80-\u303e\u3040-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe10-\ufe19\ufe30-\ufe6f\uff00-\uff60\uffe0-\uffe6]/u;

export function estimateDisplayUnits(text: string) {
  let total = 0;
  for (const character of Array.from(text || "")) {
    if (/\p{Extended_Pictographic}/u.test(character) || wideCharacterPattern.test(character)) {
      total += 2;
    } else if (/\s/u.test(character)) {
      total += 0.6;
    } else {
      total += 1;
    }
  }
  return Math.max(1, total);
}
