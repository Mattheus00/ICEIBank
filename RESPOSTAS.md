# RESPOSTAS — ICEIBank Sprint 1

## Funcionalidade adicional

**Histórico de transações por conta** (`GET /contas/{id}/historico`).

Lista os eventos registrados no `.jsonl` da agência cujo `detalhes` referencia a conta informada (criação, depósito, saque, débitos/créditos de transferência, falhas). Escolhida porque torna o relógio de Lamport e o log observáveis por conta, sem depender só do script de linha do tempo global.

---

## Parte B (6.4)

### 1. Por que `max(contador_local, timestampRecebido) + 1` ao receber?

Porque o relógio local pode já estar à frente do remetente. Se apenas adotássemos o timestamp recebido, poderíamos **voltar no tempo** e violar a propriedade de Lamport (eventos futuros ficariam com timestamps menores que eventos locais já ocorridos). O `max` preserva o maior conhecimento causal visto até então; o `+1` marca o evento de recebimento como posterior a ambos.

### 2. Agência 0 no contador 10 recebe timestamp 3 — novo valor?

Novo contador = `max(10, 3) + 1 = 11`. Agências que processam muitos eventos avançam o relógio mais rápido; ao sincronizar, a agência “atrasada” não reduz o relógio da mais rápida — só a mais lenta “pula” para acompanhar quando recebe mensagens.

---

## Parte D (8.3)

### 1. Por que transferência local não usa `aoEnviar`/`aoReceber`?

Na mesma agência não há mensagem entre processos: débito e crédito são eventos **locais** no mesmo relógio. Entre agências há troca de mensagem REST; aí aplicam-se as regras 2 e 3 (anexar timestamp no envio e ajustar no destino).

### 2. Após a falha conhecida, o saldo de origem foi revertido?

Não. O débito permanece e o crédito remoto não ocorre — inconsistência temporária registrada como `TRANSFERENCIA_FALHOU`. Em termos bancários, o sistema **não** garante atomicidade entre agências neste sprint.

### 3. Duas formas de corrigir no Sprint 4 (alto nível)

1. **2PC (Two-Phase Commit):** prepare/commit nas duas agências; se alguma falhar, aborta e reverte.
2. **Saga:** sequência de passos com compensações (ex.: estorno do débito se o crédito remoto falhar).

---

## Parte E (10.3)

### Observação (tarefa passo 3)

Eventos com o mesmo `timestampLamport` em agências diferentes tendem a ser **concorrentes** (sem relação causal). A ordem por `horaParede` pode divergir da ordem por Lamport, pois o relógio físico não define causalidade no algoritmo.

### 1. Timestamps diferentes sem saber se um influenciou o outro

Lamport garante: se A → B causalmente, então `ts(A) < ts(B)`. A volta **não** vale: `ts(A) < ts(B)` **não** implica que A aconteceu antes de B causalmente — podem ser só concorrentes ordenados arbitrariamente pelo contador.

### 2. Lamport basta para distinguir concorrência com certeza?

Não. Timestamps iguais ou apenas a comparação numérica não provam concorrência nem precedência causal completa. Isso motiva o **relógio vetorial** (Sprint 2), que captura o “conhecimento” de cada processo e permite detectar concorrência de forma precisa.

---

## Parte F (11.3) — decisões de design JWT

### Credenciais

Login com usuário/senha em memória (`admin` / `admin123`). Simples para o sprint (sem banco) e suficiente para demonstrar JWT; documentado aqui de propósito.

### `creditar-remoto`

Usa header `X-Internal-Token` com segredo compartilhado entre agências, **não** o JWT do usuário. Motivo: a chamada é agência-a-agência (confiança mútua de rede local do lab); exigir JWT de usuário forçaria propagar credenciais do cliente e acoplaria o token humano ao canal interno. Rotas públicas do frontend continuam exigindo Bearer JWT.

### Perguntas

1. **Autenticação vs autorização:** autenticação = quem é; autorização = o que pode fazer. Nesta implementação verificamos principalmente autenticação (JWT válido). Um usuário autenticado ainda pode operar qualquer conta da agência — autorização por dono da conta **não** está implementada.
2. **JWT sem consultar banco:** a assinatura HMAC com a chave secreta prova integridade/autenticidade do token. Escala melhor que sessões em memória: qualquer instância valida o token sem sticky session nem store compartilhado de sessão.
3. **Se a chave vazar:** um atacante pode forjar tokens válidos e impersonar qualquer usuário até a chave ser rotacionada.

---

## Parte G (12.3)

### 1. Como o frontend “lembra” o token?

Após o login, o JWT é salvo em `localStorage`. Cada chamada à API inclui `Authorization: Bearer <token>` via função auxiliar `apiFetch`.

### 2. Se o token expirar no meio do uso?

A API responde 401; o frontend exibe a mensagem de erro na tela e sugere novo login (limpa o token inválido).

### 3. MVC no frontend

- **Model:** estado em JS (`token`, `agenciaUrl`) e dados JSON da API.
- **View:** HTML (`index.html`) + CSS.
- **Controller:** handlers em `app.js` que ligam eventos da UI às chamadas HTTP. A separação é leve (sem framework), mas os papéis existem de forma reconhecível.
