# ICEIBank — plano da Sprint 3

Planejamento de 13/11/2026, baseado no código local até `85829ee` e no roteiro `Sprint 3.docx`. Este arquivo é um plano: as funcionalidades abaixo ainda não foram implementadas nem demonstradas.

## Objetivo e limites

Entregar eleição de líder com Bully, failover automático, histórico de lideranças e aplicativo Flutter com operações bancárias, painel de liderança e modo offline-first.

A líder é apenas informativa nesta sprint. As contas continuam particionadas por `id % 3`; não encaminhar todas as operações para a líder. Manter JWT, frontend web, RabbitMQ, relógio vetorial e a funcionalidade adicional da Sprint 2. Não antecipar 2PC/Saga, replicação de contas ou infraestrutura da Sprint 4.

O mínimo obrigatório offline cobre depósito e saque. Transferências locais e remotas continuam disponíveis online; transferência offline é uma extensão, não requisito mínimo da Parte F.

## Diagnóstico do projeto

| Área | O que existe | Consequência para a Sprint 3 |
| --- | --- | --- |
| Backend | Java 21, Spring Boot 3.3.5, Maven | Adaptar os exemplos Node do roteiro para Java; não trocar o backend |
| Agências | IDs 0, 1 e 2; portas 4000–4002; OFFSET efetivo em `ConfigAgencias` | Reutilizar a descoberta estática de pares |
| Contas | `ConcurrentHashMap<Integer, Conta>`; saldos mutáveis em memória | Reiniciar a agência apaga as contas; failover não recupera dados |
| Relógio | `RelogioVetorial.copia()` já lê sem incrementar | Reutilizar o método; não é necessário duplicá-lo com outro nome |
| Comparação | `MesclarLogs.compararVetores()` compara as quatro relações | Extrair para classe compartilhada e validar dimensão/valores |
| Saldo | `GET /contas/{id}` retorna apenas a conta | Acrescentar `vetorAtual` sem remover campos usados pelo frontend |
| Autenticação | `JwtFilter` e `SecurityConfig` liberam apenas login/health/OPTIONS | As novas rotas Bully exigem alteração nos dois pontos |
| Transferências | Publicação RabbitMQ; confirmação de crédito não implementada | O app deve mostrar "enviada para processamento", sem afirmar crédito confirmado |
| Dead-letter | Há listener da DLQ que registra o evento | A mensagem é consumida da DLQ; não prometer que fica nela indefinidamente |
| Concorrência | Relógio sincronizado, mas leitura/alteração de saldo separadas | Comparar vetor e aplicar saldo precisa de exclusão mútua compartilhada |
| Testes | Não há testes versionados nem starter de testes no POM | Adicionar testes dos comportamentos novos e regressões críticas |
| Mobile | Não existe `app_mobile/` | Criar Flutter no mesmo repositório |
| Git | Branch `master`; somente `roteiro2.md` estava não rastreado | Preservar esse arquivo e evitar incluí-lo acidentalmente |

O build offline tentado (`mvn -o -DskipTests package`) falhou no empacotamento por dependências de plugins ausentes no cache. A compilação foi considerada atualizada pelo Maven; isso não comprova uma compilação limpa nem o funcionamento em execução. Não foram executados testes integrados com RabbitMQ ou app.

Java e Maven foram encontrados no PATH; Flutter, Dart e ADB não foram encontrados nesta sessão. Isso pode ser instalação ausente ou PATH ainda não configurado.

## Ordem de execução e estimativa

Estimativa inicial de 30–45 horas em três semanas, ajustável após configurar o Android. Não é um prazo de entrega confirmado.

| Ordem | Entrega | Estimativa | Momento do commit |
| --- | --- | --- | --- |
| 0 | Plano e ambiente validado | 2–3 h | Plano revisado; setup documentado quando validado |
| 1 | Eleição Bully | 4–6 h | As três agências convergem para líder 2 |
| 2 | Heartbeat e failover | 2–3 h | Queda de 2 e retorno de 2 demonstrados |
| 3 | Histórico de lideranças | 1–2 h | Histórico corresponde à execução observada |
| 4 | Backend de sincronização | 5–7 h | Sucesso, 409, validações e concorrência testados |
| 5 | Flutter online e painel | 6–8 h | Fluxo bancário e troca automática de líder demonstrados |
| 6 | Flutter offline-first | 7–10 h | Fila persistente, reconexão e conflito demonstrados |
| 7 | Extra: indicador de agências ativas | 1–2 h | Estado das três agências visível e testado |
| 8 | Regressão, respostas e entrega | 2–4 h | Checklist concluído com evidências reais |

Semana 1: etapas 0–3 e configuração do Flutter. Semana 2: etapas 4–5. Semana 3: etapas 6–8. O endpoint offline vem antes do app offline para estabilizar o contrato e evitar retrabalho.

## Etapa 0 — preparação

1. Validar Java 21, Maven, Flutter e um emulador/dispositivo Android.
2. Rodar o backend com acesso às dependências Maven; validar login, saldo e transferência existentes nas três agências, usando a configuração RabbitMQ já adotada.
3. Criar `evidencias/sprint3/` quando começar a gerar as evidências.
4. Criar `app_mobile/` na etapa de Flutter; revisar os arquivos gerados e ignores antes de adicioná-los ao Git.

Comandos de diagnóstico (na raiz):

```powershell
java -version
mvn -version
flutter doctor
flutter devices
mvn -f agencia/pom.xml test
```

Hoje `mvn test` sozinho não prova os comportamentos: ainda não há testes. Adicionar testes na etapa correspondente, com `spring-boot-starter-test` em escopo `test`.

Para executar cada agência, abrir um terminal, configurar `RABBITMQ_URL` sem versionar o segredo, entrar em `agencia/`, definir `AGENCIA_ID` como 0, 1 ou 2 e usar `mvn spring-boot:run`. Rodar a partir de `agencia/` preserva o diretório esperado dos logs.

## Etapa 1 — eleição Bully

Arquivos previstos: `bully/BullyService.java`, `controller/BullyController.java`, DTOs de eleição/coordenador, integração de inicialização e ajustes em `security/`.

- Manter `liderAtual` inicialmente nulo e impedir eleições locais sobrepostas.
- Iniciar a eleição após a aplicação estar pronta para receber HTTP.
- Enviar eleição somente aos IDs maiores; se nenhum responder, anunciar liderança aos pares.
- Responder prontamente a uma eleição e processar a própria eleição fora do encadeamento síncrono de chamadas HTTP.
- Receber/anunciar coordenador com relógio vetorial; validar IDs e vetor de tamanho 3, com valores não negativos.
- Não manter o bloqueio do estado bancário enquanto espera rede.
- Registrar `ELEICAO_INICIADA`, `ELEICAO_RECEBIDA`, `TORNOU_LIDER` e `LIDER_ANUNCIADO`.
- Prever espera limitada pelo coordenador; um OK de agência maior seguido de falha não pode deixar a eleição presa para sempre.

Contrato previsto: `POST /bully/eleicao`, `POST /bully/coordenador` e `GET /bully/lider`, este último retornando `{idAgencia, liderAtual}`. Liderança desconhecida deve aparecer como estado explícito, não como um ID inventado.

Para reproduzir o exercício, liberar apenas as três rotas Bully no ambiente de laboratório, nos dois componentes de segurança; manter contas e transferências protegidas por JWT. Documentar a ausência de autenticação de eleição na resposta da Parte A. Se for adicionada proteção interna, combinar o contrato e ajustar as demonstrações; não usar JWT do usuário para coordenar processos.

Aceite: subir as agências em ordens diferentes e confirmar convergência para 2. Com apenas 0 e 1, confirmar líder 1. Testar recebimento inválido e ausência de JWT nas rotas bancárias. Evidência: `eleicao-inicial.png`.

## Etapa 2 — heartbeat e failover

- Começar com heartbeat de 3 segundos e timeout de 1 segundo, conforme referência do roteiro.
- Se não houver líder ou ela parar de responder, iniciar eleição.
- Evitar verificações sobrepostas; encerrar tarefas ao desligar o processo.
- Registrar `LIDER_NAO_RESPONDEU`; não incrementar o relógio a cada simples consulta bem-sucedida de saúde/liderança. Eventos de eleição continuam usando o relógio.

Aceite: 2 é líder; derrubar 2; 0 e 1 convergem para 1 sem ação manual; subir 2 novamente e observar a retomada. Medir o tempo real, sem prometer que será exatamente 3 segundos. Evidência: `failover.png`.

Bully não fornece garantia contra partições de rede neste exercício. Divergência transitória deve ser observável, e líder eleita não significa réplica dos dados.

## Etapa 3 — histórico de lideranças

Criar `HistoricoLideranca.java` reaproveitando a leitura de JSONL do projeto. Filtrar eventos Bully, exibir horário/agência/evento e resumir `TORNOU_LIDER`.

Ordenar por hora de parede para a apresentação do histórico, identificando essa escolha; ela não prova uma ordem causal total entre máquinas. Diferenciar anúncios temporários da fase inicial e períodos de estabilidade.

Comando previsto, somente após implementar, executar dentro de `agencia/`:

```powershell
mvn -q compile exec:java "-Dexec.mainClass=com.iceibank.agencia.HistoricoLideranca"
```

Aceite: saída corresponde à sequência inicial, queda, substituição e retorno. Evidência: `historico-lideranca.png`.

## Etapa 4 — sincronização no backend

Arquivos previstos: `clock/ComparadorVetores.java`, DTOs de saldo/sincronização, `service/OperacoesContaService.java` e alterações nos controllers e consumidor para compartilhar a proteção do estado.

- Reutilizar `RelogioVetorial.copia()`.
- Retornar saldo e vetor em um snapshot consistente, mantendo `id`, `nomeAluno` e `saldo` no nível atual da resposta.
- Criar `POST /contas/{id}/sincronizar` autenticado com JWT.
- Entrada mínima: `tipo` (`DEPOSITO` ou `SAQUE`), `valor` positivo e finito, `vetorConhecido` válido.
- Aplicar somente se os vetores forem iguais; qualquer outra relação retorna 409, com `vetorConhecido`, `vetorAtual` e `contaAtual`, sem modificar saldo.
- Sucesso retorna conta e vetor resultante, e registra `SINCRONIZACAO_OFFLINE`.
- Verificar saldo antes de saque. Devolver 400 para entrada inválida, 404 para conta inexistente e 401 para sessão inválida.
- Comparação de vetor, verificação de saldo e atualização devem ser uma única região crítica, coordenada com depósitos, saques, criação, transferências, crédito RabbitMQ e eventos que alteram o relógio. Apenas sincronizar o novo endpoint não resolve a corrida.
- Evitar serializar uma referência mutável de `Conta` depois de liberar a região crítica; produzir DTOs com cópias dos valores.

Proteção recomendada no mesmo bloco: `operacaoId` estável por pendência, deduplicação por usuário/conta/ID e conteúdo, antes da comparação do vetor. Uma repetição já aplicada deve ser reconhecida sem aplicar o valor de novo; reutilização do ID com outro conteúdo deve ser rejeitada. Manter a consulta de saldo/vetor atual separada do recibo original se necessário. Deduplicação em memória só vale durante a vida do processo; não alegar garantia após reinício.

Se essa proteção não entrar, timeout após envio deve virar "resultado desconhecido" e exigir reconciliação, sem repetição automática cega. HTTP 409, por si só, não identifica se uma tentativa anterior chegou a ser aplicada.

Testes de aceite: igualdade aplica uma vez; vetor antigo retorna 409 sem alteração; vetor inválido retorna 400; saque sem saldo não altera estado; mesma operação repetida não duplica; duas escritas concorrentes não perdem atualização. Incluir regressão de crédito remoto e transferência local.

Evidência: `conflito-sincronizacao.png`, com tentativa usando vetor antigo e nova tentativa autorizada com vetor atual.

## Etapa 5 — Flutter online e liderança

Estrutura sugerida: `lib/core/` para API/configuração/sessão, `lib/data/` para repositórios e armazenamento, `lib/features/` para login, conta, operações e liderança. Usar gerenciamento de estado simples; evitar criar uma arquitetura maior que o exercício.

- Login com JWT; não guardar senha. Preservar pendências ao expirar sessão e solicitar novo login antes de enviar.
- Saldo, depósito, saque e transferência local/remota; distinguir envio assíncrono de crédito confirmado.
- Reutilizar contratos HTTP, não tentar portar diretamente o JavaScript da interface.
- Incluir seleção de conta/agência ou roteamento pelo ID; não confundir agência responsável com líder.
- Painel consulta liderança periodicamente, inicialmente a cada 3 segundos em primeiro plano, sem sobrepor requisições.
- Se a agência consultada falhar, tentar as demais para consultar liderança. Isso não autoriza enviar operações da conta a outra agência, pois não há réplica.
- Em divergência, mostrar a última observação e o estado de atualização; não escolher uma líder por votação inventada no cliente.
- Pausar polling quando o app estiver suspenso; retomar ao voltar. Não prometer execução permanente em segundo plano.
- Mostrar erros de API, incluindo 400, 404 e 401, de forma visível.

No emulador Android, o host de desenvolvimento é acessível por `10.0.2.2`, não pelo localhost do celular. Em dispositivo físico, configurar IP acessível do computador e verificar rede/firewall. Configurar HTTP de desenvolvimento apenas onde necessário para o laboratório. Validar compatibilidade dos pacotes com o SDK instalado antes de fixar versões.

Aceite: fluxo completo online e mudança automática de 2 para 1 após queda. Evidências: `app-lider-atual.png` e `app-failover.png`.

## Etapa 6 — Flutter offline-first

Escolha inicial proposta: SQLite via `sqflite` para cache e fila, pela facilidade de persistir registros e atualizar estados em transações. Avaliar a versão compatível durante o setup. `connectivity_plus` pode disparar tentativas de reconexão, mas disponibilidade de Wi-Fi não garante acesso à agência; validar pela chamada HTTP e seus timeouts.

Dados de cache: usuário, agência, conta, saldo confirmado, vetor confirmado e horário da leitura. Dados de pendência: ID estável, usuário, agência, conta, tipo, valor, vetor-base, ordem de criação e estado.

Estados mínimos: pendente, enviando, sincronizada, em conflito e falha definitiva. Recuperar pendências interrompidas ao reabrir o app. Cache e fila devem ser isolados por usuário; logout não pode fazer outro usuário enviar operações anteriores.

- Consultar cache sem rede e mostrar horário do último dado confirmado.
- Persistir a pendência antes de mostrar sucesso local; mostrar saldo confirmado e saldo provisório/pêndencias de maneira distinguível.
- Depósitos e saques offline entram na fila; transferência permanece online no escopo mínimo.
- Sincronizar automaticamente ao reconectar, reabrir ou retomar o app com sessão válida; impedir dois sincronizadores simultâneos.
- Processar em ordem por agência, pois o vetor é por agência, inclusive para contas diferentes. Atualizar o vetor-base das próximas pendências apenas após sucessos conhecidos da própria fila; mudanças externas ainda devem causar conflito.
- Em 409, pausar a sequência afetada, atualizar o saldo confirmado, mostrar a divergência e permitir descartar ou confirmar uma nova tentativa. Nunca trocar o vetor e reaplicar silenciosamente.
- Em 401, pausar e pedir login sem apagar a fila. Erros de negócio, como saldo insuficiente, não viram "sem internet" nem geram retries infinitos.
- Se houver timeout após envio, usar o mesmo ID para reconciliar; observar o limite de deduplicação em memória após reinício do backend.

Aceite: offline com saldo em cache; depósito pendente e saldo provisório; fechar/reabrir preserva fila; reconectar sincroniza sem botão; duas pendências em sequência funcionam; mudança pelo web gera 409 visível; sessão expirada preserva fila.

Evidências: `app-offline.png`, `app-sincronizacao.png` e uma captura adicional `app-conflito.png` para demonstrar o requisito de conflito no app.

Para testar offline, desligar a rede do cliente sem derrubar a agência. Confirmar que a rota HTTP realmente ficou indisponível: modo avião em um emulador pode não reproduzir sozinho toda falha desejada. Derrubar a agência apaga contas e é um cenário diferente.

## Etapa 7 — funcionalidade adicional

Proposta: indicador das três agências, usando `/health`, com status responde/não responde, horário da última consulta e marcação da líder.

Tem valor visual na demonstração e reutiliza endpoint existente. Não exige abrir uma nova frente de persistência ou coordenação. "Não responde" descreve a observação do cliente; não prova que o servidor morreu.

Aceite: derrubar e restaurar uma agência altera o indicador automaticamente. Documentar escolha em `RESPOSTAS.md`, capturar `funcionalidade-adicional.png` e fazer commit próprio.

## Commits — executar somente no checkpoint indicado

Todos os comandos abaixo partem da raiz do repositório. Para cada checkpoint futuro: implementar apenas aquele bloco, executar sua validação, capturar a evidência real e então revisar o diff staged. Os caminhos novos são previstos; ajustar à implementação efetiva. Não executar blocos de etapas futuras agora.

Primeiro commit, já aplicável ao plano criado:

```powershell
git add -- PLANO-SPRINT-3.md
git diff --cached --stat
git diff --cached
git commit -m "docs: planeja sprint 3 com criterios de aceite e checkpoints"
```

Revisar o diff antes do comando de commit. A branch atual é `master`; criar `sprint-3` com `git switch -c sprint-3` é opcional, caso queira isolar o trabalho. Não é necessário trocar a branch para cumprir o roteiro.

Checkpoint 1 — eleição inicial validada:

```powershell
git add -- agencia/src agencia/pom.xml evidencias/sprint3/eleicao-inicial.png
git diff --cached
git commit -m "feat(bully): implementa mensagens de eleicao e coordenador"
```

Checkpoint 2 — failover e retorno validados:

```powershell
git add -- agencia/src evidencias/sprint3/failover.png
git diff --cached
git commit -m "feat(bully): adiciona heartbeat e failover automatico"
```

Checkpoint 3 — histórico conferido:

```powershell
git add -- agencia/src evidencias/sprint3/historico-lideranca.png
git diff --cached
git commit -m "feat(observabilidade): adiciona historico de liderancas"
```

Checkpoint 4 — sincronização e proteção de estado validadas:

```powershell
git add -- agencia/src agencia/pom.xml evidencias/sprint3/conflito-sincronizacao.png
git diff --cached
git commit -m "feat(offline-first): sincroniza operacoes com deteccao de conflitos"
```

Checkpoint 5 — app online e liderança validados:

```powershell
git add -- app_mobile .gitignore evidencias/sprint3/app-lider-atual.png evidencias/sprint3/app-failover.png
git diff --cached --stat
git diff --cached
git commit -m "feat(mobile): implementa app Flutter com painel de lideranca"
```

Checkpoint 6 — fila, reconexão e conflito validados:

```powershell
git add -- app_mobile evidencias/sprint3/app-offline.png evidencias/sprint3/app-sincronizacao.png evidencias/sprint3/app-conflito.png
git diff --cached
git commit -m "feat(mobile): implementa modo offline-first com fila de sincronizacao"
```

Checkpoint 7 — extra validado e documentado:

```powershell
git add -- app_mobile RESPOSTAS.md evidencias/sprint3/funcionalidade-adicional.png
git diff --cached
git commit -m "feat(extra): exibe disponibilidade das agencias no app"
```

Checkpoint 8 — revisão final concluída:

```powershell
git add -- README.md RESPOSTAS.md PLANO-SPRINT-3.md
git diff --cached
git commit -m "docs: conclui instrucoes e respostas da sprint 3"
git status --short
git log -10 --oneline
```

Se uma etapa levar vários dias, dividir em commits menores e coerentes: estrutura Flutter, fluxo bancário, painel; cache, fila, tratamento de conflito. Esses checkpoints são limites de entrega, não uma exigência de acumular todo o trabalho em um commit grande. Não criar commits vazios, fabricar datas ou juntar implementações sem relação. `roteiro2.md` permanece fora dos comandos acima.

## Checklist de entrega

- [ ] Build e testes backend passam; `flutter analyze` e `flutter test` passam.
- [ ] Login/JWT, frontend web, partições e RabbitMQ continuam funcionando.
- [ ] Eleição inicial, queda, retorno e histórico demonstrados.
- [ ] App executado em Android, com fluxo online completo e erros visíveis.
- [ ] Líder atualizada automaticamente com fallback entre agências.
- [ ] Cache/fila sobrevivem ao fechamento do app e dados são isolados por usuário.
- [ ] Reconexão automática, 409 visível e 401 sem perda da fila demonstrados.
- [ ] Funcionalidade extra tem explicação, captura e commit próprio.
- [ ] Oito evidências obrigatórias do roteiro, além do extra e do conflito no app, foram capturadas de execução real; usar `Get-Date` visível conforme o roteiro.
- [ ] `RESPOSTAS.md` responde às Partes A–F com resultados observados, sem inventar número de eleições, tempos ou comportamento de tela.
- [ ] README explica ambiente, três agências, Flutter, endereços de rede, testes e limitações.
- [ ] Confirmar regras de envio e prazo no ambiente da disciplina; não inferir datas ausentes do material.

## Referências consultadas

- Roteiro do professor: [Sprint 3.docx](https://chatgpt.com/library?file_id=libfile_2389f52af9a48191a32e025e3b97aeef&account_id=personal).
- [Flutter: arquitetura offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first).
- [Android: endereçamento de rede do emulador](https://developer.android.com/studio/run/emulator-networking-address).
- [connectivity_plus: limites da detecção de conectividade](https://pub.dev/packages/connectivity_plus).
