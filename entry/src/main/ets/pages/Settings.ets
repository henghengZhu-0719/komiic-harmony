/**
 * 设置页：登录、推荐开关、清缓存。
 * 收藏相关的接口都要登录，不登录只能看公开内容。
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { getSdk } from '../komiic/Sdk';

@Entry
@Component
struct Settings {
  @State private account: string = '';
  @State private password: string = '';
  @State private loggedIn: boolean = false;
  @State private recommendEnabled: boolean = false;
  @State private busy: boolean = false;
  @State private cacheText: string = '';

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    try {
      const sdk = await getSdk(getContext(this) as common.Context);
      this.account = await sdk.store.getAccount();
      this.password = await sdk.store.getPassword();
      this.recommendEnabled = await sdk.store.getRecommendEnabled();
      const token = await sdk.store.getToken();
      this.loggedIn = token.length > 0;
      this.refreshCacheText(sdk.images.diskUsage());
    } catch (e) {
      const err = e as Error;
      promptAction.showToast({ message: err.message });
    }
  }

  private refreshCacheText(bytes: number): void {
    if (bytes < 1024 * 1024) {
      this.cacheText = (bytes / 1024).toFixed(0) + ' KB';
    } else {
      this.cacheText = (bytes / 1024 / 1024).toFixed(1) + ' MB';
    }
  }

  private async doLogin(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.account.trim().length === 0 || this.password.trim().length === 0) {
      promptAction.showToast({ message: '账号或密码不能为空' });
      return;
    }
    this.busy = true;
    try {
      const sdk = await getSdk(getContext(this) as common.Context);
      await sdk.client.login(this.account, this.password);
      this.loggedIn = true;
      promptAction.showToast({ message: '登录成功' });
    } catch (e) {
      const err = e as Error;
      this.loggedIn = false;
      promptAction.showToast({ message: '登录失败：' + err.message });
    } finally {
      this.busy = false;
    }
  }

  private async doSignOut(): Promise<void> {
    const sdk = await getSdk(getContext(this) as common.Context);
    await sdk.store.signOut();
    this.account = '';
    this.password = '';
    this.loggedIn = false;
    promptAction.showToast({ message: '已退出登录' });
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(15)
          .fontColor($r('sys.color.font_emphasize'))
          .onClick(() => router.back())
        Blank()
        Text('设置').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('').width(30)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })

      Scroll() {
        Column() {
          Text('账号')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ bottom: 8 })

          TextInput({ placeholder: '邮箱', text: this.account })
            .type(InputType.Email)
            .height(44)
            .onChange((value: string) => this.account = value)

          TextInput({ placeholder: '密码', text: this.password })
            .type(InputType.Password)
            .height(44)
            .margin({ top: 10 })
            .onChange((value: string) => this.password = value)

          Row() {
            Button(this.loggedIn ? '重新登录' : '登录')
              .layoutWeight(1)
              .enabled(!this.busy)
              .onClick(() => this.doLogin())

            if (this.loggedIn) {
              Button('退出')
                .layoutWeight(1)
                .margin({ left: 10 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .fontColor($r('sys.color.font_primary'))
                .onClick(() => this.doSignOut())
            }
          }
          .width('100%')
          .margin({ top: 12 })

          Text(this.loggedIn ? '状态：已登录' : '状态：未登录（只能浏览公开内容）')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .margin({ top: 8 })

          Divider().margin({ top: 20, bottom: 16 })

          Row() {
            Column() {
              Text('推荐功能').fontSize(15)
              Text('详情页显示相关推荐，会多一次请求')
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.recommendEnabled })
              .onChange(async (isOn: boolean) => {
                this.recommendEnabled = isOn;
                const sdk = await getSdk(getContext(this) as common.Context);
                await sdk.store.setRecommendEnabled(isOn);
              })
          }
          .width('100%')

          Divider().margin({ top: 16, bottom: 16 })

          Row() {
            Column() {
              Text('图片缓存').fontSize(15)
              Text(this.cacheText)
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('清除')
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(async () => {
                const sdk = await getSdk(getContext(this) as common.Context);
                sdk.images.clearMemory();
                sdk.images.clearDisk();
                this.refreshCacheText(sdk.images.diskUsage());
                promptAction.showToast({ message: '已清除' });
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
