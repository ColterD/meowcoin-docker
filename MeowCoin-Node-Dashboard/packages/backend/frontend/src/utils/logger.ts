export const logger = {
  info: (message: string) => console.log([Info] ),
  error: (message: string, error?: any) => console.error([Error] , error),
  warn: (message: string) => console.warn([Warn] ),
};
