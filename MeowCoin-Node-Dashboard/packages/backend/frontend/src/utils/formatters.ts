export const formatPercentage = (value: number): string => {
  return ${value.toFixed(2)}%;
};

export const formatDate = (date: Date): string => {
  return date.toLocaleString();
};
