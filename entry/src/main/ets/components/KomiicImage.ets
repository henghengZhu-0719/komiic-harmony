/**
 * 会带请求头的 Image。直接写 Image(url) 会 403，必须走这个。
 */

import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { getSdk } from '../komiic/Sdk';

@Component
export struct KomiicImage {
  @Prop url: string = '';
  @Prop referer: string = '';
  @Prop imageFit: ImageFit = ImageFit.Cover;
  /** 长图模式：宽度撑满，高度由图片比例决定。 */
  @Prop autoHeight: boolean = false;
  /** 容器宽度（vp）。autoHeight 模式下给了才能算实际尺寸，0 表示还是按 100% 铺满。 */
  @Prop boxWidth: number = 0;
  /** 单页最大高度（vp）。横屏时给屏幕高度，整页就能塞进一屏，0 表示不限。 */
  @Prop maxHeight: number = 0;

  @State private pixelMap: image.PixelMap | null = null;
  @State private failed: boolean = false;
  @State private ratio: number = 0;

  aboutToAppear(): void {
    this.loadImage();
  }

  private async loadImage(): Promise<void> {
    const target = this.url.trim();
    if (target.length === 0) {
      this.failed = true;
      return;
    }
    try {
      const sdk = await getSdk(getContext(this) as common.Context);
      const pixelMap = await sdk.images.load(target, this.referer);
      // 组件可能已经被回收了，这里再判一次 url 没变。
      if (this.url.trim() !== target) {
        return;
      }
      if (this.autoHeight) {
        const info = await pixelMap.getImageInfo();
        const size = info.size;
        if (size.width > 0 && size.height > 0) {
          this.ratio = size.width / size.height;
        }
      }
      this.pixelMap = pixelMap;
      this.failed = false;
    } catch (e) {
      this.failed = true;
    }
  }

  /** 先按容器宽度铺满；高过 maxHeight 就改成贴合高度，两边留黑。 */
  private fittedHeight(): number {
    const natural = this.boxWidth / this.ratio;
    if (this.maxHeight > 0 && natural > this.maxHeight) {
      return this.maxHeight;
    }
    return natural;
  }

  private fittedWidth(): number {
    return this.fittedHeight() * this.ratio;
  }

  /** 图还没下完时先占住位置，不然旋转/滚动的时候列表会乱跳。 */
  private placeholderHeight(): Length {
    if (!this.autoHeight) {
      return '100%';
    }
    if (this.maxHeight > 0) {
      return this.maxHeight;
    }
    return this.boxWidth > 0 ? this.boxWidth * 1.4 : 420;
  }

  build() {
    Stack() {
      if (this.pixelMap !== null) {
        if (this.autoHeight && this.ratio > 0) {
          if (this.boxWidth > 0) {
            Image(this.pixelMap)
              .width(this.fittedWidth())
              .height(this.fittedHeight())
              .objectFit(ImageFit.Contain)
          } else {
            Image(this.pixelMap)
              .width('100%')
              .aspectRatio(this.ratio)
              .objectFit(ImageFit.Contain)
          }
        } else {
          Image(this.pixelMap)
            .width('100%')
            .height('100%')
            .objectFit(this.imageFit)
        }
      } else if (this.failed) {
        Column() {
          Text('加载失败')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          Text('点击重试')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ top: 4 })
        }
        .width('100%')
        .height(this.placeholderHeight())
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          this.failed = false;
          this.loadImage();
        })
      } else {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
        }
        .width('100%')
        .height(this.placeholderHeight())
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
      }
    }
    .width('100%')
  }
}
