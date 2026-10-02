/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_GOOGLE_CLIENT_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface GoogleCredentialResponse {
  credential?: string;
}
interface GoogleButtonConfiguration {
  theme?: string;
  size?: string;
  width?: number;
  text?: string;
}
interface GoogleAccountsId {
  initialize(options: {
    client_id: string;
    callback: (response: GoogleCredentialResponse) => void;
  }): void;
  renderButton(element: HTMLElement, options: GoogleButtonConfiguration): void;
  prompt(): void;
}
interface GoogleGlobal {
  accounts: { id: GoogleAccountsId };
}
interface Window {
  google?: GoogleGlobal;
}
