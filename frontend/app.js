const TOKEN_KEY = "iceibank_token";
const AGENCIA_KEY = "iceibank_agencia";

const els = {
  agenciaUrl: document.getElementById("agenciaUrl"),
  loginForm: document.getElementById("loginForm"),
  username: document.getElementById("username"),
  password: document.getElementById("password"),
  authStatus: document.getElementById("authStatus"),
  mensagem: document.getElementById("mensagem"),
  resultado: document.getElementById("resultado"),
  criarForm: document.getElementById("criarForm"),
  saldoForm: document.getElementById("saldoForm"),
  depositoForm: document.getElementById("depositoForm"),
  saqueForm: document.getElementById("saqueForm"),
  transferForm: document.getElementById("transferForm"),
  historicoForm: document.getElementById("historicoForm"),
};

function baseUrl() {
  return els.agenciaUrl.value.replace(/\/$/, "");
}

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function setToken(token) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token);
  } else {
    localStorage.removeItem(TOKEN_KEY);
  }
  atualizarAuthStatus();
}

function atualizarAuthStatus() {
  const token = getToken();
  if (token) {
    els.authStatus.textContent = "Autenticado (token em localStorage)";
    els.authStatus.classList.add("ok");
  } else {
    els.authStatus.textContent = "Não autenticado";
    els.authStatus.classList.remove("ok");
  }
}

function showMessage(texto, tipo) {
  els.mensagem.hidden = false;
  els.mensagem.className = "mensagem " + tipo;
  els.mensagem.textContent = texto;
}

function showResult(data) {
  els.resultado.textContent =
    typeof data === "string" ? data : JSON.stringify(data, null, 2);
}

async function apiFetch(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  const token = getToken();
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${baseUrl()}${path}`, {
    ...options,
    headers,
  });

  let body;
  const text = await response.text();
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { erro: text || "Resposta inválida" };
  }

  if (response.status === 401) {
    setToken(null);
    const msg = body.erro || "Não autorizado. Faça login novamente.";
    showMessage(msg, "erro");
    throw new Error(msg);
  }

  if (!response.ok) {
    const msg = body.erro || `Erro HTTP ${response.status}`;
    showMessage(msg, "erro");
    throw new Error(msg);
  }

  return body;
}

els.agenciaUrl.value =
  localStorage.getItem(AGENCIA_KEY) || "http://localhost:4000";

els.agenciaUrl.addEventListener("change", () => {
  localStorage.setItem(AGENCIA_KEY, els.agenciaUrl.value);
});

els.loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    const body = await apiFetch("/auth/login", {
      method: "POST",
      body: JSON.stringify({
        username: els.username.value,
        password: els.password.value,
      }),
    });
    setToken(body.token);
    showMessage("Login realizado com sucesso.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.criarForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch("/contas", {
      method: "POST",
      body: JSON.stringify({
        id: Number(fd.get("id")),
        nomeAluno: fd.get("nomeAluno"),
        saldoInicial: Number(fd.get("saldoInicial")),
      }),
    });
    showMessage("Conta criada.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.saldoForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch(`/contas/${fd.get("id")}`);
    showMessage("Saldo consultado.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.depositoForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch(`/contas/${fd.get("id")}/depositar`, {
      method: "POST",
      body: JSON.stringify({ valor: Number(fd.get("valor")) }),
    });
    showMessage("Depósito realizado.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.saqueForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch(`/contas/${fd.get("id")}/sacar`, {
      method: "POST",
      body: JSON.stringify({ valor: Number(fd.get("valor")) }),
    });
    showMessage("Saque realizado.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.transferForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch("/transferencias", {
      method: "POST",
      body: JSON.stringify({
        idOrigem: Number(fd.get("idOrigem")),
        idDestino: Number(fd.get("idDestino")),
        valor: Number(fd.get("valor")),
      }),
    });
    showMessage(body.mensagem || "Transferência concluída.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

els.historicoForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  try {
    const body = await apiFetch(`/contas/${fd.get("id")}/historico`);
    showMessage("Histórico carregado.", "ok");
    showResult(body);
  } catch (err) {
    showResult({ erro: err.message });
  }
});

atualizarAuthStatus();
