# 独立仿真目录规则

- 用户指定 MATLAB R2024b；Windows入口使用 run_R2024b.ps1。
- 所有新增独立仿真脚本、配置、测试、报告和输出保留在本目录，使用 +iceind 命名空间。
- 不调用 VSX、activate、硬件操作或编辑 license.enc；不把整个仓库递归加入 MATLAB path。
- 原软件参数只能标为 existing_code_unverified；合成目标标为 synthetic，模型假设标为 assumed，未验证物理能力为 unknown。
- 区分解析基准、独立传播求解、厂商序列验证和实测；内部定位通过不得写成实物精度、固化或安全结论。
- 后续工具包接口和许可说明也放本目录。根目录CHANGELOG仅链接本目录报告。
