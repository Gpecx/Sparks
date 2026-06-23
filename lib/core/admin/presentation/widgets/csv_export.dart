// Download de CSV com import condicional: no web usa dart:html (download real),
// nas demais plataformas vira no-op (a UI faz fallback de copiar p/ a área de
// transferência). Assim o app continua compilando para android/ios/macos.
export 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_web.dart';
