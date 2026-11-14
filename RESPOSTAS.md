# RESPOSTAS - ICEIBank Sprint 1

## Funcionalidade adicional

Implementei o endpoint GET /contas/{id}/historico.

Ele pega os eventos do arquivo .jsonl da agencia e filtra os que tem a ver com aquela conta (criar, deposito, saque, transferencia etc).

Escolhi isso porque facilita ver o que aconteceu em cada conta sem precisar abrir o log inteiro na mao.

---

## Parte B (6.4)

1) Por que usa max(contador_local, timestampRecebido) + 1?

Porque se so adotasse o timestamp recebido, o relogio local poderia voltar pra tras. Ex: se eu ja estou no 10 e recebo 3, nao faz sentido ir pra 3. O max garante que fica o maior dos dois, e o +1 marca o recebimento como um evento novo.

2) Agencia 0 no contador 10 recebe timestamp 3. Qual o novo valor?

max(10, 3) + 1 = 11.

Isso mostra que agencia que processa mais eventos fica com o contador maior. Quando uma mais lenta manda mensagem, a rapida nao diminui o relogio dela.

---

## Parte D (8.3)

1) Por que na transferencia local nao usa aoEnviar/aoReceber?

Porque e tudo na mesma agencia, no mesmo processo. Nao tem mensagem indo de um processo pro outro. Debito e credito sao so eventos locais. Entre agencias tem chamada REST, ai precisa anexar o timestamp no envio e atualizar no destino.

2) Depois da falha conhecida, o saldo da origem foi revertido?

Nao. O debito ja tinha sido feito e nao volta. O credito remoto nao acontece. Fica inconsistente de proposito nesse sprint, e registra TRANSFERENCIA_FALHOU no log.

3) Duas formas de corrigir no Sprint 4:

- 2PC: as duas agencias preparam e so confirmam se as duas toparem; se uma falhar, cancela.
- Saga: faz os passos em sequencia e, se der ruim no meio, roda uma compensacao (tipo estornar o debito).

---

## Parte E (10.3)

Observacao do teste:
Apareceram eventos com o mesmo timestampLamport em agencias diferentes. Sao concorrentes, um nao causou o outro. A ordem pela horaParede tambem nao bate necessariamente com a ordem do Lamport.

1) Se vejo timestamps diferentes, isso prova que um influenciou o outro?

Nao. Lamport garante so um lado: se A aconteceu antes de B causalmente, ts(A) < ts(B). O contrario nao vale. Pode ser so concorrente e o numero ficou diferente.

2) Lamport sozinho da pra saber com certeza se dois eventos sao concorrentes?

Nao. Por isso no Sprint 2 entra o relogio vetorial, que consegue mostrar melhor quando dois eventos sao independente.

---

## Parte F (11.3)

Decisoes:
- Login com usuario/senha em memoria: admin / admin123 (sem banco ainda).
- Token JWT com expiracao (5 minutos).
- A rota creditar-remoto nao usa o JWT do usuario. Usa o header X-Internal-Token entre as agencias. Achei melhor assim porque e chamada interna, nao precisa carregar o token da pessoa do frontend.

1) Autenticacao vs autorizacao?

Autenticacao e quem voce e. Autorizacao e o que voce pode fazer. No meu codigo eu verifico se o token e valido (autenticacao). Ainda nao tem regra de "so pode sacar da sua conta" - qualquer usuario logado consegue mexer nas contas da agencia.

2) Por que nao precisa consultar banco pra validar o JWT?

Porque a assinatura com a chave secreta ja prova se o token e verdadeiro. Isso escala melhor do que guardar sessao em memoria no servidor.

3) Se a chave secreta vazar?

Quem tiver a chave consegue fabricar token valido e se passar por usuario autenticado ate trocar a chave.

---

## Parte G (12.3)

1) Como o frontend lembra do token?

Depois do login salva no localStorage. Nas proximas requisicoes a funcao apiFetch coloca Authorization: Bearer com esse token.

2) Se o token expirar no meio do uso?

A API devolve 401. O frontend mostra o erro na tela, apaga o token e a pessoa precisa logar de novo.

3) Onde fica o MVC no frontend?

Model: os dados (token, url da agencia, JSON da API).
View: o HTML e o CSS.
Controller: o app.js, que pega o clique/submit e chama a API.

Nao e um MVC certinho de framework, mas da pra separar assim.

---

## Sprint 2 - funcionalidade adicional

Dead-letter: quando o credito remoto chega e a conta nao existe, a mensagem nao e descartada. Ela vai para a fila `fila-agencia-X.dlq` (exchange `iceibank.dlx`) e o log grava `CREDITO_REMOTO_FALHOU` e `DEAD_LETTER`.

Escolhi isso porque o teste de resiliencia do sprint mostra exatamente esse caso: a fila guarda a mensagem, mas a conta em memoria some se a agencia reinicia.

---

## Sprint 3 - funcionalidade adicional

Indicador de agencias ativas no app Flutter. A cada 3 segundos o app consulta `/health` das tres agencias e mostra se responde ou nao, o horario da ultima consulta e marca a lider (vindo do painel Bully).

Escolhi isso porque reaproveita o endpoint que ja existia e ajuda na demonstracao do failover: derruba a agencia 2 e o indicador muda sozinho. "Nao responde" e so a observacao do cliente - nao prova sozinho que o processo morreu.

---

## Parte B (6.4) - relogio vetorial

1) Se forem 10 agencias, cada mensagem carrega um vetor de 10 numeros. O tamanho cresce com o numero de processos. Para 3 ou 10 agencias isso e barato. Em um sistema enorme (milhares de processos) o vetor fica grande e custa mais para enviar e comparar. Por isso existe o relogio vetorial com versoes mais compactas, mas aqui nao e problema.

2) V1 = [3, 1, 0] e V2 = [3, 2, 0]. Posicao a posicao: 3<=3, 1<=2, 0<=0, e eles sao diferentes. Entao V1 aconteceu antes de V2.

3) V1 = [3, 1, 0] e V2 = [1, 3, 0]. Na posicao 0, 3 > 1. Na posicao 1, 1 < 3. Nenhum vetor e menor ou igual ao outro em todas as posicoes. Sao concorrentes.

---

## Parte C (7.5) - mensageria

1) Quando a agencia de destino volta, o RabbitMQ entrega a mensagem que ficou na fila. O credito so e aplicado se a conta ainda existir na memoria. Se a agencia reiniciou, a conta sumiu. A mensagem chega, o log mostra CREDITO_REMOTO_FALHOU e ela vai para a dead-letter. A mensageria nao falhou: a conta e que nao estava mais la.

2) Melhorou: a mensagem nao se perde se a agencia estiver fora do ar no momento da transferencia. A resposta 200 agora so significa "publiquei", nao "o dinheiro ja caiu". Continua aberto: conta so em memoria, e nao ha atomicidade (o debito ja foi feito mesmo se o credito falhar).

3) O consumidor da fila nao usa JWT porque nao passa pelo HTTP. Quem publica e outra agencia, usando a URL do CloudAMQP. No lab isso e aceitavel, mas se a URL vazar qualquer pessoa consegue publicar credito falso. A seguranca aqui e a senha do broker, nao o token do usuario.

---

## Parte D (8.3) - linha do tempo causal

1) O Lamport e um numero so. ts(A) < ts(B) nao prova que A causou B. O vetorial guarda o que cada agencia ja viu. Da para comparar posicao a posicao e concluir "antes" ou "concorrente" com certeza.

2) Criar uma conta na agencia 0 e criar outra na agencia 1, sem transferencia entre elas, gera dois vetores que o script marca como CONCORRENTES. Faz sentido: um nao causou o outro. Ja o debito da transferencia e o credito remoto nao devem aparecer nessa lista, porque o credito carrega o vetor do envio (aoReceber).

3) Comparar todos os pares e O(n^2). Com milhoes de eventos fica pesado. Daria para guardar so os vetores recentes, comparar por agencia, ou usar uma estrutura que descarte pares que ja se sabe que sao ordenados.

---

## Sprint 3 - Parte A (Bully)

1) Subindo as tres agencias, as tres passaram a reportar liderAtual = 2. Faz sentido no Bully: o maior ID vivo vira coordenador e anuncia.

2) As rotas `/bully/*` ficaram sem JWT de proposito no lab. Contas e transferencias continuam protegidas. Quem coordena sao os processos das agencias, nao o usuario do app. O risco e alguem na rede chamar `/bully/coordenador` e mentir o lider; no laboratorio isso e aceito e documentado.

3) Quando so 0 e 1 estavam no ar, o lider ficou 1. Quando a 2 voltou, ela retomou a lideranca.

---

## Sprint 3 - Parte B (heartbeat / failover)

1) Derrubei a agencia 2. Em alguns segundos (heartbeat de 3s + timeout de 1s) as agencias 0 e 1 marcaram LIDER_NAO_RESPONDEU e elegeram 1. Nao prometi tempo exato de 3 segundos - medi olhando o painel/app.

2) Bully nao garante nada contra particao de rede neste exercicio. Lider eleita tambem nao replica saldo: a conta continua so na agencia do id % 3.

3) Consulta bem-sucedida de `/bully/lider` no heartbeat nao incrementa o relogio vetorial. So eventos de eleicao (iniciar, receber, tornar lider, anunciar, lider nao respondeu) usam o relogio.

---

## Sprint 3 - Parte C (historico de liderancas)

1) O `HistoricoLideranca` ordena por hora de parede. Serve pra apresentar a sequencia, mas nao prova ordem causal total entre maquinas.

2) No teste, o resumo mostrou TORNOU_LIDER da 2 e depois da 1 depois do failover. Os LIDER_ANUNCIADO da fase inicial podem ser temporarios; os periodos mais estaveis ficam entre TORNOU_LIDER consecutivos.

---

## Sprint 3 - Parte D (sincronizacao / conflito)

1) POST `/contas/{id}/sincronizar` so aplica se `vetorConhecido` for igual ao vetor atual. Se for antigo, volta 409 com vetorAtual e contaAtual, sem mudar saldo. Vi isso no print conflito-sincronizacao (409 e depois sync com vetor novo).

2) Comparar vetor e aplicar saldo fica na mesma regiao critica (`estadoLock`) junto com deposito/saque/transferencia/credito Rabbit. Sem isso duas escritas concorrentes podiam sobrescrever.

3) `operacaoId` evita aplicar a mesma pendencia duas vezes enquanto o processo estiver vivo. Depois de reiniciar a agencia a deduplicacao some da memoria.

---

## Sprint 3 - Parte E (app online / lideranca)

1) No Flutter o painel consulta lider a cada 3s. Se a agencia preferida falha, tenta as outras so pra observar o lider - nao manda operacao da conta pra outra agencia (nao tem replica).

2) Transferencia remota no app mostra "enviada para processamento". Nao afirma que o credito ja caiu, porque o credito e assincrono no RabbitMQ.

3) Polling pausa quando o app fica em segundo plano e volta no resume.

---

## Sprint 3 - Parte F (offline-first)

1) Deposito/saque offline entram na fila local (SharedPreferences/JSON, pra funcionar no Chrome do lab). Transferencia ficou so online.

2) Mostra saldo confirmado e provisorio separados. A pendencia e gravada antes de mostrar sucesso local.

3) Em 409 o app pausa a sequencia, atualiza o cache com contaAtual e oferece Descartar ou Nova tentativa. Nao troca o vetor e reaplica em silencio. Em 401 pede login de novo e nao apaga a fila (vi a mensagem de sessao expirada com pendencia preservada).

4) Derrubar a agencia pra testar offline apaga as contas da memoria. O teste limpo de fila/sync foi com Offline do Chrome e as agencias ainda no ar.
