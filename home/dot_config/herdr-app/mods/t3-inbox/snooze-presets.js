// The Snooze menu's times, for an Inbox card's and the tab bar breadcrumb's (t3-menu).

// T3's default snooze menu, in local time: soonest first, one row per wake minute, tonight's gone once it's past.
export function presets(now) {
  const d = new Date(now), at = (days, h) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + days, h).getTime();
  const time = (ms) => { const w = new Date(ms); return `${w.getHours() % 12 || 12}:${String(w.getMinutes()).padStart(2, "0")} ${w.getHours() < 12 ? "am" : "pm"}`; };
  const day = (ms) => `${["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date(ms).getDay()]} ${time(ms)}`;
  const inFrom = (hours) => { const ms = now + hours * 3600000; return { label: `In ${hours} hour${hours === 1 ? "" : "s"}`, at: ms, hours, when: new Date(ms).getDate() === d.getDate() ? time(ms) : day(ms) }; };
  const monday = at((1 - d.getDay() + 7) % 7 || 7, 9);
  return [inFrom(1), inFrom(3), { label: "This evening", at: at(0, 18), when: time(at(0, 18)) }, { label: "Tomorrow", at: at(1, 9), when: time(at(1, 9)) }, { label: "Next week", at: monday, when: day(monday) }]
    .filter((p) => p.at > now).sort((x, y) => x.at - y.at)
    .filter((p, i, xs) => xs.findIndex((q) => Math.floor(q.at / 60000) === Math.floor(p.at / 60000)) === i);
}
