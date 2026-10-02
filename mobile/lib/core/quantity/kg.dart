class Kg {
  final BigInt units; // in hundredths of a kg (cents)

  const Kg._(this.units);

  factory Kg.fromUnits(BigInt units) => Kg._(units);

  factory Kg.parse(String text) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,11})\.[0-9]{2}$').hasMatch(text)) {
      throw const FormatException('Isi kg dengan dua desimal.');
    }
    return Kg._(BigInt.parse(text.replaceAll('.', '')));
  }

  String wire() {
    final str = units.toString().padLeft(3, '0');
    final whole = str.substring(0, str.length - 2);
    final decimals = str.substring(str.length - 2);
    return '$whole.$decimals';
  }

  Kg operator +(Kg other) => Kg._(units + other.units);

  Kg operator -(Kg other) => Kg._(units - other.units);

  bool operator <(Kg other) => units < other.units;
  bool operator <=(Kg other) => units <= other.units;
  bool operator >(Kg other) => units > other.units;
  bool operator >=(Kg other) => units >= other.units;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Kg && units == other.units;

  @override
  int get hashCode => units.hashCode;

  @override
  String toString() => '${wire()} kg';
}
