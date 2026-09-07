# ICEIBank

Banco simplificado particionado em agências — Sprint 1 (API REST/MVC + Relógio de Lamport).

## Stack

- Backend: Java 21 + Spring Boot
- Frontend: HTML/CSS/JS puro
- Autenticação: JWT

## Estrutura

```
agencia/     # serviço Spring Boot (mesmo código, 3 instâncias)
frontend/    # interface web
evidencias/  # prints de teste
RESPOSTAS.md # respostas das questões do roteiro
```

## Como executar as 3 agências

```powershell
cd agencia

# Terminal 1
$env:AGENCIA_ID="0"; mvn spring-boot:run

# Terminal 2
$env:AGENCIA_ID="1"; mvn spring-boot:run

# Terminal 3
$env:AGENCIA_ID="2"; mvn spring-boot:run
```

Portas padrão: `4000`, `4001`, `4002`.

## Login padrão

- Usuário: `admin`
- Senha: `admin123`

## Frontend

Abra `frontend/index.html` com um servidor estático (ex.: Live Server) ou:

```powershell
npx --yes serve frontend -p 3000
```

## Linha do tempo unificada

```powershell
cd agencia
mvn -q exec:java -Dexec.mainClass="com.iceibank.agencia.MesclarLogs"
```
