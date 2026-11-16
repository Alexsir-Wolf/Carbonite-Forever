# Guia de manutenção da Edição Forever

Este guia mostra como trazer versões novas do Carbonite oficial e como publicar releases da edição.

## Repositórios

| Remoto | Repositório | Papel |
|---|---|---|
| `origin` | `IrcDirk/Carbonite-All-in-One-Retail-Classic` | upstream, o Carbonite oficial |
| `fork` | `Alexsir-Wolf/Carbonite-Forever` | esta edição |

```bash
git remote add fork https://github.com/Alexsir-Wolf/Carbonite-Forever.git
```

## O que a edição muda

Estes são os pontos de conflito mais prováveis num merge do upstream:

| Mudança | Arquivos |
|---|---|
| Minimapa ao vivo em masmorras | `Carbonite/Modules/Map/MapEngine.lua`, `UnmappedInstance.lua`, `DungeonChart.lua` (`DC:Current`), `Carbonite/Modules/Modules.xml` |
| Botão do Spoken na lista de quests | `Carbonite.Quests/SpokenPlay.lua` e uma linha em cada `Carbonite.Quests*.toc` |
| Quests do Forever a partir do QuestieDB | `Carbonite.Quests/QuestieSource.lua` e `Carbonite.Quests-Camelot.toc` (`OptionalDeps` e a linha do arquivo) |
| Sem ids de sites de addons | todos os `.toc`: sem `X-Curse-Project-ID`, `X-WoWI-ID` nem `X-Wago-ID` |
| Releases só da edição | `.github/workflows/release.yml` (tags `v*-forever*`) |
| Documentação | `README.md`, este guia |

## Trazer uma versão nova do upstream

1. Atualize e traga as mudanças:
   ```bash
   git fetch origin
   git switch fork-master
   git pull --ff-only fork master
   git merge origin/master -m "chore: trazer a versão v12.1.0-00024 do upstream"
   ```
2. Resolva os conflitos com estas regras:
   - nos `.toc`, aceite as linhas novas do upstream, mas mantenha sem ids de sites e mantenha as linhas de `SpokenPlay.lua`, `QuestieSource.lua` e `OptionalDeps: QuestieDB`;
   - mantenha o `README.md`, este guia e o filtro de tags do `release.yml` da edição;
   - no código, combine as duas versões e preserve o comportamento das três mudanças da tabela acima.
3. Confira se o upstream trouxe de volta algum id de site:
   ```bash
   git grep -n -E "^## X-(Curse-Project-ID|WoWI-ID|Wago-ID):" -- "*.toc"
   ```
   Se aparecer algum, apague as linhas e faça o commit com `build: tirar os ids dos sites de addons dos toc`.
4. Teste no jogo antes de publicar:
   - a lista de addons mostra o Carbonite sem erros Lua no login;
   - numa masmorra, a janela do mapa mostra o minimapa ao vivo com o nome da masmorra;
   - com o Spoken ativo, o ▶ aparece ao lado do ícone das quests que ele narra, toca e para;
   - com o QuestieDB ativo, quem dá as quests novas do Forever aparece no mapa, por exemplo o Constable Aonda em Zephras Isle (45.7, 45.5).
5. Envie a `master` (sem tags do upstream):
   ```bash
   git push fork fork-master:master
   ```

## Publicar uma release

A versão segue o formato `<versão do upstream>-forever.<n>`. O `n` recomeça em 1 a cada versão nova do upstream.

```bash
git tag -a v12.1.0-00024-forever.1 -m "Edição Forever sobre o Carbonite v12.1.0-00024"
git push fork v12.1.0-00024-forever.1
```

A tag dispara o workflow `Package and release`. Ele monta o zip com as 6 pastas, preenche a versão nos `.toc` e cria a Release no fork.

Depois, confira na Release:
- o zip contém `Carbonite`, `Carbonite.Quests`, `Carbonite.Info`, `Carbonite.Notes`, `Carbonite.Warehouse` e `Carbonite.Gathermate2_Data`;
- os `.toc` mostram a versão da tag, e não `@project-version@`.

O GitHub Actions precisa estar ativo no fork, na aba Actions. Nunca adicione ao fork os segredos `CF_API_KEY`, `WOWI_API_TOKEN` ou `WAGO_API_TOKEN`: a edição não deve ir para as páginas do Carbonite oficial.

## Commits

Os commits seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), em pt-BR, no imperativo e com a descrição em minúsculas. Exemplo: `fix(map): corrigir zoom do minimapa em masmorras`.
