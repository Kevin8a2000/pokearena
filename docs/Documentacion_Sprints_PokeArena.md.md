# Documentación Scrum — PokéArena (CIPA DevOps)

## Sprint 0 — Setup del proyecto
**Duración planeada:** 26–28 sept 2026
**Repositorio:** github.com/Kevin8a2000/pokearena — rama `main`

### 1. Sprint Goal (objetivo del sprint)

Dejar listo el entorno de desarrollo, la arquitectura del proyecto y una primera versión mínima de la Pokédex, para que el equipo pudiera empezar a trabajar en paralelo desde el Sprint 1.

### 2. Tareas trabajadas

| ID | Tarea | Estado |
|----|-------|--------|
| S0-1 | Configurar el entorno: Flutter SDK, VS Code + extensión Flutter | ✅ Hecho |
| S0-2 | Crear el proyecto base `pokearena` (`flutter create`) | ✅ Hecho |
| S0-3 | Definir arquitectura por *features* (`core/` + `features/`) | ✅ Hecho |
| S0-4 | Crear `PokeApiService` y los modelos base (`PokemonSummary`, `PokemonDetail`) | ✅ Hecho |
| S0-5 | Construir la Pokédex mínima: lista con scroll y detalle con stats | ✅ Hecho |
| S0-6 | Navegación con 5 pestañas (una por módulo) y tema claro/oscuro | ✅ Hecho |
| S0-7 | Crear el repositorio en GitHub y subir el proyecto | ✅ Hecho |
| S0-8 | Crear el backlog completo del proyecto (sprints 1 a 4) | ✅ Hecho |

### 3. Incremento entregado (qué se podía mostrar al cierre del sprint)

Una app Flutter que corre en Chrome, con una Pokédex funcional (lista de Pokémon con su imagen oficial, detalle con tipos y estadísticas) y una barra de navegación con las 5 secciones planeadas (Pokédex, Equipo, Batalla, Quiz, Perfil), aunque solo la primera tenía contenido real.

### 4. Decisiones técnicas y su justificación

1. **Flutter como framework**, aunque el profesor luego aclaró que el entorno era libre. Se decidió continuar con Flutter porque ya se había configurado el entorno y probado que funcionaba, y porque permite compilar para Android y Web desde una sola base de código, útil para la demo en el stand.
2. **Se descartó usar un repositorio público de terceros como base** (se evaluó un proyecto de Pokédex existente en GitHub). Se decidió construir un proyecto propio desde cero por dos razones: riesgo de integridad académica al presentar código ajeno como propio, y porque ese proyecto no incluía los módulos planeados (equipo, batalla, quiz), que son el diferenciador de PokéArena.
3. **Arquitectura por features desde el inicio**, con una carpeta `core/` para lo compartido (modelos, servicio de API, colores de tipo). Esto permite que los 5 integrantes trabajen en paralelo sobre sus propios módulos sin pisarse entre sí.
4. **Provider como gestor de estado**, por ser más simple de explicar en la sustentación que alternativas como Bloc o Riverpod.

### 5. Dificultades encontradas

- Errores de compatibilidad al intentar correr un proyecto de terceros (paquetes desactualizados frente a la versión reciente de Flutter), lo que confirmó la decisión de construir un proyecto propio.
- Confusión inicial ubicando las carpetas correctas al copiar código entre proyectos en Windows (rutas duplicadas al descomprimir), resuelta verificando siempre el contenido con `dir` antes de copiar.

### 6. Retrospectiva

| Qué funcionó bien | Qué mejorar | Acuerdo para el próximo sprint |
|---|---|---|
| Probar el entorno (`flutter doctor`) antes de escribir código evitó sorpresas grandes más adelante. | Se perdió tiempo evaluando un repositorio de terceros antes de decidir construir uno propio. | Antes de reutilizar cualquier código externo, evaluar primero si calza con los requisitos propios del proyecto. |
| Definir la arquitectura por módulos desde el día 1 facilitó el reparto de trabajo. | Aún no se habían asignado los módulos a cada integrante del CIPA al cierre del sprint. | Asignar módulos y roles (Product Owner, Scrum Master) al iniciar el Sprint 1. |

### 7. Evidencia para la sustentación

- Captura de `flutter doctor` con el entorno correctamente configurado.
- Primer commit del repositorio (`Sprint 0: base del proyecto con Pokedex funcional`).
- Captura de la app corriendo en Chrome con la Pokédex mínima y las 5 pestañas.

---

## Sprint 1 — Pokédex completa
**Duración planeada:** 29 sept – 5 oct 2026
**Repositorio:** github.com/Kevin8a2000/pokearena — rama `feature/pokedex`

---

### 1. Sprint Goal (objetivo del sprint)

Completar el módulo Pokédex: búsqueda, filtros por tipo y generación, detalle ampliado con habilidades y cadena evolutiva, y caché local para uso sin conexión.

### 2. Historias de usuario trabajadas

| ID | Historia de usuario | Estado |
|----|----------------------|--------|
| P1 | Como usuario, quiero buscar un Pokémon por nombre o número para encontrarlo rápido. | ✅ Hecho |
| P2 | Como usuario, quiero filtrar por tipo para ver solo los Pokémon que me interesan. | ✅ Hecho |
| P3 | Como usuario, quiero filtrar por generación para explorar por juego/época. | ✅ Hecho |
| P4 | Como usuario, quiero ver las habilidades de un Pokémon en su detalle. | ✅ Hecho |
| P5 | Como usuario, quiero ver la cadena evolutiva de un Pokémon y navegar entre sus etapas. | ✅ Hecho |
| P6 | Como usuario, quiero que lo que ya vi siga disponible sin conexión a internet. | ✅ Hecho |
| P7 | Como usuario, quiero saber si algo falló y poder reintentar, o ver un mensaje claro si no hay resultados. | ✅ Hecho |
| P8 | Como equipo, queremos pruebas automáticas que confirmen que el modelo de datos y los filtros funcionan bien. | ✅ Hecho (12 pruebas) |

### 3. Incremento entregado (qué se puede mostrar hoy)

- Pokédex con los 1025 Pokémon, cuadrícula con imagen oficial.
- Búsqueda por nombre o número, con espera de 400 ms para no recalcular con cada tecla.
- Filtro por los 18 tipos y por las 9 generaciones, combinables entre sí y con la búsqueda.
- Pantalla de detalle: tipos, altura, peso, habilidades (marcando la oculta) y barras de estadísticas.
- Cadena evolutiva navegable, incluyendo casos ramificados (ej. Eevee).
- Caché local: lo ya visitado se puede volver a abrir sin conexión.
- Manejo de estados: cargando, error con botón "Reintentar", y "sin resultados" con botón "Limpiar filtros".

### 4. Decisiones técnicas y su justificación

*(Para poder explicarlas si el profesor pregunta)*

1. **Carga completa en vez de scroll infinito por páginas.** Se pide una sola vez la lista de los 1025 Pokémon (solo nombres e ids, es liviana) y se filtra en memoria. Esto permite que la búsqueda y los filtros trabajen sobre toda la Pokédex y se combinen entre sí, algo que no sería posible si solo se tuvieran cargados los primeros 30.
2. **Caché "primero disco, luego red".** Como los datos de PokeAPI casi no cambian, se consulta primero el almacenamiento local y solo se llama a la API si no está guardado. Esto acelera la app en visitas repetidas y permite uso parcial sin conexión.
3. **Todas las llamadas HTTP centralizadas en `PokeApiService`.** Ningún widget llama directamente a la API; esto facilita mantenimiento y pruebas.

### 5. Pendiente / conocido

- Se observaron líneas de repintado en la cuadrícula durante el scroll en la versión web de Chrome (cosmético, no afecta la lógica). Pendiente de revisar antes de la sustentación; se probará también en el APK de Android.
- No se llegó a probar exhaustivamente sin conexión (validación rápida hecha, pendiente prueba formal).

### 6. Retrospectiva

| Qué funcionó bien | Qué mejorar | Acuerdo para el próximo sprint |
|---|---|---|
| Definir la arquitectura (core/ + features/) desde el Sprint 0 evitó retrabajo. | La instalación inicial del entorno (Flutter, extensión, copiar carpetas) tomó más tiempo del esperado. | Documentar el paso a paso de instalación una sola vez, para que el resto del equipo no repita los mismos tropiezos. |
| Usar un asistente de IA con instrucciones claras (reglas + tareas numeradas) permitió avanzar rápido en un módulo completo. | Los demás módulos (Equipo, Batalla, Quiz, Perfil) no han iniciado. | Definir en el próximo Daily quién toma cada módulo y fijar fecha de arranque. |

### 7. Evidencia para la sustentación

- Capturas de la Pokédex funcionando: búsqueda, filtros combinados, detalle y evolución (adjuntas en este documento o en el repositorio, carpeta `docs/capturas/`).
- Historial de commits en la rama `feature/pokedex` como evidencia de avance incremental.
- Este documento como acta de Sprint Review + Retrospectiva.

---

## Cómo seguir documentando (guía para ti)

No necesitas saber Scrum de memoria para esto. Cada vez que cierres un sprint, solo responde estas preguntas y las paso a este mismo formato:

1. **¿Qué tareas del backlog se completaron y cuáles no?** (copia la lista del archivo `Backlog_Scrum_PokeArena.md`)
2. **¿Qué se puede mostrar hoy en la app?** (2-3 frases)
3. **¿Qué decisiones técnicas tomaste que valga la pena explicar?**
4. **¿Qué no salió bien o quedó pendiente?**
5. **¿Qué aprendieron y qué acuerdan para el siguiente sprint?**

Con esas 5 respuestas (aunque sea en frases sueltas, sin formato), yo te devuelvo el acta ya redactada, como esta. Solo dime "documenta el Sprint X" y te hago las preguntas.

### Qué guardar como evidencia en cada sprint

- 2-3 capturas de pantalla de lo que ya funciona.
- El resultado de `flutter test` (captura de la terminal en verde).
- El link al commit o Pull Request del sprint.

Con esas tres cosas por sprint, al final del proyecto tienes un historial completo y creíble del proceso Scrum, sin haber tenido que llevar un diario constante.
