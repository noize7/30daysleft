# 30 DAYS LEFT — Godot 4.6

- **Sistema de pago dual** (Online vs Efectivo)
  - Selector en la app Trabajo
  - Online suma sospecha (mitigado por Proxy anónimo)
  - Efectivo no suma sospecha **pero puede retrasarse o fallar** (pérdida parcial del pago)
  - Riesgos de efectivo aumentan con cordura baja y día avanzado
  - Persistido en save

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


- **Cuota diaria del empleador** (`LoopSystem`): escala con tu nivel de trabajo, CPU y el día. Cumplirla da bono, +cordura y −sospecha; no llegar castiga (desde el día 3). Cada 5 días seguidos cumpliendo hay premio extra.

- **Racha de calidad:** notas A/S seguidas suben el pago hasta +32 %; una C/D la rompe.

- **3 encargos por día** (completar N trabajos, sacar notas A/S, alcanzar una racha, ganar $X antes de las 03:00, no subir sospecha). Recompensa inmediata.

- **Acciones:** *Descansar* (+cordura a cambio de 25 min de reloj y 3 % de batería) y *Borrar rastros* (−sospecha a cambio de dinero; el coste escala con la cuota). Son los primeros "sumideros" de dinero y de cordura del juego.

- **Eventos con decisiones** (`EventSystem`, `data/events.json`): 14 dilemas con 2-3 opciones y consecuencias (dinero, cordura, sospecha, batería, tiempo, pistas). Máximo 2 por día, empiezan el día 2. Congelan reloj y batería mientras están abiertos.

- **Panel TURNO** arriba a la derecha (se puede plegar con el botón «—») y avisos arriba al centro. Todo se crea por código: no hay escenas nuevas.

### Balance (ajustable)
Constantes al inicio de `loop_system.gd` (`REST_*`, `TRACKS_*`, `STREAK_*`, `GRACE_DAYS`) y la fórmula `_compute_quota` (`3.0 + 0.22 * día` trabajos equivalentes).
