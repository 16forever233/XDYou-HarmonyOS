interface CardItem {
  type: string;
  name: string;
  teacher: string;
  place: string;
  seat: string;
  startTime: string;
  endTime: string;
  colorIndex: number;
}

const CARD_COLORS: string[] = [
  '#EF5350', '#EC407A', '#AB47BC', '#7E57C2', '#5C6BC0', '#42A5F5',
  '#29B6F6', '#26C6DA', '#26A69A', '#66BB6A', '#9CCC65', '#66BB6A',
];

/** FormDimension: 2=2x2, 3=2x4, 4=4x4 */
const DIMENSION_2_2 = 2;

@Entry
@Component
struct WidgetCard {
  @LocalStorageProp('title') title: string = '今日课表';
  @LocalStorageProp('date') date: string = '';
  @LocalStorageProp('week') week: string = '';
  @LocalStorageProp('isLoggedIn') isLoggedIn: boolean = true;
  @LocalStorageProp('isTomorrow') isTomorrow: boolean = false;
  @LocalStorageProp('itemsJson') itemsJson: string = '[]';
  @LocalStorageProp('errorType') errorType: string = '';
  @LocalStorageProp('error') error: string = '';
  @LocalStorageProp('formDimension') formDimension: number = DIMENSION_2_2;
  /** 数据已跨天失效（窗口里没有该日期），提示用户打开应用刷新。 */
  @LocalStorageProp('stale') stale: boolean = false;
  /** 今日有日程但都已完成。 */
  @LocalStorageProp('allFinished') allFinished: boolean = false;

  readonly FULL_WIDTH_PERCENT: string = '100%';
  readonly FULL_HEIGHT_PERCENT: string = '100%';

  private isSmall(): boolean {
    return this.formDimension === DIMENSION_2_2;
  }

  /** 副标题：教室 + 座位号（考试）+ 教师，都为空时返回空串。 */
  private subTitle(item: CardItem): string {
    const parts: string[] = [];
    if (item.place !== undefined && item.place !== null && item.place.length > 0) {
      parts.push(item.place);
    }
    if (item.seat !== undefined && item.seat !== null && item.seat.length > 0) {
      parts.push('座位' + item.seat);
    }
    if (item.teacher !== undefined && item.teacher !== null && item.teacher.length > 0) {
      parts.push(item.teacher);
    }
    return parts.join(' ');
  }

  private getItems(): CardItem[] {
    try {
      const arr = JSON.parse(this.itemsJson) as CardItem[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  private itemColor(index: number): string {
    return CARD_COLORS[index % CARD_COLORS.length];
  }

  @Builder
  ScheduleRow(item: CardItem) {
    Row() {
      Column() {
        Text(item.startTime)
          .fontSize(this.isSmall() ? 9 : 10)
          .fontColor($r('app.color.card_text_primary'))
        Text(item.endTime)
          .fontSize(this.isSmall() ? 9 : 10)
          .fontColor($r('app.color.card_text_secondary'))
      }
      .width(this.isSmall() ? 32 : 40)

      Text(item.type)
        .fontSize(this.isSmall() ? 9 : 10)
        .fontColor(this.itemColor(item.colorIndex))
        .width(this.isSmall() ? 24 : 28)

      Column() {
        Text(item.name)
          .fontSize(this.isSmall() ? 11 : 13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.card_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subTitle(item))
          .fontSize(this.isSmall() ? 9 : 10)
          .fontColor($r('app.color.card_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width(this.FULL_WIDTH_PERCENT)
    .padding({ top: this.isSmall() ? 2 : 4, bottom: this.isSmall() ? 2 : 4 })
  }

  // 卡片不使用 emoji：状态一律只用文字表达（作者要求）。
  // 原来这里带一个 icon 参数画 emoji（🔄 / 😀 / ⚠️ / ✅），已全部去掉 ——
  // 参数也一并删除，免得以后又被塞回来。
  @Builder
  StateView(text: string) {
    Column() {
      Text(text)
        .fontSize(this.isSmall() ? 11 : 12)
        .fontColor($r('app.color.card_text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.FULL_WIDTH_PERCENT)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(this.isSmall() ? 13 : 15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_text_primary'))
            .maxLines(1)
          if (!this.isSmall()) {
            Text(`${this.date} ${this.week}`)
              .fontSize(10)
              .fontColor($r('app.color.card_text_secondary'))
              .margin({ top: 2 })
              .maxLines(1)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.isTomorrow ? '今日' : '明日')
          .fontSize(this.isSmall() ? 10 : 12)
          .fontColor($r('app.color.card_text_primary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.card_chip_bg'))
          .borderRadius(10)
          .margin({ left: 4 })
          .onClick(() => {
            console.info('[WidgetCard] click toggle_day, isTomorrow=' + this.isTomorrow);
            postCardAction(this, {
              action: 'message',
              params: {
                message: 'toggle_day'
              }
            });
          })
      }
      .width(this.FULL_WIDTH_PERCENT)

      Divider()
        .color($r('app.color.card_divider'))
        .margin({ top: this.isSmall() ? 4 : 6, bottom: this.isSmall() ? 4 : 6 })

      if (this.stale) {
        this.StateView('打开应用刷新')
      } else if (!this.isLoggedIn) {
        this.StateView('未登录')
      } else if (this.errorType.length > 0) {
        this.StateView(this.error)
      } else if (this.allFinished) {
        this.StateView('今日课程已结束')
      } else if (this.getItems().length === 0) {
        this.StateView('暂无课程')
      } else {
        // 用 List 渲染全部日程：多门课时卡片内可上下滑动查看。
        List({ space: 0 }) {
          ForEach(this.getItems(), (item: CardItem) => {
            ListItem() {
              this.ScheduleRow(item)
            }
          }, (item: CardItem) => item.startTime + item.endTime + item.name + item.place)
        }
        .width(this.FULL_WIDTH_PERCENT)
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width(this.FULL_WIDTH_PERCENT)
    .height(this.FULL_HEIGHT_PERCENT)
    .padding(this.isSmall() ? 8 : 12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .onClick(() => {
      console.info('[WidgetCard] click whole card -> router');
      postCardAction(this, {
        action: 'router',
        bundleName: 'com.xdyou.hmos',
        moduleName: 'entry',
        abilityName: 'EntryAbility',
        params: {}
      });
    })
  }
}
