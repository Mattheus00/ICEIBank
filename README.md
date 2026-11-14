# ICEIBank

Banco particionado em 3 agências (Java 21 + Spring Boot).  
Sprint 3: eleição Bully, failover, sincronização offline e app Flutter.

## Backend (3 agências)

Em **cada** terminal:

```powershell
$env:RABBITMQ_URL="amqps://...sua url do CloudAMQP..."
cd c:\Users\Matheus\Documents\ICEIBank\agencia
$env:AGENCIA_ID="0"
mvn spring-boot:run
```

Repita com `AGENCIA_ID` 1 e 2 (portas 4000, 4001, 4002). A URL não vai para o Git.

Login JWT: `admin` / `admin123`  
Partição: conta `id % 3` define a agência responsável. A líder Bully é só informativa.

### Utilitários (pasta `agencia/`)

```powershell
mvn -q exec:java "-Dexec.mainClass=com.iceibank.agencia.MesclarLogs"
mvn -q exec:java "-Dexec.mainClass=com.iceibank.agencia.HistoricoLideranca"
mvn test
```

### Rotas Bully (sem JWT, só no lab)

- `POST /bully/eleicao`
- `POST /bully/coordenador`
- `GET /bully/lider`

Contas e transferências continuam com Bearer JWT.  
Offline sync: `POST /contas/{id}/sincronizar` (JWT).

## App Flutter (`app_mobile/`)

```powershell
$env:PATH = "C:\Users\Matheus\flutter\bin;$env:PATH"
cd c:\Users\Matheus\Documents\ICEIBank\app_mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

- Emulador Android: o app usa `10.0.2.2` no lugar de `localhost`.
- Chrome/Windows: usa `localhost`.
- Transferência remota: mensagem "enviada para processamento" (crédito assíncrono via RabbitMQ).
- Offline: depósito/saque entram na fila local; use Offline do Chrome (Network) sem derrubar a agência, senão a conta some da memória.

### Fila e reconexão

Depósito e saque usam a mesma fila e o endpoint `/sincronizar` também online.
O ID e a versão são gravados antes do primeiro envio. Timeout mantém o ID; uma
consulta de saldo não altera a versão de uma pendência. Só um recibo confirmado
avança as operações seguintes da mesma agência que compartilham aquela base.

Com a tela ativa, há tentativa automática a cada 5 segundos (e na abertura/retorno
ao app). Não depende de clicar em Sincronizar nem de sair e voltar à tela. O timer
pausa em segundo plano. Um 409 ou erro de negócio bloqueia a sequência da agência,
inclusive após reiniciar o app; outras agências continuam. A pessoa pode descartar
uma rejeição ou autorizar Nova tentativa no conflito. Resultados incertos não podem
ser descartados enquanto não forem reconciliados.

### Verificação das correções

Na raiz do repositório:

```powershell
mvn -f agencia/pom.xml test
Push-Location app_mobile
flutter analyze
flutter test
Pop-Location
```

Os testes Java incluem Bully com rede simulada, timeout de coordenador, heartbeat,
concorrência e deduplicação. Os testes Flutter incluem fila persistente, resposta
perdida, conflito, várias contas da mesma agência e reconexão sem evento de resume.
Eles não substituem a validação com três processos, RabbitMQ e Android reais.

Antes de entregar, renovar as evidências (as imagens atuais antecedem as correções):

1. Subir as três agências e confirmar líder 2; derrubar 2, observar 1 e retornar 2.
2. Gerar o histórico e conferir os eventos com a sequência executada.
3. No Android, consultar saldo, desconectar apenas o cliente e registrar duas operações.
4. Reabrir o app ainda offline e conferir a fila. Reconectar com a tela aberta e
   aguardar a tentativa automática, sem apertar Sincronizar.
5. Repetir com alteração externa: conferir 409, estado real e bloqueio das demais
   operações daquela agência mesmo depois de outra tentativa automática/reabertura.
6. Testar Nova tentativa e Descartar; validar 401 com fila preservada e novo login.
7. Testar transferência local/remota e frontend web para verificar regressões.
8. Capturar `Get-Date` junto das telas; registrar antes/depois ou vídeo para
   demonstrar a sincronização automática, não apenas o resultado final.

## Frontend web

```powershell
start c:\Users\Matheus\Documents\ICEIBank\frontend\index.html
```

## Evidências

`evidencias/sprint1/`, `evidencias/sprint2/`, `evidencias/sprint3/`.

## Limitações

- Contas só em memória: reiniciar a agência apaga saldos.
- Bully não resolve partição de rede neste exercício.
- Deduplicação de `operacaoId` no sync vale só enquanto o processo estiver vivo.
- A fila em SharedPreferences não é transacional entre múltiplas abas/processos;
  usar uma instância do app na demonstração. O saldo provisório é estimativo.
