# Recapitulação — Comunicação indireta, Pub/Sub e Relógio Vetorial

Atividade baseada no ICEIBank Sprint 1 (Java + Spring Boot, 3 agências, relógio de Lamport, transferência REST, JWT).

---

## 1. Arquitetura atual e divisão em agências

Hoje a aplicação é um banco particionado em **3 agências**. O código é o mesmo (`agencia/` Spring Boot), mas sobe **3 processos** diferentes, cada um com `AGENCIA_ID=0|1|2` nas portas `4000`, `4001` e `4002`.

Componentes:
- **Agência 0, 1 e 2:** cada uma guarda só as contas da sua partição, em memória (`ConcurrentHashMap`), tem o próprio `RelogioLamport` e grava eventos em `data/eventos-agencia-X.jsonl`.
- **Frontend web:** HTML/JS que escolhe uma agência de entrada, faz login JWT e chama a API.
- **MesclarLogs:** utilitário que junta os `.jsonl` e ordena por Lamport (só observação, não é serviço online).

Associação conta → agência:
```
agenciaResponsavel(idConta) = idConta % 3
```
Ex.: conta 0 → agência 0, conta 1 → agência 1, conta 3 → agência 0 de novo.

Operações **locais** (só na agência dona da conta): criar conta, consultar saldo, depositar, sacar, transferência entre duas contas da **mesma** agência, histórico.

Operações que **dependem de outra agência:** transferência em que origem e destino estão em partições diferentes. A origem debita local e chama a destino via HTTP em `/contas/{id}/creditar-remoto`.

Fronteiras de comunicação importantes pra próxima etapa:
- frontend ↔ agência (JWT)
- agência ↔ agência (hoje HTTP direto; depois deve virar mensageria)

---

## 2. Comunicação atual entre as agências

Hoje a comunicação entre agências é **direta e síncrona** por REST.

Fluxo da transferência remota:
1. Cliente autenticado chama `POST /transferencias` na agência da origem.
2. Agência origem valida saldo, faz `eventoLocal()`, debita e registra `TRANSFERENCIA_DEBITO`.
3. Calcula a agência do destino (`id % 3`).
4. Faz `aoEnviar()` e manda `POST` com `RestTemplate` para  
   `http://localhost:400X/contas/{destino}/creditar-remoto`  
   com body `{ valor, timestampLamport, origemAgencia }` e header `X-Internal-Token`.
5. Destino faz `aoReceber(timestamp)`, credita, registra `TRANSFERENCIA_CREDITO_REMOTO` e responde OK.
6. Origem devolve sucesso ao cliente.

Se o destino está **indisponível** (processo parado, porta fechada):
- a chamada HTTP falha (`Connection refused`)
- a origem **não reverte** o débito (limitação conhecida do Sprint 1)
- registra `TRANSFERENCIA_FALHOU` e responde **502**

Se **demora** ou a rede trava: o cliente fica esperando a resposta HTTP; não tem fila nem retry automático. Se a mensagem “não chega”, o efeito prático é o mesmo da falha: débito feito, crédito não aplicado, inconsistência temporária.

Limitação da comunicação direta: acoplamento forte (origem precisa conhecer URL da destino), falha imediata se o outro processo caiu, e não há desacoplamento temporal (os dois precisam estar online ao mesmo tempo). Por isso faz sentido introduzir comunicação **indireta** (mensageria/Pub-Sub).

---

## 3. Operações distribuídas e seus efeitos

Operação escolhida: **transferência entre agências** — conta 0 (Ana, agência 0) envia 15 para conta 1 (Bruno, agência 1).

Passo a passo:
1. Frontend (ou `Invoke-RestMethod`) autentica na agência 0 e chama `POST /transferencias` com `{ idOrigem:0, idDestino:1, valor:15 }`.
2. **Agência 0** acha a conta 0, confere saldo.
3. Debita 15 da conta 0; saldo local muda na hora.
4. Log: `TRANSFERENCIA_DEBITO` com timestamp Lamport.
5. Como destino é agência 1, incrementa relógio com `aoEnviar()` e envia HTTP para a agência 1.
6. **Agência 1** recebe, atualiza Lamport com `aoReceber()`, credita 15 na conta 1.
7. Log na 1: `TRANSFERENCIA_CREDITO_REMOTO`.
8. Responde OK; agência 0 responde ao cliente: “Transferência concluída (entre agências)”.

Dados alterados:
- saldo da conta 0 (débito)
- saldo da conta 1 (crédito)
- contadores Lamport das duas agências
- arquivos `.jsonl` das duas

Quando considera concluída **hoje:** quando o HTTP do `creditar-remoto` retorna sucesso. Se falhar no meio, o débito já ocorreu e a operação **não** fica atomicamente concluída (problema deixado pro Sprint 4).

Eventos distribuídos que depois vão virar mensagens: débito na origem, pedido de crédito no destino, confirmação/falha do crédito.

---

## 4. Eventos que precisam ser comunicados

Dois eventos bons pra publicar sem chamada direta:

### Evento A — `transferencia.credito.solicitado`
- **Quando:** depois do débito na agência de origem (transferência remota).
- **Dados:** `idOperacao`, `idOrigem`, `idDestino`, `valor`, `agenciaOrigem`, `agenciaDestino`, `timestampLamport` (hoje) / vetor (depois).
- **Produtor:** agência da conta origem.
- **Consumidor:** agência da conta destino (credita).

### Evento B — `transferencia.credito.aplicado`
- **Quando:** destino creditou com sucesso.
- **Dados:** `idOperacao`, `idDestino`, `valor`, `saldoAtual`, relógio.
- **Produtor:** agência destino.
- **Consumidor:** agência origem (pode marcar a transferência como confirmada) e/ou um serviço de auditoria/linha do tempo.

Outro possível (bônus): `conta.criada` — útil se no futuro um extrato consolidado ou outro serviço quiser saber de contas novas sem consultar cada agência.

Isso já aponta tópicos tipo:
- `iceibank.transferencias.credito`
- `iceibank.transferencias.confirmacao`

---

## 5. Mensageria e comunicação indireta

Proposta de fluxo com Pub/Sub (em vez do `RestTemplate` direto):

1. Cliente chama `POST /transferencias` na agência 0 (igual hoje).
2. Agência 0 debita local e **publica** mensagem no tópico `transferencias.credito`.
3. O **broker** (RabbitMQ, Kafka, etc.) guarda a mensagem.
4. Agência 1, inscrita nesse tópico (filtrando `agenciaDestino=1` ou com fila própria), **consome** a mensagem e credita.
5. Agência 1 publica `transferencias.confirmacao` (ou ack).
6. Agência 0 pode consumir a confirmação pra atualizar status da operação.

Papéis:
- **Produtor:** Agência 0 (origem)
- **Canal/tópico:** `transferencias.credito`
- **Consumidor:** Agência 1 (destino)
- **Conteúdo exemplo:**

```json
{
  "idOperacao": "op-20260914-0001",
  "tipo": "CREDITO_REMOTO",
  "idOrigem": 0,
  "idDestino": 1,
  "valor": 15.0,
  "agenciaOrigem": 0,
  "agenciaDestino": 1,
  "relogio": { "tipo": "vetorial", "vetor": [5, 2, 0] }
}
```

Vantagem: se a agência 1 estiver offline, a mensagem fica no broker e pode ser processada quando ela voltar (desacoplamento temporal). Hoje, com HTTP, a mensagem simplesmente falha.

---

## 6. Entrega, duplicidade e processamento de mensagens

### Cenário de duplicidade
O broker entrega de novo a mensagem de crédito (retry, redelivery). Se a agência 1 creditar as duas vezes, o Bruno ganha 30 em vez de 15.

### Cenário de falha / reprocessamento
Agência 1 credita, grava no saldo, mas cai **antes** de confirmar o ack. O broker reenvia. Sem cuidado, credita de novo.

### Fora de ordem
Pode chegar confirmação antes de outro evento relacionado, ou dois créditos da mesma conta em ordem trocada, atrapalhando auditoria e regras que dependem de sequência.

Informações necessárias pra processar com segurança:
- **`idOperacao` único** (idempotência: se já processei esse id, ignoro)
- `idOrigem`, `idDestino`, `valor`
- `agenciaOrigem` / `agenciaDestino`
- timestamp lógico (Lamport hoje / vetorial depois)
- talvez `tentativa` ou `versão`

No sistema atual isso quase não existe: cada HTTP é “uma vez”, e na falha conhecida nem compensamos. Na mensageria, idempotência vira obrigatória.

---

## 7. Eventos concorrentes e ordenação causal

Cenário:
- Agência 0 faz depósito na conta 0 (evento local A).
- Ao mesmo tempo, Agência 1 cria a conta 1 (evento local B).
- Depois a Agência 0 manda transferência pra conta 1; o crédito remoto C na Agência 1 **depende** da mensagem vinda de 0.

Se olharmos só a **ordem de recebimento/processamento** dos logs mesclados ou a ordem das mensagens no broker, B pode aparecer “depois” de C na visualização de alguém, ou dois observadores verem ordens diferentes.

Com Lamport (Sprint 1) já vimos: timestamps iguais ou `ts(A) < ts(B)` **não** provam causalidade completa. Dois eventos em agências diferentes podem ser **concorrentes** (nenhum causou o outro).

Consequência pro banco:
- a linha do tempo “global” pode sugerir uma ordem que não é causal
- auditoria pode interpretar errado “o que aconteceu antes”
- regras futuras (limites diários, fraude, extrato consolidado) precisam saber se um evento realmente influenciou o outro

Por isso precisa distinguir:
- ordem **local** (dentro de uma agência)
- ordem de **recebimento** da mensagem
- relação **causal** (A → B de verdade)

---

## 8. Relógio vetorial na aplicação

Cada agência é um processo do vetor de tamanho 3:

```
V = [v0, v1, v2]
```
onde `vi` é o contador da agência i.

Regras (resumo):
- **Evento local** na agência i: `V[i] = V[i] + 1`
- **Ao enviar** mensagem: incrementa `V[i]` e anexa o vetor na mensagem
- **Ao receber** mensagem com vetor `Vm`:  
  `V[j] = max(V[j], Vm[j])` pra todo j, depois `V[i] = V[i] + 1`

Comparação:
- A **aconteceu antes** de B se `VA ≤ VB` em todas as posições e `<` em pelo menos uma
- A e B são **concorrentes** se nenhum `≤` o outro

### Exemplo causalmente relacionados
1. Agência 0 debita (local): `V0 = [1,0,0]`
2. Envia mensagem de crédito com `[1,0,0]` (depois do incremento de envio, ex. `[2,0,0]`)
3. Agência 1 recebe e credita: atualiza com o vetor recebido → ex. `V1 = [2,1,0]`

Aqui o crédito na 1 **foi causado** pelo débito/envio na 0: vetores mostram precedência.

### Exemplo concorrentes
- Agência 0 cria conta 0 → `[1,0,0]`
- Agência 1 cria conta 1 → `[0,1,0]`  
Nenhum vetor domina o outro → concorrentes (igual à ideia dos empates de Lamport que já observamos na linha do tempo).

No código atual o `RelogioLamport` seria evoluído (ou trocado) por um `RelogioVetorial` com array de 3 inteiros, serializado no JSON das mensagens e nos eventos do `.jsonl`.

---

## 9. Consistência e observabilidade dos eventos

Pra verificar ordem/causalidade na aplicação, cada evento/mensagem deveria registrar no mínimo:

- `agencia` (quem gerou)
- `tipo` (DEBITO, CREDITO_REMOTO, etc.)
- `idOperacao`
- `vetor` completo `[v0,v1,v2]`
- `horaParede` (só auxiliar, como hoje)
- referência ao `idOperacao` pai / mensagem que causou (opcional)

Com isso dá pra:
- comparar dois logs e dizer se A → B ou se são concorrentes
- ver se a agência 1 “já viu” o que a 0 enviou (posição do vetor)
- montar uma linha do tempo causal (melhor que só ordenar por Lamport escalar)

Ferramentas práticas:
- continuar gravando `.jsonl` por agência
- evoluir o `MesclarLogs` pra ler o vetor e classificar pares (antes / depois / concorrente)
- evidências: print de dois eventos concorrentes e dois causais

---

## 10. Proposta de evolução para a próxima implementação

### O que muda
A transferência **entre agências** deixa de usar `RestTemplate`/`creditar-remoto` HTTP direto e passa a usar **mensageria Pub/Sub** + **relógio vetorial**.

### Componentes
- 3 agências (iguais)
- 1 broker (ex.: RabbitMQ ou Kafka)
- Frontend (quase igual; só a API de transferência muda por baixo)
- Logs `.jsonl` com vetor
- Script/utilitário de análise causal (evolução do `MesclarLogs`)

### Mensagens
1. Origem publica em `transferencias.credito` após debitar  
2. Destino consome, credita (idempotente por `idOperacao`), publica `transferencias.confirmacao`  
3. (Opcional) origem marca status `CONFIRMADA` / timeout `PENDENTE`

### Metadados novos
- `idOperacao`
- `vetor` relógio vetorial
- `agenciaOrigem` / `agenciaDestino`
- tipo do evento

### Como demonstrar que funciona
1. Subir broker + 3 agências.
2. Transferir 0 → 1 com destino **ligado** → saldo ok + mensagens nos logs.
3. Transferir com destino **desligado** → mensagem fica na fila; ao religar a agência 1, o crédito aplica (diferença clara vs 502 atual).
4. Forçar reenvio da mesma `idOperacao` → saldo **não** duplica (idempotência).
5. Gerar dois eventos concorrentes e dois causais; mostrar no utilitário de logs a classificação pelo vetor.

Isso resolve o acoplamento da comunicação direta e prepara melhor observabilidade causal; a atomicidade total (não “sumir” dinheiro em falhas mais complexas) continua sendo tema de transação distribuída (2PC/Saga) numa etapa posterior.

---

## Observação final

Tudo acima parte do sistema já entregue no Sprint 1:
- partição `% 3`
- Lamport + `.jsonl`
- transferência local vs remota
- falha conhecida 502 sem estorno
- JWT e frontend

A próxima implementação deve **substituir a chamada direta agência→agência** por mensagens e **trocar/complementar Lamport por vetorial**, sem jogar fora a API de contas nem o frontend.
