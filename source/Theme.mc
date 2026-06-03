import Toybox.Graphics;

// === MOTYW KOLOROW (cyan/niebieski na czarnym tle) ===
// Epix Pro Gen 2 = AMOLED 16M kolorow, wiec uzywamy dokladnych wartosci hex.
// Zmieniajac te 3 stale przefarbujesz cala aplikacje.

const ACCENT = 0x14B4E8;      // glowny akcent cyan (zastepuje dawne DK_RED)
const ACCENT_HI = 0x6AD4FF;   // jasny cyan - highlight (dzisiejszy slupek, akcenty)
const ACCENT_DK = 0x0A5E7C;   // ciemny cyan - elementy tla / wygaszone

// Status celu zostaje semantyczny:
//   biel  = w toku
//   ACCENT/ACCENT_HI = akcent UI
//   COLOR_GREEN/DK_GREEN = cel osiagniety
