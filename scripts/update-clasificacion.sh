#!/usr/bin/env bash
# Genera data/clasificacion_martinenc.json con la clasificación del grupo del
# Martinenc S16A a partir de la API de la FCF, aplicando las correcciones de
# data/clasificacion_ajustes.json (partidos que la FCF tiene mal registrados).
#
# Ejecutar en local: la FCF (CloudFront) bloquea las IPs de GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

GRUP_ID=$(jq -r '.grupId' data/clasificacion_ajustes.json)
API="https://www.fcf.cat/api/competition"

fetch() {
  curl -sSL --fail-with-body \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \
    -H "Accept: application/json, text/plain, */*" \
    -H "Accept-Language: es-ES,es;q=0.9,ca;q=0.8,en;q=0.7" \
    -H "Referer: https://www.fcf.cat/" \
    -H "Origin: https://www.fcf.cat" \
    "$1"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch "$API/classificacio?grupId=${GRUP_ID}" > "$tmp/clasificacion.json"
fetch "$API/partidos?grupId=${GRUP_ID}" > "$tmp/partidos.json"

# Un ajuste solo se aplica mientras la FCF siga mostrando el partido con el
# resultado erróneo; si lo corrige, se ignora para no contarlo dos veces.
jq -n --slurpfile aj data/clasificacion_ajustes.json --slurpfile pa "$tmp/partidos.json" '
  [ $aj[0].partidos[] as $a
    | select([$pa[0].partidos[][]
        | select(.CODEQUIPO_CASA == $a.casa and .CODEQUIPO_FUERA == $a.fuera
                 and (.GOLES_CASA | tonumber) == $a.registrado.casa
                 and (.GOLES_FUERA | tonumber) == $a.registrado.fuera)] | length > 0)
    | $a ]' > "$tmp/ajustes_activos.json"

jq -n \
  --slurpfile cl "$tmp/clasificacion.json" \
  --slurpfile aj "$tmp/ajustes_activos.json" \
  --slurpfile all data/clasificacion_ajustes.json '
  def stats($gf; $gc): {
    pt: (if $gf > $gc then 3 elif $gf == $gc then 1 else 0 end),
    pg: (if $gf > $gc then 1 else 0 end),
    pe: (if $gf == $gc then 1 else 0 end),
    pp: (if $gf < $gc then 1 else 0 end),
    gf: $gf, gc: $gc };
  def sumar($d): .pt += $d.pt | .pg += $d.pg | .pe += $d.pe | .pp += $d.pp | .gf += $d.gf | .gc += $d.gc;
  def restar($a; $b): {pt: ($a.pt-$b.pt), pg: ($a.pg-$b.pg), pe: ($a.pe-$b.pe), pp: ($a.pp-$b.pp), gf: ($a.gf-$b.gf), gc: ($a.gc-$b.gc)};

  ($cl[0].data) as $orig
  | ($orig | map(.promotionColor)) as $colores
  | ($orig | map({
      key: .team.teamId,
      value: {
        teamId: .team.teamId, clubId: .team.clubId, nombre: .team.name, escudo: .team.logo,
        pt: (.points | tonumber | floor), pj: .played, pg: .won, pe: .drawn, pp: .lost,
        gf: (.goalsFor | tonumber), gc: (.goalsAgainst | tonumber), ajustado: false
      }}) | from_entries) as $base
  | reduce $aj[0][] as $a ($base;
      (stats($a.registrado.casa; $a.registrado.fuera)) as $rc
      | (stats($a.registrado.fuera; $a.registrado.casa)) as $rf
      | (stats($a.real.casa; $a.real.fuera)) as $ac
      | (stats($a.real.fuera; $a.real.casa)) as $af
      | .[$a.casa]  |= (sumar(restar($ac; $rc)) | .ajustado = true)
      | .[$a.fuera] |= (sumar(restar($af; $rf)) | .ajustado = true))
  | [.[]] | sort_by([-.pt, -(.gf - .gc), -.gf, .nombre])
  | to_entries
  | map(.value + {pos: (.key + 1), dg: (.value.gf - .value.gc), promocion: $colores[.key]})
  | { updatedAt: (now | todate),
      grupId: $all[0].grupId,
      ajustes: ($aj[0] | map(.descripcion)),
      equipos: . }
' > data/clasificacion_martinenc.json

echo "Clasificación actualizada: $(jq '.equipos|length' data/clasificacion_martinenc.json) equipos, $(jq '.ajustes|length' data/clasificacion_martinenc.json) ajuste(s) aplicado(s)"
