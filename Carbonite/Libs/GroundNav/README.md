# Busca de caminho a pé (GroundNav)

Motor de busca de caminho a pé do [Shortest Path Forever](https://github.com/cjber/shortest-path-forever),
de Cillian Berragan e colaboradores, licença **GPL-3.0-or-later** (`LICENSE`; origem dos dados em
`THIRD_PARTY.md`). Usado pela rota a pé que contorna o terreno (#79, `Modules/Map/GroundRoute.lua`).

- `Path.lua` e `PathGrid.lua` são cópias **sem alteração** dos arquivos que o GatherLite 8.4.11 traz em
  `plugins/routes/navigation/vendor/Routing`, adaptados por ele a partir da revisão fixada em
  `manifest.json` (hashes de origem e da cópia). A adaptação do GatherLite põe o estado da busca em
  `select(2, ...).GroundNavigation` e lê os dados de `GatherLiteGroundPathData`.
- `bootstrap.lua` cria esse namespace na tabela do próprio Carbonite: esta cópia não compartilha estado com a do
  GatherLite.
- **Os dados de terreno (cerca de 12 MB) não vêm com o Carbonite.** São lidos do global
  `GatherLiteGroundPathData`, que o GatherLite carrega. Sem o GatherLite, a rota continua em linha reta.

Para atualizar: copie de novo os dois arquivos de uma versão nova do GatherLite, confira os hashes com o
`vendor/manifest.json` dele e rode os testes (`tests/spec/ground_route_spec.lua`).
