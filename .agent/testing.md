# 测试

目标是快速闭环，不是每次改一行都跑全仓库。默认顺序是语法检查、受影响用例、最后完整套。测试本身很快（Rust 约 1 秒，Flutter widget 约 4 秒），真正耗时的是反复准备 Flutter SDK 和生成截图。

## 快速检查

```
cargo check -p app -p tui -p bridge
/opt/flutter/bin/cache/dart-sdk/bin/dart analyze flutter/lib flutter/test
```

`dart analyze` 不需要可写 Flutter SDK，直接指向 SDK 里的 dart 即可。Rust 模块级过滤：

```
cargo test -p app config::output
cargo test -p app config::map
cargo test -p tui tui::settings
```

Flutter 局部用例：

```
flutter test test/interaction_test.dart --plain-name "menu"
flutter test test/interaction_test.dart --plain-name "output"
flutter test test/interaction_test.dart --plain-name "settings"
```

菜单、文案、单个布局这种改动只看对应 `testWidgets`，不要跑截图/golden。测试用例里的 AppShell 有持续 ticker，`pumpAndSettle` 会超时；菜单动画用固定 `pump`，`interaction_test.dart` 的 `settleMenu` 就是干这个的。

## Flutter SDK 环境

本机的 `/opt/flutter` 和 `~/.cache/flutter_sdk` 是只读 unionfs，直接跑 `flutter test` 会在 `engine.stamp` 上失败。可以一次性复制到工作区再复用，`.cache` 已在 `.gitignore` 里：

```
cp -a --reflink=auto /opt/flutter .cache/flutter_sdk
env CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
  PUB_CACHE="$PWD/.cache/pub" \
  XDG_CONFIG_HOME="$PWD/.cache/xdg-config" \
  XDG_CACHE_HOME="$PWD/.cache/xdg-cache" \
  .cache/flutter_sdk/bin/flutter test test/widget_test.dart test/interaction_test.dart
```

这份副本约 2.3G，一次会话里保留，测试完再删，不要每轮重新复制。`PUB_CACHE` 和 XDG 目录也放工作区，避免写 `~/.pub-cache` / `~/.dart-tool` 被只读挂载挡掉。如果以后拿到可写的 Flutter SDK 路径，直接把 `PATH` 指过去，不再需要复制。

## 完整验证

收尾时跑：

```
cargo test -p app -p tui
flutter test test/widget_test.dart test/interaction_test.dart
```

`golden_test.dart` 需要 `test/goldens/*.png`，仓库里缺参考图时本来就会失败，不作为门槛。临时截图、临时 golden 用完就删，不提交。

## 生成绑定

只有改了 `crates/bridge/src/api.rs` 或需要更新 DTO 时才重跑：

```
PATH="$PWD/.cache/flutter_sdk/bin:$PATH" \
  ~/.cargo/bin/flutter_rust_bridge_codegen generate \
  --config-file flutter_rust_bridge.yaml
```

Rust 和 Dart 的 `flutter_rust_bridge` 锁在 2.13.0。生成物 `crates/bridge/src/frb_generated.rs` 和 `flutter/lib/bridge/generated/` 都提交，不手改。codegen 若被 SDK 版本检查卡住，同样用 `CI=true FLUTTER_SUPPRESS_ANALYTICS=true` 和上面的 SDK 副本路径。

## 常见坑

不要在仓库全局跑 `cargo fmt --all`；仓库里有不少和当前 rustfmt 版本不一致的旧格式，全量格式化会带出无关 diff。只格式化新增文件，或让现有格式保持原样。

TUI 的 guide/settings 测试会写系统临时目录，不要留下用户路径的 fixture。Flutter 只读环境失败时先确认是不是 `/opt` 的只读缓存，不要反复重跑同一条命令。菜单视觉检查用一次性临时截图看，看完删除；功能正确性以 widget 测试和 `dart analyze` 为准。
