import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.pagesofus.app',
  appName: 'Pages of Us',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
}

export default config
