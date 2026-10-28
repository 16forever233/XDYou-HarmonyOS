
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  /**
   * Flutter 首帧前的占位启动画面：纯品牌蓝（无文字），与系统启动画面同色。
   * 首帧后 FlutterPage 自动隐藏本组件，露出 Flutter 侧同色蓝盖，
   * 蓝盖再淡出揭开应用内容，实现「启动画面 → 应用内容」连续过渡。
   */
  @Builder
  SplashScreenView() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#0089DC')
  }

  build() {
    Column() {
      FlutterPage({
        viewId: this.viewId,
        splashScreenView: this.SplashScreenView
      })
    }
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
