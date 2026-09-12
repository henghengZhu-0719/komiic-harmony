/**
 * 账号、token、开关的本地存储。
 * 对应插件里的 pluginConfig，换成鸿蒙的 preferences。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'komiic_store';

const KEY_ACCOUNT: string = 'auth.account';
const KEY_PASSWORD: string = 'auth.password';
const KEY_TOKEN: string = 'auth.token';
const KEY_RECOMMEND: string = 'feature.recommend.enabled';

export class KomiicStore {
  private store: preferences.Preferences | null = null;
  /** token 在内存里缓存一份，避免每个请求都读磁盘。 */
  private tokenCache: string | null = null;

  async init(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    const options: preferences.Options = { name: STORE_NAME };
    this.store = await preferences.getPreferences(context, options);
  }

  private requireStore(): preferences.Preferences {
    if (this.store === null) {
      throw new Error('KomiicStore 未初始化，先调用 init(context)');
    }
    return this.store;
  }

  private async getString(key: string, fallback: string): Promise<string> {
    const value = await this.requireStore().get(key, fallback);
    return typeof value === 'string' ? value : fallback;
  }

  private async putString(key: string, value: string): Promise<void> {
    const store = this.requireStore();
    await store.put(key, value);
    await store.flush();
  }

  async getAccount(): Promise<string> {
    const value = await this.getString(KEY_ACCOUNT, '');
    return value.trim();
  }

  async setAccount(value: string): Promise<void> {
    await this.putString(KEY_ACCOUNT, value.trim());
  }

  async getPassword(): Promise<string> {
    return await this.getString(KEY_PASSWORD, '');
  }

  async setPassword(value: string): Promise<void> {
    await this.putString(KEY_PASSWORD, value);
  }

  async getToken(): Promise<string> {
    if (this.tokenCache !== null) {
      return this.tokenCache;
    }
    const token = (await this.getString(KEY_TOKEN, '')).trim();
    this.tokenCache = token;
    return token;
  }

  async setToken(value: string): Promise<void> {
    const normalized = value.trim();
    this.tokenCache = normalized;
    await this.putString(KEY_TOKEN, normalized);
  }

  async clearToken(): Promise<void> {
    await this.setToken('');
  }

  async getRecommendEnabled(): Promise<boolean> {
    const value = (await this.getString(KEY_RECOMMEND, 'false')).trim().toLowerCase();
    return value === 'true' || value === '1' || value === 'yes';
  }

  async setRecommendEnabled(value: boolean): Promise<void> {
    await this.putString(KEY_RECOMMEND, value ? 'true' : 'false');
  }

  /** 是否存了账号密码，够做静默重登。 */
  async canAutoLogin(): Promise<boolean> {
    const account = await this.getAccount();
    const password = await this.getPassword();
    return account.length > 0 && password.trim().length > 0;
  }

  /** 退出登录：清掉全部凭据。 */
  async signOut(): Promise<void> {
    await this.setAccount('');
    await this.setPassword('');
    await this.clearToken();
  }
}
