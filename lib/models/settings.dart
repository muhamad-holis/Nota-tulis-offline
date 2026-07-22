class PrinterDevice {
  final String id;
  final String name;

  PrinterDevice({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory PrinterDevice.fromMap(Map<String, dynamic> map) =>
      PrinterDevice(id: map['id'] as String, name: map['name'] as String);
}

class Settings {
  final int? id;
  final String storeName;
  final String address;
  final String phone;
  final String? logo; // base64 PNG string, setara dataURL di versi lama
  final bool showLogo;
  final String headerText;
  final String footerText;
  final String paperSize; // "58" atau "80"
  final PrinterDevice? printer;
  final int lastNotaNumber;

  Settings({
    this.id,
    required this.storeName,
    required this.address,
    required this.phone,
    this.logo,
    required this.showLogo,
    required this.headerText,
    required this.footerText,
    required this.paperSize,
    this.printer,
    required this.lastNotaNumber,
  });

  factory Settings.defaults() {
    return Settings(
      storeName: 'Toko Saya',
      address: '',
      phone: '',
      logo: null,
      showLogo: true,
      headerText: 'TERIMA KASIH\nSELAMAT DATANG',
      footerText: 'Terima kasih atas kepercayaan Anda.',
      paperSize: '58',
      printer: null,
      lastNotaNumber: 0,
    );
  }

  Settings copyWith({
    String? storeName,
    String? address,
    String? phone,
    String? logo,
    bool clearLogo = false,
    bool? showLogo,
    String? headerText,
    String? footerText,
    String? paperSize,
    PrinterDevice? printer,
    int? lastNotaNumber,
  }) {
    return Settings(
      id: id,
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logo: clearLogo ? null : (logo ?? this.logo),
      showLogo: showLogo ?? this.showLogo,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      paperSize: paperSize ?? this.paperSize,
      printer: printer ?? this.printer,
      lastNotaNumber: lastNotaNumber ?? this.lastNotaNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeName': storeName,
      'address': address,
      'phone': phone,
      'logo': logo,
      'showLogo': showLogo ? 1 : 0,
      'headerText': headerText,
      'footerText': footerText,
      'paperSize': paperSize,
      'printerId': printer?.id,
      'printerName': printer?.name,
      'lastNotaNumber': lastNotaNumber,
    };
  }

  factory Settings.fromMap(Map<String, dynamic> map) {
    final printerId = map['printerId'] as String?;
    final printerName = map['printerName'] as String?;
    return Settings(
      id: map['id'] as int?,
      storeName: map['storeName'] as String? ?? 'Toko Saya',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      logo: map['logo'] as String?,
      showLogo: (map['showLogo'] as int? ?? 1) == 1,
      headerText: map['headerText'] as String? ?? '',
      footerText: map['footerText'] as String? ?? '',
      paperSize: map['paperSize'] as String? ?? '58',
      printer: (printerId != null && printerName != null)
          ? PrinterDevice(id: printerId, name: printerName)
          : null,
      lastNotaNumber: map['lastNotaNumber'] as int? ?? 0,
    );
  }
}
