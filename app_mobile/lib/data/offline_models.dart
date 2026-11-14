enum EstadoPendencia { pendente, enviando, sincronizada, conflito, falha }

class ContaCache {
  ContaCache({
    required this.usuario,
    required this.agencia,
    required this.contaId,
    required this.nome,
    required this.saldoConfirmado,
    required this.vetorConfirmado,
    required this.lidoEm,
  });

  final String usuario;
  final int agencia;
  final int contaId;
  final String nome;
  final double saldoConfirmado;
  final List<int> vetorConfirmado;
  final DateTime lidoEm;

  Map<String, dynamic> toJson() => {
    'usuario': usuario,
    'agencia': agencia,
    'contaId': contaId,
    'nome': nome,
    'saldoConfirmado': saldoConfirmado,
    'vetorConfirmado': vetorConfirmado,
    'lidoEm': lidoEm.toIso8601String(),
  };

  factory ContaCache.fromJson(Map<String, dynamic> json) => ContaCache(
    usuario: json['usuario'] as String,
    agencia: json['agencia'] as int,
    contaId: json['contaId'] as int,
    nome: json['nome'] as String? ?? '',
    saldoConfirmado: (json['saldoConfirmado'] as num).toDouble(),
    vetorConfirmado: (json['vetorConfirmado'] as List)
        .map((e) => (e as num).toInt())
        .toList(),
    lidoEm: DateTime.parse(json['lidoEm'] as String),
  );
}

class Pendencia {
  Pendencia({
    required this.id,
    required this.usuario,
    required this.agencia,
    required this.contaId,
    required this.tipo,
    required this.valor,
    required this.vetorBase,
    required this.criadaEm,
    required this.estado,
    this.mensagemErro,
    this.tentada = false,
  });

  final String id;
  final String usuario;
  final int agencia;
  final int contaId;
  final String tipo; // DEPOSITO | SAQUE
  final double valor;
  List<int> vetorBase;
  final DateTime criadaEm;
  EstadoPendencia estado;
  String? mensagemErro;
  // Depois do primeiro envio, não descartar nem trocar a versão por timeout.
  bool tentada;

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': usuario,
    'agencia': agencia,
    'contaId': contaId,
    'tipo': tipo,
    'valor': valor,
    'vetorBase': vetorBase,
    'criadaEm': criadaEm.toIso8601String(),
    'estado': estado.name,
    'mensagemErro': mensagemErro,
    'tentada': tentada,
  };

  factory Pendencia.fromJson(Map<String, dynamic> json) => Pendencia(
    id: json['id'] as String,
    usuario: json['usuario'] as String,
    agencia: json['agencia'] as int,
    contaId: json['contaId'] as int,
    tipo: json['tipo'] as String,
    valor: (json['valor'] as num).toDouble(),
    vetorBase: (json['vetorBase'] as List)
        .map((e) => (e as num).toInt())
        .toList(),
    criadaEm: DateTime.parse(json['criadaEm'] as String),
    estado: EstadoPendencia.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoPendencia.pendente,
    ),
    mensagemErro: json['mensagemErro'] as String?,
    // Filas antigas podem conter envios com resultado incerto.
    tentada: json['tentada'] as bool? ?? true,
  );
}
