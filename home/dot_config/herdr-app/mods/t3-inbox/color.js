// A theme color at a share of its own opacity, for every fill, wash and ring the layout derives from one.

/**
 * `color` (`#rgb`, `#rrggbb` or `#rrggbbaa`, as Herdr's themes write them) at `share`, two hex digits as the layout writes its
 * shares ("12" is 7%). An 8-digit color's own alpha is scaled, not followed by two more digits: the host reads 3, 6 or 8
 * (gpui-kit's as_color), so `#abcdef80` + "12" would be refused. Anything else comes back as it was.
 * @param {string} color @param {string} share
 */
export function alpha(color, share) {
  const m = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(color ?? "");
  if (!m) return color;
  const hex = m[1].length === 3 ? [...m[1]].map((c) => c + c).join("") : m[1];
  const own = hex.length === 8 ? parseInt(hex.slice(6), 16) : 255;
  return `#${hex.slice(0, 6)}${Math.round(own * parseInt(share, 16) / 255).toString(16).padStart(2, "0")}`;
}
