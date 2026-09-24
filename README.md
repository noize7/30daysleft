# 30 DAYS LEFT — Godot 4.6

## Tanda 8+ — Mejoras de profundidad narrativa y jugabilidad

### Implementado (incluye tandas anteriores + esta mejora)
- **Sistema de pago dual** (Online vs Efectivo)
  - Selector en la app Trabajo
  - Online suma sospecha (mitigado por Proxy anónimo)
  - Efectivo no suma sospecha **pero puede retrasarse o fallar** (pérdida parcial del pago)
  - Riesgos de efectivo aumentan con cordura baja y día avanzado
  - Persistido en save
- **Pistas con profundidad y Verdad vs Mentira**
  - Cada pista tiene `is_true` (verificada o posible alucinación)
  - Cadenas de pistas (`chain`, `related_clue`, `related_email`, `related_bank`)
  - Al leer pistas de la misma cadena → bonus de cordura + registro de investigación
  - UI de Archivos y Correo muestra claramente ✓ VERIFICADO / ⚠ ALUCINACIÓN
  - `ClueSystem.get_truth_archive()` listo para pantalla final
- **Trabajos con minijuegos**
  - Tipos: `click`, `timing`, `sequence`, `hold`, `rapid`
  - Cada trabajo indica el tipo en la descripción
  - Variación real de interacción (no solo spam de clics)
- **Tutorial saltables**
  - Botón «Saltar tutorial» visible durante la secuencia de tutorial
- **Más trabajos** (clasificación de imágenes, moderación de foros, reseñas falsas, análisis de datos, tareas especiales)
  - Algunos bajan cordura (mitigado por Filtro de ruido)
  - Algunos pueden generar pistas
- **Nuevas mejoras**
  - Optimizador de tareas (reduce duración/cooldown)
  - Filtro de ruido (−pérdida de cordura)
  - Proxy anónimo (−sospecha Online)
  - Script de limpieza de logs (chance de bajar sospecha al día)
  - Batería ampliada hasta 1000%
- **App MusicPlayer**
  - Icono en escritorio ("Música")
  - 5 pistas en loop (placeholder hasta que pongas los OGG)
  - Persiste pista y volumen
  - Bajo cordura puede saltar a pista de crisis
- **DayEventManager ampliado** (días clave + llegadas falsas de efectivo)
- Guardado/carga actualizado (payment_method + nuevas upgrades)

### Pendiente / a completar por ti o en siguientes pasos
- Asignar icono Musica.png al export icon_musica en main.tscn (Inspector del nodo Main)
- Colocar archivos OGG en assets/audio/music/ (musica_juego1.ogg … 5)
- Iconos dedicados para las 4 mejoras nuevas (actualmente usan placeholders)
- Más correos/pistas temáticos si se desea (ya hay base sólida)
- Animación corta de entrega de efectivo (estilo FNAF) — opcional visual
- Pantalla final Truth Archive (usar `ClueSystem.get_truth_archive()` + emails leídos)
- New Game+ / rejugabilidad extra (flags de finales vistos, variación de eventos)

### Tandas
| Tanda | Estado |
|-------|--------|
| 1–7 | Completadas |
| **8** | Parcialmente implementada (core hecho) |
| 9 | Audio completo + SanityFX profundo + finales |
| 10 | Balance, polish, release |

### Autoloads
GameManager, TimeManager, WorkSystem, UpgradeSystem,
EmailSystem, ClueSystem, SaveManager, SanityFX

### Cómo poner el icono de Música
1. Abre scenes/main/main.tscn
2. Nodo Main → Inspector → Iconos del escritorio → icon_musica
3. Asigna assets/Icons Pc/Musica.png

### Cómo poner música
Coloca en assets/audio/music/:
- musica_juego1.ogg … musica_juego5.ogg


## Sistemas narrativos coordinados (Godot 4.6)

La versión actual integra cinco sistemas conectados:

- `scripts/systems/investigation_system.gd`: une Correo → Banco → Archivos y guarda banderas, pistas y archivos descubiertos.
- `scripts/systems/paranoia_system.gd`: paranoia interna 0–100, por etapas, con eventos limitados por cooldown.
- `scripts/systems/bank_system.gd`: historial de movimientos narrativos sin alterar el saldo del jugador.
- `scripts/apps/email_app.gd` / `scripts/apps/files_app.gd`: reaccionan a eventos de paranoia sin crear estado independiente.
- `scripts/managers/time_manager.gd` + `email_system.gd`: contenido dependiente del día y correos narrativos con fecha límite.

Los estados nuevos se incluyen en `SaveManager` y son compatibles con partidas anteriores: si un guardado antiguo no contiene estos campos, se reconstruyen a partir de los correos y pistas ya leídos.
