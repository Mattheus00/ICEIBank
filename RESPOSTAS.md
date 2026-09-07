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
