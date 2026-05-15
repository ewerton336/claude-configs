---
name: ado-workflow
description: Use when criar User Story, Task ou branch no Azure DevOps Usiminas Cubatão (org usiminasdevops, projeto LEVEL_II_Automation-Cub) — cobre fluxo completo (US + tasks filhas + branch + commit + state machine). Específico do processo PT-BR customizado deste org. Triggers: "crie uma US", "abre uma task no ADO", "vincule a US X", "mova para concluído", "branch para essa task", "ABs deste commit", "linkar parent" e similares.
---

# ADO Workflow — Usiminas Cubatão (LEVEL_II_Automation-Cub)

Esta skill documenta o fluxo end-to-end para criar User Stories, Tasks, branches e commits no ADO desta organização, e movê-los pelo state machine customizado em PT-BR. **Inclui pitfalls aprendidos na prática que não aparecem na documentação oficial.**

## Constantes do ambiente

- **Organização ADO:** `usiminasdevops`
- **Projeto:** `LEVEL_II_Automation-Cub`
- **Project ID:** `cfbc68fd-0b01-4305-b1df-3b6db0843faa`
- **Repos comuns:**
  - `GERENCIADOR.LE2.SERVER` → repoId `72e7103c-f2e0-4138-a96d-c957835bddca`
  - `GERENCIADOR.LE2.WEB` → repoId `7608d4ef-ea56-41b9-b7de-675a50c09eb7`
- **Assignee padrão:** `UT18166@usiminas.com` (Ewerton Guimaraes)
- **Area/Iteration Path padrão:** `LEVEL_II_Automation-Cub` (raiz)

Para outros repos, descobrir via `mcp__ado__repo_list_repos_by_project`.

## Fluxo completo (passo a passo)

### 1. Criar a User Story

```
mcp__ado__wit_create_work_item({
  project: "LEVEL_II_Automation-Cub",
  workItemType: "User Story",
  fields: [
    { name: "System.Title", value: "..." },
    { name: "System.AreaPath", value: "LEVEL_II_Automation-Cub" },
    { name: "System.IterationPath", value: "LEVEL_II_Automation-Cub" },
    { name: "System.AssignedTo", value: "UT18166@usiminas.com" },
    { name: "System.Tags", value: "Tag1; Tag2; ..." },
    { name: "System.Description", format: "Markdown", value: "..." }
  ]
})
```

Anote o `id` retornado — será o **{US_ID}**.

### 2. Criar Tasks filhas

**CAMPO OBRIGATÓRIO para Task:** `Microsoft.VSTS.Common.Activity` (valores válidos: `Development`, `Design`, `Testing`, `Documentation`, `Deployment`, `Requirements`). Sem isso, o create falha com `TF401320: Rule Error for field Activity`.

```
mcp__ado__wit_create_work_item({
  workItemType: "Task",
  fields: [
    { name: "System.Title", value: "..." },
    { name: "System.AreaPath", value: "LEVEL_II_Automation-Cub" },
    { name: "System.IterationPath", value: "LEVEL_II_Automation-Cub" },
    { name: "System.AssignedTo", value: "UT18166@usiminas.com" },
    { name: "Microsoft.VSTS.Common.Activity", value: "Development" },
    { name: "System.Description", format: "Markdown", value: "..." }
  ]
})
```

### 3. ⚠️ Vincular Task → US (parent)

**PITFALL CRÍTICO:** passar `System.Parent` no `fields` durante o create **NÃO** cria o link `Hierarchy-Reverse`. A task fica órfã. **Sempre** linkar explicitamente depois:

```
mcp__ado__wit_work_items_link({
  project: "LEVEL_II_Automation-Cub",
  updates: [
    { id: <TASK_ID>, linkToId: <US_ID>, type: "parent" },
    ...
  ]
})
```

Vincular várias tasks no mesmo batch. **Sempre verificar com `wit_get_work_items_batch_by_ids` se o `System.Parent` está populado depois.**

### 4. Vincular US a US relacionadas (opcional)

```
mcp__ado__wit_work_items_link({
  updates: [
    { id: <US_ID>, linkToId: <RELATED_US_ID>, type: "related", comment: "..." }
  ]
})
```

### 5. Criar branch no repo

Convenção de nome: `<prefixo>/<US_ID>-<slug-curto>`:
- `feature/{ID}-...` → nova funcionalidade
- `refactor/{ID}-...` → reorganização sem mudar comportamento
- `fix/{ID}-...` → correção de bug

```
mcp__ado__repo_create_branch({
  project: "LEVEL_II_Automation-Cub",
  repositoryId: "<repo_id>",
  branchName: "feature/64187-async-bobina-picker",
  sourceBranchName: "master"
})
```

### 6. Commitar com trailer AB#

A organização tem integração ADO ↔ Git: commits com `AB#<id>` no body criam automaticamente o `ArtifactLink` "Fixed in Commit" no work item (testado e confirmado).

```bash
git commit -m "$(cat <<'EOF'
feat: <título curto>

<corpo descritivo>

Related: AB#64187 AB#64188 AB#64189
EOF
)"
git push -u origin feature/64187-async-bobina-picker
```

Múltiplos `AB#` no mesmo trailer linkam o commit a múltiplos work items. Isso funciona tanto para a US quanto para suas Tasks.

**Convenções obrigatórias dos commits deste usuário (memory):**
- ❌ NUNCA incluir `Co-Authored-By: Claude` (ver `feedback_no_coauthor_in_commits.md`)
- Commit é autoria exclusiva do usuário

## State Machine — processo PT-BR customizado

### Task (estados)

```
Novo → Fila Desenvolvimento → Em Desenvolvimento → Em Testes → Concluído
                                                              ↘ Removido
```

**Transições NÃO podem pular estados.** Tentar `Novo → Concluído` direto retorna `The field 'State' contains the value 'X' that is not in the list of supported values` (mensagem enganosa — o estado existe, a transição é que não).

### User Story (estados)

```
Nova → Em Desenvolvimento → Pronto para Testes → Em Testes →
       Pronto para Aceite → Em Aceite → Pronto para Homologação →
       Em Homologação → Pronto para Deploy → Concluído
```

**Mapeamento de termos coloquiais:**
- "Aguardando Teste" → **`Pronto para Testes`** (dev concluído, QA não iniciou) — preferir este
- "Em Testes" → QA em andamento

### Campos obrigatórios por transição (Tasks)

| Saindo de | Campo required |
|---|---|
| Novo | (nenhum extra além do `Activity` já no create) |
| Em Desenvolvimento | `Microsoft.VSTS.Scheduling.OriginalEstimate` (em horas, ex.: 1, 2, 3) |
| Em Testes | `Microsoft.VSTS.Scheduling.CompletedWork` + `Microsoft.VSTS.Scheduling.RemainingWork` (geralmente `0`) |

A mensagem de erro nesse caso é mais clara: `TF401320: Rule Error for field <Nome>. Error code: Required, InvalidEmpty.`

Setar o campo no mesmo PATCH da mudança de estado:

```
mcp__ado__wit_update_work_item({
  id: <TASK_ID>,
  updates: [
    { op: "add", path: "/fields/Microsoft.VSTS.Scheduling.CompletedWork", value: "2" },
    { op: "add", path: "/fields/Microsoft.VSTS.Scheduling.RemainingWork", value: "0" },
    { op: "add", path: "/fields/System.State", value: "Em Testes" }
  ]
})
```

### Sequência típica "trabalho já entregue → encerrar tudo"

Para US recém-criada (Nova) + Tasks recém-criadas (Novo) com código já mergeado:

1. **Tasks:** `Novo → Fila Desenvolvimento` (sem campo extra)
2. **US:** `Nova → Em Desenvolvimento` (sem campo extra)
3. **Tasks:** `Fila Desenvolvimento → Em Desenvolvimento` (com `OriginalEstimate`)
4. **US:** `Em Desenvolvimento → Pronto para Testes` (fim do fluxo da US, deixa para QA)
5. **Tasks:** `Em Desenvolvimento → Em Testes` (com `CompletedWork` + `RemainingWork`)
6. **Tasks:** `Em Testes → Concluído`

Cada hop pode ser feito em paralelo para todas as tasks do mesmo grupo (mas hops diferentes têm que ser sequenciais).

## Validações finais recomendadas

Antes de declarar terminado, sempre:

1. **Conferir parent links:** `wit_get_work_items_batch_by_ids` com fields `["System.Parent"]` — todas as tasks devem ter `System.Parent` setado.
2. **Procurar tasks órfãs:**
   ```sql
   SELECT [System.Id], [System.Title] FROM WorkItems
   WHERE [System.TeamProject] = 'LEVEL_II_Automation-Cub'
     AND [System.WorkItemType] = 'Task'
     AND [System.Parent] = ''
     AND [System.State] NOT IN ('Removido')
   ```
3. **Conferir ArtifactLink:** o work item deve ter relação `Fixed in Commit` (ou `Pull Request`) para a SHA correta.

## Tips e gotchas

- **WIQL retorna pouco?** O `wit_query_by_wiql` usa por padrão a "default team context" que pode filtrar. Use `[System.AreaPath] UNDER 'LEVEL_II_Automation-Cub'` para garantir cobertura.
- **`wit_get_work_item_type` retorna >50k chars:** salva em arquivo temp. Para extrair estados, fazer `Grep` por `"name":` filtrando categorias `Proposed/InProgress/Completed/Removed`.
- **Custom fields:** `Custom.6141f08d-cc60-4276-adc3-6efb648ab529` é o campo "Severidade" (default `4 - Baixa`) — geralmente não precisa setar.
- **Subprocessos `claude -p` com MCP ADO:** se o MCP `ado` não estiver disponível na sessão atual, agendar via subprocess pode falhar — o subprocess herda env mas pode não ter o MCP injetado. Verificar com ToolSearch antes.
- **CRLF warnings no push:** ignorar — é só conversão de line endings do Git no Windows.
