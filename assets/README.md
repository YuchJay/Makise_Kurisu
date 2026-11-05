# 素材源文件

`source/` 保存当前素材管线需要的正式输入：

- `typing-outfit-02.png`：用户选定的模型原图，服装参考原动画角色页截图。
- `typing-face-approved.png`：用户最终确认的 96 × 104 逻辑像素图片。
- `outfit-generation-prompt.txt`：服装生图提示词。
- `face-polish-record.json`：最终下巴微调的来源记录。

原始 Petdex 动作与运行时图集保存在 `KurisuDesktop/Resources/`。
完整来源及动画处理见 `docs/ASSETS.md`。

`face-polish-record.json` 中的旧文件名属于历史预览记录；
较早的过程稿已归入本机 `work/archive/artwork/`，不参与构建或提交。
正式构建只使用仓库中的文件，不需要本机历史归档或 API 密钥。
