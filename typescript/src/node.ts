import * as fs from 'fs/promises';
import * as path from 'path';
import type { InvoiceBuilder } from './invoice-builder';

export async function savePdf(pdfBase64: string, filePath: string): Promise<void> {
  const buffer = Buffer.from(pdfBase64, 'base64');
  const dir = path.dirname(filePath);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(filePath, buffer);
}

export async function fileToBase64(filePath: string): Promise<string> {
  const buffer = await fs.readFile(filePath);
  return buffer.toString('base64');
}

export class NodeInvoiceBuilder {
  private builder: InvoiceBuilder;

  constructor(builder: InvoiceBuilder) {
    this.builder = builder;
  }

  async logoFile(filePath: string, widthMm?: number): Promise<InvoiceBuilder> {
    const base64 = await fileToBase64(filePath);
    return this.builder.logoBase64(base64, widthMm);
  }
}

export function withNodeSupport(builder: InvoiceBuilder): NodeInvoiceBuilder {
  return new NodeInvoiceBuilder(builder);
}

export * from './index';
