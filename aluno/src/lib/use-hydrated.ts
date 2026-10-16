import { useSyncExternalStore } from "react";

const subscribe = () => () => {};

/** `false` no SSR e na hidratação; `true` depois, no cliente (permite ler localStorage sem efeito). */
export function useHydrated(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );
}
