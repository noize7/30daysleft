# 30 DAYS LEFT — Godot 4.6

## Tanda 7 — Escape por banco, iconos de mejoras, UI de finales, glitches

### Esta tanda
- **Nueva partida**: sin flash de "Apagando PC"
- **Iconos en Mejoras**: cada categoría usa PNG en `assets/Icons Pc/` (cámbialos por los tuyos)
- **Meta de escape**: $150.000 (antes $1.000.000)
- **Escape por transferencia**: entre el día 1 y 10 llega un correo con un nº de cuenta; en Banco pegas la cuenta, la cantidad y transfieres. Al completar la meta (+ pistas) → Escape
- **UI de finales**: texto y botón abajo a la izquierda; imágenes opcionales en `assets/endings/{escape,locura,atrapado}.png`
- **Etiqueta de final**: "ESCAPE 1 de 3", "FINAL 2 de 3 — LOCURA", "FINAL 3 de 3 — ATRAPADO"
- **Glitches de cordura** (SanityFX): viñeta y barras cuando la cordura baja

### Tandas completadas
| Tanda | Contenido |
|-------|-----------|
| 1–4 | Core, trabajo, mejoras, guardado, correo, pistas, cordura |
| 5 | Menús, créditos, balance, más jobs/upgrades |
| 6 | UI por escenas, boot, icono opciones, Archivos limpio |
| **7** | Banco/transferencia, escape, iconos mejoras, finales, glitches |

### Tandas que faltan (estimación)
| Tanda | Contenido previsto |
|-------|--------------------|
| 8 | Más correos/pistas, arte de iconos/fondos, más variantes de escape |
| 9 | Audio (música / SFX), ilustraciones de finales |
| 10 | Balance final, bugs, build de release |

### Autoloads
GameManager, TimeManager, WorkSystem, UpgradeSystem,
EmailSystem, ClueSystem, SaveManager, SanityFX

### Cómo poner iconos de mejoras
Sustituye estos archivos (mismo nombre) en `assets/Icons Pc/`:
- `Bateria.png`, `CPU.png`, `Ram.png`, `Navegador.png`
- `bot.png`, `ventilador.png`, `Almacenamiento.png`

### Cómo poner imágenes de finales
Coloca en `assets/endings/`:
- `escape.png`, `locura.png`, `atrapado.png`

### Cómo poner iconos del escritorio
1. Abre `scenes/main/main.tscn`
2. Nodo **Main** → Inspector → **Iconos del escritorio**
3. Asigna texturas a cada `icon_*`
