import { registerPlugin } from '@capacitor/core';

import type { PhovidPlugin } from './definitions';

const Phovid = registerPlugin<PhovidPlugin>('Phovid', {
  web: () => import('./web').then(m => new m.PhovidWeb()),
});

export * from './definitions';
export { Phovid };
