// Fallback (não-web): sem acesso ao DOM. Retorna false para a UI cair no
// fallback de copiar o CSV para a área de transferência.
bool downloadCsv(String filename, String content) => false;
