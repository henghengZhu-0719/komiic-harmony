/**
 * 展示层的小工具：时间格式化、字段拼接。
 */

import { KomiicAuthor, KomiicCategory, KomiicComic } from './Types';

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

export function formatDateTime(value?: string): string {
  const text = (value ?? '').trim();
  if (text.length === 0) {
    return '';
  }
  const parsed = new Date(text);
  const time = parsed.getTime();
  if (Number.isNaN(time)) {
    return text;
  }
  return `${parsed.getFullYear()}-${pad2(parsed.getMonth() + 1)}-${pad2(parsed.getDate())} ` +
    `${pad2(parsed.getHours())}:${pad2(parsed.getMinutes())}`;
}

export function formatDateOnly(value?: string): string {
  const text = (value ?? '').trim();
  if (text.length === 0) {
    return '';
  }
  const parsed = new Date(text);
  const time = parsed.getTime();
  if (Number.isNaN(time)) {
    return text;
  }
  return `${parsed.getFullYear()}-${pad2(parsed.getMonth() + 1)}-${pad2(parsed.getDate())}`;
}

export function relativeUpdateText(value?: string): string {
  const text = (value ?? '').trim();
  if (text.length === 0) {
    return '';
  }
  const time = new Date(text).getTime();
  if (Number.isNaN(time)) {
    return text;
  }
  const diff = Date.now() - time;
  const hourMs = 1000 * 60 * 60;
  const dayMs = hourMs * 24;
  if (diff < hourMs) {
    return '刚刚更新';
  }
  if (diff < dayMs) {
    return `${Math.max(1, Math.floor(diff / hourMs))}小时前更新`;
  }
  return `${Math.max(1, Math.floor(diff / dayMs))}天前更新`;
}

export function authorNames(comic: KomiicComic): string[] {
  const list = comic.authors ?? [];
  const names: string[] = [];
  list.forEach((item: KomiicAuthor) => {
    const name = (item.name ?? '').trim();
    if (name.length > 0) {
      names.push(name);
    }
  });
  return names;
}

export function categoryNames(comic: KomiicComic): string[] {
  const list = comic.categories ?? [];
  const names: string[] = [];
  list.forEach((item: KomiicCategory) => {
    const name = (item.name ?? '').trim();
    if (name.length > 0) {
      names.push(name);
    }
  });
  return names;
}

export function authorLine(comic: KomiicComic): string {
  return authorNames(comic).join(' / ');
}

export function statusText(comic: KomiicComic): string {
  const status = (comic.status ?? '').trim();
  if (status === 'END') {
    return '完結';
  }
  if (status === 'ONGOING') {
    return '連載中';
  }
  return status;
}

export function formatCount(value?: number): string {
  const n = value ?? 0;
  if (n >= 10000) {
    return (n / 10000).toFixed(1) + '万';
  }
  return n.toString();
}
