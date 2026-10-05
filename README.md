# ICEIBank

Banco simplificado particionado em agências — Sprint 2 (RabbitMQ + relógio vetorial).

## Como subir

Em **cada** terminal, antes da agência:

```powershell
$env:RABBITMQ_URL="amqps://...sua url do CloudAMQP..."
$env:AGENCIA_ID="0"
cd agencia
mvn spring-boot:run
```

Repita com `AGENCIA_ID` 1 e 2. A URL não vai para o Git.

Linha do tempo causal (a partir de `agencia/`):

```powershell
mvn -q exec:java "-Dexec.mainClass=com.iceibank.agencia.MesclarLogs"
```


