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
- Apoio de IA usado na implementação; o código foi revisado e testado localmente.
