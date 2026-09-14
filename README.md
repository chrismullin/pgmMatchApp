# pgmMatchApp

Web estática (GitHub Pages) con los amistosos del Martinenc S16A y de sus
rivales, sin build step: cada página HTML es autocontenida y lee datos
pre-generados en formato JSON.

## Páginas

- **`index.html`** — Amistosos del Martinenc S16A.
- **`rivales.html`** — Resultados y tabla estadística de los 16 equipos del
  grupo.
- **`otros.html`** — Resultados de otros equipos.

## Datos

Los ficheros de `data/` los generan (o generaban, ver más abajo) unos
GitHub Actions que consultan la API de fcf.cat, porque esta no envía
cabeceras CORS y bloquea el `fetch()` directo desde el navegador:

| Fichero | Generado por |
|---|---|
| `data/amistosos.json` | `.github/workflows/update-data.yml` |
| `data/rivales.json` | `.github/workflows/update-rivales-data.yml` |
| `data/otros.json` | `.github/workflows/update-otros-data.yml` |
| `data/equipos.json` | mantenido a mano (equipos del grupo, escudos de recambio) |
| `data/default.json` | mantenido a mano (partidos/resultados que la API no recoge o recoge incompletos; tiene prioridad sobre los datos descargados) |
| `data/youtube-links.json` | mantenido a mano (enlaces a vídeos de partidos, usado en `otros.html`) |

## ⚠️ Actualización automática de datos: desactivada

Los tres workflows que actualizan `data/amistosos.json`, `data/rivales.json`
y `data/otros.json` (`update-data.yml`, `update-rivales-data.yml`,
`update-otros-data.yml`) están **desactivados manualmente** desde el
14/09/2026, porque la temporada de amistosos ha terminado y ya no hay
partidos que consultar. Los JSON de `data/` han quedado congelados con los
últimos datos descargados.

Para reactivarlos cuando vuelva a haber amistosos:

```sh
gh workflow enable update-data.yml
gh workflow enable update-rivales-data.yml
gh workflow enable update-otros-data.yml
```

Cada uno puede lanzarse también manualmente en cualquier momento (estén
activados o no) con `gh workflow run <fichero>.yml`, o desde la pestaña
Actions de GitHub.
