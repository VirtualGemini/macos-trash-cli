# macos-trash-cli

[English](README.md) | 简体中文

像使用 `rm` 一样使用它，让文件进入 macOS 废纸篓。命令名是 `tc`：

```sh
tc report.txt build/
```

`tc` 将文件和目录移入废纸篓，不执行永久删除。误删后，只要项目仍在废纸篓中，就能在 Finder 中找到它们。
移入废纸篓不会立即释放磁盘空间。

## 安装

要求 macOS 13+。Homebrew 会从源码构建，需要 Xcode 或 Command Line Tools 提供的 Apple Swift 6+
工具链，可用 `xcrun swift --version` 检查。工具链本身可能要求更高版本的 macOS。

```sh
brew install VirtualGemini/tap/macos-trash-cli-beta
tc --version
```

当前版本：**v0.1.0-beta.1**。beta formula 安装的命令仍是 `tc`，正式版 formula 尚未发布。
首次移入废纸篓时，macOS 可能要求允许终端或 `tc` 控制 Finder。

也可以从 [GitHub Releases](https://github.com/VirtualGemini/macos-trash-cli/releases/tag/v0.1.0-beta.1)
下载兼容 Apple Silicon 和 Intel 的通用二进制包，并验证配套的 SHA-256 文件。
这些二进制文件未经 Apple 签名，首次运行可能需要在 Gatekeeper 中允许打开。

## 特性

- **系统废纸篓：**移动文件和整个目录；移动符号链接本身，不跟随其目标。
- **安全检查：**拒绝以 root 身份运行，保护 `/`、用户主目录、当前目录，并拒绝 `..` 等显式父目录表达式。
  强制选项也不能绕过这些检查。
- **操作预览：**通过 `--dry-run` 查看计划，不移动任何项目。
- **确认策略：**支持智能确认、整批确认、逐项确认或不询问。
- **有序批处理：**按输入顺序处理，可在某项失败后继续，也可遇错停止。
- **脚本支持：**输出包含精确废纸篓目标路径的 JSON 结果，也支持详细输出和安静模式。

## 常见使用场景

### 替代终端里的 `rm` 命令

使用 zsh 时，在 `~/.zshrc` 中加入这一行，让 `rm` 调用 `tc`：

```sh
alias rm='tc'
```

执行 `source ~/.zshrc` 或打开新的 zsh 终端，就能继续使用熟悉的命令：

```sh
rm report.txt                   # 将文件移入废纸篓
rm -rf build/                   # 不询问，将整个目录移入废纸篓
rm --dry-run report.txt build/   # 先预览，再决定是否移动
```

这会设置 shell 别名，不会修改 `/bin/rm`。别名只在加载它的 shell 中生效；脚本和 Agent 仍可能直接调用
原始 `rm`。支持的参数与兼容差异见下方命令参考。

### Agent 误删文件后，从废纸篓找回来

当 Agent **通过 `tc`** 误删文件时，只要文件仍在废纸篓中，你就可以找到并恢复它们。
应明确要求 Agent 调用 `tc`，仅设置终端别名不能覆盖所有 Agent 命令。例如，在项目的 `AGENTS.md` 中加入：

```text
删除文件时使用 tc 代替 rm。无人值守操作使用：
tc --json --non-interactive --confirm=never -- <路径>
```

这适用于通过 `tc` 执行的移除操作；直接调用删除 API 或覆写文件不在其保护范围内。

### 让 Finder 保留“放回原处”

成功移入废纸篓，并不总意味着 Finder 会提供“放回原处”。我们修复了已复现的问题场景，包括文件恢复后
立即再次移入废纸篓，以及通过系统废纸篓 API 移动符号链接时丢失“放回原处”的情况。修复作用于 `tc` 移动的项目。

这些恢复场景已通过[本地 macOS 验收](docs/release-acceptance-v0.1.0.md#finder-recovery-evidence)。
并非每个磁盘卷或失败场景都能保证“放回原处”可用。

## 命令参考

```text
用法：
  tc [选项] [--] <路径>...
  tc --help [-a] [-zh]
  tc --version

确认策略：
  -f, --force             不询问，并忽略不存在的路径
  -i, --interactive       逐项确认
  -I                      超过 3 个输入或包含目录时，整批确认一次
      --confirm=<模式>    指定确认策略：
                            smart  多个输入或包含目录时确认一次（默认）
                            never  不询问
                            once   整批确认一次
                            each   逐项确认

操作控制：
      --dry-run           只预览，不移动任何项目
      --ignore-missing    忽略不存在的路径，不改变确认策略
      --non-interactive   如果需要确认提示，则直接失败
      --stop-on-error     首项失败后停止，跳过后续输入
      --strict-options    拒绝无效果的兼容选项，包括 -P
  --                      结束选项解析，用于以连字符开头的路径

输出：
  -v, --verbose           输出每个顶层项目的结果
      --quiet             抑制正常输出，保留警告和错误
      --json              向 stdout 输出一个完整 JSON 文档，诊断信息写入 stderr

信息：
      --help              显示原生帮助
  -a                      与 --help 配合：显示兼容选项
  -zh                     与 --help 配合：显示中文帮助
      --version           显示已安装版本

rm 兼容选项：
  -r, -R, -d, -x          接受但无效果；目录作为整体移动
  -P                      警告：不执行安全覆写
  -W                      不支持，返回用法错误

退出码：
  0  成功（包括移动成功但附带警告）
  1  操作失败或安全检查拒绝
  64 参数或命令用法错误
```

`--json` 与 `--quiet` 不能同时使用。操作类短选项可以组合，例如 `-iv`。
需要确认时必须有 TTY；脚本中可使用 `--non-interactive --confirm=never`。

## 更多示例

```sh
tc -i report.txt build/   # 逐项确认
tc -- -leading-hyphen     # 处理以连字符开头的文件名
tc --help -a -zh          # 查看中文兼容选项帮助
```

详细行为见[帮助约定](docs/help.md)。参与开发请阅读[开发指南](docs/development.md)和
[贡献指南](CONTRIBUTING.md)。这些技术文档以英文为准。

采用 [Apache-2.0](LICENSE) 许可证。另见 [NOTICE](NOTICE) 和[安全策略](SECURITY.md)。
