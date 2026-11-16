# Testes

Testes em Lua 5.1 puro, sem dependências: cada arquivo de `tests/spec/` carrega um arquivo do
addon num ambiente isolado com stubs da API do WoW (`tests/support/wow.lua`) e confere o
comportamento. O CI (`.github/workflows/tests.yml`) roda em cada push na master e em cada PR:

1. `tests/check-syntax.sh`: compila todos os `.lua` com `luac5.1 -p`;
2. `lua5.1 tests/run.lua tests/spec/*.lua`: os testes;
3. `luacheck .`: lint dos arquivos listados em `include_files` no `.luacheckrc`.

## Rodar localmente

Com Lua 5.1 e luacheck instalados, a partir da raiz do repositório:

```sh
bash tests/check-syntax.sh
lua5.1 tests/run.lua tests/spec/*.lua
luacheck .
```

No Windows, sem Lua instalado, dá para usar Docker:

```sh
docker run --rm -v "$PWD:/w" -w /w ubuntu:24.04 bash -c \
  "apt-get update -qq && apt-get install -y -qq lua5.1 luarocks >/dev/null && luarocks install luacheck >/dev/null && \
   bash tests/check-syntax.sh && lua5.1 tests/run.lua tests/spec/*.lua && luacheck ."
```

## Escrever um teste

```lua
-- tests/spec/exemplo_spec.lua
describe("Battleground:Refresh", function()
    it("marca instância pvp como battleground", function()
        local env = wow.env({ GetInstanceInfo = function() return "WSG", "pvp" end })
        loader.run(env, "Carbonite/Modules/Map/Battleground.lua")
        env.Nx = {}
        env.Carbonite.Modules.Map.Battleground:Refresh()
        expect(env.Nx.InBG).toBe(true)
    end)
end)
```

Funções de `expect`: `toBe`, `toEqual`, `toBeTruthy`, `toBeFalsy`, `toBeNil`, `toContain`,
`toNotThrow`. Um arquivo novo do addon só entra no lint quando estiver limpo; acrescente-o ao
`include_files` do `.luacheckrc`.

As specs e os planos ficam fora do repositório.
