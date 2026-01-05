/**
 * Node.js-specific utilities for the envoice SDK
 * Import from '@envoice/sdk/node' for file system operations
 */
import * as fs from 'fs/promises';
import * as path from 'path';
import type { InvoiceBuilder } from './invoice-builder';

/**
 * Save PDF data to a file (Node.js only)
 */
export async function savePdf(pdfBase64: string, filePath: string): Promise<void> {
  const buffer = Buffer.from(pdfBase64, 'base64');
  const dir = path.dirname(filePath);

  // Ensure directory exists
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(filePath, buffer);
}

/**
 * Read a file and return as Base64 (for logos, etc.)
 */
export async function fileToBase64(filePath: string): Promise<string> {
  const buffer = await fs.readFile(filePath);
  return buffer.toString('base64');
}

/**
 * Extension methods for InvoiceBuilder in Node.js environments
 */
export class NodeInvoiceBuilder {
  private builder: InvoiceBuilder;

  constructor(builder: InvoiceBuilder) {
    this.builder = builder;
  }

  /**
   * Set logo from a local file path (Node.js only)
   */
  async logoFile(filePath: string, widthMm?: number): Promise<InvoiceBuilder> {
    const base64 = await fileToBase64(filePath);
    return this.builder.logoBase64(base64, widthMm);
  }
}

/**
 * Extend an InvoiceBuilder with Node.js-specific methods
 */
export function withNodeSupport(builder: InvoiceBuilder): NodeInvoiceBuilder {
  return new NodeInvoiceBuilder(builder);
}

/**
 * Re-export everything from main module for convenience
 */
export * from './index';
