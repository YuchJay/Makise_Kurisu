# 阶段记录

## 0.8.6：严格区分打字与快捷操作

- 改为逐事件按键分类；聚合计数只更新一般活动，不再作为打字兜底。
- Cmd/Ctrl/Option/Fn/Help 排除；Shift/Caps Lock 保留。方向、功能键、Tab 等
  不触发打字。按住快捷键期间的字母键，必须释放后才能重新参与判断。
- 0.8 秒内两个独立文字键按下确认一轮打字；单键自动重复不能起动。
  空格、回车和删除仅可延续 1.1 秒内已确认的打字。
- 快捷操作、鼠标点击/滚动、安全输入及监听中断清除打字状态；
  事件监听未连接时不再仅凭计数将状态显示为监听成功。
- 不读取输入文字，不持久化按键序列；内存仅暂存按住/被抑制的键及判断时机。
- 属于按键行为判断，不承诺验证文字已插入输入框；游戏字母连按仍可能误判，
  很慢的零散输入则可能不启动。未申请额外辅助功能权限。
- 0.8.6 已成功编译并打开；未添加或运行自动化测试。

## 0.8.5：情境气泡文案

- 用户确认角色口吻方案后，替换全部 22 类功能事件的随机台词。
- 日常反馈干练、有轻微吐槽；休息提醒更明确，关心通过行动和补充表达。
- 作品梗仅保留少量情境用语，不反复使用口吃和“才不是为了你”。
- 不使用“观察到皱眉”等应用无法感知的描述；失败反馈保留排查方向。
- 沿用同事件避免连续重复、剪贴板自动反馈限流及休息提醒按钮机制。
- 0.8.5 已成功编译并打开；未添加或运行自动化测试。

## 2026-11-05：收尾整理

- 补齐 0.8.4 更新说明及 README 的当前功能、素材重建命令。
- 正式源码、运行素材、生成输入、脚本和文档继续分目录保存。
- 删除编译缓存、渲染临时文件、旧 Git 索引备份、Python 缓存及过时预览，
  共清理约 287.23 MiB；历史素材归档保留在本地 work/archive。
- 保留 outputs/Kurisu.app 的路径和当前正式预览，新增本地输出索引；
  中间缩放参考图改为写入 work，避免与正式素材混淆。
- .gitignore 已覆盖这些本地产物，应用用户数据不属于项目目录。
- 本次整理未改变应用行为，未添加或运行自动化测试。

## 0.8.4：打字形态略微放大

- 复核发现旧版打字额头区域约 98–100 像素宽，普通待机约 108；
  之前宽度一致的测量包含了打字形态较低处的长发外缘，不能代表视觉上一致。
- 按用户要求将打字形态整体再放大约 5%，内容从 155 × 168 改为 163 × 176；
  从原始已确认 A6 素材一次最近邻缩放，保留脸型和五官。
- 同步重建进入、打字、等待、退出图集；手腕和头部呼吸区域随尺寸映射，
  避免放大后动作区域错位或带动电脑边缘。
- 已查看待机/调整前/调整后的同尺寸对照；调整后额头区域约 104–106 像素，
  更接近待机，因低头角度和头型不同不宣称所有轮廓完全相等。
- 0.8.4 已编译并打开；未添加或运行自动化测试。

## 0.8.3：恢复点击动作

- 点击小人同时播放原有开心动作并切换随手工具；恢复点击的动画反馈。
- 显式动作接管上一轮打字状态，新的键盘活动仍可立即进入打字。
- 五帧开心素材逐帧按普通待机的头顶至额头宽度等比缩小；
  不把甩动长发及举起的手纳入头部宽度，使用最近邻保持清晰像素。
- 动作渲染和透明点击区域共用缩放后的图集。
- 已查看实际图集对照，五帧额头宽度与待机相差不超过一个素材像素；
  0.8.3 已编译并打开，未添加或运行自动化测试。

## 0.8.2：工具窗口标题栏

- 移除工具面板的紧凑 utilityWindow 样式，采用标准尺寸的原生标题栏按钮。
- 删除内容区右上角重复的关闭按钮，保留系统关闭按钮和 Esc 收起。
- 已编译并重新打开 0.8.2；工具窗口的辅助功能树中只保留系统关闭按钮。
- 未添加或运行自动化测试。

## 0.8.1：实际悬浮信息卡

- 替换原先仅设置 `toolTip` 的实现，新增 304 × 270 原生非激活悬浮面板。
- 指针停留在小人有效像素约 0.45 秒后显示，复用点击穿透判定，
  不依赖透明窗口上不稳定的鼠标 tracking 事件。
- 展示最近便签两行摘要、暂存数、剪贴板数、休息和保持唤醒状态；
  剪贴板不在悬浮时展示内容。
- 指针可移进卡片使用入口；离开小人与卡片 0.32 秒后收起。
- 拖动、隐藏、锁屏、熄屏或说话气泡出现时收起，工具打开期间不显示。
- 只有显式点击入口才激活编辑工具；悬浮不抢键盘焦点、不触发说话。
- 源码编译完成；未添加或运行自动化测试。

## 项目目录整理与首次提交

- 将正式素材输入归入 assets/source，构建和素材脚本不再依赖历史 outputs 目录。
- 文档归入 docs，版本说明归入 docs/releases。
- 试作图和旧脚本保留在本地 work/archive，不提交到仓库。
- 清理编译缓存、Python 缓存、Finder 元数据和过期压缩包约 223 MiB。
- 新增 .gitignore，排除应用包、导出文件、缓存、日志、密钥和运行时用户数据。
- 本次仅整理文件与素材路径，未修改应用功能；未运行自动化测试。

## 0.8.0：随手工具与情境气泡

- 用户授权五项实用功能和符合角色语气的随机情境气泡。
- 新增可编辑原生工具面板：便签、暂存、剪贴板、专注四个页签。
- 便签本地持久化，可添加、编辑、复制和删除。
- 文件/文件夹以独立副本暂存；链接和文字也可暂存，支持拖入、
  复制、拖出、打开、定位和移除；磁盘复制在后台完成并反馈错误。
- 剪贴板历史仅驻留内存，最多 40 条，支持文字、文件引用、图片，
  图片总量上限 32 MB；可暂停、检索、清空或加入暂存。
- 跳过标准机密/临时标记和安全输入期间的剪贴板变化。
- IOKit 电源断言实现限时保持唤醒，默认屏幕仍可按系统设置熄灭；
  可选择同时保持屏幕，支持手动结束，到时或退出释放断言。
- 估算交互使用时长，默认 50/2 分钟；锁屏、睡眠、熄屏不计入，
  离开达到休息时长重置，支持主动休息及五分钟延后。
- 每类事件有随机台词且避免相邻重复；被动复制气泡限流，
  休息气泡附按钮，普通反馈自动消失且不抢输入焦点。
- 工具面板通过点击或菜单打开，拖入内容可自动打开暂存页；
  工具可以接收键盘焦点，气泡保留非激活窗口。
- 兼容本地 SwiftUI 工具链：草稿状态使用 ObservableObject，
  不依赖当前缺失的 State 宏插件。
- 已完成本机编译并打开工具面板；未添加或运行自动化测试。
- CUA 可读到工具面板的便签控件，但其截图始终返回桌宠窗口，
  因此没有将桌宠截图冒充工具面板的视觉验收证据。
- 现有设计辅助索引较 DESIGN.md 陈旧，本轮沿用原生界面；
  未扩展本次任务去修复旧的设计索引。

## 0.7.0：最终 A6 脸型与精细打字动画

- 用户确认 A6（保留柔和左侧、右侧稍恢复外扩）并授权修改应用。
- 动画使用已确认的逻辑图片，直接一次缩放至最终 155 × 168 内容；
  不再先缩至低分辨率再放大，保留用户在预览中确认的下巴台阶。
- 图集扩为 16 列 × 4 行，进入 12 帧、打字 16 帧、等待 12 帧、
  退出 12 帧，剩余单元以末帧补齐。
- 手腕与袖口采用一至二输出像素的预备、按压、回弹、停顿节奏；
  等待呼吸按 3.6 秒循环，五官整块移动不重画。
- 进入/退出采用缓入缓出且对齐头顶，降低不同高度脸部的重影。
- 播放时钟提高至 24 Hz；其他原动作仍按各自原有时间参数播放。
- 同步扩展图集加载及所有帧的透明点击区域。
- 未添加或运行自动化测试。
- 0.7.0 已成功编译、本地签名，并通过系统打开新版应用。

## 0.6.0：接入动漫服装 02，统一头部大小

- 用户选择原动画双参考生图 02，授权修改应用。
- 打字使用该模型原图，只去除外连背景、等比缩放并制作既有轻微动作；
  不重画眼睛、衣服或脸部，也不回贴原图的局部身体。
- 普通待机头部作为基准，打字素材等比缩至约 80.6%，坐定休息约
  76–77%；坐下过程逐帧匹配头部大小，避免整套固定缩放后入场头部过小。
- 新增独立休息图集；显示与透明区域点击使用同一组缩放后的图片。
- 保留当前键盘响应、休息呼吸/点头及进入退出逻辑。
- 输出三状态同比例对比图和最新打字动画预览。
- 本轮不添加或运行自动化测试。
- 0.6.0 已编译成功、完成本地签名，并通过系统打开新版应用。

## 0.5.0：接入用户通过的 C 高光版本

- 用户通过 C 素材及眼睛小高光版本后，将其接入打字动画。
- 保留批准的眼形、向下视线、眼睛高光、棕红头发和红色电脑。
- 以 96 × 104 逻辑像素制作 192 × 208 帧；使用最近邻放大。
- 八帧敲键包含一逻辑像素的前臂动作及轻微起伏，等待时缓慢呼吸。
- 进入和退出以短暂的淡入淡出配合下沉完成；退出可随再次打字反转。
- 不再使用此前的原图拼接脸部和程序重画眼睛；不添加未经确认的闭眼形状。
- 输入监测逻辑沿用现有实现。本轮未添加或运行自动化测试。
- 0.5.0 已编译成功并重新本地签名；已通过系统打开新版应用。


## 0.4.2：恢复原眼形

- Removed the artificial half-closed eye drawing rejected by the user.
- Preserved original eyes and eyelashes; moved existing iris pixels down 1px.
- Added a 2px head nod consistently to both open-eye and blinking poses.
- Red computer and all existing behavior remain unchanged.

## 0.4.1：低头看屏幕与红色电脑

- Lowered eyelids and pupils in the working frames; preserved head orientation
  and original hair pixels. Original blinking remains in use.
- Changed the computer casing, rim and side shading to a coordinated red palette.
- Regenerated the shipping atlas and preview assets; input behavior unchanged.

## 0.4：重做桌后坐姿打字

- Removed the rotated running head and preserved the entire original idle
  head/body alignment, including original blinking.
- Replaced enlarged palms with tiny round hands at the source pixel scale.
- Added a small wooden table; seated upper body lowers behind it and the
  opaque front panel hides the lower body.
- Laptop shows only its back cover, with no forced screen/keyboard perspective.
- Opening/seating takes 0.90 seconds; closing/rising takes 0.96 seconds.
- Keyboard activity monitoring is unchanged. No automated tests were run.

## 0.3：拿出电脑并面对屏幕打字

- Added a transparent laptop atlas edited from original character pixels.
- Standing body, right-facing head/hair and original palms are reused; the
  laptop, forearm connections and eyelid touches are local raster edits.
- Added opening, typing, waiting and closing phases with reversible progress.
- Short pauses retain the laptop; it closes after 3.2 seconds without typing.
- Added permission-free previews to settings and the existing pose menu.
- Alpha-based hit handling follows the new laptop frames too.
- Original input-monitoring logic is retained.
- Preview GIF and frame contact sheet use the shipping raster frames.
- Version 0.3 compiles successfully and the local app is launched.
- Character art was edited locally; no image generation API was called.
- No automated input tests were requested or run.

## 0.2：用户反馈修正

- Confirmed two behavior defects in source: forced mouse/wave poses outranked
  typing, and sleeping used modulo playback across the stand-up frame.
- Typing now outranks transient reactions and clears a previous forced pose.
- Added authorized aggregate keyboard activity sampling alongside passive
  event callbacks, with secure-input detection and actual-receipt feedback.
- Reconnect now tears down the previous tap before starting a new one.
- Drag direction follows the latest horizontal movement, including reversals.
- Idle rest plays entry frames once, then uses seated breathing and rare nods.
- App now displays its version and helps locate the exact permission target.
- Build now closes this project's running app before replacing its executable.
- Compilation is performed; no automated or synthetic input tests were requested.
- Authorized human keyboard behavior still requires confirmation in the final
  rebuilt app; ad hoc signing can require reauthorizing after this update.

## 第一阶段：素材与环境 — 完成

- Native arm64 Swift compiler available.
- Original Kurisu sheet decoded with alpha; preview inspected on a solid ground.
- Confirmed 8 × 9 layout and 192 × 208 cell geometry.
- Original installed pet remains the asset source.

## 第二阶段：桌面表现 — 已实现，编译成功

- Transparent nonactivating floating panel, nearest-neighbor frame drawing.
- Nine existing poses, click, drag, size, reposition and alpha-based pass-through.
- Menu bar access and native Chinese settings.

## 第三阶段：系统联动 — 已实现，等待用户授权后体验

- Passive CGEvent tap, event categories and input timing only.
- Typing speed, pixel keyboard, pointer proximity, click and scroll reactions.
- 90-second sleep, pause, hide, reduced motion, sleep/wake handling.
- Opt-in SMAppService login startup with live status and error reporting.
- Size, position and preferences persisted through UserDefaults.

## 第四阶段：本地应用交付 — 首版已生成

- `outputs/Kurisu.app` compiled and locally signed.
- Initial app process was observed running.
- Settings window was captured and visually inspected.
- During implementation, fixed startup status wording and initial position saves,
  and removed residual purple chroma-matte fringes from the sprite alpha edge.
- No automated tests or permission-granted keyboard exercise were run.
- User input permission and login after restart remain unconfirmed.

## 视觉记录范围

The in-thread visual pass used the supplied original pixel frame and a captured
native settings window. It is not an independent agent review. No web detector
was run against native Swift code. The final settings screenshot should reflect
the final build; earlier captures are intermediate evidence only.
