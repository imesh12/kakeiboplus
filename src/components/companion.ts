/** Original concept art. Replace this renderer when production artwork is ready. */
export type PetKind = "dog" | "cat" | "rabbit" | "bird";
export function companion(
  kind: PetKind = "dog",
  state = "idle",
  decorative = false,
): string {
  const face =
    state === "sleeping"
      ? '<path d="m73 92 10 2m27 0 10-2"/>'
      : state === "happy" || state === "celebrate"
        ? '<path d="M74 93q5-7 10 0m26 0q5-7 10 0"/>'
        : '<ellipse cx="80" cy="92" rx="3" ry="4" fill="#123333"/><ellipse cx="114" cy="92" rx="3" ry="4" fill="#123333"/>';
  const bodies: Record<PetKind, string> = {
    dog: '<path d="M127 127q32-21 31 2" fill="none" stroke="#CCA87D" stroke-width="13" stroke-linecap="round"/><path d="M66 115q-15 50 14 51h39q24-5 9-48" fill="#DDC4A2"/><path d="M65 63Q36 54 42 95q2 18 21 7m65-39q29-9 23 32-2 18-21 7" fill="#9C8066"/><rect x="57" y="52" width="79" height="77" rx="33" fill="#E8D3B3"/><ellipse cx="96" cy="106" rx="22" ry="14" fill="#F4E8D5"/><path d="M61 122q35 14 73-1l-5 16-61-1Z" fill="#006B68"/><path d="m112 133 17 20 3-24" fill="#008776"/><path d="M91 128q-9-12-14-6 2 8 14 6m0 0q-1-12 9-13 2 8-9 13" fill="#9BEA45"/><path d="M67 155v12h22m20-12v12h21" stroke="#C1A481" stroke-width="8" stroke-linecap="round"/>',
    cat: '<path d="M128 144q37 7 31-26" fill="none" stroke="#9DAFAC" stroke-width="12" stroke-linecap="round"/><path d="M66 117q-9 43 14 50h39q24-9 8-51" fill="#B8C7C0"/><path d="m59 78-2-39 30 21m22 0 27-21-1 43" fill="#B8C7C0"/><path d="m63 60 1-12 15 16m40 0 11-16 1 16" fill="#E0B4AA"/><rect x="56" y="57" width="81" height="71" rx="28" fill="#CDD8D1"/><path d="m51 99 24 3m-24 7 24-2m45-5 25-3m-25 8 25 2" stroke="#7D9990" stroke-width="2"/><path d="M67 128h58" stroke="#006B68" stroke-width="7"/><circle cx="98" cy="136" r="10" fill="#FFC83D"/><text x="91" y="139" font-family="Arial,sans-serif" font-size="9" fill="#123333" stroke="none">K+</text><path d="M70 157v10h20m18-10v10h17" stroke="#98AFA3" stroke-width="8" stroke-linecap="round"/>',
    rabbit:
      '<circle cx="133" cy="141" r="14" fill="#E7E7DC"/><path d="M65 112q-18 51 18 56h38q19-11 3-52" fill="#E6E4D8"/><ellipse cx="76" cy="47" rx="12" ry="34" fill="#E6E4D8" transform="rotate(-8 76 47)"/><ellipse cx="119" cy="44" rx="12" ry="35" fill="#E6E4D8" transform="rotate(9 119 44)"/><path d="m75 26 3 37m42-39-3 38" stroke="#D8BBB2" stroke-width="8" stroke-linecap="round"/><rect x="56" y="63" width="80" height="67" rx="31" fill="#F0EEE3"/><path d="M65 128h64" stroke="#006B68" stroke-width="8"/><circle cx="99" cy="133" r="8" fill="#FFC83D"/><path d="M75 155v13h15m20-13v13h17" stroke="#CCCBBC" stroke-width="8" stroke-linecap="round"/>',
    bird: '<path d="m127 120 30-17-8 33-29 9" fill="#3C8274"/><ellipse cx="98" cy="110" rx="44" ry="51" fill="#9FCABC"/><path d="M64 120q13 43 39 35c27-8 15-38-10-35Z" fill="#CEE4D8"/><path d="M111 111q26 1 10 25" fill="none" stroke="#609F8D" stroke-width="7" stroke-linecap="round"/><path d="m86 108 12 9 11-9-11-4Z" fill="#DBAC47"/><path d="M83 157v13m26-13v13" stroke="#AD8F47" stroke-width="5" stroke-linecap="round"/><path d="M90 58q-6-17-15-13m16 13q5-15 15-10" fill="none" stroke="#006B68" stroke-width="7" stroke-linecap="round"/><path d="M70 74q-9-6-5-13 8 0 9 9" fill="#FFC83D"/>',
  };
  return `<svg class="pet pet-${state} animal animal-${kind}" viewBox="0 0 200 190" ${decorative ? 'aria-hidden="true"' : `role="img" aria-label="${kind} companion, ${state}"`}><ellipse cx="100" cy="177" rx="55" ry="6" fill="#123333" opacity=".08"/><g class="animal-body">${bodies[kind]}<g class="animal-face" fill="none" stroke="#123333" stroke-width="2.5" stroke-linecap="round">${face}${kind === "bird" ? "" : '<path d="m92 104 5 4 5-4" fill="#123333"/><path d="M97 108v4m-6 0q6 6 12 0"/>'}</g></g>${state === "celebrate" ? '<g fill="#DAAD32"><path d="m37 69 3 8 8 3-8 3-3 8-3-8-8-3 8-3Zm121-30 3 8 8 3-8 3-3 8-3-8-8-3 8-3Z"/></g>' : ""}${state === "warning" ? '<circle cx="154" cy="63" r="13" fill="#FFE9AD"/><path d="M154 55v8m0 5v1" stroke="#725617" stroke-width="3" stroke-linecap="round"/>' : ""}${state === "sleeping" ? '<text x="145" y="65" font-family="Arial,sans-serif" font-size="14" fill="#526B63">z z</text>' : ""}</svg>`;
}
export function companionScene(
  id: string,
  kind: PetKind,
  story: string,
): string {
  return `<div class="pet-scene" data-scene="${id}" data-kind="${kind}" data-story="${story}" data-action="rest" aria-hidden="true"><span class="story-money"><span>K+</span><i>✦</i></span><div class="story-animal">${companion(kind, "idle", true)}</div><span class="story-spark">✧</span></div>`;
}
