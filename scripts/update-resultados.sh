#!/usr/bin/env bash
# Descarga los resultados de liga de los equipos de data/martinenc.json y
# regenera data/resultados_martinenc.json. Misma lógica que el workflow
# update-resultados-martinenc.yml, para ejecutarlo en local cuando la FCF
# bloquea las IPs de GitHub Actions (403 de CloudFront).
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
FECHA_INICIO_LIGA="2026-08-15"
FECHA_FIN_LIGA="2027-06-30"
set -euo pipefail
> $tmp/resultados_all.jsonl
while IFS=$'\t' read -r nombre club codigo; do
  curl -sSL --fail-with-body \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \
    -H "Accept: application/json, text/plain, */*" \
    -H "Accept-Language: es-ES,es;q=0.9,ca;q=0.8,en;q=0.7" \
    -H "Referer: https://www.fcf.cat/" \
    -H "Origin: https://www.fcf.cat" \
    "https://www.fcf.cat/api/clubs/${club}/team/${codigo}" \
    | jq --arg team "$codigo" --arg inicio "$FECHA_INICIO_LIGA" --arg fin "$FECHA_FIN_LIGA" \
       '.data.matches
        | map(select(.JORNADA != "0" and .COMIENZO1 >= $inicio and .COMIENZO1 <= $fin))
        | map(. + {trackedTeams: [$team]})' \
    >> $tmp/resultados_all.jsonl
done < <(jq -r '.equipos[] | [.nombre, .club, .codigo] | @tsv' data/martinenc.json)

jq -s 'add' $tmp/resultados_all.jsonl > $tmp/resultados_flat.json

# Deduplica partidos que pudieran aparecer en la descarga de dos
# equipos distintos (si dos equipos de martinenc.json se enfrentan
# entre sí), fusionando trackedTeams.
jq '
  group_by([.COMIENZO1, .CODEQUIPO_CASA, .CODEQUIPO_FUERA])
  | map(reduce .[] as $m ({}; . * $m + {trackedTeams: ((.trackedTeams // []) + $m.trackedTeams | unique)}))
' $tmp/resultados_flat.json > $tmp/resultados_dedup.json

jq -n --slurpfile equipos data/martinenc.json --slurpfile matches $tmp/resultados_dedup.json \
  '{updatedAt: (now | todate), equipos: $equipos[0].equipos, matches: ($matches[0] | sort_by(.COMIENZO1))}' \
  > data/resultados_martinenc.json

