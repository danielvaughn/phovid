export interface PhovidPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
