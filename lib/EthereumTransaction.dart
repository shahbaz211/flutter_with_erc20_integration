class EthereumTransaction {
  const EthereumTransaction({
    required this.from,
    required this.to,
    required this.value,
    this.data,
  });

  final String from;
  final String to;
  final String value;
  final String? data;

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'value': value,
    'data': data,
  };
}