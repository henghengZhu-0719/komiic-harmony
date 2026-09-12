/**
 * HTTP 层：GraphQL 调用、登录、图片字节流。
 *
 * 两个关键行为照搬自 Breeze 插件：
 *  1. 响应里出现 "token is expired" 时，用存储的账号密码静默重登并重放一次请求；
 *  2. 同时只允许一个登录请求在飞，避免并发过期时把服务端打爆。
 */

import { http } from '@kit.NetworkKit';
import {
  API_BASE,
  DEFAULT_USER_AGENT,
  GRAPHQL_URL,
  LOGIN_URL,
  REQUEST_TIMEOUT_MS
} from './Config';
import { GraphQlRequest, GraphQlResponse, LoginRequest, LoginResponse } from './Types';
import { KomiicStore } from './Store';

export class KomiicError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KomiicError';
  }
}

interface RawResponse {
  code: number;
  body: string;
}

function isTokenExpiredMessage(message: string): boolean {
  return message.toLowerCase().includes('token is expired');
}

function firstErrorMessage(errors?: Array<{ message?: string }>): string {
  if (errors === undefined || errors.length === 0) {
    return '';
  }
  return (errors[0].message ?? '').trim();
}

export class KomiicClient {
  private store: KomiicStore;
  private loginInFlight: Promise<string> | null = null;

  constructor(store: KomiicStore) {
    this.store = store;
  }

  // ---------- 底层请求 ----------

  private baseHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = 'application/json';
    headers['Referer'] = API_BASE + '/';
    headers['User-Agent'] = DEFAULT_USER_AGENT;
    return headers;
  }

  private async postJson(url: string, body: string, headers: Record<string, string>): Promise<RawResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      });
      const result: RawResponse = {
        code: response.responseCode,
        body: typeof response.result === 'string' ? response.result : ''
      };
      return result;
    } finally {
      // 不 destroy 会泄漏底层句柄。
      request.destroy();
    }
  }

  // ---------- 登录 ----------

  /** 手动登录（设置页调用）。成功后写入账号密码和 token。 */
  async login(account: string, password: string): Promise<string> {
    const trimmedAccount = account.trim();
    if (trimmedAccount.length === 0 || password.trim().length === 0) {
      throw new KomiicError('账号或密码不能为空');
    }
    return await this.runLogin(trimmedAccount, password);
  }

  /** 用已存凭据重登，供 token 过期时调用。 */
  private async loginWithStoredCredentials(): Promise<string> {
    const account = await this.store.getAccount();
    const password = await this.store.getPassword();
    if (account.length === 0 || password.trim().length === 0) {
      throw new KomiicError('未配置账号密码，无法自动登录');
    }
    return await this.runLogin(account, password);
  }

  /** 登录去重：并发调用共享同一个 Promise。 */
  private async runLogin(account: string, password: string): Promise<string> {
    const pending = this.loginInFlight;
    if (pending !== null) {
      return await pending;
    }
    const task = this.doLogin(account, password);
    this.loginInFlight = task;
    try {
      return await task;
    } finally {
      this.loginInFlight = null;
    }
  }

  private async doLogin(account: string, password: string): Promise<string> {
    const payload: LoginRequest = { email: account, password: password };
    const raw = await this.postJson(LOGIN_URL, JSON.stringify(payload), this.baseHeaders());

    let parsed: LoginResponse = {};
    try {
      parsed = JSON.parse(raw.body) as LoginResponse;
    } catch (e) {
      throw new KomiicError(`登录失败(${raw.code})：响应不是合法 JSON`);
    }

    const token = (parsed.token ?? '').trim();
    if (token.length === 0) {
      const remote = (parsed.message ?? parsed.error ?? parsed.errmsg ?? parsed.msg ?? '').trim()
        || firstErrorMessage(parsed.errors);
      throw new KomiicError(remote.length > 0 ? remote : `登录失败(${raw.code})`);
    }

    await this.store.setAccount(account);
    await this.store.setPassword(password);
    await this.store.setToken(token);
    return token;
  }

  // ---------- GraphQL ----------

  /**
   * 发一个 GraphQL 请求。
   * skipAuth=true 时不带 Authorization，也不做过期重试（公开接口用）。
   */
  async graphql<TData, TVars>(request: GraphQlRequest<TVars>, skipAuth: boolean = false): Promise<TData> {
    const body = JSON.stringify(request);

    let parsed = await this.sendGraphQl<TData>(body, skipAuth);
    let errorMessage = firstErrorMessage(parsed.errors);

    // token 过期 → 重登一次再重放。
    if (!skipAuth && isTokenExpiredMessage(errorMessage) && await this.store.canAutoLogin()) {
      try {
        await this.loginWithStoredCredentials();
      } catch (e) {
        await this.store.clearToken();
        throw new KomiicError(errorMessage.length > 0 ? errorMessage : '登录已过期');
      }
      parsed = await this.sendGraphQl<TData>(body, false);
      errorMessage = firstErrorMessage(parsed.errors);
    }

    if (errorMessage.length > 0) {
      throw new KomiicError(errorMessage);
    }
    const data = parsed.data;
    if (data === undefined || data === null) {
      throw new KomiicError('接口未返回数据');
    }
    return data;
  }

  private async sendGraphQl<TData>(body: string, skipAuth: boolean): Promise<GraphQlResponse<TData>> {
    const headers = this.baseHeaders();
    if (!skipAuth) {
      const token = await this.store.getToken();
      if (token.length > 0) {
        headers['Authorization'] = 'Bearer ' + token;
      }
    }

    const raw = await this.postJson(GRAPHQL_URL, body, headers);
    if (raw.code !== 200) {
      throw new KomiicError(`请求失败 HTTP ${raw.code}`);
    }
    try {
      return JSON.parse(raw.body) as GraphQlResponse<TData>;
    } catch (e) {
      throw new KomiicError('响应解析失败');
    }
  }

  /** 需要登录的接口在调用前先过这一道，给出的报错比服务端的清楚。 */
  async ensureAuthenticated(): Promise<void> {
    const account = await this.store.getAccount();
    const password = await this.store.getPassword();
    if (account.length === 0 || password.trim().length === 0) {
      throw new KomiicError('请先在设置里填写账号密码');
    }
    const token = await this.store.getToken();
    if (token.length === 0) {
      // 有凭据但没 token，直接补一次登录。
      await this.loginWithStoredCredentials();
    }
  }

  /** 冷启动时的静默登录，失败静默忽略。 */
  async warmUp(): Promise<boolean> {
    if (!await this.store.canAutoLogin()) {
      return false;
    }
    try {
      await this.loginWithStoredCredentials();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------- 图片 ----------

  /**
   * 下载图片字节。不带 Authorization，但必须带 Referer 和 UA。
   * ArkUI 的 Image 组件不能自定义请求头，所以只能走这条路。
   */
  async fetchImageBytes(url: string, referer: string): Promise<ArrayBuffer> {
    const headers: Record<string, string> = {};
    headers['Referer'] = referer.trim().length > 0 ? referer : API_BASE + '/';
    headers['User-Agent'] = DEFAULT_USER_AGENT;
    headers['Accept'] = 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8';

    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      });
      if (response.responseCode !== 200) {
        throw new KomiicError(`图片请求失败 HTTP ${response.responseCode}`);
      }
      const buffer = response.result as ArrayBuffer;
      if (buffer.byteLength === 0) {
        throw new KomiicError('图片数据为空');
      }
      return buffer;
    } finally {
      request.destroy();
    }
  }
}
