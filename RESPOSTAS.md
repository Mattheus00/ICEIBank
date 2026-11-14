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

## Sprint 3 - Parte A (5.5 - Bully)

1) **Por que vence o maior ID? A regra poderia ser invertida?**

Cada agência consulta somente IDs maiores e desiste de se eleger quando algum responde. A maior agência ativa não encontra candidato superior e anuncia a coordenação. A regra poderia privilegiar o menor ID, desde que TODOS os participantes invertessem as comparações e a direção das mensagens. O importante é uma prioridade única, determinística e compartilhada.

2) **Mais de uma declaração de liderança na subida é um bug?**

Pode ser transitório: uma agência começa sozinha, assume, e depois outra de maior ID entra. A captura `historico-lideranca.png` registra 0 → 1 → 2 em uma rodada de subida. Isso demonstra mudanças durante a inicialização, mas não prova que os três processos tenham começado simultaneamente. Depois da comunicação estabilizar, todos devem reconhecer o maior ID ativo. Divergência persistente exige investigação. A correção rejeita anúncios inferiores ao próprio ID e repete a eleição se um candidato maior respondeu sem anunciar.

3) **Qual é o risco das rotas sem autenticação?**

É um risco real: um processo com acesso às portas pode disparar eleições ou enviar anúncios falsos, afetando disponibilidade e liderança. No laboratório as rotas Bully ficam públicas para o exercício; isso não seria adequado em produção. Seriam necessárias autenticação entre serviços e restrições de rede. JWT do usuário continua obrigatório nas operações bancárias.

---

## Sprint 3 - Parte B (6.4 - heartbeat e failover)

1) **Intervalo de 100 ms ou 60 segundos?**

100 ms detecta problemas mais cedo, mas aumenta tráfego, CPU e eleições desnecessárias diante de oscilações. 60 segundos reduz as consultas, mas demora para perceber uma queda. O código usa intervalo de 3 segundos e timeout HTTP de 1 segundo. A latência real de recuperação inclui espera até o próximo heartbeat, timeouts, eleição e anúncio; não é exatamente 3 segundos.

2) **É desejável a agência que retorna tomar a liderança?**

No Bully isso mantém a prioridade determinística, mas causa outra troca mesmo quando a líder atual funciona. Em um sistema no qual a líder coordena operações, a troca pode interromper trabalho em andamento ou exigir recuperação de transações. Nesta sprint a liderança é apenas informativa; não há coordenação bancária nem replicação de contas.

3) **O que ocorre se a rede demorar mais que o timeout?**

Uma agência viva pode ser suspeita de falha. Podem ocorrer eleições extras e divergência temporária. Receber OK de uma agência maior e não receber seu anúncio em 5 segundos agora deixa a liderança desconhecida; o heartbeat dispara nova eleição. Isso evita assumir a liderança apenas pelo anúncio ausente, mas não resolve partições de rede.

---

## Sprint 3 - Parte C (7.3 - histórico de lideranças)

1) **Quantas trocas ocorreram durante a subida e qual o custo?**

Na primeira sequência da captura existente `historico-lideranca.png`, a ordem é 0 → 1 → 2: duas trocas depois da primeira eleição. A imagem contém também outra rodada de subida e a passagem posterior de 2 para 1; não se deve contar tudo como uma única inicialização. As trocas geram chamadas de eleição/anúncio, gravações de logs e tempo até estabilizar. O histórico ordena por hora de parede para apresentação, sem provar ordem causal total entre máquinas. A captura é anterior às correções e deve ser renovada na validação integrada.

---

## Sprint 3 - Parte D (8.3 - app Flutter e liderança)

1) **Frequência de consulta e trade-off?**

O painel consulta a liderança a cada 3 segundos. É um compromisso entre atualização rápida e consumo de rede/bateria. Evita chamadas sobrepostas, pausa ao sair do primeiro plano e retoma ao retornar. A sincronização da fila é independente: tenta a cada 5 segundos enquanto a tela está ativa, além da abertura, retorno ao app e registro de uma operação.

2) **E se duas agências reportarem líderes diferentes?**

O painel tenta a agência preferida e usa outra se houver falha. Exibe a observação recebida, sua origem e horário, sem inventar uma votação no cliente. Durante uma transição pode apresentar um estado temporário; o próximo polling reflete uma observação mais recente. Se a divergência persistir, a próxima consulta não garante resolução: é preciso verificar eleição e conectividade.

3) **O que foi reaproveitado do frontend web?**

API REST, JWT, particionamento por `id % 3`, operações e interpretação dos erros. No Flutter foram separados cliente HTTP, repositórios, sessão e widgets. Foi necessário tratar ciclo de vida do app, endereço do host no emulador, cache persistente, fila, saldo provisório e reconciliação após falhas de rede. Transferências continuam online; uma resposta de transferência remota indica publicação para processamento, não confirmação de crédito.

---

## Sprint 3 - Parte E (9.6 - sincronização no backend)

1) **Por que comparar o vetor inteiro em vez do saldo?**

O saldo pode voltar ao valor anterior após depósito e saque, apesar de terem ocorrido eventos. O vetor registra avanço do estado observado por cada agência e permite detectar essa mudança. Vetores diferentes resultam em HTTP 409, mesmo se os saldos coincidirem.

2) **Por que outra conta também pode causar conflito?**

O vetor é compartilhado pela agência, incluindo eventos bancários e de eleição. É uma simplificação conservadora: qualquer avanço pode invalidar a versão conhecida. Para detectar mudanças por conta seriam necessárias versões associadas a cada conta e regras para propagá-las nas operações, inclusive transferências entre contas/agências.

3) **O que fazer com o estado devolvido no 409?**

Mostrar o conflito e o saldo atual, preservar a operação e bloquear as seguintes daquela agência até a decisão da pessoa. Descartar é explícito; Nova tentativa obtém o estado atual e mantém a posição da operação na fila. Uma simples consulta de saldo não troca seu vetor-base. O avanço automático é permitido apenas após um recibo de sucesso, para operações seguintes ainda não enviadas com a mesma base. Uma alteração externa entre os envios ainda deve causar 409.

Detalhes da implementação: comparação, saldo e incremento usam o monitor do próprio relógio, compartilhado com eventos Bully. Nenhuma chamada de rede é feita dentro desse monitor. O recibo de `operacaoId` é guardado antes de escrever o log, para permitir reconciliação mesmo se o log falhar depois da alteração de saldo. A deduplicação continua em memória e não sobrevive ao reinício do backend.

---

## Sprint 3 - Parte F (10.3 - offline-first)

1) **Armazenamento escolhido e alternativas?**

SharedPreferences com JSON por usuário, para manter compatibilidade com Chrome e Android no exercício. Sqflite, Hive e Drift são alternativas; SQLite/Drift permitem modelagem e transações mais adequadas para uma fila maior, e exigem considerar o suporte web. O armazenamento atual serializa alterações dentro do mesmo isolate e verifica o retorno das gravações, mas não oferece transação entre múltiplas abas/processos nem as garantias de um banco transacional. O uso de uma única instância do app é a configuração de demonstração.

2) **Comportamento da tela no conflito e justificativa?**

A captura existente `app-conflito.png` mostra a pendência em conflito, saldo confirmado/provisório e as ações Descartar/Nova tentativa. Na versão corrigida o bloqueio da agência permanece também na próxima tentativa automática e após reabrir o app. Outras agências podem sincronizar. Isso preserva a decisão da pessoa em vez de reaplicar silenciosamente contra uma versão diferente. A nova versão precisa de evidência integrada atualizada.

3) **Qual o risco da UI otimista e como reduzi-lo?**

A pessoa pode confundir uma estimativa local com dinheiro efetivamente disponível. Por isso a tela separa saldo confirmado e provisório e identifica pendências/conflitos. Depósitos e saques são persistidos com ID e vetor antes do primeiro envio, mesmo online; timeout conserva o mesmo ID para reconciliação. Uma operação já enviada com resultado incerto não pode ser descartada até confirmar seu resultado. O saldo provisório é uma estimativa, especialmente durante respostas perdidas; não garante saldo disponível no servidor. Transferências offline não foram implementadas.

**Validação e evidências:** as imagens existentes são anteriores às correções. Reproduzir reconexão com a tela aberta (sem apertar Sincronizar), conflito com duas pendências, expiração do JWT e reinício do app. Capturar `Get-Date` junto das evidências. Desconectar o cliente sem derrubar a agência, pois reiniciar o backend apaga contas e recibos.
