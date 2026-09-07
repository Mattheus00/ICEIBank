# Sprint 1 — ICEIBank: API REST/MVC + Relógio de Lamport

## Índice

1. [Visão geral do projeto: ICEIBank](#1-visão-geral-do-projeto-iceibank)
2. [Escopo do Sprint 1](#2-escopo-do-sprint-1)
3. [Cronograma sugerido](#3-cronograma-sugerido)
4. [Preparação do ambiente](#4-preparação-do-ambiente)
5. [Parte A — Modelagem e partição](#5-parte-a--modelagem-e-partição)
6. [Parte B — Relógio de Lamport e registro de eventos](#6-parte-b--relógio-de-lamport-e-registro-de-eventos)
7. [Parte C — API REST de contas (MVC)](#7-parte-c--api-rest-de-contas-mvc)
8. [Parte D — Transferências locais e entre agências](#8-parte-d--transferências-locais-e-entre-agências)
9. [Adaptando o backend para Java ou Python](#9-adaptando-o-backend-para-java-ou-python)
10. [Parte E — Linha do tempo unificada](#10-parte-e--linha-do-tempo-unificada)
11. [Parte F — Autenticação com JWT](#11-parte-f--autenticação-com-jwt)
12. [Parte G — Frontend web](#12-parte-g--frontend-web)
13. [Checklist de entrega](#13-checklist-de-entrega)
14. [Critérios de avaliação](#14-critérios-de-avaliação)

---

## 1. Visão geral do projeto: ICEIBank

Este é o primeiro de 4 sprints de um único projeto que evolui ao longo do semestre. O **ICEIBank** é um banco simplificado particionado em agências: cada agência é um processo/serviço independente que guarda apenas as contas sob sua responsabilidade. Ao longo das unidades, o mesmo sistema ganha novas camadas de distribuição, sincronização e consistência.

| Sprint | Unidade | Foco técnico | O que o ICEIBank ganha |
| --- | --- | --- | --- |
| **1** (este) | U2 — REST/MVC + Lamport | API REST, MVC, relógio lógico de Lamport | 3 agências HTTP, contas/transferências, linha do tempo lógica, JWT, frontend |
| **2** | U3 — Mensageria + relógio vetorial | Filas/tópicos e relógios vetoriais | Detecção precisa de concorrência entre eventos |
| **3** | U4 — Flutter + consenso | Cliente móvel e algoritmos de consenso | App e coordenação entre réplicas/agências |
| **4** | U5 — Containers + 2PC/Saga | Empacotamento e transações distribuídas | Correção da falha conhecida deste sprint (atomicidade) |

O código que você entregar no Sprint 1 **não será descartado**: ele é a base dos sprints seguintes. Por isso, organize bem o repositório, use commits claros e documente decisões em `RESPOSTAS.md`.

### 1.1 Por que um banco?

Um banco particionado em agências é um cenário didático clássico de sistemas distribuídos:

- há **estado particionado** (cada agência só conhece “suas” contas);
- há **mensagens** entre processos (transferência entre agências);
- há necessidade de **ordenar eventos** sem um relógio global perfeito (Lamport);
- há uma **falha de consistência** fácil de provocar (débito local sem crédito remoto) — que será resolvida no Sprint 4 com 2PC ou Saga;
- o domínio é intuitivo (saldo, depósito, saque, transferência), o que permite focar nos conceitos de distribuição.

---

## 2. Escopo do Sprint 1

Neste sprint você deve entregar:

1. **Três agências** como serviços HTTP independentes (mesmo código, três processos), cada uma responsável por um subconjunto das contas.
2. **API REST** no estilo MVC para criar conta, consultar saldo, depositar, sacar e transferir.
3. **Relógio de Lamport** por agência, com registro persistente de eventos em arquivo `.jsonl`.
4. **Transferências** locais (mesma agência) e remotas (entre agências), anexando/atualizando o timestamp de Lamport.
5. **Limitação conhecida (obrigatória):** se a agência de destino estiver fora do ar no crédito remoto, o débito na origem **não** é revertido. O sistema registra a falha e responde com erro. A correção fica para o Sprint 4 (2PC/Saga).
6. **Parte F — JWT:** autenticação por token nas rotas de uso do frontend.
7. **Parte G — Frontend web:** interface para login e operações básicas.
8. **Funcionalidade adicional obrigatória** (seção 2.1), em commit separado.
9. **Respostas** às questões de cada parte em `RESPOSTAS.md`.
10. **Evidências** (prints) em `evidencias/sprint1/`.

### 2.1 Funcionalidade adicional (obrigatória)

Além do escopo mínimo, implemente **uma** funcionalidade extra de sua escolha, relacionada ao domínio do banco ou à observabilidade do sistema distribuído. Exemplos aceitos:

- **Histórico de transações por conta** — endpoint que lista eventos do `.jsonl` relacionados a uma conta;
- **Limite de saque/transferência** — regra de negócio com valor máximo por operação;
- **Extrato consolidado** — consulta que soma saldos do mesmo aluno em várias agências;
- **Idempotência de transferências** — chave de idempotência para evitar crédito duplicado em retentativas;
- **Health-check enriquecido** — endpoint com contador de Lamport atual e quantidade de contas na agência.

A funcionalidade adicional deve:

- estar documentada em `RESPOSTAS.md` (o que foi feito e por quê);
- ter ao menos uma evidência `evidencias/sprint1/funcionalidade-adicional.png`;
- ser entregue em **commit separado**, por exemplo:

```powershell
git add .
git commit -m "feat(extra): historico de transacoes por conta"
```

(ajuste a mensagem ao que você implementou)

### 2.2 Escolha de linguagem

Os trechos de código de referência deste roteiro estão em **Node.js (Express)** apenas para deixar o fluxo didático legível e uniforme. **A entrega do Sprint 1 não pode ser em Node.js.**

Escolha **uma** stack e use-a do Sprint 1 ao Sprint 4:

- **Java + Spring Boot**, ou
- **Python + FastAPI** (ou Flask).

A seção [9](#9-adaptando-o-backend-para-java-ou-python) traz as adaptações oficiais do relógio de Lamport e do registro de eventos para Java e Python. O restante da API (controllers, rotas, JWT, frontend) deve ser implementado por você na linguagem escolhida, preservando o comportamento descrito nas Partes A–G.

---

## 3. Cronograma sugerido

| Dia | Atividade |
| --- | --- |
| 1 | Preparação do ambiente, estrutura do repositório, Parte A (config/partição) |
| 2 | Parte B (Lamport + log) e Parte C (API de contas); subir 3 agências |
| 3 | Parte D (transferências + falha conhecida) e evidências |
| 4 | Parte E (mesclar logs) + início da Parte F (JWT) |
| 5 | Concluir JWT, funcionalidade adicional, Parte G (frontend) |
| 6 | Polir `README.md` / `RESPOSTAS.md`, checklist, vídeo curto de apresentação |

Adapte o ritmo à sua agenda; o importante é não deixar transferências, JWT e frontend para a última hora.

---

## 4. Preparação do ambiente

Este roteiro assume **Windows**, com **PowerShell** como terminal padrão.

Instale e confira:

- **Git for Windows** (`git --version`)
- Editor de preferência (VS Code, IntelliJ, PyCharm etc.)
- Para a **stack escolhida**:
  - Java: JDK 17+ e Maven 3.8+ (`java -version`, `mvn -version`), **ou**
  - Python: 3.10+ com pip (`python --version`)
- **Node.js LTS** (opcional): útil apenas se você quiser reproduzir a estrutura de referência deste roteiro antes de portar. A entrega final **não** pode ser Node.js.

> **Firewall do Windows:** na primeira execução de cada agência, o Windows Defender Firewall pode pedir permissão de rede — clique em **Permitir acesso**.

### 4.1 Estrutura do repositório

Crie a estrutura abaixo (os nomes de pastas em português/inglês podem variar na sua stack, mas mantenha a organização lógica):

```text
iceibank/
├── agencia/                    # serviço da agência (mesmo código, 3 instâncias)
│   ├── config.js               # (referência Node — adapte para Java/Python)
│   ├── lamportClock.js
│   ├── eventLog.js
│   ├── controllers/
│   │   ├── contasController.js
│   │   └── transferenciasController.js
│   ├── routes.js
│   ├── app.js
│   ├── package.json
│   └── data/                   # eventos-agencia-*.jsonl (runtime; no .gitignore)
├── scripts/
│   └── mesclar-logs.js
├── frontend/                   # Parte G
├── evidencias/
│   └── sprint1/
├── RESPOSTAS.md
├── README.md
└── .gitignore
```

Comandos sugeridos no PowerShell (a partir da pasta do projeto):

```powershell
New-Item -ItemType Directory -Force -Path agencia/controllers, agencia/data, scripts, frontend, evidencias/sprint1 | Out-Null
New-Item -ItemType File -Force -Path README.md, RESPOSTAS.md, .gitignore, evidencias/sprint1/.gitkeep | Out-Null
```

Conteúdo mínimo sugerido para `.gitignore`:

```gitignore
node_modules/
agencia/data/*.jsonl
.env
*.local
target/
__pycache__/
.venv/
.idea/
.vscode/
Thumbs.db
.DS_Store
```

Primeiro commit:

```powershell
git add README.md RESPOSTAS.md .gitignore evidencias/sprint1/.gitkeep
git commit -m "chore: estrutura inicial do repositorio"
```

Todas as respostas às questões devem ir em `RESPOSTAS.md`, organizadas por parte (B, D, E, F, G e funcionalidade adicional).

### 4.2 Evidências de teste

Capture prints de execução real (não só código). Sempre que possível, deixe visível no print a saída de `Get-Date` em algum terminal, para comprovar execução recente.

Nomes esperados (mínimo):

| Evidência | Arquivo |
| --- | --- |
| Transferência na mesma agência | `evidencias/sprint1/transferencia-local.png` |
| Transferência entre agências | `evidencias/sprint1/transferencia-entre-agencias.png` |
| Falha conhecida (destino offline) | `evidencias/sprint1/falha-conhecida.png` |
| Linha do tempo unificada | `evidencias/sprint1/linha-do-tempo.png` |
| API sem token | `evidencias/sprint1/auth-sem-token.png` |
| API com token válido | `evidencias/sprint1/auth-com-token.png` |
| Token expirado / inválido | `evidencias/sprint1/auth-token-expirado.png` |
| Frontend — login | `evidencias/sprint1/frontend-login.png` |
| Frontend — transferência | `evidencias/sprint1/frontend-transferencia.png` |
| Frontend — erro visível | `evidencias/sprint1/frontend-erro.png` |
| Funcionalidade adicional | `evidencias/sprint1/funcionalidade-adicional.png` |

### 4.3 Portas exclusivas (OFFSET)

No laboratório, várias máquinas/alunos podem colidir em `localhost:4000`. Defina um `OFFSET` com os **dois últimos dígitos do seu RA** (ou outro valor combinado com o professor) e derive as portas:

- Agência 0 → `4000 + OFFSET`
- Agência 1 → `4001 + OFFSET`
- Agência 2 → `4002 + OFFSET`

Se estiver sozinho na máquina, pode usar `OFFSET = 0` (portas `4000`, `4001`, `4002`). Documente o valor escolhido no `README.md`.

### 4.4 Disciplina de commits

Use commits pequenos e descritivos, no estilo Conventional Commits quando possível (`feat:`, `fix:`, `chore:`, `docs:`). Cada parte deste roteiro indica um commit sugerido. **Não** entregue um único commit gigante no final.

---

## 5. Parte A — Modelagem e partição

### 5.1 Ideia

Há **3 agências** e um conjunto de contas identificadas por inteiros. A conta `id` pertence à agência:

```text
agenciaResponsavel(id) = id % 3
```

Exemplos: conta `0` → agência 0; conta `1` → agência 1; conta `2` → agência 2; conta `3` → agência 0; etc.

### 5.2 Código de referência (`agencia/config.js`)

```javascript
// agencia/config.js
// OFFSET: use os dois últimos dígitos do RA se necessário no laboratório
const OFFSET = 0;
const NUMERO_AGENCIAS = 3;
const PORTA_BASE = 4000 + OFFSET;

const AGENCIAS = [
  { id: 0, url: `http://localhost:${PORTA_BASE}` },
  { id: 1, url: `http://localhost:${PORTA_BASE + 1}` },
  { id: 2, url: `http://localhost:${PORTA_BASE + 2}` },
];

function agenciaResponsavel(idConta) {
  return ((idConta % NUMERO_AGENCIAS) + NUMERO_AGENCIAS) % NUMERO_AGENCIAS;
}

module.exports = {
  OFFSET,
  NUMERO_AGENCIAS,
  PORTA_BASE,
  AGENCIAS,
  agenciaResponsavel,
};
```

### 5.3 Tarefas

1. Crie o módulo de configuração equivalente na sua linguagem.
2. Confirme mentalmente (e no `README`) quais contas cada agência aceita.
3. Faça o commit:

```powershell
git add agencia
git commit -m "feat(config): define particionamento de contas entre 3 agencias"
```

---

## 6. Parte B — Relógio de Lamport e registro de eventos

### 6.1 Regras do relógio de Lamport (por processo)

1. **Evento local:** `contador = contador + 1`
2. **Ao enviar mensagem:** `contador = contador + 1` e anexar esse valor à mensagem
3. **Ao receber mensagem** com timestamp `T`: `contador = max(contador, T) + 1`

### 6.2 Código de referência — `lamportClock.js`

```javascript
// agencia/lamportClock.js
class LamportClock {
  constructor() {
    this.contador = 0;
  }

  eventoLocal() {
    this.contador += 1;
    return this.contador;
  }

  aoEnviar() {
    this.contador += 1;
    return this.contador;
  }

  aoReceber(timestampRecebido) {
    this.contador = Math.max(this.contador, timestampRecebido) + 1;
    return this.contador;
  }

  getContador() {
    return this.contador;
  }
}

module.exports = { LamportClock };
```

### 6.3 Código de referência — `eventLog.js`

Cada agência grava um arquivo JSON Lines (`*.jsonl`): uma linha JSON por evento.

```javascript
// agencia/eventLog.js
const fs = require("fs");
const path = require("path");

class EventLog {
  constructor(nomeAgencia) {
    this.nomeAgencia = nomeAgencia;
    this.pastaDados = path.join(__dirname, "data");
    fs.mkdirSync(this.pastaDados, { recursive: true });
    this.caminhoArquivo = path.join(
      this.pastaDados,
      `eventos-${nomeAgencia}.jsonl`
    );
  }

  registrar(tipo, timestampLamport, detalhes = {}) {
    const evento = {
      agencia: this.nomeAgencia,
      tipo,
      timestampLamport,
      horaParede: new Date().toISOString(),
      detalhes,
    };
    fs.appendFileSync(this.caminhoArquivo, JSON.stringify(evento) + "\n", "utf8");
    console.log(`[Lamport ${timestampLamport}] ${tipo}`, detalhes);
    return evento;
  }

  lerTodos() {
    if (!fs.existsSync(this.caminhoArquivo)) return [];
    const linhas = fs.readFileSync(this.caminhoArquivo, "utf8").split(/\r?\n/);
    return linhas
      .filter((l) => l.trim().length > 0)
      .map((l) => JSON.parse(l));
  }
}

module.exports = { EventLog };
```

### 6.4 Questões (responda em `RESPOSTAS.md`)

1. Por que, ao receber, usamos `max(contador_local, timestampRecebido) + 1` e não apenas `timestampRecebido + 1` nem só o valor recebido?
2. Se a agência 0 está com contador `10` e recebe uma mensagem com timestamp `3`, qual será o novo valor do contador? O que isso revela sobre agências “mais rápidas” e “mais lentas”?

### 6.5 Commit

```powershell
git add agencia RESPOSTAS.md
git commit -m "feat(lamport): implementa relogio logico e registro de eventos"
```

---

## 7. Parte C — API REST de contas (MVC)

### 7.1 Endpoints mínimos

| Método | Rota | Descrição |
| --- | --- | --- |
| `POST` | `/contas` | Cria conta `{ id, nomeAluno, saldoInicial? }` — só se `id % 3` for esta agência |
| `GET` | `/contas/:id` | Consulta saldo |
| `POST` | `/contas/:id/depositar` | Corpo `{ valor }` |
| `POST` | `/contas/:id/sacar` | Corpo `{ valor }` |

Cada operação de escrita deve avançar o relógio (`eventoLocal`) e registrar o evento no log.

### 7.2 Código de referência — `package.json`

```json
{
  "name": "iceibank-agencia",
  "version": "1.0.0",
  "private": true,
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "axios": "^1.7.7"
  }
}
```

### 7.3 Código de referência — `contasController.js`

```javascript
// agencia/controllers/contasController.js
function criarContasController({ idAgencia, contas, relogio, registro, agenciaResponsavel }) {
  function criarConta(req, res) {
    const id = Number(req.body.id);
    const nomeAluno = req.body.nomeAluno;
    const saldoInicial = Number(req.body.saldoInicial ?? 0);

    if (agenciaResponsavel(id) !== idAgencia) {
      return res.status(400).json({
        erro: `Conta ${id} não pertence a esta agência.`,
      });
    }
    if (contas.has(id)) {
      return res.status(409).json({ erro: "Conta já existe." });
    }

    const ts = relogio.eventoLocal();
    const conta = { id, nomeAluno, saldo: saldoInicial };
    contas.set(id, conta);
    registro.registrar("CRIAR_CONTA", ts, { id, nomeAluno, saldoInicial });
    return res.status(201).json(conta);
  }

  function consultarSaldo(req, res) {
    const id = Number(req.params.id);
    const conta = contas.get(id);
    if (!conta) {
      return res.status(404).json({ erro: "Conta não encontrada nesta agência." });
    }
    return res.json(conta);
  }

  function depositar(req, res) {
    const id = Number(req.params.id);
    const valor = Number(req.body.valor);
    const conta = contas.get(id);
    if (!conta) {
      return res.status(404).json({ erro: "Conta não encontrada nesta agência." });
    }
    const ts = relogio.eventoLocal();
    conta.saldo += valor;
    registro.registrar("DEPOSITO", ts, { id, valor, novoSaldo: conta.saldo });
    return res.json(conta);
  }

  function sacar(req, res) {
    const id = Number(req.params.id);
    const valor = Number(req.body.valor);
    const conta = contas.get(id);
    if (!conta) {
      return res.status(404).json({ erro: "Conta não encontrada nesta agência." });
    }
    if (conta.saldo < valor) {
      return res.status(400).json({ erro: "Saldo insuficiente." });
    }
    const ts = relogio.eventoLocal();
    conta.saldo -= valor;
    registro.registrar("SAQUE", ts, { id, valor, novoSaldo: conta.saldo });
    return res.json(conta);
  }

  return { criarConta, consultarSaldo, depositar, sacar };
}

module.exports = { criarContasController };
```

### 7.4 Código de referência — `routes.js`

```javascript
// agencia/routes.js
const express = require("express");

function montarRotas({ contasController, transferenciasController }) {
  const router = express.Router();

  router.post("/contas", (req, res) => contasController.criarConta(req, res));
  router.get("/contas/:id", (req, res) => contasController.consultarSaldo(req, res));
  router.post("/contas/:id/depositar", (req, res) => contasController.depositar(req, res));
  router.post("/contas/:id/sacar", (req, res) => contasController.sacar(req, res));

  // Parte D
  router.post("/transferencias", (req, res) =>
    transferenciasController.transferir(req, res)
  );
  router.post("/contas/:id/creditar-remoto", (req, res) =>
    transferenciasController.creditarRemoto(req, res)
  );

  return router;
}

module.exports = { montarRotas };
```

### 7.5 Código de referência — `app.js`

```javascript
// agencia/app.js
const express = require("express");
const { AGENCIAS, PORTA_BASE, agenciaResponsavel } = require("./config");
const { LamportClock } = require("./lamportClock");
const { EventLog } = require("./eventLog");
const { criarContasController } = require("./controllers/contasController");
const { criarTransferenciasController } = require("./controllers/transferenciasController");
const { montarRotas } = require("./routes");

const idAgencia = Number(process.env.AGENCIA_ID || "0");
const meta = AGENCIAS.find((a) => a.id === idAgencia);
if (!meta) {
  console.error("AGENCIA_ID inválido. Use 0, 1 ou 2.");
  process.exit(1);
}

const porta = PORTA_BASE + idAgencia;
const contas = new Map();
const relogio = new LamportClock();
const registro = new EventLog(`agencia-${idAgencia}`);

const contasController = criarContasController({
  idAgencia,
  contas,
  relogio,
  registro,
  agenciaResponsavel,
});

const transferenciasController = criarTransferenciasController({
  idAgencia,
  contas,
  relogio,
  registro,
  agenciaResponsavel,
  AGENCIAS,
});

const app = express();
app.use(express.json());
app.use(montarRotas({ contasController, transferenciasController }));

app.listen(porta, "0.0.0.0", () => {
  console.log(`Agência ${idAgencia} ouvindo em http://localhost:${porta}`);
});
```

### 7.6 Como subir as 3 agências (referência Node)

Em **três terminais** PowerShell, a partir de `agencia/`:

```powershell
npm install

# Terminal 1
$env:AGENCIA_ID="0"; npm start

# Terminal 2
$env:AGENCIA_ID="1"; npm start

# Terminal 3
$env:AGENCIA_ID="2"; npm start
```

Na sua entrega Java/Python, use o equivalente (`mvn spring-boot:run`, `uvicorn`, etc.), sempre com `AGENCIA_ID=0|1|2`.

### 7.7 Exemplos com `Invoke-RestMethod` (OFFSET = 0)

```powershell
# Criar conta 0 na agência 0
Invoke-RestMethod -Method POST -Uri http://localhost:4000/contas `
  -ContentType "application/json" `
  -Body '{"id":0,"nomeAluno":"Ana","saldoInicial":100}'

# Criar conta 1 na agência 1
Invoke-RestMethod -Method POST -Uri http://localhost:4001/contas `
  -ContentType "application/json" `
  -Body '{"id":1,"nomeAluno":"Bruno","saldoInicial":50}'

# Depositar na conta 0
Invoke-RestMethod -Method POST -Uri http://localhost:4000/contas/0/depositar `
  -ContentType "application/json" `
  -Body '{"valor":25}'

# Consultar saldo
Invoke-RestMethod -Method GET -Uri http://localhost:4000/contas/0
```

### 7.8 Commit

```powershell
git add agencia
git commit -m "feat(contas): implementa API REST/MVC de contas com relogio de Lamport"
```

---

## 8. Parte D — Transferências locais e entre agências

### 8.1 Comportamento esperado

`POST /transferencias` com corpo:

```json
{ "idOrigem": 0, "idDestino": 1, "valor": 10 }
```

Fluxo:

1. Validar conta de origem nesta agência e saldo.
2. Debitar origem com `eventoLocal` e registrar `TRANSFERENCIA_DEBITO`.
3. Se destino for **da mesma agência**: creditar localmente com outro `eventoLocal` (`TRANSFERENCIA_CREDITO`).
4. Se destino for **outra agência**:
   - chamar `aoEnviar()` e obter `timestampLamport`;
   - `POST` para `{urlDestino}/contas/{idDestino}/creditar-remoto` com `{ valor, timestampLamport, origemAgencia }`;
   - no destino, `aoReceber(timestampLamport)` antes de creditar e registrar `TRANSFERENCIA_CREDITO_REMOTO`.
5. **Falha conhecida:** se a chamada remota falhar (destino offline, timeout etc.), **não reverter** o débito; registrar `TRANSFERENCIA_FALHOU` e responder **502** explicando a inconsistência temporária (a corrigir no Sprint 4 com 2PC/Saga).

### 8.2 Código de referência — `transferenciasController.js` (completo)

```javascript
// agencia/controllers/transferenciasController.js
const axios = require("axios");

function criarTransferenciasController({
  idAgencia,
  contas,
  relogio,
  registro,
  agenciaResponsavel,
  AGENCIAS,
}) {
  async function transferir(req, res) {
    const idOrigem = Number(req.body.idOrigem);
    const idDestino = Number(req.body.idDestino);
    const valor = Number(req.body.valor);

    const contaOrigem = contas.get(idOrigem);
    if (!contaOrigem) {
      return res.status(404).json({ erro: "Conta de origem não encontrada nesta agência." });
    }
    if (contaOrigem.saldo < valor) {
      return res.status(400).json({ erro: "Saldo insuficiente." });
    }

    const agenciaDestino = agenciaResponsavel(idDestino);

    const tsDebito = relogio.eventoLocal();
    contaOrigem.saldo -= valor;
    registro.registrar("TRANSFERENCIA_DEBITO", tsDebito, {
      idOrigem,
      idDestino,
      valor,
    });

    // Mesma agência
    if (agenciaDestino === idAgencia) {
      const contaDestino = contas.get(idDestino);
      if (!contaDestino) {
        contaOrigem.saldo += valor; // destino local inexistente: desfaz débito
        return res.status(404).json({ erro: "Conta de destino não encontrada." });
      }
      const tsCredito = relogio.eventoLocal();
      contaDestino.saldo += valor;
      registro.registrar("TRANSFERENCIA_CREDITO", tsCredito, {
        idOrigem,
        idDestino,
        valor,
      });
      return res.json({ mensagem: "Transferência concluída (mesma agência)." });
    }

    // Entre agências
    const tsEnvio = relogio.aoEnviar();
    const metaDestino = AGENCIAS.find((a) => a.id === agenciaDestino);
    const url = `${metaDestino.url}/contas/${idDestino}/creditar-remoto`;

    try {
      await axios.post(url, {
        valor,
        timestampLamport: tsEnvio,
        origemAgencia: idAgencia,
      });
      return res.json({ mensagem: "Transferência concluída (entre agências)." });
    } catch (erro) {
      // LIMITAÇÃO CONHECIDA: débito NÃO é revertido (Sprint 4: 2PC/Saga)
      registro.registrar("TRANSFERENCIA_FALHOU", relogio.eventoLocal(), {
        idOrigem,
        idDestino,
        valor,
        erro: String(erro.message || erro),
      });
      return res.status(502).json({
        erro:
          "Falha ao contatar agência de destino. Débito já aplicado - inconsistência conhecida (ver Sprint 4).",
      });
    }
  }

  function creditarRemoto(req, res) {
    const id = Number(req.params.id);
    const valor = Number(req.body.valor);
    const timestampLamport = Number(req.body.timestampLamport);
    const origemAgencia = Number(req.body.origemAgencia);

    const ts = relogio.aoReceber(timestampLamport);
    const conta = contas.get(id);
    if (!conta) {
      return res.status(404).json({ erro: "Conta não encontrada nesta agência." });
    }

    conta.saldo += valor;
    registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", ts, {
      idConta: id,
      valor,
      origemAgencia,
    });

    return res.json({
      mensagem: "Crédito remoto aplicado.",
      saldoAtual: conta.saldo,
    });
  }

  return { transferir, creditarRemoto };
}

module.exports = { criarTransferenciasController };
```

### 8.3 Questões (responda em `RESPOSTAS.md`)

1. Por que a transferência **local** (mesma agência) não precisa chamar `aoEnviar` / `aoReceber`?
2. Após provocar a falha conhecida (destino offline), o saldo de origem foi revertido? O sistema garante atomicidade entre agências neste sprint?
3. Cite, em alto nível, **duas** formas de corrigir isso no Sprint 4 (ex.: 2PC e Saga).

### 8.4 Tarefas e evidências

1. Implemente transferências locais e remotas na sua stack.
2. Teste transferência local (ex.: `0 → 3` na agência 0) e salve `transferencia-local.png`.
3. Teste transferência entre agências (ex.: `0 → 1`) e salve `transferencia-entre-agencias.png`.
4. Pare a agência de destino e repita a transferência remota; salve `falha-conhecida.png` mostrando o 502 e o saldo debitado sem crédito remoto.
5. Commit:

```powershell
git add agencia evidencias/sprint1 RESPOSTAS.md
git commit -m "feat(transferencias): implementa transferencia local e entre agencias"
```

---

## 9. Adaptando o backend para Java ou Python

Lembrete: a entrega **não pode ser Node.js**. Use os trechos abaixo como base oficial do relógio e do log; o restante (REST, JWT, frontend) fica a seu cargo.

### 9.1 Java — `RelogioLamport`

```java
package com.iceibank.agencia.clock;

/**
 * Relógio lógico de Lamport (contador por processo).
 * synchronized: servidores HTTP atendem requisições em threads concorrentes.
 */
public class RelogioLamport {

    private int contador = 0;

    public synchronized int eventoLocal() {
        contador += 1;
        return contador;
    }

    public synchronized int aoEnviar() {
        contador += 1;
        return contador;
    }

    public synchronized int aoReceber(int timestampRecebido) {
        contador = Math.max(contador, timestampRecebido) + 1;
        return contador;
    }

    public synchronized int getContador() {
        return contador;
    }
}
```

### 9.2 Java — `RegistroEventos`

```java
package com.iceibank.agencia.log;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class RegistroEventos {

    private final String nomeAgencia;
    private final Path caminhoArquivo;
    private final ObjectMapper mapper = new ObjectMapper();

    public RegistroEventos(String nomeAgencia) throws IOException {
        this.nomeAgencia = nomeAgencia;
        Path pastaDados = Paths.get("data");
        Files.createDirectories(pastaDados);
        this.caminhoArquivo = pastaDados.resolve("eventos-" + nomeAgencia + ".jsonl");
    }

    public synchronized Map<String, Object> registrar(
            String tipo,
            int timestampLamport,
            Map<String, Object> detalhes
    ) throws IOException {
        Map<String, Object> evento = new LinkedHashMap<>();
        evento.put("agencia", nomeAgencia);
        evento.put("tipo", tipo);
        evento.put("timestampLamport", timestampLamport);
        evento.put("horaParede", Instant.now().toString());
        evento.put("detalhes", detalhes);

        String linha = mapper.writeValueAsString(evento);
        Files.writeString(
                caminhoArquivo,
                linha + System.lineSeparator(),
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
        );
        System.out.println("[Lamport " + timestampLamport + "] " + tipo + " " + detalhes);
        return evento;
    }

    public synchronized List<Map<String, Object>> lerTodos() throws IOException {
        List<Map<String, Object>> eventos = new ArrayList<>();
        if (!Files.exists(caminhoArquivo)) {
            return eventos;
        }
        List<String> linhas = Files.readAllLines(caminhoArquivo, StandardCharsets.UTF_8);
        for (String linha : linhas) {
            if (linha == null || linha.isBlank()) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> evento = mapper.readValue(linha, Map.class);
            eventos.add(evento);
        }
        return eventos;
    }
}
```

### 9.3 Python — `RelogioLamport`

```python
# relogio_lamport.py
import threading


class RelogioLamport:
    """Relógio lógico de Lamport (contador por processo)."""

    def __init__(self) -> None:
        self._contador = 0
        self._lock = threading.Lock()

    def evento_local(self) -> int:
        with self._lock:
            self._contador += 1
            return self._contador

    def ao_enviar(self) -> int:
        with self._lock:
            self._contador += 1
            return self._contador

    def ao_receber(self, timestamp_recebido: int) -> int:
        with self._lock:
            self._contador = max(self._contador, timestamp_recebido) + 1
            return self._contador

    def get_contador(self) -> int:
        with self._lock:
            return self._contador
```

### 9.4 Python — `RegistroEventos`

```python
# registro_eventos.py
from __future__ import annotations

import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class RegistroEventos:
    def __init__(self, nome_agencia: str, pasta_dados: str | Path = "data") -> None:
        self.nome_agencia = nome_agencia
        self._lock = threading.Lock()
        self.pasta_dados = Path(pasta_dados)
        self.pasta_dados.mkdir(parents=True, exist_ok=True)
        self.caminho_arquivo = self.pasta_dados / f"eventos-{nome_agencia}.jsonl"

    def registrar(
        self,
        tipo: str,
        timestamp_lamport: int,
        detalhes: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        evento = {
            "agencia": self.nome_agencia,
            "tipo": tipo,
            "timestampLamport": timestamp_lamport,
            "horaParede": datetime.now(timezone.utc).isoformat(),
            "detalhes": detalhes or {},
        }
        linha = json.dumps(evento, ensure_ascii=False)
        with self._lock:
            with self.caminho_arquivo.open("a", encoding="utf-8") as f:
                f.write(linha + "\n")
        print(f"[Lamport {timestamp_lamport}] {tipo} {detalhes or {}}")
        return evento

    def ler_todos(self) -> list[dict[str, Any]]:
        if not self.caminho_arquivo.exists():
            return []
        eventos: list[dict[str, Any]] = []
        with self._lock:
            for linha in self.caminho_arquivo.read_text(encoding="utf-8").splitlines():
                if linha.strip():
                    eventos.append(json.loads(linha))
        return eventos
```

---

## 10. Parte E — Linha do tempo unificada

### 10.1 Objetivo

Ler os arquivos `.jsonl` de **todas** as agências, mesclar os eventos e ordená-los pelo campo `timestampLamport`, imprimindo uma linha do tempo global aproximada (ordenação total arbitrária em empates).

### 10.2 Código de referência — `scripts/mesclar-logs.js`

```javascript
// scripts/mesclar-logs.js
const fs = require("fs");
const path = require("path");

const pastaDados = path.join(__dirname, "..", "agencia", "data");

if (!fs.existsSync(pastaDados)) {
  console.error("Pasta agencia/data não encontrada. Gere eventos antes.");
  process.exit(1);
}

const arquivos = fs
  .readdirSync(pastaDados)
  .filter((nome) => nome.endsWith(".jsonl"))
  .map((nome) => path.join(pastaDados, nome));

const todosEventos = [];

for (const arquivo of arquivos) {
  const linhas = fs.readFileSync(arquivo, "utf8").split(/\r?\n/);
  for (const linha of linhas) {
    if (!linha.trim()) continue;
    todosEventos.push(JSON.parse(linha));
  }
}

todosEventos.sort((a, b) => a.timestampLamport - b.timestampLamport);

console.log("=== Linha do tempo unificada (ordenada por relógio de Lamport) ===");
for (const evento of todosEventos) {
  console.log(
    `[Lamport ${evento.timestampLamport}] (${evento.horaParede}) ` +
      `${evento.agencia} - ${evento.tipo} ${JSON.stringify(evento.detalhes)}`
  );
}
```

Na entrega Java/Python, implemente um utilitário equivalente (classe `main`, script CLI etc.).

### 10.3 Questões (responda em `RESPOSTAS.md`)

**Observação prática (faça antes de responder):** rode algumas operações concorrentes em agências diferentes e compare a ordem por `timestampLamport` com a ordem por `horaParede`. Eventos com o mesmo timestamp em agências distintas tendem a ser **concorrentes**.

1. Se dois eventos têm timestamps de Lamport diferentes, isso prova que um influenciou causalmente o outro? Explique a implicação (e a não-implicação) da relação *happens-before*.
2. O relógio de Lamport basta para distinguir concorrência com certeza? Por que o Sprint 2 introduz relógio **vetorial**?

### 10.4 Tarefas e commit

1. Implemente o mesclador de logs.
2. Gere evidência `linha-do-tempo.png`.
3. Commit:

```powershell
git add . evidencias/sprint1 RESPOSTAS.md
git commit -m "feat(observabilidade): adiciona script de linha do tempo unificada"
```

---

## 11. Parte F — Autenticação com JWT

Nesta parte **não há código de amostra completo**: você deve pesquisar e aplicar a biblioteca adequada à sua stack (ex.: `jjwt` / Spring Security no Java; `PyJWT` + dependências no FastAPI/Flask).

### 11.1 Requisitos mínimos

1. Endpoint de login, por exemplo `POST /auth/login`, recebendo usuário/senha e devolvendo um **JWT** com expiração (curta, ex.: poucos minutos para facilitar o teste de expiração).
2. Credenciais podem ser **fixas em memória** neste sprint (documente usuário/senha no `README` e em `RESPOSTAS.md`).
3. Rotas de contas e transferências usadas pelo frontend devem exigir header:

   ```http
   Authorization: Bearer <token>
   ```

4. Sem token válido → **401**.
5. Decida e documente como autenticar `POST /contas/{id}/creditar-remoto` (chamada **interna** entre agências). Opções aceitas, desde que justificadas:
   - token de serviço compartilhado (ex.: header `X-Internal-Token`);
   - JWT de serviço distinto do JWT do usuário;
   - outra estratégia equivalente e segura o bastante para o laboratório.
6. Não “protege” só no frontend: a API deve recusar requisições não autenticadas.

### 11.2 Tarefas e evidências

1. Implemente login + middleware/filtro JWT.
2. Evidências: `auth-sem-token.png`, `auth-com-token.png`, `auth-token-expirado.png`.
3. Responda as questões 11.3.
4. Commit:

```powershell
git add . evidencias/sprint1 RESPOSTAS.md
git commit -m "feat(auth): protege a API com autenticacao JWT"
```

### 11.3 Questões (responda em `RESPOSTAS.md`)

1. Qual a diferença entre **autenticação** e **autorização**? Na sua implementação, o que de fato está sendo verificado?
2. Por que um JWT assinado permite validar o token **sem consultar um banco de sessões** a cada request? Que vantagem isso traz com várias instâncias da API?
3. O que acontece (em termos de segurança) se a **chave secreta** de assinatura vazar?

---

## 12. Parte G — Frontend web

### 12.1 Requisitos mínimos

Implemente uma interface web (HTML/CSS/JS puro, React, Vue etc.) capaz de:

1. **Login** (obter JWT e guardá-lo, tipicamente em `localStorage`).
2. Selecionar a **agência de entrada** (URL/porta) ou equivalente.
3. Consultar saldo, depositar, sacar e transferir, enviando `Authorization: Bearer ...`.
4. Exibir **erros** de forma visível (401, saldo insuficiente, falha conhecida 502 etc.).

Não é necessário um design sofisticado; a clareza da demonstração importa mais.

### 12.2 Tarefas e evidências

1. Implemente o frontend em `frontend/`.
2. Evidências: `frontend-login.png`, `frontend-transferencia.png`, `frontend-erro.png`.
3. Responda 12.3.
4. Commit:

```powershell
git add frontend evidencias/sprint1 RESPOSTAS.md
git commit -m "feat(frontend): implementa interface web para o ICEIBank"
```

### 12.3 Questões (responda em `RESPOSTAS.md`)

1. Como o frontend “lembra” o token entre as telas/operações?
2. O que a interface deve fazer se o token expirar no meio do uso?
3. Onde estão Model, View e Controller (ou equivalentes) na sua organização do frontend? A separação precisa ser formal, mas os papéis devem ser reconhecíveis.

---

## 13. Checklist de entrega

Marque mentalmente antes de submeter:

- [ ] Repositório Git com histórico de commits por parte (não um único commit final)
- [ ] Três agências sobem e respondem nas portas documentadas (`OFFSET` no README)
- [ ] Partição `id % 3` respeitada na criação de contas
- [ ] Relógio de Lamport + arquivos `.jsonl` por agência
- [ ] Transferência local e entre agências funcionando
- [ ] Falha conhecida demonstrada (débito sem crédito remoto + registro)
- [ ] Script/utilitário de linha do tempo unificada
- [ ] JWT protegendo rotas do frontend; evidências de auth
- [ ] Frontend utilizável para login e operações básicas
- [ ] Funcionalidade adicional em **commit separado** + evidência
- [ ] `RESPOSTAS.md` completo (partes B, D, E, F, G + extra)
- [ ] `README.md` com como executar (3 agências, frontend, mesclar logs, login)
- [ ] Prints em `evidencias/sprint1/` com os nomes pedidos
- [ ] Vídeo curto de apresentação (se solicitado pelo professor)
- [ ] Entrega **não** é Node.js (Java Spring Boot ou Python FastAPI/Flask)

---

## 14. Critérios de avaliação (20 pontos)

| Critério | Pontos |
| --- | --- |
| Modelagem/partição e API REST de contas (MVC) | 3 |
| Relógio de Lamport + registro de eventos (`.jsonl`) | 3 |
| Transferências locais e entre agências com sincronização Lamport | 3 |
| Demonstração e compreensão da falha conhecida (limitação documentada) | 2 |
| Linha do tempo unificada + respostas conceituais (Lamport vs concorrência) | 2 |
| Autenticação JWT (API + evidências + decisões documentadas) | 2 |
| Frontend web funcional (login + operações + erros) | 2 |
| Funcionalidade adicional (commit separado + evidência + texto) | 1 |
| Qualidade de engenharia: commits, README, estrutura, reproducibilidade | 1 |
| Apresentação / domínio do que foi entregue (vídeo ou demo) | 1 |
| **Total** | **20** |

Boa implementação — e lembre-se: o Sprint 1 é a fundação do ICEIBank até o fim do semestre.
