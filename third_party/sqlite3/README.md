# SQLite amalgamation

- 版本：3.54.1（2026）
- 来源：https://www.sqlite.org/2026/sqlite-amalgamation-3540100.zip
- 文件：`sqlite3.c`、`sqlite3.h`
- 许可：SQLite 为公共领域（public domain），见 https://sqlite.org/copyright.html

## 为什么放在仓库里

`package:sqlite3` 的默认构建钩子会从 GitHub Releases 下载预编译库。当前网络访问 GitHub 不稳定，改为在本地用这份 amalgamation 编译，Windows 与 Android 都不再依赖下载。

构建配置见 `pubspec.yaml`：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: source
      path: third_party/sqlite3/sqlite3.c
```

升级 SQLite 时替换 `sqlite3.c` / `sqlite3.h`，并同步更新本文件的版本与来源。
