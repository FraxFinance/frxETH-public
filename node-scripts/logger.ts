/* eslint-disable no-console */
import chalk from 'chalk';

export interface ILogger {
  info(...args: any[]): void;
  warn(...args: any[]): void;
  error(...args: any[]): void;
}

const logInternal = (method: 'info' | 'warn' | 'error', symbol: string, ...args: any[]) => {
  const now = new Date();
  const timestamp = chalk.gray(`[${now.toLocaleTimeString()}]`);

  console[method](timestamp, symbol, ...args);
};

const spacer = ' ';
const frax = `${spacer}\u00A4${spacer}`;
const square = `${spacer}\u25A0${spacer}`;
const triangle = `${spacer}\u25B2${spacer}`;

export const logger: ILogger = {
  info(...args: any[]) {
    logInternal('info', chalk.green(square), ...args);
  },

  warn(...args: any[]) {
    logInternal('warn', chalk.yellow(triangle), ...args);
  },

  error(...args: any[]) {
    logInternal('error', chalk.bgRedBright.whiteBright(frax), ...args);
  },
};