# 30 DAYS LEFT — Godot 4.6

## Tanda 8 — En progreso / parcialmente implementada

### Implementado en esta tanda
- **Sistema de pago dual** (Online vs Efectivo)
  - Selector en la app Trabajo
  - Online suma sospecha (mitigado por Proxy anónimo)
  - Efectivo no suma sospecha
  - Persistido en save
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
- TruthArchive al final de partida (lista real vs falso)

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
