import * as fs from 'fs';

const filePath = 'functions/src/services/asaasService.ts';
let code = fs.readFileSync(filePath, 'utf8');

const updateCustomerFn = `
export async function updateCustomer(id: string, cpfCnpj: string): Promise<void> {
  const { apiKey, baseUrl } = getAsaasConfig();
  const headers = buildHeaders(apiKey);
  
  const res = await httpRequest(
    \`\${baseUrl}/customers/\${id}\`,
    { method: "POST", headers },
    JSON.stringify({ cpfCnpj })
  );
  if (res.status >= 400) {
    throw new Error(\`Failed to update customer \${id} with CPF: \${JSON.stringify(res.data)}\`);
  }
}
`;

// Insert the new function before the Charge section
code = code.replace('// ── Charge ───────────────────────────────────────────────────────', updateCustomerFn + '\n// ── Charge ───────────────────────────────────────────────────────');

fs.writeFileSync(filePath, code);
