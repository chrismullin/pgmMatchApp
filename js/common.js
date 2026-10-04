// Utilidades compartidas por todas las páginas. Se carga como script clásico
// (sin módulos) antes del script propio de cada página, así que todo lo
// declarado aquí es global.

const CREST_BASE = 'https://files.fcf.cat/escudos/clubes/escudos/';

const statusEl = document.getElementById('status');

function setError(message) {
  statusEl.textContent = message;
  statusEl.classList.add('error');
}

function fetchJson(url) {
  return fetch(url).then(res => {
    if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
    return res.json();
  });
}

// Igual que fetchJson pero para ficheros opcionales: si falla, devuelve el
// valor de recambio en lugar de rechazar.
function fetchJsonOr(url, fallback) {
  return fetchJson(url).catch(() => fallback);
}

function crestUrl(filename) {
  return filename ? CREST_BASE + encodeURIComponent(filename) : '';
}

// Algunos escudos que devuelve la API de amistosos están rotos (404 en
// files.fcf.cat) para ciertos equipos. Los ficheros de datos permiten informar
// un "escudo" de recambio por código de equipo, que tiene prioridad sobre el
// que venga en el partido. Cada página rellena este objeto al cargar.
let escudoOverrides = {};

function resolveEscudo(codigoEquipo, escudoApi) {
  return escudoOverrides[codigoEquipo] || escudoApi;
}

function formatHora(hora) {
  return hora ? hora.slice(0, 5) : '';
}

// Acepta una fecha ISO o un objeto Date.
function formatFecha(fecha) {
  if (!fecha) return '';
  const d = new Date(fecha);
  if (isNaN(d)) return '';
  return d.toLocaleDateString('es-ES', { weekday: 'long', day: '2-digit', month: '2-digit', year: 'numeric' });
}

// Muestra la fecha/hora de actualización del Action en la zona horaria de
// Madrid, con el formato "dd/mm/aaaa a las hh:mm", independientemente de la
// zona horaria del navegador de quien visite la página.
function formatActualizado(iso) {
  if (!iso) return '?';
  const fecha = new Date(iso);
  if (isNaN(fecha)) return iso;
  const partes = new Intl.DateTimeFormat('es-ES', {
    timeZone: 'Europe/Madrid',
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: false,
  }).formatToParts(fecha);
  const valor = tipo => partes.find(p => p.type === tipo)?.value;
  return `${valor('day')}/${valor('month')}/${valor('year')} a las ${valor('hour')}:${valor('minute')}`;
}

// data/default.json permite informar a mano partidos que la descarga
// automática no recoge (o recoge con datos incompletos). Sus entradas tienen el
// mismo formato de fila que las de la API, y tienen prioridad sobre las
// equivalentes descargadas automáticamente (misma fecha/hora/equipos).
function mergeMatches(base, extra) {
  const key = m => `${m.FECHA}|${m.HORA_COMIENZO}|${m.CODEQUIPO_CASA}|${m.CODEQUIPO_FUERA}`;
  const map = new Map(base.map(m => [key(m), m]));
  for (const m of extra) map.set(key(m), m);
  return [...map.values()].sort((a, b) =>
    `${a.FECHA}T${a.HORA_COMIENZO || ''}`.localeCompare(`${b.FECHA}T${b.HORA_COMIENZO || ''}`)
  );
}

// CODACTA no es fiable como señal de "partido disputado": hay partidos con
// CODACTA ya asignado que aún no se han jugado, y partidos ya jugados sin
// CODACTA todavía informado por la FCF. En su lugar, se compara la hora de
// inicio teórica del partido con la hora en que el Action recogió los datos
// (data.updatedAt): si han pasado más de 3h desde el inicio, se asume
// finalizado. Todo el rango de fechas de esta temporada cae en horario de
// verano (CEST, UTC+2), de ahí el offset fijo '+02:00'.
// Además, si ya hay un resultado distinto de 0-0 informado, se considera
// jugado de inmediato aunque no hayan pasado las 3h ni haya CODACTA, ya que
// un marcador no nulo solo se rellena una vez el partido está en curso o
// finalizado.
function isJugado(m, updatedAt) {
  const golesCasa = Number(m.PARTIDO_GOLES_CASA);
  const golesFuera = Number(m.PARTIDO_GOLES_VISITANTE);
  if (!Number.isNaN(golesCasa) && !Number.isNaN(golesFuera) && (golesCasa !== 0 || golesFuera !== 0)) return true;
  if (!m.FECHA || !m.HORA_COMIENZO || !updatedAt) return !!m.CODACTA;
  const kickoff = new Date(`${m.FECHA.slice(0, 10)}T${m.HORA_COMIENZO}+02:00`);
  const referencia = new Date(updatedAt);
  if (isNaN(kickoff) || isNaN(referencia)) return !!m.CODACTA;
  return referencia.getTime() >= kickoff.getTime() + 3 * 60 * 60 * 1000;
}

// --- piezas HTML de las tarjetas de partido ---

// Zona central de la tarjeta: marcador (con enlace al acta si existe) o la
// etiqueta "Programado" si aún no se ha jugado.
function matchCenterHtml(jugado, codActa, golesCasa, golesFuera) {
  if (!jugado) return `<span class="badge-pending">Programado</span>`;
  const marcador = `${golesCasa} - ${golesFuera}`;
  return codActa
    ? `<a class="match-score" href="https://www.fcf.cat/ca/competicio/acta/${encodeURIComponent(codActa)}" target="_blank" rel="noopener">${marcador}</a>`
    : `<span class="match-score">${marcador}</span>`;
}

function equipoUrl(codigoClub, codEquipo) {
  return (codigoClub && codEquipo)
    ? `https://www.fcf.cat/ca/clubs/${encodeURIComponent(codigoClub)}/categories/${encodeURIComponent(codEquipo)}`
    : null;
}

// Escudo, envuelto en un enlace al equipo si hay URL.
function crestHtml(src, url) {
  const img = `<img src="${crestUrl(src)}" alt="" loading="lazy">`;
  return url ? `<a href="${url}" target="_blank" rel="noopener">${img}</a>` : img;
}

function mapsSearchUrl(query) {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}

// --- pestañas (.tab-btn[data-tab] ↔ #panel-<tab>) ---
function initTabs() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
    });
  });
}
