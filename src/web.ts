import { WebPlugin } from '@capacitor/core';

import type { PhovidPlugin } from './definitions';

export class PhovidWeb extends WebPlugin implements PhovidPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
